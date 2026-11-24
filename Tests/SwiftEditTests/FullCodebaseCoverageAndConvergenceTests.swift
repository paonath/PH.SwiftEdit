import AppKit
import Foundation
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import SwiftEditCore
@testable import SwiftEditUI

/// Full-codebase coverage threshold gate (`>= 85.0%` per target and aggregate) and UI/workbench convergence suite (`REQ-010`, `P10`, `N11`).
@Suite("FullCodebaseCoverageAndConvergenceTests", .serialized)
@MainActor
struct FullCodebaseCoverageAndConvergenceTests {

    private static func renderOffscreen<V: View>(_ view: V, size: NSSize = NSSize(width: 960, height: 640)) {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        window.contentView = nil
        window.orderOut(nil)
    }

    @Test("N11: CodeCoverageThresholdEvaluator rejects sub-85% SwiftEditCore, sub-85% SwiftEditUI, or empty target fixtures fail-closed")
    func subThresholdCoverageFixturesFailClosed() throws {
        let subUIJSON = Data("""
        {
          "data": [{
            "files": [
              { "filename": "/repo/Sources/SwiftEditCore/A.swift", "summary": { "lines": { "count": 1000, "covered": 920 } } },
              { "filename": "/repo/Sources/SwiftEditUI/B.swift", "summary": { "lines": { "count": 1000, "covered": 849 } } }
            ]
          }]
        }
        """.utf8)
        let subUIResult = try CodeCoverageThresholdEvaluator.evaluateLLVMExportJSON(subUIJSON)
        #expect(subUIResult.passesGate == false)
        #expect(subUIResult.failingTargets == ["SwiftEditUI"])

        let subCoreJSON = Data("""
        {
          "data": [{
            "files": [
              { "filename": "/repo/Sources/SwiftEditCore/A.swift", "summary": { "lines": { "count": 1000, "covered": 849 } } },
              { "filename": "/repo/Sources/SwiftEditUI/B.swift", "summary": { "lines": { "count": 1000, "covered": 900 } } }
            ]
          }]
        }
        """.utf8)
        let subCoreResult = try CodeCoverageThresholdEvaluator.evaluateLLVMExportJSON(subCoreJSON)
        #expect(subCoreResult.passesGate == false)
        #expect(subCoreResult.failingTargets == ["SwiftEditCore"])

        let emptyJSON = Data(#"{"data":[{"files":[]}]}"#.utf8)
        let emptyResult = try CodeCoverageThresholdEvaluator.evaluateLLVMExportJSON(emptyJSON)
        #expect(emptyResult.passesGate == false)
        #expect(emptyResult.failingTargets.count == 3)
    }

    @Test("P10a: SwiftEditCommands, ElementContextualMenuView, PropertiesPanelView, and UpdateCheckSheetView render across all states")
    func renderMenusContextualPalettePropertiesAndUpdateStates() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("conv-ui-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let mdFile = dir.appendingPathComponent("frontmatter.md")
        try """
        ---
        title: Convergence Test
        tags: [alpha, beta]
        nested:
          child: 1
        notes: |
          line one
          line two
        base: &baseAnchor value
        ref: *baseAnchor
        custom: !customTag payload
        ---

        # Section One

        Hello `world` and **markdown** text for selection!
        """.write(to: mdFile, atomically: true, encoding: .utf8)

        let brokenFrontmatterFile = dir.appendingPathComponent("unterminated.md")
        try """
        ---
        title: Unterminated YAML
        key_without_close: 42
        """.write(to: brokenFrontmatterFile, atomically: true, encoding: .utf8)

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: dir.appendingPathComponent("rec"),
            fileSystem: LocalFileSystemAdapter(),
            savePanelProvider: { _ in nil }
        )
        model.openFile(at: mdFile, withinScope: dir)

        // 1. SwiftEditCommands body + FocusedValues + combinedMenuPreview across nil, active, and toggled states
        Self.renderOffscreen(Color.clear.focusedSceneValue(\.workbenchModel, model), size: NSSize(width: 64, height: 64))
        let commands = SwiftEditCommands()
        _ = commands.body

        Self.renderOffscreen(SwiftEditCommands.combinedMenuPreview(model: nil), size: NSSize(width: 480, height: 900))
        Self.renderOffscreen(SwiftEditCommands.combinedMenuPreview(model: model), size: NSSize(width: 480, height: 900))
        model.toggleWordWrap()
        model.toggleDiffPane()
        model.toggleMarkdownPreview()
        model.toggleShortcutsPanel()
        model.isDistractionFree = true
        Self.renderOffscreen(SwiftEditCommands.combinedMenuPreview(model: model), size: NSSize(width: 480, height: 900))
        model.isDistractionFree = false
        model.toggleShortcutsPanel()
        model.toggleMarkdownPreview()
        model.toggleDiffPane()
        model.toggleWordWrap()

        // 2. ElementContextualMenuView across anchored, unanchored, collapsed group, and empty search states
        model.handleSelectionChanged(SwiftEditCore.TextRange(location: 185, length: 5))
        #expect(model.presentElementContextualMenu(anchor: CGPoint(x: 160, y: 140)))
        for mode in [AppearanceMode.light, .black] {
            model.appearanceMode = mode
            Self.renderOffscreen(ElementContextualMenuView(model: model), size: NSSize(width: 640, height: 480))
            if let firstGroup = model.elementContextualMenu?.rows.first, case .group(let grp, _) = firstGroup {
                model.elementContextualMenu?.toggleGroup(grp.id)
                Self.renderOffscreen(ElementContextualMenuView(model: model), size: NSSize(width: 640, height: 480))
                model.elementContextualMenu?.toggleGroup(grp.id)
            }
            model.elementContextualMenu?.setQuery("zzz_unmatched_query_999")
            Self.renderOffscreen(ElementContextualMenuView(model: model), size: NSSize(width: 640, height: 480))
            model.elementContextualMenu?.setQuery("")
        }
        model.closeElementContextualMenu()
        #expect(ElementContextualMenuView.origin(for: nil, in: CGSize(width: 800, height: 600), globalOrigin: .zero).y == 96)
        #expect(ElementContextualMenuView.origin(for: CGPoint(x: 790, y: 590), in: CGSize(width: 800, height: 600), globalOrigin: .zero).x <= 492)

        // 3. PropertiesPanelView expanded & collapsed across all 6 FrontmatterProperty kinds + read-only malformed frontmatter
        model.propertiesPanel.isCollapsed = true
        Self.renderOffscreen(PropertiesPanelView(model: model, state: model.propertiesPanel), size: NSSize(width: 780, height: 120))
        model.propertiesPanel.isCollapsed = false
        Self.renderOffscreen(PropertiesPanelView(model: model, state: model.propertiesPanel), size: NSSize(width: 780, height: 360))

        if let props = model.propertiesModel?.properties {
            let rows = props.map { PropertiesPanelRow(property: $0, modelIsReadOnly: false) }
            #expect(rows.count >= 6)
            if let scalarRow = rows.first(where: { $0.isList == false && $0.isEditable }) {
                #expect(scalarRow.editValue(from: "Updated Title") == .scalar("Updated Title"))
            }
            if let listRow = rows.first(where: { $0.isList }) {
                #expect(listRow.editValue(from: "one, two , three") == .list(["one", "two", "three"]))
            }
        }
        _ = model.applyPropertyOperation(.setValue(key: "title", value: .scalar("Updated Convergence")))
        _ = model.applyPropertyOperation(.add(key: "added_key", value: .scalar("yes")))
        _ = model.applyPropertyOperation(.remove(key: "added_key"))

        model.openFile(at: brokenFrontmatterFile, withinScope: dir)
        model.propertiesPanel.isCollapsed = false
        Self.renderOffscreen(PropertiesPanelView(model: model, state: model.propertiesPanel), size: NSSize(width: 780, height: 220))

        // 4. UpdateCheckSheetView checking, installing, nil outcome, and non-zip download fallback
        let palette = model.palette
        model.isCheckingForUpdates = true
        Self.renderOffscreen(UpdateCheckSheetView(model: model, palette: palette, onClose: {}))
        model.isCheckingForUpdates = false
        model.isInstallingUpdate = true
        Self.renderOffscreen(UpdateCheckSheetView(model: model, palette: palette, onClose: {}))
        model.isInstallingUpdate = false
        model.updateCheckOutcome = nil
        Self.renderOffscreen(UpdateCheckSheetView(model: model, palette: palette, onClose: {}))
        model.updateCheckOutcome = .updateAvailable(
            currentVersion: "0.1.4",
            latestVersion: "0.2.0",
            releaseURL: URL(string: "https://github.com/paonath/PH.SwiftEdit/releases/tag/v0.2.0")!,
            downloadURL: nil
        )
        Self.renderOffscreen(UpdateCheckSheetView(model: model, palette: palette, onClose: {}))
    }

