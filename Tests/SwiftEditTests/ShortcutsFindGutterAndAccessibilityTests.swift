import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("ShortcutsFindGutterAndAccessibilityTests")
struct ShortcutsFindGutterAndAccessibilityTests {

    @Test("P5: SwiftEditCommands isolates Cmd+H to system Hide, uses Opt+Cmd+F for Find & Replace, and removes duplicate Redo")
    func p5CommandsShortcutParityWithoutCollisions() throws {
        // GIVEN SwiftEditCommands source
        let commandsURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/SwiftEditUI/Views/SwiftEditCommands.swift")
        let source = try String(contentsOf: commandsURL, encoding: .utf8)

        // THEN Cmd+H is absent (left to macOS Hide), Opt+Cmd+F binds Find and Replace, and duplicate Cmd+Y Redo is removed
        #expect(!source.contains(".keyboardShortcut(\"h\""))
        #expect(source.contains(".keyboardShortcut(\"f\", modifiers: [.command, .option])"))
        #expect(!source.contains(".keyboardShortcut(\"y\", modifiers: .command)"))
    }

    @Test("P5: Find/Next/Prev/GoToLine bump programmaticSelectionToken, executeReplaceSingle replaces 1 occurrence, and Dismiss restores editor focus")
    @MainActor
    func p5FindSelectionTokensSingleReplaceAndFocusRestoration() throws {
        // GIVEN an active workbench holding "alpha one\nbeta one\ngamma"
        let recoveryDir = FileManager.default.temporaryDirectory.appendingPathComponent("p5-find-rec-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: recoveryDir) }
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: recoveryDir,
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
        model.newUntitledTab()
        model.handleEditorTextChanged("alpha one\nbeta one\ngamma")
        let initialToken = model.programmaticSelectionToken
        let initialFocusToken = model.editorFocusRequestToken

        // WHEN finding "one", stepping next/prev, replacing a single match, jumping to line 3, and closing FindBar
        model.presentFindBar(mode: .findAndReplace)
        model.findReplaceState.query = "one"
        model.findReplaceState.replacement = "TWO"
        model.executeFind()
        let tokenAfterFind = model.programmaticSelectionToken
        model.findNextMatch()
        let tokenAfterNext = model.programmaticSelectionToken
        model.findPreviousMatch()
        let tokenAfterPrev = model.programmaticSelectionToken

        model.executeReplaceSingle()
        let textAfterSingleReplace = model.activeDocumentSession?.text
        let remainingMatches = model.findReplaceState.matches.count

        model.findReplaceState.goToLineText = "3"
        model.executeGoToLine()
        let tokenAfterGoTo = model.programmaticSelectionToken
        let goToLineLocation = model.currentSelection.location

        model.presentFindBar(mode: .hidden)
        let focusTokenAfterClose = model.editorFocusRequestToken

        // THEN every navigation bumps selection token, single replace changes only 1st match keeping 1 match left, and close requests editor focus
        #expect(tokenAfterFind > initialToken)
        #expect(tokenAfterNext > tokenAfterFind)
        #expect(tokenAfterPrev > tokenAfterNext)
        #expect(textAfterSingleReplace == "alpha TWO\nbeta one\ngamma")
        #expect(remainingMatches == 1)
        #expect(tokenAfterGoTo > tokenAfterPrev)
        #expect(goToLineLocation == ("alpha TWO\nbeta one\n" as NSString).length)
        #expect(focusTokenAfterClose > initialFocusToken)
    }

    @Test("P5: Current-line highlight spans all wrapped lineFragments and GutterViewportMetrics tracks scroll & soft-wrap heights")
    @MainActor
    func p5WrappedLineHighlightAndGutterViewportSync() throws {
        // GIVEN a narrow (140 pt wide) TextKit 2 NSTextView inside an NSScrollView causing a long paragraph to wrap across >= 3 lines
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 220),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        defer { window.close() }

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 160, height: 220))
        let textView = SwiftEditNSTextView(usingTextLayoutManager: true)
        textView.frame = NSRect(x: 0, y: 0, width: 140, height: 220)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let longLine = String(repeating: "wrappedword ", count: 24)
        let multiline = (1...60).map { "line \($0) \(longLine)" }.joined(separator: "\n")
        textView.string = multiline
        textView.setSelectedRange(NSRange(location: 4, length: 0))
        scrollView.documentView = textView
        window.contentView = scrollView
        window.layoutIfNeeded()
        textView.textLayoutManager?.textViewportLayoutController.layoutViewport()

        // WHEN measuring wrapped current-line highlight and scrolling vertically to capture GutterViewportMetrics
        let highlightRect = try #require(textView.currentLineFullWidthRect())
        let singleLineHeight = max(14.0, (textView.font?.ascender ?? 12) - (textView.font?.descender ?? -3) + (textView.font?.leading ?? 2))

        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 400))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        textView.textLayoutManager?.textViewportLayoutController.layoutViewport()
        let metrics = TextKit2EditorView.Coordinator.captureGutterViewportMetrics(in: scrollView, textView: textView)

        // THEN current-line rect covers multiple wrapped fragments AND gutter metrics reflect scrollOffsetY >= 350 and non-empty visible fragments
        #expect(highlightRect.height > singleLineHeight * 1.8)
        #expect(metrics.scrollOffsetY >= 350)
        #expect(metrics.visibleLines.isEmpty == false)
    }

    @Test("N8: AboutSheetDescriptor alpha5 fallback, inert empty Replace, out-of-range GoToLine, and zero-width gutter clamping")
    @MainActor
    func n8FallbacksEmptyGuardsAndZeroWidthGutterDegradeCleanly() {
        // GIVEN AboutSheetDescriptor fallback helper, a workbench with empty Find query, and an empty GutterViewportMetrics
        let fallbackFull = AboutSheetDescriptor.resolveFallbackFullVersion(bundleFullVersion: nil)
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
        let revBefore = model.activeDocumentSession?.revision
        let selBefore = model.currentSelection

        // WHEN triggering empty Replace Single, GoToLine "999999", and empty GutterViewportMetrics
        model.executeReplaceSingle()
        model.findReplaceState.goToLineText = "999999"
        model.executeGoToLine()
        let emptyMetrics = GutterViewportMetrics(scrollOffsetY: -10, visibleLines: [])

        // THEN fallback matches 0.0.1-alpha5, empty Replace / bad GoToLine perform zero mutations, and negative scroll clamps cleanly
        #expect(fallbackFull == "0.0.1-alpha5")
        #expect(model.activeDocumentSession?.revision == revBefore)
        #expect(model.currentSelection == selBefore)
        #expect(emptyMetrics.scrollOffsetY == 0)
        #expect(emptyMetrics.visibleLines.isEmpty)
    }
}
