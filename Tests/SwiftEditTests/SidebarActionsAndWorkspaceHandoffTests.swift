import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

private final class RecordingTrasherFake: ItemTrashing, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var trashedURLs: [URL] = []

    func trashItem(at url: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        trashedURLs.append(url.standardizedFileURL)
        try FileManager.default.removeItem(at: url)
    }
}

@MainActor
private final class RecordingDesktopWorkspaceFake: DesktopWorkspaceIntegrating {
    var isITerm2Installed: Bool = true
    var isITerm2Preferred: Bool = true
    private(set) var revealedURLs: [URL] = []
    private(set) var openedFolderURLs: [URL] = []
    private(set) var terminalLaunches: [(directoryURL: URL, bundleIdentifier: String)] = []

    func revealInFinder(itemURL: URL, withinScope scopeURL: URL?) throws {
        try DesktopWorkspaceValidator.verifyItemConfinement(targetURL: itemURL, withinScope: scopeURL)
        revealedURLs.append(itemURL.standardizedFileURL)
    }

    func openFolderInFinder(folderURL: URL, withinScope scopeURL: URL?) throws {
        try DesktopWorkspaceValidator.verifyDirectoryConfinement(folderURL: folderURL, withinScope: scopeURL)
        openedFolderURLs.append(folderURL.standardizedFileURL)
    }

    func openInTerminal(
        targetURL: URL,
        withinScope scopeURL: URL?,
        explicitBundleIdentifier: String?
    ) throws -> TerminalLaunchResolution {
        let resolution = try DesktopWorkspaceValidator.resolveTerminalLaunch(
            targetURL: targetURL,
            withinScope: scopeURL,
            explicitBundleIdentifier: explicitBundleIdentifier,
            isITerm2Installed: isITerm2Installed,
            isITerm2Preferred: isITerm2Preferred
        )
        terminalLaunches.append((resolution.directoryURL, resolution.bundleIdentifier))
        return resolution
    }
}

@Suite("SidebarActionsAndWorkspaceHandoffTests")
struct SidebarActionsAndWorkspaceHandoffTests {