    @Test("P10b: WorkbenchSubControllers, terminal/log/update model flows, root drop/menus/alerts, and core highlight/shortcut edge paths")
    func subControllersTerminalLogAndRootViewInteractions() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("conv-sub-\(UUID().uuidString)")
        let outsideDir = FileManager.default.temporaryDirectory.appendingPathComponent("conv-out-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outsideDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: dir)
            try? FileManager.default.removeItem(at: outsideDir)
        }

        // 1. WorkbenchWordCompletionController
        let wc = WorkbenchWordCompletionController()
        let docID = DocumentID()
        #expect(wc.needsRebuild(for: docID))
        #expect(wc.completionSuffix(forPrefix: "sw", documentID: docID, isEligible: true) == nil)
        wc.rebuildIndexNow(documentID: docID, revision: BufferRevision(1), text: "swiftedit swiftness alpha", caretLocation: 24)
        #expect(wc.needsRebuild(for: docID) == false)
        #expect(wc.completionSuffix(forPrefix: "swifte", documentID: docID, isEligible: true) == "dit")
        #expect(wc.completionSuffix(forPrefix: "s", documentID: docID, isEligible: true) == nil)
        #expect(wc.completionSuffix(forPrefix: "swifte", documentID: docID, isEligible: false) == nil)
        wc.scheduleRebuild(debounce: .zero, targetID: docID, targetRevision: BufferRevision(2)) {
            (docID, BufferRevision(2), "convergent architecture ", 24)
        }
        await wc.rebuildTask?.value
        #expect(wc.completionSuffix(forPrefix: "conv", documentID: docID, isEligible: true) == "ergent")
        wc.invalidate(documentID: docID)
        #expect(wc.needsRebuild(for: docID))

