import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

#if os(macOS)
import AppKit

@Suite("Unit 1: Clean/Baseline-Reverted Tab Close, Bulk Tab Context Actions & Tab History (REQ-001, REQ-002)")
struct TabBulkCloseAndHistoryTests {

    private static func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftEditTabBulkTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @MainActor
    private static func makeModel(recoveryDir: URL) -> SwiftEditWorkbenchModel {
        SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: recoveryDir,
            fileSystem: LocalFileSystemAdapter(),
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
    }

    @Test("P1: New Untitled tab, clean file tab, and edited-then-reverted tab report isDirty == false and close immediately without confirmation")
    @MainActor
    func p1CleanUntitledFileAndBaselineRevertedTabsCloseWithoutConfirmation() throws {
        // GIVEN a workbench with an ephemeral workspace directory
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("notes.md")
        try Data("# Original\nLine 2\n".utf8).write(to: fileURL)
        let model = Self.makeModel(recoveryDir: dir.appendingPathComponent("rec"))

        // 1. New empty Untitled tab starts with isDirty == false and closes immediately
        model.newUntitledTab()
        let untitledID = try #require(model.tabSession.activeTabID)
        #expect(model.tabSession.tabs.first(where: { $0.id == untitledID })?.isDirty == false)
        #expect(model.sessionsByID[untitledID]?.isDirty == false)
        model.requestCloseTab(id: untitledID)
        #expect(model.pendingDirtyCloseTabID == nil)
        #expect(model.tabSession.tabs.isEmpty)

        // 2. Freshly opened file tab edits text & LineEnding, then reverts back to baseline -> isDirty resets to false and closes immediately
        model.openFile(at: fileURL, withinScope: dir)
        let fileID = try #require(model.tabSession.activeTabID)
        model.handleEditorTextChanged("# Modified\n")
        model.setActiveDocumentLineEnding(.crlf)
        #expect(model.tabSession.tabs.first(where: { $0.id == fileID })?.isDirty == true)

        model.handleEditorTextChanged("# Original\nLine 2\n")
        model.setActiveDocumentLineEnding(.lf)
        #expect(model.sessionsByID[fileID]?.isDirty == false)
        #expect(model.tabSession.tabs.first(where: { $0.id == fileID })?.isDirty == false)

        model.requestCloseActiveTab()
        #expect(model.pendingDirtyCloseTabID == nil)
        #expect(model.tabSession.tabs.isEmpty)
    }

    @Test("N1: Modified text or modified LineEnding sets pendingDirtyCloseTabID and single pinned close blocks with banner")
    @MainActor
    func n1ModifiedTextOrLineEndingPromptsAndPinnedSingleCloseBlocks() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("doc.md")
        try Data("hello\n".utf8).write(to: fileURL)
        let model = Self.makeModel(recoveryDir: dir.appendingPathComponent("rec"))

        model.openFile(at: fileURL, withinScope: dir)
        let id = try #require(model.tabSession.activeTabID)

        // LineEnding-only mutation keeps isDirty == true
        model.setActiveDocumentLineEnding(.crlf)
        #expect(model.tabSession.tabs.first(where: { $0.id == id })?.isDirty == true)
        model.requestCloseTab(id: id)
        #expect(model.pendingDirtyCloseTabID == id)
        model.resolvePendingDirtyClose(.cancel)
        #expect(model.tabSession.tabs.count == 1)

