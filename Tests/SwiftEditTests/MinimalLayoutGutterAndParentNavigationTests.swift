import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("MinimalLayoutGutterAndParentNavigationTests")
struct MinimalLayoutGutterAndParentNavigationTests {

    @MainActor
    @Test("P1: Sidebar defaults to collapsed, stays collapsed on single-file open, auto-expands on folder open, and projects 1-based LineNumberGutter and live status metrics")
    func p1DefaultCollapsedSidebarAutoExpandLineGutterAndLiveStatusMetrics() throws {
        // GIVEN an isolated temporary workspace directory, an isolated recovery/defaults workbench, and a 3-line CRLF document
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftEditLayout-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let fileURL = tempRoot.appendingPathComponent("sample.md")
        try Data("alpha\r\nbeta\r\ngamma".utf8).write(to: fileURL)

        let recoveryDir = tempRoot.appendingPathComponent("Recovery", isDirectory: true)
        let suiteName = "it.ph.SwiftEdit.test.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let model = SwiftEditWorkbenchModel(
            preferencesSuiteName: suiteName,
            recentFilesSuiteName: suiteName + ".recent",
            recoveryDirectoryURL: recoveryDir
        )

        // WHEN checking initial state, opening a single file, moving caret to offset 7 (line 2, col 2 of canonical LF "alpha\nbeta\ngamma"), and then mounting the workspace folder
        let initialCollapsed = model.isLeftSidebarCollapsed
        model.openFile(at: fileURL, withinScope: tempRoot)
        let afterSingleFileCollapsed = model.isLeftSidebarCollapsed
        model.handleSelectionChanged(SwiftEditCore.TextRange(location: 7, length: 0))
        let gutter = model.activeLineNumberGutter
        let status = model.activeStatusBarMetrics
        model.selectWorkspaceFolder(tempRoot)