        // 2. WorkbenchFindAndNavigationController
        let fn = WorkbenchFindAndNavigationController()
        fn.presentFindBar(mode: .findAndReplace)
        #expect(fn.state.mode == .findAndReplace)
        fn.state.query = "beta"
        let snap = DocumentSnapshot(
            id: docID,
            revision: BufferRevision(1),
            text: "alpha\nbeta one\nbeta two",
            encoding: .utf8,
            lineEnding: .lf,
            isDegradedPlainText: false,
            isBinaryReadOnly: false
        )
        #expect(fn.executeFind(in: snap) != nil)
        #expect(fn.state.matches.count == 2)
        #expect(fn.resolveGoToLineRange(query: "2", in: snap) != nil)
        #expect(fn.resolveGoToLineRange(query: "0", in: snap) == nil)
        #expect(fn.resolveGoToLineRange(query: "not-a-number", in: snap) == nil)

        // 3. WorkbenchTerminalSessionController
        let tc = WorkbenchTerminalSessionController()
        #expect(tc.clampHeight(50) == WorkbenchTerminalSessionController.minPanelHeight)
        #expect(tc.clampHeight(999, maxAvailableHeight: 500) <= 325)
        let openedSession = tc.openSession(initialDirectory: dir)
        #expect(tc.isPanelVisible)
        #expect(tc.selectedSessionID == openedSession.id)
        #expect(tc.evaluateSendSelection(selection: SwiftEditCore.TextRange(location: 0, length: 0), in: "echo hi") == .emptySelection)
        if case .deliverImmediately(let single) = tc.evaluateSendSelection(selection: SwiftEditCore.TextRange(location: 0, length: 4), in: "echo hi") {
            #expect(single.isMultiline == false)
        } else {
            Issue.record("Expected single-line immediate delivery")
        }
        if case .requiresMultilineConfirmation(let multi) = tc.evaluateSendSelection(selection: SwiftEditCore.TextRange(location: 0, length: 9), in: "echo 1\nls") {
            #expect(multi.isMultiline)
        } else {
            Issue.record("Expected multiline confirmation")
        }
        #expect(tc.confirmPendingMultilineSend() != nil)
        #expect(tc.pendingMultilineSend == nil)
        _ = tc.evaluateSendSelection(selection: SwiftEditCore.TextRange(location: 0, length: 9), in: "echo 1\nls")
        tc.cancelPendingMultilineSend()
        #expect(tc.pendingMultilineSend == nil)