        // Revert LineEnding, pin tab, and verify single-tab close blocks
        model.setActiveDocumentLineEnding(.lf)
        #expect(model.tabSession.tabs.first(where: { $0.id == id })?.isDirty == false)
        model.togglePin(id: id)
        model.requestCloseTab(id: id)
        #expect(model.tabSession.tabs.count == 1)
        #expect(model.statusBannerMessage?.contains("Pinned tab") == true)
    }

    @Test("P2: Bulk close actions (Right, Other, Unpinned, All), middle-click, Shift+Cmd+T reopen, and tab shortcuts execute deterministically")
    @MainActor
    func p2BulkCloseActionsReopenMiddleClickAndTabShortcuts() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let urls = try (1...5).map { idx -> URL in
            let u = dir.appendingPathComponent("f\(idx).md")
            try Data("content-\(idx)".utf8).write(to: u)
            return u
        }
        let model = Self.makeModel(recoveryDir: dir.appendingPathComponent("rec"))
        model.selectWorkspaceFolder(dir)
        for u in urls {
            model.openFile(at: u, withinScope: dir)
        }
        let ids = model.tabSession.tabs.map(\.id)
        let (p1, p2, u1, u2Dirty, u3Clean) = (ids[0], ids[1], ids[2], ids[3], ids[4])
        model.togglePin(id: p1)
        model.togglePin(id: p2)

        // Keyboard cycling & Cmd+1..9
        model.selectTabAtShortcutIndex(1)
        #expect(model.tabSession.activeTabID == p1)
        model.selectNextTab()
        #expect(model.tabSession.activeTabID == p2)
        model.selectPreviousTab()
        #expect(model.tabSession.activeTabID == p1)
        model.selectTabAtShortcutIndex(9)
        #expect(model.tabSession.activeTabID == u3Clean)

        // Dirty u2Dirty
        model.activateTab(id: u2Dirty)
        model.handleEditorTextChanged("dirty-u2")

        // Close Tabs to the Right of u1 -> u3Clean closes immediately, u2Dirty prompts -> dontSave closes u2Dirty; [p1, p2, u1] remain
        model.requestCloseTabsToTheRight(of: u1)
        #expect(model.pendingDirtyCloseTabID == u2Dirty)
        model.resolvePendingDirtyClose(.dontSave)
        #expect(model.tabSession.tabs.map(\.id) == [p1, p2, u1])

        // Reopen Closed Tab (Shift+Cmd+T) reopens most recently closed file (f4.md / u2Dirty's disk file)
        #expect(model.reopenLastClosedTab() == true)
        #expect(model.tabSession.tabs.last?.fileURL?.standardizedFileURL == urls[3].standardizedFileURL)

        // Middle-click closes active unpinned tab
        let reopenedID = try #require(model.tabSession.tabs.last?.id)
        model.handleMiddleClickTab(id: reopenedID)
        #expect(model.tabSession.tabs.map(\.id) == [p1, p2, u1])

        // Reopen f5.md so we have [p1, p2, u1, f5] and test Close Other Tabs keeping f5 -> preserves [p1, p2, f5]
        #expect(model.reopenLastClosedTab() == true)
        let f5ID = try #require(model.tabSession.tabs.last?.id)
        model.requestCloseOtherTabs(keeping: f5ID)
        #expect(model.tabSession.tabs.map(\.id) == [p1, p2, f5ID])

        // Close All Unpinned Tabs -> preserves [p1, p2]
        model.requestCloseAllUnpinnedTabs()
        #expect(model.tabSession.tabs.map(\.id) == [p1, p2])

        // Close All Tabs -> closes pinned tabs too
        model.requestCloseAllTabs()
        #expect(model.tabSession.tabs.isEmpty)
    }

    @Test("N2: Canceling dirty prompt during bulk close halts remaining queue and empty bulk scopes perform safe no-ops")
    @MainActor
    func n2CancelHaltsBulkQueueAndEmptyScopesNoOp() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let model = Self.makeModel(recoveryDir: dir.appendingPathComponent("rec"))

        // Empty history reopen is a safe false
        #expect(model.reopenLastClosedTab() == false)

        model.newUntitledTab()
        let p1 = try #require(model.tabSession.activeTabID)
        model.togglePin(id: p1)

        // Only pinned tabs open -> Close All Unpinned Tabs is a safe no-op
        model.requestCloseAllUnpinnedTabs()
        #expect(model.tabSession.tabs.map(\.id) == [p1])

        model.newUntitledTab()
        let u1Dirty = try #require(model.tabSession.activeTabID)
        model.handleEditorTextChanged("unsaved-1")

        model.newUntitledTab()
        let u2Dirty = try #require(model.tabSession.activeTabID)
        model.handleEditorTextChanged("unsaved-2")

        // Rightmost tab -> Close Tabs to the Right is a safe no-op
        model.requestCloseTabsToTheRight(of: u2Dirty)
        #expect(model.pendingDirtyCloseTabID == nil)
        #expect(model.tabSession.tabs.count == 3)

        // Close All Unpinned Tabs -> prompts u1Dirty -> Cancel halts queue leaving both u1Dirty and u2Dirty open
        model.requestCloseAllUnpinnedTabs()
        #expect(model.pendingDirtyCloseTabID != nil)
        model.resolvePendingDirtyClose(.cancel)
        #expect(model.pendingDirtyCloseTabID == nil)
        #expect(model.tabSession.tabs.map(\.id) == [p1, u1Dirty, u2Dirty])
        #expect(model.sessionsByID[u1Dirty]?.text == "unsaved-1")
        #expect(model.sessionsByID[u2Dirty]?.text == "unsaved-2")
    }

    @Test("N3 [Security]: Bulk close and dirty termination immediately unlink recovery snapshots, stop log tails, evict undo/caches, and reject symlink-escaped reopen")
    @MainActor
    func n3SecurityImmediateSnapshotUnlinkDescriptorStopAndSymlinkReopenRejection() throws {
        let dir = try Self.makeTempDir()
        let outsideDir = try Self.makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: dir)
            try? FileManager.default.removeItem(at: outsideDir)
        }
        let recDir = dir.appendingPathComponent("rec", isDirectory: true)
        let logFile = dir.appendingPathComponent("app.log")
        let docFile = dir.appendingPathComponent("note.md")
        let outsideSecret = outsideDir.appendingPathComponent("secret.md")
        try Data("2026-11-25 INFO boot\n".utf8).write(to: logFile)
        try Data("# Note\n".utf8).write(to: docFile)
        try Data("secret".utf8).write(to: outsideSecret)

        let model = Self.makeModel(recoveryDir: recDir)
        model.selectWorkspaceFolder(dir)
        model.openFile(at: logFile, withinScope: dir)
        let logID = try #require(model.tabSession.activeTabID)
        model.startLogTail(mode: .direct)
        #expect(model.logTails[logID]?.isRunning == true)

        model.openFile(at: docFile, withinScope: dir)
        let docID = try #require(model.tabSession.activeTabID)
        _ = model.undoRegistry.undoManager(for: docID)
        model.handleEditorTextChanged("# Unsaved secret draft\n")
        // Force immediate recovery snapshot persistence
        try model.deps.recoveryStore.saveRecoverySnapshot(try #require(model.sessionsByID[docID]?.snapshot))
        PreviewThumbnailCache.shared.store(NSImage(size: NSSize(width: 8, height: 8)), forKey: "sec-thumb", costBytes: 64)

        // 1. Bulk Close All Tabs -> unlinks .recovery, stops log tail, clears undo & PreviewThumbnailCache
        model.requestCloseAllTabs()
        model.resolvePendingDirtyClose(.dontSave)
        #expect(model.tabSession.tabs.isEmpty)
        #expect(model.logTails.isEmpty)
        #expect(model.undoRegistry.containsUndoManager(for: docID) == false)
        #expect(PreviewThumbnailCache.shared.image(forKey: "sec-thumb") == nil)
        let remainingRecFiles = (try? FileManager.default.contentsOfDirectory(atPath: recDir.path)) ?? []
        #expect(remainingRecFiles.filter { $0.hasSuffix(".recovery") }.isEmpty)

        // 2. Replace closed docFile with a symlink escaping dir -> Shift+Cmd+T reopen rejects escaping symlink fail-closed
        try FileManager.default.removeItem(at: docFile)
        try FileManager.default.createSymbolicLink(at: docFile, withDestinationURL: outsideSecret)
        _ = model.reopenLastClosedTab()
        #expect(model.tabSession.tabs.contains { $0.fileURL?.lastPathComponent == "note.md" } == false)

        // 3. App termination (.dontSave) ALSO stops active logTails and clears PreviewThumbnailCache / diffCoordinator
        model.openFile(at: logFile, withinScope: dir)
        let termLogID = try #require(model.tabSession.activeTabID)
        model.startLogTail(mode: .direct)
        model.newUntitledTab()
        model.handleEditorTextChanged("dirty-quit")
        PreviewThumbnailCache.shared.store(NSImage(size: NSSize(width: 8, height: 8)), forKey: "quit-thumb", costBytes: 64)
        _ = model.requestApplicationTermination { _ in }
        model.resolvePendingDirtyClose(.dontSave)
        #expect(model.logTails[termLogID] == nil)
        #expect(PreviewThumbnailCache.shared.image(forKey: "quit-thumb") == nil)
    }
}
#endif