    @MainActor
    @Test("P5: All 11 sidebar actions execute inside scope with tab sync and directory-only iTerm2 / Terminal.app resolution")
    func p5AllElevenSidebarActionsTabSyncAndDirectoryOnlyTerminalHandoff() throws {
        // GIVEN an isolated workspace folder on disk with "draft.md" open in a tab, a Trash fake, and a DesktopWorkspaceIntegrating fake
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftEditSidebar11-\(UUID().uuidString)", isDirectory: true)
        let workspaceURL = tempRoot.appendingPathComponent("Workspace", isDirectory: true)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let canonicalWorkspace = workspaceURL.resolvingSymlinksInPath().standardizedFileURL
        let draftURL = canonicalWorkspace.appendingPathComponent("draft.md")
        try Data("# Draft".utf8).write(to: draftURL)

        let trashFake = RecordingTrasherFake()
        let fs = LocalFileSystemAdapter(trasher: trashFake)
        let desktopFake = RecordingDesktopWorkspaceFake()

        let suiteName = "it.ph.SwiftEdit.s11.\(UUID().uuidString)"
        let recentSuite = suiteName + ".recent"
        defer {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
            UserDefaults(suiteName: recentSuite)?.removePersistentDomain(forName: recentSuite)
        }

        let model = SwiftEditWorkbenchModel(
            preferencesSuiteName: suiteName,
            recentFilesSuiteName: recentSuite,
            recoveryDirectoryURL: tempRoot.appendingPathComponent("Recovery", isDirectory: true),
            fileSystem: fs,
            desktopWorkspace: desktopFake
        )

        model.selectWorkspaceFolder(canonicalWorkspace)
        model.openFile(at: draftURL, withinScope: canonicalWorkspace)
        let draftTabID = try #require(model.tabSession.activeTabID)

        // WHEN executing all 11 sidebar actions:
        // 1. New Folder, 2. Rename Folder, 3. New File, 4. Rename File, 5. Copy File, 6. Paste File,
        // 7. Cut File + Paste into Folder, 8. Delete File (with confirmation), 9. Reveal in Finder,
        // 10. Open Folder in Finder, 11. Open Terminal on a file (preferring iTerm2, then fallback to Terminal.app)
        let createdDocs = try #require(model.sidebarCreateFolder(named: "docs", in: canonicalWorkspace))
        let renamedDocs = try #require(model.sidebarRenameItem(at: createdDocs, to: "guides"))
        let createdNote = try #require(model.sidebarCreateFile(named: "note.md", in: canonicalWorkspace))
        let renamedDraft = try #require(model.sidebarRenameItem(at: draftURL, to: "final.md"))

        model.sidebarCopyItem(at: renamedDraft)
        let pastedCopy = try #require(model.sidebarPasteItem(into: canonicalWorkspace))

        model.sidebarCutItem(at: createdNote)
        let movedNote = try #require(model.sidebarPasteItem(into: renamedDocs))

        model.requestSidebarTrashItem(at: pastedCopy)
        model.confirmPendingTrashItem()

        model.sidebarRevealInFinder(at: renamedDraft)
        model.sidebarOpenFolderInFinder(at: renamedDocs)
        model.sidebarOpenInTerminal(at: renamedDraft) // selected item is a FILE -> resolves to canonicalWorkspace
        desktopFake.isITerm2Installed = false
        model.sidebarOpenInTerminal(at: renamedDocs)

        // THEN open tab updated to "final.md", copy-paste created "final copy.md", cut moved note into "guides", Trash received "final copy.md", and Open Terminal resolved file to parent directory
        let updatedTab = try #require(model.tabSession.tabs.first(where: { $0.id == draftTabID }))
        #expect(updatedTab.title == "final.md")
        #expect(updatedTab.fileURL == renamedDraft)
        #expect(pastedCopy.lastPathComponent == "final copy.md")
        #expect(movedNote == renamedDocs.appendingPathComponent("note.md"))
        #expect(trashFake.trashedURLs == [pastedCopy])
        #expect(desktopFake.revealedURLs == [renamedDraft])
        #expect(desktopFake.openedFolderURLs.map(\.path) == [renamedDocs.path])
        #expect(desktopFake.terminalLaunches.count == 2)
        #expect(desktopFake.terminalLaunches[0].directoryURL.path == canonicalWorkspace.path)
        #expect(desktopFake.terminalLaunches[0].bundleIdentifier == "com.googlecode.iterm2")
        #expect(desktopFake.terminalLaunches[1].directoryURL.path == renamedDocs.path)
        #expect(desktopFake.terminalLaunches[1].bundleIdentifier == "com.apple.Terminal")
    }

    @MainActor
    @Test("N6: Empty sidebar clipboard paste and canceled Trash confirmation perform zero filesystem mutations")
    func n6EmptyClipboardPasteAndCanceledTrashAreNoOps() throws {
        // GIVEN a workspace folder containing "keep.md" and an empty sidebar clipboard
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftEditNoOp-\(UUID().uuidString)", isDirectory: true)
        let workspaceURL = tempRoot.appendingPathComponent("Workspace", isDirectory: true)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let canonicalWorkspace = workspaceURL.resolvingSymlinksInPath().standardizedFileURL
        let keepURL = canonicalWorkspace.appendingPathComponent("keep.md")
        try Data("stay".utf8).write(to: keepURL)

        let trashFake = RecordingTrasherFake()
        let fs = LocalFileSystemAdapter(trasher: trashFake)
        let suiteName = "it.ph.SwiftEdit.snoop.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let model = SwiftEditWorkbenchModel(
            preferencesSuiteName: suiteName,
            recentFilesSuiteName: suiteName + ".recent",
            recoveryDirectoryURL: tempRoot.appendingPathComponent("Recovery", isDirectory: true),
            fileSystem: fs,
            desktopWorkspace: RecordingDesktopWorkspaceFake()
        )
        model.selectWorkspaceFolder(canonicalWorkspace)