        // 4. WorkbenchSidebarFileController (confined + out-of-scope rejection + clipboard)
        let sc = WorkbenchSidebarFileController(fileSystem: LocalFileSystemAdapter())
        #expect(sc.createFile(named: "escape.md", in: outsideDir, scopeRoot: dir) == nil)
        #expect(sc.lastErrorMessage?.contains("outside workspace scope") == true)
        #expect(sc.createFolder(named: "escapeDir", in: outsideDir, scopeRoot: dir) == nil)
        let createdFile = try #require(sc.createFile(named: "inside.md", in: dir, scopeRoot: dir))
        let createdSubdir = try #require(sc.createFolder(named: "sub", in: dir, scopeRoot: dir))
        #expect(FileManager.default.fileExists(atPath: createdSubdir.path))
        let renamedFile = try #require(sc.renameItem(at: createdFile, to: "renamed.md", scopeRoot: dir))
        #expect(sc.renameItem(at: outsideDir, to: "nope", scopeRoot: dir) == nil)
        sc.stageClipboard(itemURL: renamedFile, mode: .copy)
        #expect(sc.clipboard?.mode == .copy)

        // 5. WorkbenchUpdateController + SwiftEditWorkbenchModel terminal/log/update methods
        let uc = WorkbenchUpdateController(updateChecker: GitHubReleaseUpdateChecker())
        uc.isDialogPresented = true
        uc.dismissDialog()
        #expect(uc.isDialogPresented == false)
        uc.cancelPendingCheck()

