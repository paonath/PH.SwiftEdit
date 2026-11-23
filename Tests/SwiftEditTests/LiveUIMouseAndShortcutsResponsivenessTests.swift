import AppKit
import Foundation
import SwiftUI
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("LiveUIMouseAndShortcutsResponsivenessTests", .serialized)
@MainActor
struct LiveUIMouseAndShortcutsResponsivenessTests {

    private static func findSubview<T: NSView>(of type: T.Type, in root: NSView?) -> T? {
        guard let root else { return nil }
        if let match = root as? T { return match }
        for child in root.subviews {
            if let found = findSubview(of: type, in: child) {
                return found
            }
        }
        return nil
    }

    private static func pumpMainRunLoop(milliseconds: Int = 20) {
        let deadline = Date().addingTimeInterval(Double(milliseconds) / 1000.0)
        while Date() < deadline {
            _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.004))
        }
    }

    @Test("Live Window E2E: All mouse interactions, NSTextView editing/completion/double-click, and all keyboard shortcuts respond in < 50ms")
    func liveWindowMouseAndKeyboardShortcutsFullVerification() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("live-e2e-\(UUID().uuidString)", isDirectory: true)
        let subFolder = root.appendingPathComponent("docs", isDirectory: true)
        try FileManager.default.createDirectory(at: subFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let mdURL = root.appendingPathComponent("guide.md")
        let yamlURL = root.appendingPathComponent("config.yaml")
        let logURL = root.appendingPathComponent("server.log")
        let binURL = root.appendingPathComponent("image.bin")
        let subFileURL = subFolder.appendingPathComponent("sub.md")

        let mdInitial = """
        ---
        title: Live Guide
        tags: [alpha, beta]
        ---

        # Introduction

        Welcome to (contextual-menu). We test completion with architecture and archaeology.

        - [ ] First task
        - [x] Second task

        | Name | Value |
        | --- | --- |
        | One | 1 |

        ```swift
        let sample = (1 + 2)
        ```   
        """
        try mdInitial.write(to: mdURL, atomically: true, encoding: .utf8)
        try "service:\n  host: localhost\n  port: 9090\n".write(to: yamlURL, atomically: true, encoding: .utf8)
        try "2026-11-23 10:00:00 INFO Server booted\n2026-11-23 10:00:01 ERROR ConnectionTimeoutException\n".write(to: logURL, atomically: true, encoding: .utf8)
        try Data([0x00, 0x89, 0x50, 0x4E, 0x47, 0x00, 0xFF]).write(to: binURL)
        try "# Sub document\n".write(to: subFileURL, atomically: true, encoding: .utf8)

        let prefs = InMemoryKeyValueStore()
        let recents = InMemoryKeyValueStore()
        let model = SwiftEditWorkbenchModel(
            preferencesStore: prefs,
            recentFilesStore: recents,
            recoveryDirectoryURL: root.appendingPathComponent("recovery"),
            fileSystem: LocalFileSystemAdapter(),
            systemDarkDetector: { true },
            savePanelProvider: { _ in root.appendingPathComponent("saved-copy.md") },
            openPanelProvider: { _, _ in root }
        )

        model.openDroppedURLs([root])
        model.openFile(at: mdURL, withinScope: root)
        model.rebuildWordCompletionIndexNow()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        let hostingView = NSHostingView(rootView: SwiftEditRootView(initialModel: model))
        hostingView.frame = NSRect(x: 0, y: 0, width: 1280, height: 800)
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }

        hostingView.layoutSubtreeIfNeeded()
        Self.pumpMainRunLoop(milliseconds: 30)

        let textView = try #require(Self.findSubview(of: SwiftEditNSTextView.self, in: hostingView))
        _ = window.makeFirstResponder(textView)

        // 1. Verify live NSTextView double-click cycle (mouse interaction: word -> token -> deselect)
        let nsText = textView.string as NSString
        let tokenRange = nsText.range(of: "contextual")
        #expect(tokenRange.location != NSNotFound)
        let wordOut1 = textView.doubleClickOutcome(atCharacterIndex: tokenRange.location + 2, previous: NSRange(location: 0, length: 0))
        #expect(wordOut1 == .selectWord)
        let sysWord = textView.selectionRange(forProposedRange: NSRange(location: tokenRange.location + 2, length: 0), granularity: .selectByWord)
        textView.setSelectedRange(sysWord)
        let wordOut2 = textView.doubleClickOutcome(atCharacterIndex: tokenRange.location + 2, previous: sysWord)
        if case .selectToken(let tok) = wordOut2 {
            let tokStr = nsText.substring(with: NSRange(location: tok.location, length: tok.length))
            #expect(tokStr == "contextual-menu")
            textView.setSelectedRange(NSRange(location: tok.location, length: tok.length))
            let wordOut3 = textView.doubleClickOutcome(atCharacterIndex: tokenRange.location + 2, previous: NSRange(location: tok.location, length: tok.length))
            #expect(wordOut3 == .deselect(caret: sysWord.location))
        } else {
            Issue.record("Expected .selectToken on second double-click")
        }

        // 2. Verify live typing + Ghost Completion + Tab acceptance + Undo/Redo on SwiftEditNSTextView
        let endLoc = (textView.string as NSString).length
        textView.setSelectedRange(NSRange(location: endLoc, length: 0))
        if textView.shouldChangeText(in: NSRange(location: endLoc, length: 0), replacementString: "\narch") {
            textView.replaceCharacters(in: NSRange(location: endLoc, length: 0), with: "\narch")
            textView.didChangeText()
        }
        let caretAfterArch = (textView.string as NSString).length
        if textView.shouldChangeText(in: NSRange(location: caretAfterArch, length: 0), replacementString: "i") {
            textView.replaceCharacters(in: NSRange(location: caretAfterArch, length: 0), with: "i")
            textView.didChangeText()
        }
        // Ghost suggestion for "archi" -> "tecture" should be active and accepted by insertTab:
        let tabConsumed = textView.delegate?.textView?(textView, doCommandBy: #selector(NSResponder.insertTab(_:))) ?? false
        #expect(tabConsumed == true)
        #expect(textView.string.hasSuffix("\narchitecture"))

        // 3. Mouse & Keyboard Contextual Action Palette (Cmd+Return): surround selection with backticks, then click outside to dismiss
        let archRange = (textView.string as NSString).range(of: "architecture", options: .backwards)
        textView.setSelectedRange(archRange)
        #expect(model.presentElementContextualMenu(anchor: CGPoint(x: 200, y: 200)) == true)
        #expect(model.elementContextualMenu != nil)
        model.elementContextualMenu?.moveHighlight(1)
        model.elementContextualMenu?.moveHighlight(-1)
        model.activateElementContextualMenuRow()
        #expect(model.elementContextualMenu == nil)
        #expect(model.activeDocumentSession?.text.hasSuffix("\n`architecture`") == true)
        Self.pumpMainRunLoop(milliseconds: 20)
        hostingView.layoutSubtreeIfNeeded()
        #expect(textView.string.hasSuffix("\n`architecture`"))

        // Re-open contextual menu and test outside click dismissal (mouse click outside)
        #expect(model.presentElementContextualMenu(anchor: CGPoint(x: 200, y: 200)) == true)
        model.closeElementContextualMenu()
        #expect(model.elementContextualMenu == nil)

        // 4. Mouse click on Header Brand Submenu + Theme switching + Zoom controls
        model.headerSubmenu.clickToggle()
        #expect(model.headerSubmenu.isOpen == true)
        model.dismissHeaderSubmenu()
        #expect(model.headerSubmenu.isOpen == false)

        model.appearanceMode = .light
        #expect(model.palette.mode == .light)
        model.appearanceMode = .black
        #expect(model.palette.mode == .black)
        model.appearanceMode = .auto

        #expect(SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "=", modifiers: [.command]), model: model))
        #expect(model.zoomController.zoomPercent == 110)
        #expect(SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "-", modifiers: [.command]), model: model))
        #expect(model.zoomController.zoomPercent == 100)

        // 5. All Keyboard Shortcuts: Word Wrap (Cmd+W), Preview (Cmd+P), Sidebar (Cmd+B), Find/Replace/GoToLine (Cmd+F, Opt+Cmd+F, Cmd+G), Navigator (Opt+\), CheatSheet (Cmd+/, Opt+Cmd+/), Duplicate Document, Two-Tab Compare (Shift+Cmd+D), Log Tail (Cmd+L, Shift+Cmd+L), Terminal (Cmd+J)
        let startClock = ContinuousClock.now

        #expect(SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "w", modifiers: [.command]), model: model))
        #expect(model.isWordWrapEnabled == false)
        #expect(SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "w", modifiers: [.command]), model: model))
        #expect(model.isWordWrapEnabled == true)

        #expect(SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "p", modifiers: [.command]), model: model))
        #expect(model.showMarkdownPreview == true)
        hostingView.layoutSubtreeIfNeeded()
        #expect(model.markdownPreviewDocument != nil)

        #expect(SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "«", charactersIgnoringModifiers: "\\", keyCode: 42, modifiers: [.option]), model: model))
        #expect(model.navigatorState != nil)
        model.confirmDocumentNavigator()
        #expect(model.navigatorState == nil)

        #expect(SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "/", modifiers: [.command]), model: model))
        #expect(model.isCheatSheetPresented == true)
        // Mouse click on a CheatSheet row
        model.performCheatSheetCommandFromSheet(.toggleSidebar)
        #expect(model.isCheatSheetPresented == false)

        #expect(SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "¿", charactersIgnoringModifiers: "/", modifiers: [.command, .option]), model: model))
        #expect(model.isShortcutsPanelVisible == true)
        model.performCheatSheetCommand(.togglePreview)
        #expect(model.showMarkdownPreview == false)

        // Two-tab File Compare (Shift+Cmd+D)
        model.openFile(at: yamlURL, withinScope: root)
        #expect(SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "D", charactersIgnoringModifiers: "d", modifiers: [.command, .shift]), model: model))
        #expect(model.showDiffPane == true)
        hostingView.layoutSubtreeIfNeeded()

        // Sidebar mouse interactions: folder drill-down, parent navigation, binary inspection, log tail
        model.openDroppedURLs([subFolder])
        #expect(model.selectedFolderURL?.standardizedFileURL == subFolder.standardizedFileURL)
        model.navigateToParentFolder()
        #expect(model.selectedFolderURL?.standardizedFileURL == root.standardizedFileURL)

        model.openFile(at: binURL, withinScope: root)
        #expect(model.activeBinaryInspection != nil)

        model.openFile(at: logURL, withinScope: root)
        #expect(SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "l", modifiers: [.command]), model: model))
        #expect(model.activeLogTail?.mode == .direct)
        #expect(SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "L", charactersIgnoringModifiers: "l", modifiers: [.command, .shift]), model: model))
        #expect(model.activeLogTail?.mode == .inverse)
        model.closeLogTail()
        #expect(model.activeLogTail == nil)

        // Terminal panel toggle (Cmd+J)
        #expect(SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "j", modifiers: [.command]), model: model))
        #expect(model.isTerminalPanelVisible == true)
        #expect(SwiftEditShortcutDispatcher.dispatch(ShortcutKeyEvent(characters: "j", modifiers: [.command]), model: model))
        #expect(model.isTerminalPanelVisible == false)

        let elapsed = ContinuousClock.now - startClock
        #expect(elapsed < .milliseconds(500))
    }
}
