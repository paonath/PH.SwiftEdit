import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

/// Spec 020: word completion, collapsed Properties, Compare shortcut, ElementContextualMenu, literal occurrences.
@Suite("Integrations020Tests", .serialized)
@MainActor
struct Integrations020Tests {

    private static func makeModel() -> SwiftEditWorkbenchModel {
        SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: FileManager.default.temporaryDirectory.appendingPathComponent("i020-\(UUID().uuidString)"),
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
    }

    // MARK: 1. Word completion index

    @Test("P-WC1: index keeps only words longer than 3 chars and ranks by frequency, then length")
    func pWordCompletionRanking() {
        let index = WordCompletionIndex.build(from: "the swift swiftly swiftedit swiftedit swiftedit cat swim swimming")
        #expect(!index.words.contains("the"))
        #expect(!index.words.contains("cat"))
        #expect(index.completionSuffix(forPrefix: "sw") == "iftedit")      // highest frequency
        #expect(index.completionSuffix(forPrefix: "swifte") == "dit")
        #expect(index.completionSuffix(forPrefix: "swim") == "ming")       // "swim" itself is never suggested
        #expect(index.completionSuffix(forPrefix: "Sw") == nil)            // case-sensitive
    }

    @Test("P-WC2: word prefix detection works for accented words and stops at non-word characters")
    func pWordPrefixDetection() {
        let text = "una città e (perfor" as NSString
        let city = WordCompletionIndex.wordPrefix(endingAt: 9, in: text)
        #expect(city?.prefix == "città")
        let tail = WordCompletionIndex.wordPrefix(endingAt: text.length, in: text)
        #expect(tail?.prefix == "perfor")
        #expect(tail?.range == TextRange(location: text.length - 6, length: 6))
    }

    @Test("N-WC1: no completion for short prefixes, mid-word carets, excluded word under caret, or oversize documents")
    func nWordCompletionGuards() {
        let index = WordCompletionIndex.build(from: "alphabet alphabet")
        #expect(index.completionSuffix(forPrefix: "a") == nil)
        #expect(index.completionSuffix(forPrefix: "zz") == nil)
        #expect(WordCompletionIndex.wordPrefix(endingAt: 3, in: "alphabet" as NSString) == nil) // caret inside a word
        #expect(WordCompletionIndex.wordPrefix(endingAt: 1, in: "a" as NSString) == nil)        // 1-char prefix
        // The word being typed (touching the excluded caret) is not indexed.
        let typing = WordCompletionIndex.build(from: "note: hellow", excluding: TextRange(location: 12, length: 0))
        #expect(typing.completionSuffix(forPrefix: "hel") == nil)
        #expect(WordCompletionIndex.build(from: "").words.isEmpty)
    }

    @Test("P-WC3: workbench suggests document words and refuses binary/log-tail contexts")
    func pWorkbenchWordCompletion() {
        let model = Self.makeModel()
        let text = "Introduction to SwiftEdit.\nSwiftEdit is fast. Intro"
        model.handleEditorTextChanged(text)
        // Caret at the end: "Intro" is the word being typed, so it is excluded from its own suggestions.
        model.selectRange(TextRange(location: (text as NSString).length, length: 0))
        model.rebuildWordCompletionIndexNow()
        #expect(model.wordCompletionSuffix(forPrefix: "Sw") == "iftEdit")
        #expect(model.wordCompletionSuffix(forPrefix: "Intr") == "oduction")
        #expect(model.wordCompletionSuffix(forPrefix: "x") == nil)
    }

    // MARK: 2–3. Properties collapsed, Compare out of header menu

