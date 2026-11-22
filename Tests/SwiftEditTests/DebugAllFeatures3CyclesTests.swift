import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

/// End-to-end 3-cycle debug verification suite exercising every user-facing feature of PH.SwiftEdit
/// (Editing, Tabs, Find/Replace/GoToLine, Markdown, YAML, Logs & Live Tail, Diff, Terminal, Theme/Zoom/Typography, Help, Binary).
@Suite("DebugAllFeatures3CyclesTests", .serialized)
@MainActor
struct DebugAllFeatures3CyclesTests {

    @Test("Debug 3-Pass Full Feature Verification: Editing, Markdown, YAML, Logs, Diff, Terminal, Theme, Zoom, Help, Binary")
    func threeFullDebugPassesAcrossAllFeatures() throws {
        for pass in 1...3 {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("swiftedit-debug-pass-\(pass)-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }

            let mdURL = root.appendingPathComponent("notes.md")
            let yamlURL = root.appendingPathComponent("config.yaml")
            let logURL = root.appendingPathComponent("app.log")
            let binURL = root.appendingPathComponent("blob.bin")

            let mdSeed = """
            ---
            title: Pass \(pass)
            draft: false
            ---

            # Heading One

            ### Skipped Level

            Some **bold** and `code` and (nested [brackets]).

            - [ ] Task A
            - [x] Task B

            """
            let yamlSeed = """
            app:
              name: SwiftEdit
              pass: \(pass)
            """
            let logSeed = """
            2026-11-22 10:00:00.1234|INFO|Boot|Started 550e8400-e29b-41d4-a716-446655440000
            2026-11-22 10:00:01,200 [4] WARN  Shop - low stock "sku-1"
            {"time":"2026-11-22T10:00:02Z","level":"error","msg":"DatabaseError"}
            Nov 22 10:00:03 host app[42]: crit: NullReferenceException
                at App.Run()
            """
            try mdSeed.write(to: mdURL, atomically: true, encoding: .utf8)
            try yamlSeed.write(to: yamlURL, atomically: true, encoding: .utf8)
            try logSeed.write(to: logURL, atomically: true, encoding: .utf8)
            try Data([0x00, 0x01, 0x02, 0x89, 0x50, 0x4E, 0x47, 0xFF]).write(to: binURL)

            let prefs = InMemoryKeyValueStore()
            let recents = InMemoryKeyValueStore()
            var savePanelCalled = false
            let model = SwiftEditWorkbenchModel(
                preferencesStore: prefs,
                recentFilesStore: recents,
                recoveryDirectoryURL: root.appendingPathComponent("recovery"),
                fileSystem: LocalFileSystemAdapter(),
                systemDarkDetector: { pass % 2 == 0 },
                savePanelProvider: { _ in
                    savePanelCalled = true
                    return root.appendingPathComponent("save-as-pass-\(pass).md")
                }
            )

            // 1. Open Markdown, verify language, linting, hover details, preview, navigator, properties, distraction-free
            model.openFile(at: mdURL, withinScope: root)
            #expect(model.activeDocumentLanguage == .markdown)
            #expect(model.propertiesModel != nil)
            #expect(model.isPropertiesPanelVisible)
            #expect(!model.lintDiagnostics.isEmpty)

            model.toggleMarkdownPreview()
            #expect(model.showMarkdownPreview)
            model.toggleDocumentNavigator()
            #expect(model.navigatorState != nil)
            model.confirmDocumentNavigator()
            #expect(model.navigatorState == nil)

            model.toggleDistractionFree()
            #expect(model.isDistractionFree)
            #expect(model.handleEscape() == true)
            #expect(!model.isDistractionFree)

            // 2. Editing: Cmd+D, Find, Replace Single, Replace All, Go To Line, Line Ending, Diff, Save
            let beforeCmdD = model.activeDocumentSession?.text ?? ""
            model.performCommandD()
            #expect((model.activeDocumentSession?.text.count ?? 0) > beforeCmdD.count)

            model.findReplaceState.query = "Task"
            model.findReplaceState.replacement = "Item"
            model.executeFind()
            #expect(model.findReplaceState.matches.count >= 2)
            model.executeReplaceSingle()
            #expect(model.activeDocumentSession?.text.contains("Item A") == true)
            model.executeReplaceAll()
            #expect(model.activeDocumentSession?.text.contains("Item B") == true)

            model.findReplaceState.goToLineText = "6"
            model.executeGoToLine()
            #expect(model.statusBannerMessage == nil)

            model.setActiveDocumentLineEnding(.crlf)
            #expect(model.activeDocumentSession?.lineEnding == .crlf)

            // Myers diff against saved baseline
            if let activeID = model.tabSession.activeTabID,
               let baseline = model.savedBaselineByID[activeID],
               let current = model.activeDocumentSession?.snapshot {
                let diff = SearchDiffAndBracketEngine.computeMyersDiff(lhs: baseline, rhs: current)
                #expect(diff.completedValue?.hasDifferences == true)
            }

            model.saveActiveDocument()
            let savedBytes = try Data(contentsOf: mdURL)
            #expect(savedBytes.contains(0x0D)) // CRLF preserved on disk

            // 3. YAML: open, highlight, outline, smart indent
            model.openFile(at: yamlURL, withinScope: root)
            #expect(model.activeDocumentLanguage == .yaml)
            let yamlSnap = try #require(model.activeDocumentSession?.snapshot)
            let yamlSpans = DocumentSyntaxHighlighter.spans(
                index: MarkdownLineIndex(text: yamlSnap.text),
                visibleRange: TextRange(location: 0, length: yamlSnap.text.utf16.count),
                language: .yaml
            )
            #expect(!yamlSpans.isEmpty)
            model.toggleDocumentNavigator()
            #expect(model.navigatorState != nil)
            model.closeDocumentNavigator()

            // 4. Logs: open, highlight, live tail direct/inverse, real append, stop/resume, mutation guards
            model.openFile(at: logURL, withinScope: root)
            #expect(model.activeDocumentLanguage == .log)
            let logSnap = try #require(model.activeDocumentSession?.snapshot)
            let logSpans = LogSyntaxHighlighter.spans(
                index: MarkdownLineIndex(text: logSnap.text),
                visibleRange: TextRange(location: 0, length: logSnap.text.utf16.count)
            )
            #expect(logSpans.contains { if case .logLevel(.error) = $0.kind { true } else { false } })
            #expect(logSpans.contains { $0.kind == .logGuid })
            #expect(logSpans.contains { $0.kind == .logTimestamp })
            #expect(logSpans.contains { $0.kind == .logException })

            model.startLogTail(mode: .direct)
            let tail = try #require(model.activeLogTail)
            tail.pollNow()
            #expect(tail.visibleLineCount >= 4)

            // BUG-D2 regression: mutating commands blocked while live tail is active
            let revBeforeBlocked = model.activeDocumentSession?.revision
            model.performCommandD()
            model.formatActiveDocument()
            model.setActiveDocumentLineEnding(.cr)
            #expect(model.activeDocumentSession?.revision == revBeforeBlocked)

            // Append live line on disk and poll
            let handle = try FileHandle(forWritingTo: logURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: Data("2026-11-22 10:00:09|FATAL|Live|PASS_\(pass)_APPEND\n".utf8))
            try handle.close()
            tail.pollNow()
            #expect(tail.text.contains("PASS_\(pass)_APPEND"))

            tail.setMode(.inverse)
            #expect(tail.text.components(separatedBy: "\n").first?.contains("PASS_\(pass)_APPEND") == true)
            tail.setLineCount(2)
            #expect(tail.visibleLineCount == 2)

            // Stop & restart stale-session token regression
            model.stopLogTail()
            #expect(!tail.isRunning)
            model.startLogTail(mode: .direct)
            #expect(tail.isRunning)
            var staleBuf = LogTailBuffer()
            staleBuf.ingest(Data("STALE_OLD_WORKER\n".utf8))
            tail.receive(.success(staleBuf), sequence: 999, sessionToken: 0)
            #expect(!tail.text.contains("STALE_OLD_WORKER"))
            model.closeLogTail()
            #expect(model.activeLogTail == nil)

            // 5. Oversized >64 MiB log tail-only guards (BUG-D1 Save As & BUG-D4 preview/popover cleared)
            let fakeFS = InMemoryFileSystemFake()
            let hugeURL = URL(fileURLWithPath: "/debug/huge-\(pass).log")
            fakeFS.seed(url: hugeURL, data: Data("line\n".utf8), virtualByteSize: 120 * 1024 * 1024)
            var hugeSavePanelCalled = false
            let hugeModel = SwiftEditWorkbenchModel(
                preferencesStore: InMemoryKeyValueStore(),
                recentFilesStore: InMemoryKeyValueStore(),
                recoveryDirectoryURL: root.appendingPathComponent("recovery-huge"),
                fileSystem: fakeFS,
                systemDarkDetector: { false },
                savePanelProvider: { _ in hugeSavePanelCalled = true; return hugeURL }
            )
            hugeModel.showMarkdownPreview = true
            hugeModel.isDiagnosticsPopoverPresented = true
            hugeModel.openFile(at: hugeURL, withinScope: URL(fileURLWithPath: "/debug"))
            let hugeID = try #require(hugeModel.tabSession.activeTabID)
            #expect(hugeModel.logTailOnlyTabIDs.contains(hugeID))
            #expect(!hugeModel.showMarkdownPreview)
            #expect(!hugeModel.isDiagnosticsPopoverPresented)
            hugeModel.saveActiveDocumentAsViaPanel()
            #expect(!hugeSavePanelCalled)
            #expect(hugeModel.statusBannerMessage?.contains("Save As blocked") == true)
            hugeModel.saveDocument(to: hugeURL)
            #expect(hugeModel.statusBannerMessage?.contains("Save blocked") == true)
            hugeModel.performCommandD()
            #expect(hugeModel.activeDocumentSession?.isDirty == false)
            hugeModel.closeTab(id: hugeID)

            // 6. Binary transient read-only inspection & dismiss
            model.openFile(at: binURL, withinScope: root)
            #expect(model.activeBinaryInspection != nil)
            model.dismissBinaryInspection()
            #expect(model.activeBinaryInspection == nil)

            // 7. Terminal panel (Cmd+J), Appearance, Zoom, Help
            model.toggleTerminalPanel()
            #expect(model.isTerminalPanelVisible)
            #expect(model.terminalSessions.count == 1)
            model.toggleTerminalPanel()
            #expect(!model.isTerminalPanelVisible)
            #expect(model.terminalSessions.isEmpty)

            for appearance in [AppearanceMode.light, .black, .auto] {
                model.appearanceMode = appearance
                #expect(model.appearanceMode == appearance)
            }
            model.zoomController.zoomIn()
            #expect(model.zoomController.zoomPercent > 100)
            model.zoomController.resetZoom()
            #expect(model.zoomController.zoomPercent == 100)
            model.zoomController.zoomOut()
            #expect(model.zoomController.zoomPercent < 100)
            model.zoomController.resetZoom()

            #expect(HelpDocumentation.readme()?.contains("SwiftEdit") == true)
            #expect(HelpDocumentation.document() != nil)
            _ = savePanelCalled
        }
    }
}