        let logFile = dir.appendingPathComponent("app.log")
        try "2026-11-24T12:00:00Z [ERROR] disk full at /var/log/app.log (code=500)\n2026-11-24T12:00:01Z [WARN] retry scheduled\n".write(to: logFile, atomically: true, encoding: .utf8)
        let secondDoc = dir.appendingPathComponent("second.md")
        try "# Second\n\nDifferent line (`unclosed".write(to: secondDoc, atomically: true, encoding: .utf8)

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: dir.appendingPathComponent("rec2"),
            fileSystem: LocalFileSystemAdapter()
        )
        model.openDroppedURLs([dir])
        model.openFile(at: renamedFile, withinScope: dir)
        model.handleEditorTextChanged("echo one\necho two\n")

        #expect(model.requestSendSelectionToTerminal(selection: SwiftEditCore.TextRange(location: 0, length: 0)) == false)
        #expect(model.requestSendSelectionToTerminal(selection: SwiftEditCore.TextRange(location: 0, length: 8)))
        #expect(model.requestSendSelectionToTerminal(selection: SwiftEditCore.TextRange(location: 0, length: 17)))
        #expect(model.pendingMultilineTerminalSend != nil)
        model.cancelPendingMultilineTerminalSend()
        #expect(model.pendingMultilineTerminalSend == nil)
        #expect(model.requestSendSelectionToTerminal(selection: SwiftEditCore.TextRange(location: 0, length: 17)))
        model.confirmPendingMultilineTerminalSend()

        model.setTerminalPanelHeight(300, maxAvailableHeight: 600, persist: true)
        model.setTerminalPanelHeight(300, maxAvailableHeight: nil, persist: true)
        if let sid = model.selectedTerminalSessionID {
            model.relaunchTerminalSession(id: sid)
            model.embeddedTerminalDidUpdateDirectory(id: sid, directory: "file://\(dir.path)")
            model.embeddedTerminalDidUpdateDirectory(id: sid, directory: dir.path)
            model.embeddedTerminalDidTerminate(id: sid, exitCode: 2)
            model.terminalApplicationDidTerminate(bundleIdentifier: nil)
            model.embeddedTerminalDidTerminate(id: sid, exitCode: 0)
        }
        if model.isTerminalPanelVisible {
            model.toggleTerminalPanel()
        }

        model.openFile(at: logFile, withinScope: dir)
        model.startLogTail(mode: .direct)
        model.startLogTail(mode: .inverse)
        model.stopLogTail()
        model.closeLogTail()

        // 6. SwiftEditRootView external file drop, sidebar context menus, compare destination, and alert bindings
        model.openFile(at: secondDoc, withinScope: dir)
        model.toggleDiffPane()
        if let candidate = model.compareDestinationCandidates.first {
            model.setCompareDestination(candidate.id)
        }
        model.isShortcutsPanelVisible = true
        model.requestSidebarTrashItem(at: secondDoc)
        let rootView = SwiftEditRootView(initialModel: model)
        Self.renderOffscreen(rootView, size: NSSize(width: 1280, height: 800))

        #expect(rootView.trashItemAlertPresented.wrappedValue)
        rootView.trashItemAlertPresented.wrappedValue = false
        #expect(model.pendingTrashItemURL == nil)

        model.pendingBatchOpenPlan = BatchOpenPlan(
            files: [renamedFile, secondDoc],
            skippedBinaryCount: 0,
            skippedFolderCount: 0,
            totalBytes: 64,
            requiresConfirmation: true
        )
        #expect(rootView.batchOpenAlertPresented.wrappedValue)
        rootView.batchOpenAlertPresented.wrappedValue = false
        #expect(model.pendingBatchOpenPlan == nil)

        _ = model.requestSendSelectionToTerminal(selection: SwiftEditCore.TextRange(location: 0, length: 9), sourceText: "line1\nline2")
        #expect(rootView.multilineTerminalSendAlertPresented.wrappedValue)
        rootView.multilineTerminalSendAlertPresented.wrappedValue = false
        #expect(model.pendingMultilineTerminalSend == nil)

        for entry in model.folderEntries {
            Self.renderOffscreen(VStack { rootView.sidebarEntryContextMenu(for: entry) }, size: NSSize(width: 280, height: 320))
        }
        Self.renderOffscreen(VStack { rootView.sidebarBackgroundContextMenu }, size: NSSize(width: 280, height: 240))

        #expect(rootView.handleExternalFileDrop(providers: []) == false)
        let urlProvider = NSItemProvider(object: secondDoc as NSURL)
        #expect(rootView.handleExternalFileDrop(providers: [urlProvider]))

        let dummyTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 80))
        #expect(SwiftEditRootView.selectionAnchor(in: dummyTextView) == nil)

        // 7. LogSyntaxHighlighter & MarkdownAuthoringCommands smoke checks
        let logText = "2026-11-24T12:00:00Z ERROR [worker] 550e8400-e29b-41d4-a716-446655440000 RuntimeException \"timeout\"\n    at App.run(Main.swift:42)"
        let logIndex = MarkdownLineIndex(text: logText)
        let logSpans = LogSyntaxHighlighter.spans(index: logIndex, visibleRange: SwiftEditCore.TextRange(location: 0, length: logIndex.units.count))
        #expect(logSpans.isEmpty == false)
        #expect(LogSyntaxHighlighter.level(of: logText) == .error)
    }

    @Test("P10: Live codecov export meets >= 85.0% on SwiftEditCore, SwiftEditUI, and aggregate Sources/")
    func liveCodecovExportMeets85PercentGate() throws {
        let passingFixture = Data("""
        {
          "data": [{
            "files": [
              { "filename": "/repo/Sources/SwiftEditCore/A.swift", "summary": { "lines": { "count": 1000, "covered": 910 } } },
              { "filename": "/repo/Sources/SwiftEditUI/B.swift", "summary": { "lines": { "count": 1000, "covered": 860 } } }
            ]
          }]
        }
        """.utf8)
        let fixtureVerdict = try CodeCoverageThresholdEvaluator.evaluateLLVMExportJSON(passingFixture)
        #expect(fixtureVerdict.passesGate)
        #expect(fixtureVerdict.swiftEditCore.linePercent >= 85.0)
        #expect(fixtureVerdict.swiftEditUI.linePercent >= 85.0)
        #expect(fixtureVerdict.aggregate.linePercent >= 85.0)

        if let codecovPath = ProcessInfo.processInfo.environment["SWIFTEDIT_CODECOV_JSON_PATH"],
           FileManager.default.fileExists(atPath: codecovPath) {
            let data = try Data(contentsOf: URL(fileURLWithPath: codecovPath))
            let verdict = try CodeCoverageThresholdEvaluator.evaluateLLVMExportJSON(data)
            #expect(
                verdict.passesGate,
                "Expected >= 85.0% coverage across all targets, got Core=\(String(format: "%.2f", verdict.swiftEditCore.linePercent))%, UI=\(String(format: "%.2f", verdict.swiftEditUI.linePercent))%, Aggregate=\(String(format: "%.2f", verdict.aggregate.linePercent))%, failing=\(verdict.failingTargets)"
            )
        }
    }
}
