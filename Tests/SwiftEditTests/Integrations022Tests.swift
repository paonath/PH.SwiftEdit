import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

/// Spec 022: two-tab Compare, grey gutter, theme in the SwiftEdit menu, palette outside-click, double-click cycle.
@Suite("Integrations022Tests", .serialized)
@MainActor
struct Integrations022Tests {

    private static func workspace() throws -> (model: SwiftEditWorkbenchModel, dir: URL, a: URL, b: URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("cmp022-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let a = dir.appendingPathComponent("a.md")
        let b = dir.appendingPathComponent("b.md")
        try "one\ntwo\nthree\n".write(to: a, atomically: true, encoding: .utf8)
        try "one\nTWO\nthree\nfour\n".write(to: b, atomically: true, encoding: .utf8)
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: dir.appendingPathComponent("rec"),
            fileSystem: LocalFileSystemAdapter(),
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
        model.openFile(at: b, withinScope: dir)
        model.openFile(at: a, withinScope: dir)
        return (model, dir, a, b)
    }

    private static func rhsText(_ model: SwiftEditWorkbenchModel) -> String {
        model.diffCoordinator.rows.compactMap(\.rhsText).joined(separator: "|")
    }

    // MARK: Compare

    @Test("P-CMP1: Compare opens on the active tab as source and compares saved vs current without a destination")
    func pCompareSavedVersusCurrent() throws {
        let (model, dir, _, _) = try Self.workspace()
        defer { try? FileManager.default.removeItem(at: dir) }
        model.handleEditorTextChanged("one\ntwo\nthree\nedited\n")
        model.toggleDiffPane()
        #expect(model.compareSourceTabID == model.tabSession.activeTabID)
        #expect(model.compareDestinationTabID == nil)
        #expect(Self.rhsText(model).contains("edited"))
        #expect(model.diffCoordinator.hasDifferences)
    }

    @Test("P-CMP2: picking another open tab compares source vs destination; the destination tab stays open")
    func pCompareTwoTabs() throws {
        let (model, dir, _, _) = try Self.workspace()
        defer { try? FileManager.default.removeItem(at: dir) }
        model.toggleDiffPane()
        let source = try #require(model.compareSourceTabID)
        let candidates = model.compareDestinationCandidates
        #expect(!candidates.contains { $0.id == source })
        let destination = try #require(candidates.first { $0.title == "b.md" })
        model.setCompareDestination(destination.id)
        #expect(model.compareDestinationTabID == destination.id)
        #expect(Self.rhsText(model).contains("TWO") && Self.rhsText(model).contains("four"))
        #expect(model.tabSession.tabs.contains { $0.id == destination.id })
        #expect(model.tabSession.activeTabID == source)
    }

    @Test("N-CMP1: X (nil destination) and closing the destination tab return to saved vs current; source can't be its own destination")
    func nCompareDestinationRemoval() throws {
        let (model, dir, _, _) = try Self.workspace()
        defer { try? FileManager.default.removeItem(at: dir) }
        model.toggleDiffPane()
        let source = try #require(model.compareSourceTabID)
        model.setCompareDestination(source)
        #expect(model.compareDestinationTabID == nil)
        let destination = try #require(model.compareDestinationCandidates.first)
        model.setCompareDestination(destination.id)
        model.setCompareDestination(nil)
        #expect(model.compareDestinationTabID == nil)
        #expect(model.diffCoordinator.hasDifferences == false) // saved == current
        model.setCompareDestination(destination.id)
        model.requestCloseTab(id: destination.id)
        model.refreshCompare()
        #expect(model.compareDestinationTabID == nil)
        #expect(model.compareSourceTabID == source)
    }

    // MARK: Gutter, menu, palette

    @Test("P-GUT2: line numbers render at 85% of the editor size on a grey surface distinct from the canvas")
    func pGutterStyle() {
        #expect(LineNumberGutterView.numberScale == 0.85)
        for mode in [AppearanceMode.light, .black] {
            let palette = PurpleThemePalette.resolve(appearance: mode)
            #expect(palette.gutterSurface != palette.editorCanvasBackground)
            #expect(palette.gutterForeground.contrastRatio(against: palette.gutterSurface) >= 4.5)
        }
    }

    @Test("P-MENU1: the SwiftEdit menu offers Light/Dark/Auto with a check on the active mode and switches it")
    func pThemeInSwiftEditMenu() {
        let items = HeaderCommandCatalog.items(canSave: true, canFormat: true, showMarkdownPreview: false, appearanceMode: .black)
        let appearance = items.filter { [.appearanceLight, .appearanceDark, .appearanceAuto].contains($0.id) }
        #expect(appearance.count == 3)
        #expect(appearance.filter(\.isChecked).map(\.id) == [.appearanceDark])
        #expect(items.last?.id == .showCheatSheet)
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: FileManager.default.temporaryDirectory.appendingPathComponent("m022-\(UUID().uuidString)"),
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
        model.appearanceMode = .light
        model.performHeaderCommand(.appearanceAuto)
        #expect(model.appearanceMode == .auto)
        model.performHeaderCommand(.appearanceDark)
        #expect(model.appearanceMode == .black)
    }

    @Test("P-CTX1: a click outside the palette closes it like Esc (selection restored, no edit)")
    func pPaletteOutsideClick() throws {
        let source = AuditReportFitness.read("Sources/SwiftEditUI/Views/ElementContextualMenuView.swift")
        let catcher = try #require(source.range(of: ".onTapGesture { model.closeElementContextualMenu() }"))
        let paletteCall = try #require(source.range(of: "palette(state: state)\n                        .offset"))
        #expect(catcher.lowerBound < paletteCall.lowerBound) // catcher sits below the palette in the ZStack
    }

    // MARK: Double-click cycle

    @Test("P-DBL1: word -> whitespace-free token (brackets/quotes/punctuation trimmed) -> no selection")
    func pDoubleClickCycle() {
        let text = "see (contextual-menu). now" as NSString
        let word = TextRange(location: text.range(of: "contextual").location, length: 10)
        let token = DoubleClickSelectionCycle.token(around: word, in: text)
        #expect(text.substring(with: NSRange(location: token.location, length: token.length)) == "contextual-menu")
        #expect(DoubleClickSelectionCycle.outcome(previous: TextRange(location: 0, length: 0), word: word, token: token) == .selectWord)
        #expect(DoubleClickSelectionCycle.outcome(previous: word, word: word, token: token) == .selectToken(token))
        #expect(DoubleClickSelectionCycle.outcome(previous: token, word: word, token: token) == .deselect(caret: word.location))
        // A plain word is its own token: the second double-click deselects.
        let plain = TextRange(location: 0, length: 3)
        #expect(DoubleClickSelectionCycle.outcome(previous: plain, word: plain, token: DoubleClickSelectionCycle.token(around: plain, in: text)) == .deselect(caret: 0))
    }

    @Test("N-DBL1: empty words and other previous selections keep the system word selection")
    func nDoubleClickGuards() {
        let text = "a b" as NSString
        #expect(DoubleClickSelectionCycle.outcome(previous: TextRange(location: 0, length: 1), word: TextRange(location: 0, length: 0), token: TextRange(location: 0, length: 0)) == .selectWord)
        #expect(DoubleClickSelectionCycle.token(around: TextRange(location: 5, length: 2), in: text) == TextRange(location: 5, length: 2))
        #expect(DoubleClickSelectionCycle.outcome(previous: TextRange(location: 2, length: 1), word: TextRange(location: 0, length: 1), token: TextRange(location: 0, length: 1)) == .selectWord)
    }

    @Test("P-DBL2: the editor text view applies the cycle on a real NSTextView word range")
    func pDoubleClickInTextView() {
        _ = NSApplication.shared
        let textView = SwiftEditNSTextView(usingTextLayoutManager: true)
        textView.string = "see contextual-menu now"
        let wordStart = ("see contextual-menu now" as NSString).range(of: "contextual").location
        let outcome = textView.doubleClickOutcome(atCharacterIndex: wordStart + 2, previous: NSRange(location: wordStart, length: 10))
        #expect(outcome == .selectToken(TextRange(location: wordStart, length: 15)))
        let again = textView.doubleClickOutcome(atCharacterIndex: wordStart + 2, previous: NSRange(location: wordStart, length: 15))
        #expect(again == .deselect(caret: wordStart))
    }
}