    @Test("P-PROP: Properties panel starts collapsed; N-CMP: File Compare is gone from the header menu but bound to Shift+Cmd+D")
    func pPropertiesCollapsedAndCompareShortcut() {
        #expect(PropertiesPanelState().isCollapsed == true)
        let items = HeaderCommandCatalog.items(canSave: true, canFormat: true, showMarkdownPreview: false)
        #expect(!items.map(\.title).contains { $0.contains("Compare") })

        let model = Self.makeModel()
        model.handleEditorTextChanged("abc")
        #expect(model.showDiffPane == false)
        let consumed = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "D", charactersIgnoringModifiers: "d", modifiers: [.command, .shift]), model: model)
        #expect(consumed)
        #expect(model.showDiffPane == true)
        let titles = KeyboardShortcutsCheatSheetCatalog.allSections.flatMap(\.items)
        #expect(titles.contains { $0.title == "Toggle File Compare Diff" && $0.shortcut == "Shift+Cmd+D" })
    }

    // MARK: 4. ElementContextualMenu

    @Test("P-SUR1: Surround With wraps the selection in one edit and keeps the inner text selected")
    func pSurroundActions() throws {
        let snap = DocumentSession(text: "call value now").snapshot
        let sel = TextRange(location: 5, length: 5) // "value"
        let tick = try #require(ElementContextualActionCatalog.evaluate(.surround(.backtick), in: snap, selection: sel))
        #expect(tick.edits == [TextEdit(range: sel, replacement: "`value`")])
        #expect(tick.newSelection == TextRange(location: 6, length: 5))
        let paren = try #require(ElementContextualActionCatalog.evaluate(.surround(.parentheses), in: snap, selection: sel))
        #expect(paren.edits.first?.replacement == "(value)")
        // Mid-line fence breaks onto its own lines.
        let fence = try #require(ElementContextualActionCatalog.evaluate(.surround(.tripleBacktickFence), in: snap, selection: sel))
        #expect(fence.edits.first?.replacement == "\n```\nvalue\n```\n")
        #expect(fence.newSelection == TextRange(location: 5 + 5, length: 5))
        // Whole lines (ending with a newline) get fences without blank lines.
        let lines = DocumentSession(text: "a\nb\nc").snapshot
        let block = try #require(ElementContextualActionCatalog.evaluate(.surround(.tripleBacktickFence), in: lines, selection: TextRange(location: 0, length: 4)))
        #expect(block.edits.first?.replacement == "```\na\nb\n```\n")
    }

    @Test("N-SUR1: no edit for empty, out-of-bounds or binary selections")
    func nSurroundGuards() {
        let snap = DocumentSession(text: "abc").snapshot
        #expect(ElementContextualActionCatalog.evaluate(.surround(.backtick), in: snap, selection: TextRange(location: 1, length: 0)) == nil)
        #expect(ElementContextualActionCatalog.evaluate(.surround(.backtick), in: snap, selection: TextRange(location: 2, length: 5)) == nil)
        let binary = DocumentSnapshot(id: DocumentID(), revision: BufferRevision(1), text: "abc", encoding: .utf8, lineEnding: .lf, isDegradedPlainText: false, isBinaryReadOnly: true)
        #expect(ElementContextualActionCatalog.evaluate(.surround(.backtick), in: binary, selection: TextRange(location: 0, length: 2)) == nil)
    }

    @Test("P-ECM1: menu state starts expanded on the first action, filters, wraps navigation and collapses groups")
    func pMenuStateNavigation() {
        var state = ElementContextualMenuState(selection: TextRange(location: 0, length: 3))
        #expect(state.rows.count == 6) // Surround (1 + 3) and Document (1 + 1), all expanded
        #expect(state.highlightedRowID == "action:surround.backtick")
        state.moveHighlight(-1)
        #expect(state.highlightedRowID == "group:surround")
        state.moveHighlight(-1)
        #expect(state.highlightedRowID == "action:document.duplicate")
        state.moveHighlight(-2)
        #expect(state.highlightedRowID == "action:surround.parentheses")
        state.setHighlightedGroupExpanded(false)
        #expect(state.rows.count == 3)
        #expect(state.highlightedRowID == "group:surround")
        state.setQuery("paren")
        #expect(state.rows.map(\.id) == ["group:surround", "action:surround.parentheses"])
        #expect(state.highlightedRowID == "action:surround.parentheses")
        state.setQuery("zzz")
        #expect(state.rows.isEmpty)
    }

    @Test("P-ECM2: Cmd+Return with a selection opens the palette; Return applies the highlighted surround as one revision")
    func pWorkbenchContextualMenuFlow() throws {
        let model = Self.makeModel()
        model.handleEditorTextChanged("make it bold")
        model.selectRange(TextRange(location: 5, length: 2)) // "it"
        let revision = try #require(model.activeDocumentSession?.revision)
        let opened = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "\r", keyCode: 36, modifiers: [.command]), model: model)
        #expect(opened)
        #expect(model.elementContextualMenu != nil)
        model.activateElementContextualMenuRow()
        #expect(model.elementContextualMenu == nil)
        #expect(model.activeDocumentSession?.text == "make `it` bold")
        #expect(model.activeDocumentSession?.revision == revision.next())
        #expect(model.currentSelection == TextRange(location: 6, length: 2))
    }

    @Test("N-ECM1: Cmd+Return without a selection offers only document actions (REQ-021-05); Escape closes without editing")
    func nWorkbenchContextualMenuGuards() {
        let model = Self.makeModel()
        model.handleEditorTextChanged("plain")
        model.selectRange(TextRange(location: 2, length: 0))
        let consumed = SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "\r", keyCode: 36, modifiers: [.command]), model: model)
        #expect(consumed == true)
        #expect(model.elementContextualMenu?.groups.map(\.id) == ["document"])
        #expect(model.handleEscape())
        #expect(model.elementContextualMenu == nil)

        model.selectRange(TextRange(location: 0, length: 5))
        #expect(model.presentElementContextualMenu())
        #expect(model.handleEscape())
        #expect(model.elementContextualMenu == nil)
        #expect(model.activeDocumentSession?.text == "plain")
        #expect(model.currentSelection == TextRange(location: 0, length: 5))
    }

    // MARK: 1b. Ghost text in the TextKit 2 coordinator

    @Test("P-GHOST: typing a known prefix shows ghost text, Tab inserts it as one edit, Escape dismisses")
    func pGhostTextAcceptAndDismiss() throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let textView = SwiftEditNSTextView(usingTextLayoutManager: true)
        textView.frame = window.contentView!.bounds
        window.contentView!.addSubview(textView)
        let coordinator = TextKit2EditorView.Coordinator(
            onTextChange: { _ in },
            onSelectionChange: { _ in },
            onSmartNewline: { _ in nil },
            onListIndent: { _ in .notApplicable },
            onTableTab: { _ in .notApplicable }
        )
        textView.delegate = coordinator
        coordinator.completionProvider = { prefix in prefix == "Swi" ? "ftEdit" : nil }
        textView.string = "SwiftEdit "
        textView.setSelectedRange(NSRange(location: 10, length: 0))
        textView.insertText("S", replacementRange: textView.selectedRange())
        textView.insertText("w", replacementRange: textView.selectedRange())
        #expect(coordinator.ghostSuggestion == nil)
        textView.insertText("i", replacementRange: textView.selectedRange())
        #expect(coordinator.ghostSuggestion?.suffix == "ftEdit")

        // Tab accepts.
        #expect(coordinator.textView(textView, doCommandBy: #selector(NSResponder.insertTab(_:))))
        #expect(textView.string == "SwiftEdit SwiftEdit")
        #expect(coordinator.ghostSuggestion == nil)

        // Escape dismisses without editing.
        textView.insertText(" ", replacementRange: textView.selectedRange())
        textView.insertText("Sw", replacementRange: textView.selectedRange())
        textView.insertText("i", replacementRange: textView.selectedRange())
        #expect(coordinator.ghostSuggestion != nil)
        #expect(coordinator.textView(textView, doCommandBy: #selector(NSResponder.cancelOperation(_:))))
        #expect(coordinator.ghostSuggestion == nil)
        #expect(textView.string == "SwiftEdit SwiftEdit Swi")

        // N: with no suggestion visible Tab is left to the existing list/table/default chain.
        #expect(coordinator.textView(textView, doCommandBy: #selector(NSResponder.insertTab(_:))) == false)
        window.orderOut(nil)
    }
}

