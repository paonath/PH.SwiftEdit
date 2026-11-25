import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

#if os(macOS)

@Suite("Unit 4: Confined External File Change Monitor & Revert to Saved (REQ-006)")
struct ExternalFileChangeMonitorTests {

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftEditExtWatch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("P6: Clean file-backed tab auto-reloads on external write, dirty tab preserves edits and surfaces Reload / Keep Mine / Compare, and Revert to Saved reloads from disk")
    @MainActor
    func p6CleanAutoReloadDirtyConflictBannerCompareAndRevertToSaved() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileURL = dir.appendingPathComponent("notes.md")
        try "initial v1\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: dir.appendingPathComponent("Recovery", isDirectory: true)
        )
        model.selectWorkspaceFolder(dir)
        model.openFile(at: fileURL, withinScope: dir)

        let tabID = try #require(model.tabSession.activeTabID)
        #expect(model.activeDocumentSession?.text == "initial v1\n")
        #expect(model.activeDocumentSession?.isDirty == false)

        // 1. Clean tab auto-reloads when disk changes externally, keeping isDirty == false
        try "external v2\n".write(to: fileURL, atomically: true, encoding: .utf8)
        model.checkExternalChangesNow()
        #expect(model.activeDocumentSession?.text == "external v2\n")
        #expect(model.activeDocumentSession?.isDirty == false)
        #expect(model.activeTabHasExternalConflict == false)

        // 2. Dirty tab preserves unsaved edits and stages conflict without overwriting buffer
        model.handleEditorTextChanged("my local unsaved v3\n")
        #expect(model.activeDocumentSession?.isDirty == true)
        try "concurrent disk v4\n".write(to: fileURL, atomically: true, encoding: .utf8)
        model.checkExternalChangesNow()

        #expect(model.activeDocumentSession?.text == "my local unsaved v3\n")
        #expect(model.activeTabHasExternalConflict == true)

        // 3. Compare opens diff pane showing disk vs local unsaved edits
        model.compareConflictedTabWithDisk(id: tabID)
        #expect(model.showDiffPane == true)
        #expect(model.diffCoordinator.hasDifferences == true)

        // 4. Keep Mine dismisses conflict while preserving local dirty text
        model.keepLocalEditsForConflictedTab(id: tabID)
        #expect(model.activeTabHasExternalConflict == false)
        #expect(model.activeDocumentSession?.text == "my local unsaved v3\n")
        #expect(model.activeDocumentSession?.isDirty == true)

        // 5. Re-trigger disk change and choose Reload from Disk
        try "disk v5\n".write(to: fileURL, atomically: true, encoding: .utf8)
        model.checkExternalChangesNow()
        #expect(model.activeTabHasExternalConflict == true)
        model.reloadConflictedTabFromDisk(id: tabID)
        #expect(model.activeTabHasExternalConflict == false)
        #expect(model.activeDocumentSession?.text == "disk v5\n")
        #expect(model.activeDocumentSession?.isDirty == false)

        // 6. Manual Revert to Saved discards local edits and reloads disk baseline
        model.handleEditorTextChanged("temporary scratch\n")
        #expect(model.activeDocumentSession?.isDirty == true)
        model.revertActiveDocumentToSaved()
        #expect(model.activeDocumentSession?.text == "disk v5\n")
        #expect(model.activeDocumentSession?.isDirty == false)
    }

    @Test("N7 [Security]: External binary overwrite, symlink replacement escaping scope, and Untitled tabs never clobber dirty buffers and release O_EVTONLY descriptors on close")
    @MainActor
    func n7BinaryOverwriteSymlinkEscapeUntitledGuardAndDescriptorCleanup() throws {
        let root = try makeTempDir()
        let workspace = root.appendingPathComponent("Workspace", isDirectory: true)
        let outside = root.appendingPathComponent("Outside", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let secretFile = outside.appendingPathComponent("secret.txt")
        try "TOP SECRET OUTSIDE SCOPE\n".write(to: secretFile, atomically: true, encoding: .utf8)

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: root.appendingPathComponent("Recovery", isDirectory: true)
        )
        model.selectWorkspaceFolder(workspace)

        // 1. Untitled tab has 0 descriptors and Revert to Saved is a safe no-op
        model.newUntitledTab()
        model.handleEditorTextChanged("untitled draft")
        #expect(model.externalFileMonitor.activeDescriptorCount == 0)
        model.revertActiveDocumentToSaved()
        #expect(model.activeDocumentSession?.text == "untitled draft")

        // 2. Dirty file-backed tab survives external NUL binary overwrite without losing unsaved edits
        let binTarget = workspace.appendingPathComponent("doc.md")
        try "clean text\n".write(to: binTarget, atomically: true, encoding: .utf8)
        model.openFile(at: binTarget, withinScope: workspace)
        let binTabID = try #require(model.tabSession.activeTabID)
        #expect(model.externalFileMonitor.activeDescriptorCount == 1)

        model.handleEditorTextChanged("precious unsaved text\n")
        try Data([0x48, 0x65, 0x00, 0xFF, 0x00]).write(to: binTarget, options: .atomic)
        model.checkExternalChangesNow()
        #expect(model.sessionsByID[binTabID]?.text == "precious unsaved text\n")
        #expect(model.sessionsByID[binTabID]?.isDirty == true)

        // 3. Symlink replacement escaping workspace scope aborts reload fail-closed, unwatches tab, and surfaces security banner
        let symTarget = workspace.appendingPathComponent("linked.md")
        try "safe inside scope\n".write(to: symTarget, atomically: true, encoding: .utf8)
        model.openFile(at: symTarget, withinScope: workspace)
        let symTabID = try #require(model.tabSession.activeTabID)

        try FileManager.default.removeItem(at: symTarget)
        try FileManager.default.createSymbolicLink(at: symTarget, withDestinationURL: secretFile)
        model.checkExternalChangesNow()

        #expect(model.sessionsByID[symTabID]?.text == "safe inside scope\n")
        #expect(model.externalFileMonitor.watchedTabIDs.contains(symTabID) == false)
        #expect(model.statusBannerMessage?.lowercased().contains("scope") == true)

        // 4. Closing all tabs drops activeDescriptorCount to 0
        model.requestCloseAllTabs()
        while model.pendingDirtyCloseTabID != nil {
            model.resolvePendingDirtyClose(.dontSave)
        }
        #expect(model.externalFileMonitor.activeDescriptorCount == 0)
    }
}
#endif
