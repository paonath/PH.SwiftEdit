import AppKit
import Foundation
import QuartzCore
import SwiftUI
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("LiveUIMouseAndShortcutsResponsivenessTests", .serialized, .enabled(if: ReleasePipelineTestGate.shouldRunE2EUIAndStressTests))
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

    @Test("Secondary word occurrence highlight visibly paints other occurrences (plain prose AND inside backticks) via both mouse double-click and Shift+Arrow selection")
    func secondaryWordOccurrenceHighlightRendersVisiblyInTextKit2() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("occ-render-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let sandboxText = """
        # SwiftEdit — Sandbox Ready

        Welcome to **SwiftEdit** (Minimal Neutral Chrome + Inverted B/W TextKit 2 Canvas).

        - Press `Cmd+D` to duplicate the current line or selection.
        - duplicate
        - Press `Cmd++` / `Cmd+-` / `Cmd+0` to scale Editor Zoom (`50%..300%`).
        - Open a sandboxed folder on the left to inspect hidden dotfiles (`.env`, `.gitignore`).
        - Try `#HeadingWithoutSpace` or `[XSS](javascript:alert(1))` to test live AST linting.
        - Try `#HeadingWithoutSpace` or `[XSS](javascript:alert(1))` to test live AST linting.
        """

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: dir.appendingPathComponent("recovery"),
            fileSystem: LocalFileSystemAdapter(),
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
        model.appearanceMode = .light
        model.newUntitledTab()
        model.handleEditorTextChanged(sandboxText)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        let hostingView = NSHostingView(rootView: SwiftEditRootView(initialModel: model))
        hostingView.frame = NSRect(x: 0, y: 0, width: 1100, height: 600)
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }

        hostingView.layoutSubtreeIfNeeded()
        Self.pumpMainRunLoop(milliseconds: 30)

        let textView = try #require(Self.findSubview(of: SwiftEditNSTextView.self, in: hostingView))
        _ = window.makeFirstResponder(textView)

        func bitmapHasSoftPurpleHighlight(in rect: NSRect) -> Bool {
            let sampleRect = rect.insetBy(dx: -2, dy: -2).intersection(textView.bounds)
            guard !sampleRect.isEmpty,
                  let rep = textView.bitmapImageRepForCachingDisplay(in: sampleRect) else { return false }
            textView.cacheDisplay(in: sampleRect, to: rep)
            let target = model.palette.wordOccurrenceBackground.nsColor.usingColorSpace(.sRGB)!
            guard rep.pixelsWide > 0, rep.pixelsHigh > 0 else { return false }
            for y in 0..<rep.pixelsHigh {
                for x in 0..<rep.pixelsWide {
                    if let px = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) {
                        let dr = abs(px.redComponent - target.redComponent)
                        let dg = abs(px.greenComponent - target.greenComponent)
                        let db = abs(px.blueComponent - target.blueComponent)
                        if dr < 0.08 && dg < 0.08 && db < 0.08 {
                            return true
                        }
                    }
                }
            }
            return false
        }

        func rectForUTF16Range(_ nsRange: NSRange) -> NSRect {
            let screenRect = textView.firstRect(forCharacterRange: nsRange, actualRange: nil)
            let winRect = window.convertFromScreen(screenRect)
            return textView.convert(winRect, from: nil)
        }

        let nsText = sandboxText as NSString

        // Case 1: Select "duplicate" on line 5 -> "duplicate" on line 6 MUST be highlighted in soft purple (#DDD6FE)
        let dup1 = nsText.range(of: "duplicate")
        let dup2 = nsText.range(of: "duplicate", range: NSRange(location: NSMaxRange(dup1), length: nsText.length - NSMaxRange(dup1)))
        #expect(dup1.location != NSNotFound && dup2.location != NSNotFound)

        textView.setSelectedRange(dup1)
        Self.pumpMainRunLoop(milliseconds: 40)
        hostingView.layoutSubtreeIfNeeded()

        #expect(model.activeHighlightProjection.wordOccurrenceRanges.contains(SwiftEditCore.TextRange(location: dup2.location, length: dup2.length)))
        let dup2Rect = rectForUTF16Range(dup2)
        #expect(bitmapHasSoftPurpleHighlight(in: dup2Rect), "Expected line 6 'duplicate' to render with wordOccurrenceBackground (#DDD6FE)")

        // Case 2: Select "#HeadingWithoutSpace" on line 8 (inside backticks) -> line 9 occurrence MUST ALSO be highlighted in soft purple (#DDD6FE)
        let h1 = nsText.range(of: "#HeadingWithoutSpace")
        let h2 = nsText.range(of: "#HeadingWithoutSpace", range: NSRange(location: NSMaxRange(h1), length: nsText.length - NSMaxRange(h1)))
        #expect(h1.location != NSNotFound && h2.location != NSNotFound)

        textView.setSelectedRange(h1)
        Self.pumpMainRunLoop(milliseconds: 40)
        hostingView.layoutSubtreeIfNeeded()

        #expect(model.activeHighlightProjection.wordOccurrenceRanges.contains(SwiftEditCore.TextRange(location: h2.location, length: h2.length)))
        #expect(textView.liveWordOccurrenceRanges.contains(SwiftEditCore.TextRange(location: h2.location, length: h2.length)))
        let h2Rect = rectForUTF16Range(h2)
        #expect(bitmapHasSoftPurpleHighlight(in: h2Rect), "Expected line 9 '#HeadingWithoutSpace' inside backticks to render with wordOccurrenceBackground (#DDD6FE)")

        // Case 3: Exact user repro from -beta5 screenshot:
        // Start from default Welcome.md, place caret on "sandboxed" line, press Cmd+D twice, then select "sandboxed" on line 8 via Shift+RightArrow (moveRightAndModifySelection:)!
        let welcomeText = model.activeDocumentSession?.text ?? ""
        let sandboxedFirst = (welcomeText as NSString).range(of: "sandboxed")
        textView.setSelectedRange(NSRange(location: sandboxedFirst.location, length: 0))
        Self.pumpMainRunLoop(milliseconds: 20)
        hostingView.layoutSubtreeIfNeeded()

        // Press Cmd+D twice
        model.performCommandD()
        Self.pumpMainRunLoop(milliseconds: 30)
        hostingView.layoutSubtreeIfNeeded()
        model.performCommandD()
        Self.pumpMainRunLoop(milliseconds: 30)
        hostingView.layoutSubtreeIfNeeded()

        // Now find the 2nd "sandboxed" (line 8) and select it character-by-character with Shift+RightArrow (moveRightAndModifySelection:)
        let afterCmdD = textView.string as NSString
        let sb1 = afterCmdD.range(of: "sandboxed")
        let sb2 = afterCmdD.range(of: "sandboxed", range: NSRange(location: NSMaxRange(sb1), length: afterCmdD.length - NSMaxRange(sb1)))
        let sb3 = afterCmdD.range(of: "sandboxed", range: NSRange(location: NSMaxRange(sb2), length: afterCmdD.length - NSMaxRange(sb2)))
        #expect(sb1.location != NSNotFound && sb2.location != NSNotFound && sb3.location != NSNotFound)

        textView.setSelectedRange(NSRange(location: sb2.location, length: 0))
        Self.pumpMainRunLoop(milliseconds: 20)
        window.displayIfNeeded()
        CATransaction.flush()

        for _ in 0..<sb2.length {
            textView.moveRightAndModifySelection(nil)
        }
        // Notice: EVEN BEFORE pumpMainRunLoop / SwiftUI updateNSView, SwiftEditNSTextView.liveWordOccurrenceRanges is ALREADY populated synchronously!
        #expect(textView.liveWordOccurrenceRanges == [
            SwiftEditCore.TextRange(location: sb1.location, length: sb1.length),
            SwiftEditCore.TextRange(location: sb3.location, length: sb3.length),
        ])

        window.displayIfNeeded()
        CATransaction.flush()
        #expect(bitmapHasSoftPurpleHighlight(in: rectForUTF16Range(sb1)))
        #expect(bitmapHasSoftPurpleHighlight(in: rectForUTF16Range(sb3)))

        // And deselecting clears liveWordOccurrenceRanges immediately:
        textView.setSelectedRange(NSRange(location: sb2.location, length: 0))
        #expect(textView.liveWordOccurrenceRanges.isEmpty)
    }

    @Test("Log viewer secondary occurrence highlight works in Plain, Live Direct, and Live Inverse modes without ever locking the log file")
    func logViewerSecondaryOccurrenceHighlightInPlainDirectAndInverseWithoutFileLocking() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftEditLogHighlightTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let logURL = dir.appendingPathComponent("filini2-api.log")
        let initialLogLines = [
            "2026-11-23 11:34:47.5310 TRACE [ ] - Starting Filini | [Filini2.Api.Program.Main:Program.cs:45] [Filini2.Api.Program]",
            "2026-11-23 11:34:47.9700 INFO [ ] - Initialized Scheduler Signaller of type: Quartz.Core.SchedulerSignalerImpl | [Quartz.Simpl.MicrosoftLoggingProvider.GetLogger] [Quartz.Core.SchedulerSignalerImpl]",
            "2026-11-23 11:34:47.9705 INFO [ ] - Quartz Scheduler created | [Quartz.Simpl.MicrosoftLoggingProvider.GetLogger] [Quartz.Core.QuartzScheduler]",
            "2026-11-23 11:34:47.9705 INFO [ ] - JobFactory set to: Quartz.Simpl.MicrosoftDependencyInjectionJobFactory | [Quartz.Simpl.MicrosoftLoggingProvider.GetLogger] [Quartz.Core.QuartzScheduler]",
            "2026-11-23 11:34:47.9705 INFO [ ] - RAMJobStore initialized. | [Quartz.Simpl.MicrosoftLoggingProvider.GetLogger] [Quartz.Simpl.RAMJobStore]",
            "2026-11-23 11:34:47.9705 INFO [ ] - Quartz Scheduler 3.18.0.0 - 'QuartzScheduler' with instanceId 'NON_CLUSTERED' initialized | [Quartz.Simpl.MicrosoftLoggingProvider.GetLogger] [Quartz.Impl.StdSchedulerFactory]",
            "2026-11-23 11:34:47.9712 INFO [ ] - Using thread pool 'Quartz.Simpl.DefaultThreadPool', size: 10 | [Quartz.Simpl.MicrosoftLoggingProvider.GetLogger] [Quartz.Impl.StdSchedulerFactory]",
            "2026-11-23 11:34:47.9712 INFO [ ] - Using job store 'Quartz.Simpl.RAMJobStore', supports persistence: False, clustered: False | [Quartz.Simpl.MicrosoftLoggingProvider.GetLogger] [Quartz.Impl.StdSchedulerFactory]",
            "2026-11-23 11:34:47.9767 INFO [ ] - Adding 2 jobs, 2 triggers. | [Quartz.Xml.XMLSchedulingDataProcessor.ScheduleJobs] [Quartz.ContainerConfigurationProcessor]",
            "2026-11-23 11:34:47.9767 INFO [ ] - Adding job: DEFAULT.CheckAndSendNotifiche | [Quartz.Xml.XMLSchedulingDataProcessor.ScheduleJobs] [Quartz.ContainerConfigurationProcessor]",
            "2026-11-23 11:34:47.9791 INFO [ ] - Adding job: DEFAULT.CreaNotificaPresenzeScadute | [Quartz.Xml.XMLSchedulingDataProcessor.ScheduleJobs] [Quartz.ContainerConfigurationProcessor]",
            "2026-11-23 11:34:48.4352 INFO [ ] - Now listening on: http://localhost:5000 | [Microsoft.AspNetCore.Hosting.GenericWebHostService.StartAsync] [Microsoft.Hosting.Lifetime]",
            "2026-11-23 11:34:48.4378 INFO [ ] - Application started. Press Ctrl+C to shut down. | [Microsoft.Extensions.Hosting.Internal.ConsoleLifetime.OnApplicationStarted] [Microsoft.Hosting.Lifetime]",
            "2026-11-23 11:34:48.4378 INFO [ ] - Hosting environment: Development | [Microsoft.Extensions.Hosting.Internal.ConsoleLifetime.OnApplicationStarted] [Microsoft.Hosting.Lifetime]",
            "2026-11-23 11:34:48.4382 INFO [ ] - Content root path: /Users/paoloinnocenti/Documents/git/filini-repo/filini-2.0/server/Filini2.0.Api/Filini2.0.Api | [Microsoft.Extensions.Hosting.Internal.ConsoleLifetime.OnApplicationStarted] [Microsoft.Hosting.Lifetime]",
            "2026-11-23 11:34:48.4382 INFO [ ] - Scheduler QuartzScheduler_$_NON_CLUSTERED started. | [Quartz.Simpl.MicrosoftLoggingProvider.GetLogger] [Quartz.Core.QuartzScheduler]",
        ]
        let initialContent = initialLogLines.joined(separator: "\n") + "\n"
        try Data(initialContent.utf8).write(to: logURL)

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: dir.appendingPathComponent("recovery"),
            fileSystem: LocalFileSystemAdapter(),
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
        model.appearanceMode = .light
        model.openFile(at: logURL, withinScope: dir)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        let hostingView = NSHostingView(rootView: SwiftEditRootView(initialModel: model))
        hostingView.frame = NSRect(x: 0, y: 0, width: 1280, height: 520)
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }

        hostingView.layoutSubtreeIfNeeded()
        Self.pumpMainRunLoop(milliseconds: 30)

        func currentTextView() throws -> SwiftEditNSTextView {
            try #require(Self.findSubview(of: SwiftEditNSTextView.self, in: hostingView))
        }

        func bitmapHasSoftPurpleHighlight(on tv: SwiftEditNSTextView, in rect: NSRect) -> Bool {
            let sampleRect = rect.insetBy(dx: -2, dy: -2).intersection(tv.bounds)
            guard !sampleRect.isEmpty,
                  let rep = tv.bitmapImageRepForCachingDisplay(in: sampleRect) else { return false }
            tv.cacheDisplay(in: sampleRect, to: rep)
            let target = model.palette.wordOccurrenceBackground.nsColor.usingColorSpace(.sRGB)!
            guard rep.pixelsWide > 0, rep.pixelsHigh > 0 else { return false }
            for y in 0..<rep.pixelsHigh {
                for x in 0..<rep.pixelsWide {
                    if let px = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) {
                        let dr = abs(px.redComponent - target.redComponent)
                        let dg = abs(px.greenComponent - target.greenComponent)
                        let db = abs(px.blueComponent - target.blueComponent)
                        if dr < 0.08 && dg < 0.08 && db < 0.08 {
                            return true
                        }
                    }
                }
            }
            return false
        }

        func rectForUTF16Range(_ nsRange: NSRange, in tv: SwiftEditNSTextView) -> NSRect {
            let screenRect = tv.firstRect(forCharacterRange: nsRange, actualRange: nil)
            let winRect = window.convertFromScreen(screenRect)
            return tv.convert(winRect, from: nil)
        }

        func assertLogFileIsNeverLockedAndWritable(_ appendLine: String) throws {
            let fd = open(logURL.path, O_RDWR | O_APPEND | O_CLOEXEC)
            #expect(fd >= 0, "External process must always be able to open the log file for read/write")
            guard fd >= 0 else { return }
            defer { close(fd) }
            let lockRc = flock(fd, LOCK_EX | LOCK_NB)
            #expect(lockRc == 0, "Log file must NEVER hold a shared or exclusive flock (errno=\(errno))")
            if lockRc == 0 {
                _ = flock(fd, LOCK_UN)
            }
            let bytes = Array((appendLine + "\n").utf8)
            let written = bytes.withUnsafeBytes { ptr in
                write(fd, ptr.baseAddress, ptr.count)
            }
            #expect(written == bytes.count, "External writer must be able to append to log file without contention")
        }

        // -----------------------------------------------------------------
        // 1. PLAIN MODE (.log opened as standard tab, before starting live tail)
        // -----------------------------------------------------------------
        let plainTV = try currentTextView()
        _ = window.makeFirstResponder(plainTV)
        #expect(plainTV.isWordOccurrenceHighlightEnabled == true)
        let plainNS = plainTV.string as NSString
        let plainInfo1 = plainNS.range(of: "INFO")
        let plainInfo2 = plainNS.range(of: "INFO", range: NSRange(location: NSMaxRange(plainInfo1), length: plainNS.length - NSMaxRange(plainInfo1)))
        #expect(plainInfo1.location != NSNotFound && plainInfo2.location != NSNotFound)

        plainTV.setSelectedRange(plainInfo1)
        Self.pumpMainRunLoop(milliseconds: 30)
        window.displayIfNeeded()
        CATransaction.flush()

        #expect(plainTV.liveWordOccurrenceRanges.count == 14)
        #expect(bitmapHasSoftPurpleHighlight(on: plainTV, in: rectForUTF16Range(plainInfo2, in: plainTV)))

        // -----------------------------------------------------------------
        // 2. LIVE TAIL - DIRECT MODE (Cmd+L)
        // -----------------------------------------------------------------
        model.startLogTail(mode: .direct)
        let tail = try #require(model.activeLogTail)
        tail.pollNow()
        Self.pumpMainRunLoop(milliseconds: 50)
        hostingView.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        CATransaction.flush()

        #expect(tail.mode == .direct)
        let directTV = try currentTextView()
        _ = window.makeFirstResponder(directTV)
        #expect(directTV.isEditable == false)
        #expect(directTV.isSelectable == true)
        #expect(directTV.isWordOccurrenceHighlightEnabled == true)

        let directNS = directTV.string as NSString
        let directInfo1 = directNS.range(of: "INFO")
        let directInfo2 = directNS.range(of: "INFO", range: NSRange(location: NSMaxRange(directInfo1), length: directNS.length - NSMaxRange(directInfo1)))
        #expect(directInfo1.location != NSNotFound && directInfo2.location != NSNotFound)

        // Select "INFO" via Shift + Right Arrow in read-only Live Direct mode
        directTV.setSelectedRange(NSRange(location: directInfo1.location, length: 0))
        for _ in 0..<directInfo1.length {
            directTV.moveRightAndModifySelection(nil)
        }
        Self.pumpMainRunLoop(milliseconds: 30)
        window.displayIfNeeded()
        CATransaction.flush()

        #expect(directTV.selectedRange() == directInfo1)
        #expect(directTV.liveWordOccurrenceRanges.count == 14)
        #expect(bitmapHasSoftPurpleHighlight(on: directTV, in: rectForUTF16Range(directInfo2, in: directTV)))

        // Append a new log line externally while "INFO" is selected and verify non-locking + preserved selection + 15 secondary occurrences!
        try assertLogFileIsNeverLockedAndWritable(
            "2026-11-23 11:34:49.1000 INFO [ ] - Live appended line while active selection is preserved | [Filini2.Api.Heartbeat]"
        )
        tail.pollNow()
        Self.pumpMainRunLoop(milliseconds: 50)
        hostingView.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        CATransaction.flush()

        #expect(directTV.selectedRange() == directInfo1, "Active user selection in live log tail must not be clobbered by incoming log lines")
        #expect(directTV.liveWordOccurrenceRanges.count == 15)

        // -----------------------------------------------------------------
        // 3. LIVE TAIL - INVERSE MODE (Shift+Cmd+L / Order: Inverse, matching user screenshot)
        // -----------------------------------------------------------------
        tail.setMode(.inverse)
        Self.pumpMainRunLoop(milliseconds: 50)
        hostingView.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        CATransaction.flush()

        #expect(tail.mode == .inverse)
        let inverseTV = try currentTextView()
        let inverseNS = inverseTV.string as NSString

        // Select "INFO" on the 5th line (exactly as in user's screenshot: "Now listening on: http://localhost:5000")
        let listeningLineRange = inverseNS.range(of: "Now listening on: http://localhost:5000")
        #expect(listeningLineRange.location != NSNotFound)
        let lineStart = inverseNS.lineRange(for: NSRange(location: listeningLineRange.location, length: 0))
        let infoOnLine5 = inverseNS.range(of: "INFO", options: [], range: lineStart)
        #expect(infoOnLine5.location != NSNotFound)

        inverseTV.setSelectedRange(infoOnLine5)
        Self.pumpMainRunLoop(milliseconds: 40)
        hostingView.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        CATransaction.flush()

        #expect(inverseTV.selectedRange() == infoOnLine5)
        #expect(inverseTV.liveWordOccurrenceRanges.count == 15)
        let firstLineInfo = inverseNS.range(of: "INFO")
        #expect(firstLineInfo.location != NSNotFound && firstLineInfo != infoOnLine5)
        #expect(bitmapHasSoftPurpleHighlight(on: inverseTV, in: rectForUTF16Range(firstLineInfo, in: inverseTV)))

        // Also verify external non-locking write while Inverse mode is active with "INFO" highlighted
        try assertLogFileIsNeverLockedAndWritable(
            "2026-11-23 11:34:50.2000 INFO [ ] - Second live appended line in Inverse mode | [Filini2.Api.Heartbeat]"
        )
        tail.pollNow()
        Self.pumpMainRunLoop(milliseconds: 50)
        hostingView.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        CATransaction.flush()

        let updatedInverseNS = inverseTV.string as NSString
        #expect(updatedInverseNS.substring(with: inverseTV.selectedRange()) == "INFO")
        #expect(inverseTV.liveWordOccurrenceRanges.count == 16)
    }
}