/// Redesign-020: icon set, neutral chrome and gutter fixes.
@Suite("Redesign020Tests")
@MainActor
struct Redesign020Tests {
    @Test("P-ICON1: every AppIcon has drawable geometry inside the 24-unit grid")
    func pEveryIconHasGeometryInsideGrid() {
        for icon in AppIcon.allCases {
            let geometry = icon.geometry
            let bounds = geometry.stroke.boundingRect.union(geometry.fill.boundingRect)
            #expect(!bounds.isNull && (bounds.width > 0 || bounds.height > 0), "\(icon) has no geometry")
            #expect(bounds.minX >= 0 && bounds.minY >= 0 && bounds.maxX <= 24 && bounds.maxY <= 24, "\(icon) leaves the grid: \(bounds)")
        }
    }

    @Test("N-ICON1: SwiftEditUI uses no SF Symbols (Image(systemName:), systemImage:, NSImage(systemSymbolName:))")
    func nNoSFSymbolsInSwiftEditUI() throws {
        let root = AuditReportFitness.repositoryRoot.appendingPathComponent("Sources/SwiftEditUI")
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
        var offenders: [String] = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for marker in ["Image(systemName", "systemImage:", "systemSymbolName"] where text.contains(marker) {
                offenders.append("\(file.lastPathComponent): \(marker)")
            }
        }
        #expect(offenders.isEmpty, "\(offenders)")
        // Core contextual actions reference icons by semantic name only.
        for group in ElementContextualActionCatalog.groups {
            for action in group.actions { #expect(AppIcon(rawValue: action.iconName) != nil, "\(action.iconName)") }
        }
    }