        // THEN sidebar starts collapsed, stays collapsed on single file, expands on folder open, and reports 1-based gutter + CRLF status
        #expect(initialCollapsed == true)
        #expect(afterSingleFileCollapsed == true)
        #expect(model.isLeftSidebarCollapsed == false)
        #expect(gutter.lineNumbers == [1, 2, 3])
        #expect(gutter.activeLine == 2)
        #expect(status == StatusBarMetricsProjection(
            line: 2,
            column: 2,
            characterCount: 16,
            encodingLabel: "UTF-8",
            lineEnding: .crlf
        ))
    }

    @Test("N1: Empty buffer and out-of-range caret clamp LineNumberGutterProjection and StatusBarMetricsProjection safely without throwing")
    func n1EmptyBufferAndOutOfRangeCaretClampSafely() {
        // GIVEN an empty text buffer and an out-of-range caret offset 99
        let emptySnapshot = DocumentSession(text: "", encoding: .utf8, lineEnding: .lf).snapshot

        // WHEN evaluating LineNumberGutterProjection and StatusBarMetricsProjection
        let gutter = LineNumberGutterProjection.evaluate(text: emptySnapshot.text, caretLocation: 99, fontSizePoints: 14.0)
        let status = StatusBarMetricsProjection.evaluate(snapshot: emptySnapshot, caretLocation: 99)

        // THEN gutter lists [1] with active line 1 and status clamps to line 1, col 1, 0 chars
        #expect(gutter == LineNumberGutterProjection(lineNumbers: [1], activeLine: 1, fontSizePoints: 14.0))
        #expect(status == StatusBarMetricsProjection(
            line: 1,
            column: 1,
            characterCount: 0,
            encodingLabel: "UTF-8",
            lineEnding: .lf
        ))
    }

    @MainActor
    @Test("P2: Sidebar '...' button ascends to parent folder inside granted scope and further up when user permissions allow reading parent directory")
    func p2SidebarParentFolderDotDotDotAscendsWithinScopeAndUserPermissions() throws {
        // GIVEN an outer folder "/.../Outer/Workspace/Sources" on disk where user permissions allow reading Outer
        let baseTemp = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftEditUpNav-\(UUID().uuidString)", isDirectory: true)
        let outerURL = baseTemp.appendingPathComponent("Outer", isDirectory: true)
        let workspaceURL = outerURL.appendingPathComponent("Workspace", isDirectory: true)
        let sourcesURL = workspaceURL.appendingPathComponent("Sources", isDirectory: true)
        try FileManager.default.createDirectory(at: sourcesURL, withIntermediateDirectories: true)
        try Data("# Outer".utf8).write(to: outerURL.appendingPathComponent("outer.md"))
        try Data("# Workspace".utf8).write(to: workspaceURL.appendingPathComponent("workspace.md"))
        try Data("let x = 1".utf8).write(to: sourcesURL.appendingPathComponent("main.swift"))
        defer { try? FileManager.default.removeItem(at: baseTemp) }

        let canonicalOuter = outerURL.resolvingSymlinksInPath().standardizedFileURL
        let canonicalWorkspace = workspaceURL.resolvingSymlinksInPath().standardizedFileURL
        let canonicalSources = sourcesURL.resolvingSymlinksInPath().standardizedFileURL

        let suiteName = "it.ph.SwiftEdit.upnav.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        let model = SwiftEditWorkbenchModel(
            preferencesSuiteName: suiteName,
            recentFilesSuiteName: suiteName + ".recent",
            recoveryDirectoryURL: baseTemp.appendingPathComponent("Recovery", isDirectory: true),
            parentPermissionChecker: { candidate in
                candidate.standardizedFileURL.path == canonicalOuter.path
                    || candidate.standardizedFileURL.path == canonicalWorkspace.path
            }
        )

        // WHEN mounting Workspace, entering Sources, and invoking navigateToParentFolder() ("...") twice
        model.selectWorkspaceFolder(canonicalWorkspace)
        let sourcesEntry = try #require(model.folderEntries.first(where: { $0.name == "Sources" }))
        model.openFolderEntry(sourcesEntry)
        let inSubfolderURL = model.selectedFolderURL
        let canAscendFromSubfolder = model.canNavigateToParentFolder
        model.navigateToParentFolder()
        let afterFirstUpURL = model.selectedFolderURL
        let canAscendToPermittedOuter = model.canNavigateToParentFolder
        model.navigateToParentFolder()

        // THEN first "..." returns to Workspace, and second "..." ascends to permitted Outer and updates grantedScopeRootURL
        #expect(inSubfolderURL == canonicalSources)
        #expect(canAscendFromSubfolder == true)
        #expect(afterFirstUpURL == canonicalWorkspace)
        #expect(canAscendToPermittedOuter == true)
        #expect(model.selectedFolderURL == canonicalOuter)
        #expect(model.grantedScopeRootURL == canonicalOuter)
        #expect(model.folderEntries.contains(where: { $0.name == "outer.md" }))
    }

    @MainActor
    @Test("N2: At filesystem root '/' or when parent lacks user read permission, canNavigateToParentFolder is false and '...' is a safe no-op")
    func n2RootOrUnpermittedParentDisablesDotDotDotUpNavigation() throws {
        // GIVEN a workspace folder whose parent directory is NOT readable under user permissions, plus filesystem root "/"
        let baseTemp = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftEditNoPerm-\(UUID().uuidString)", isDirectory: true)
        let workspaceURL = baseTemp.appendingPathComponent("RestrictedWorkspace", isDirectory: true)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: baseTemp) }

        let canonicalWorkspace = workspaceURL.resolvingSymlinksInPath().standardizedFileURL
        let suiteName = "it.ph.SwiftEdit.noperm.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let model = SwiftEditWorkbenchModel(
            preferencesSuiteName: suiteName,
            recentFilesSuiteName: suiteName + ".recent",
            recoveryDirectoryURL: baseTemp.appendingPathComponent("Recovery", isDirectory: true),
            parentPermissionChecker: { _ in false }
        )

        // WHEN mounting RestrictedWorkspace and attempting navigateToParentFolder(), plus checking navigator at "/"
        model.selectWorkspaceFolder(canonicalWorkspace)
        let canAscendDenied = model.canNavigateToParentFolder
        model.navigateToParentFolder()
        let rootResolution = try DotfileFolderNavigator().resolveParentDirectory(
            from: URL(fileURLWithPath: "/"),
            withinScope: URL(fileURLWithPath: "/"),
            isParentReadable: { _ in true }
        )

        // THEN canNavigateToParentFolder is false, selectedFolderURL stays at RestrictedWorkspace, and "/" returns nil
        #expect(canAscendDenied == false)
        #expect(model.selectedFolderURL == canonicalWorkspace)
        #expect(model.statusBannerMessage != nil)
        #expect(rootResolution == nil)
    }

    @MainActor
    @Test("N3 [Security]: Ascending via '...' when current folder or parent traverses a symlink escaping permitted hierarchy throws DomainError.securityScopeViolation")
    func n3SecuritySymlinkParentEscapeFailsClosed() throws {
        // GIVEN an outside secret directory and a symlinked path inside a container where the symlink jumps to an unrelated hierarchy
        let baseTemp = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftEditSymlinkParent-\(UUID().uuidString)", isDirectory: true)
        let realWorkspace = baseTemp.appendingPathComponent("RealContainer/Workspace", isDirectory: true)
        let secretOutside = baseTemp.appendingPathComponent("OutsideSecret/Sub", isDirectory: true)
        let symlinkParentContainer = baseTemp.appendingPathComponent("TrapContainer", isDirectory: true)
        try FileManager.default.createDirectory(at: realWorkspace, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secretOutside, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: symlinkParentContainer, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: baseTemp) }

        let symlinkedParent = symlinkParentContainer.appendingPathComponent("LinkedParent")
        try FileManager.default.createSymbolicLink(at: symlinkedParent, withDestinationURL: secretOutside.deletingLastPathComponent())
        let currentViaSymlink = symlinkedParent.appendingPathComponent("Sub")

        let navigator = DotfileFolderNavigator()

        // WHEN resolving parent directory on a path whose parent segment is a symbolic link
        #expect(throws: DomainError.securityScopeViolation(path: symlinkedParent.standardizedFileURL.path)) {
            _ = try navigator.resolveParentDirectory(
                from: currentViaSymlink,
                withinScope: realWorkspace,
                isParentReadable: { _ in true }
            )
        }
    }
}