        // WHEN staging a Trash confirmation and canceling it, plus pasting with empty clipboard
        let pasteOutcome = model.sidebarPasteItem(into: canonicalWorkspace)
        model.requestSidebarTrashItem(at: keepURL)
        let stagedTrashURL = model.pendingTrashItemURL
        model.cancelPendingTrashItem()

        // THEN pendingTrashItemURL was staged and then cleared, nothing was pasted or trashed, and "keep.md" still exists
        #expect(pasteOutcome == nil)
        #expect(stagedTrashURL == keepURL)
        #expect(model.pendingTrashItemURL == nil)
        #expect(trashFake.trashedURLs.isEmpty)
        #expect(FileManager.default.fileExists(atPath: keepURL.path) == true)
    }

    @MainActor
    @Test("N7 [Security]: Executable script (.command) resolves only to parent directory, while escaping symlinks and unallowlisted terminal bundle IDs throw securityScopeViolation")
    func n7SecurityExecutableScriptDirectoryOnlyEscapingSymlinkAndUnallowlistedBundleBlocked() throws {
        // GIVEN a workspace containing "deploy.command", an outside secret directory, and an escaping symlink
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftEditSecHandoff-\(UUID().uuidString)", isDirectory: true)
        let workspaceURL = tempRoot.appendingPathComponent("Workspace", isDirectory: true)
        let outsideSecret = tempRoot.appendingPathComponent("OutsideSecret", isDirectory: true)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outsideSecret, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let canonicalWorkspace = workspaceURL.resolvingSymlinksInPath().standardizedFileURL
        let commandScript = canonicalWorkspace.appendingPathComponent("deploy.command")
        try Data("#!/bin/sh\necho pwned\n".utf8).write(to: commandScript)

        let escapingSymlink = canonicalWorkspace.appendingPathComponent("escape_link")
        try FileManager.default.createSymbolicLink(at: escapingSymlink, withDestinationURL: outsideSecret)

        // WHEN resolving terminal launch on deploy.command, on escapingSymlink, on Finder reveal/open, and with "com.evil.shell"
        let scriptLaunch = try DesktopWorkspaceValidator.resolveTerminalLaunch(
            targetURL: commandScript,
            withinScope: canonicalWorkspace,
            explicitBundleIdentifier: nil,
            isITerm2Installed: false,
            isITerm2Preferred: false
        )

        // THEN deploy.command resolved strictly to canonicalWorkspace (never the script file), and all escaping / unallowlisted calls throw securityScopeViolation
        #expect(scriptLaunch.directoryURL.path == canonicalWorkspace.path)
        #expect(scriptLaunch.bundleIdentifier == "com.apple.Terminal")
        #expect(throws: DomainError.securityScopeViolation(path: escapingSymlink.standardizedFileURL.path)) {
            _ = try DesktopWorkspaceValidator.resolveTerminalLaunch(
                targetURL: escapingSymlink,
                withinScope: canonicalWorkspace,
                explicitBundleIdentifier: nil,
                isITerm2Installed: true,
                isITerm2Preferred: true
            )
        }
        #expect(throws: DomainError.securityScopeViolation(path: "com.evil.shell")) {
            _ = try DesktopWorkspaceValidator.resolveTerminalLaunch(
                targetURL: canonicalWorkspace,
                withinScope: canonicalWorkspace,
                explicitBundleIdentifier: "com.evil.shell",
                isITerm2Installed: true,
                isITerm2Preferred: true
            )
        }
        #expect(throws: DomainError.securityScopeViolation(path: escapingSymlink.standardizedFileURL.path)) {
            try DesktopWorkspaceValidator.verifyItemConfinement(targetURL: escapingSymlink, withinScope: canonicalWorkspace)
        }
        #expect(throws: DomainError.securityScopeViolation(path: commandScript.standardizedFileURL.path)) {
            try DesktopWorkspaceValidator.verifyDirectoryConfinement(folderURL: commandScript, withinScope: canonicalWorkspace)
        }
    }
}