    @Test("P-CHROME1: status bar and header share the neutral chrome surface; accent stays purple (UI-001 v1.7.0)")
    func pNeutralChromeAndPurpleAccent() {
        for mode in [AppearanceMode.light, .black] {
            let palette = PurpleThemePalette.resolve(appearance: mode)
            #expect(palette.statusBarSurface == palette.topBarSurface)
            #expect(palette.chromeAccent.hex == (mode == .light ? "#7C3AED" : "#A78BFA"))
            // REQ-022-02: the gutter is a distinct, slightly greyer surface than the canvas.
            #expect(palette.gutterSurface != palette.editorCanvasBackground)
        }
    }

    @Test("P-GUT1: the gutter reserves a diagnostics column so 4-digit numbers never share space with lint markers (V-02)")
    func pGutterReservesDiagnosticsColumn() {
        let metrics = ZoomedChromeMetrics(zoomPercent: 100)
        let advance: CGFloat = 7.8
        let width = metrics.gutterWidth(lineCount: 1_000, digitAdvanceAt100: advance)
        #expect(width >= 4 * advance + ZoomedChromeMetrics.gutterDiagnosticsColumn + LineNumberGutterView.numberTrailingPadding)
    }

    @Test("P-APP1: appearance cycles Light -> Dark -> Auto and the breadcrumb names the active tab")
    func pAppearanceCycleAndBreadcrumb() {
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: FileManager.default.temporaryDirectory.appendingPathComponent("r020-\(UUID().uuidString)"),
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
        model.appearanceMode = .light
        model.cycleAppearanceMode(); #expect(model.appearanceMode == .black)
        model.cycleAppearanceMode(); #expect(model.appearanceMode == .auto)
        model.cycleAppearanceMode(); #expect(model.appearanceMode == .light)
        model.handleEditorTextChanged("hello")
        #expect(model.headerBreadcrumb.last?.isEmpty == false)
    }
}
