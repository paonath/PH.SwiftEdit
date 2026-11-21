import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

private final class RecordingReadSpyFileSystem: FileSystemProviding, @unchecked Sendable {
    private let delegate = LocalFileSystemAdapter()
    private let lock = NSLock()
    private(set) var readRequests: [(url: URL, maxBytes: Int?)] = []

    func fileAttributes(at url: URL, withinScope scopeURL: URL?) throws -> FileAttributesDescriptor {
        try delegate.fileAttributes(at: url, withinScope: scopeURL)
    }

    func readData(at url: URL, maxBytes: Int?, withinScope scopeURL: URL?) throws -> Data {
        lock.lock()
        readRequests.append((url: url, maxBytes: maxBytes))
        lock.unlock()
        return try delegate.readData(at: url, maxBytes: maxBytes, withinScope: scopeURL)
    }

    func writeAtomic(data: Data, to url: URL, withinScope scopeURL: URL?) throws {
        try delegate.writeAtomic(data: data, to: url, withinScope: scopeURL)
    }

    @discardableResult
    func createDirectory(named name: String, in parentURL: URL, withinScope scopeURL: URL?) throws -> URL {
        try delegate.createDirectory(named: name, in: parentURL, withinScope: scopeURL)
    }

    @discardableResult
    func createFile(named name: String, contents: Data, in parentURL: URL, withinScope scopeURL: URL?) throws -> URL {
        try delegate.createFile(named: name, contents: contents, in: parentURL, withinScope: scopeURL)
    }

    @discardableResult
    func renameItem(at itemURL: URL, toName newName: String, withinScope scopeURL: URL?) throws -> URL {
        try delegate.renameItem(at: itemURL, toName: newName, withinScope: scopeURL)
    }

    @discardableResult
    func pasteItem(from sourceURL: URL, toDirectory destinationDirectoryURL: URL, mode: PasteMode, withinScope scopeURL: URL?) throws -> URL {
        try delegate.pasteItem(from: sourceURL, toDirectory: destinationDirectoryURL, mode: mode, withinScope: scopeURL)
    }

    func trashItem(at itemURL: URL, withinScope scopeURL: URL?) throws {
        try delegate.trashItem(at: itemURL, withinScope: scopeURL)
    }
}

@Suite("SidebarSymlinkPolicyAndTerminalTests")
struct SidebarSymlinkPolicyAndTerminalTests {

    @MainActor
    @Test("P7: .skipAndReport lists valid siblings, surfaces non-destructive warning banner in workbench, and respects PreferredTerminalApp selection")
    func p7SkipAndReportListsValidSiblingsWithWarningAndTerminalPreference() throws {
        // GIVEN a workspace with valid files and one escaping symlink plus temporary isolation
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftEditP7-\(UUID().uuidString)", isDirectory: true)
        let workspace = tempRoot.appendingPathComponent("Workspace", isDirectory: true)
        let outsideDir = tempRoot.appendingPathComponent("Outside", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outsideDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let canonicalWorkspace = workspace.resolvingSymlinksInPath().standardizedFileURL
        let validFile = canonicalWorkspace.appendingPathComponent("valid.md")
        try Data("# Valid".utf8).write(to: validFile)
        let escapingLink = canonicalWorkspace.appendingPathComponent("escape_link")
        try FileManager.default.createSymbolicLink(at: escapingLink, withDestinationURL: outsideDir)

        let navigator = DotfileFolderNavigator()

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: tempRoot.appendingPathComponent("Recovery", isDirectory: true)
        )

        // WHEN enumerating with .skipAndReport, refreshing workbench folder, and resolving PreferredTerminalApp options
        let diagnosticResult = try navigator.listEntriesWithDiagnostics(
            in: canonicalWorkspace,
            withinScope: canonicalWorkspace,
            symlinkPolicy: .skipAndReport
        )
        model.selectWorkspaceFolder(canonicalWorkspace)

        let autoResolution = try DesktopWorkspaceValidator.resolveTerminalLaunch(
            targetURL: validFile,
            withinScope: canonicalWorkspace,
            preferredTerminal: .auto,
            isITerm2Installed: true
        )
        let terminalResolution = try DesktopWorkspaceValidator.resolveTerminalLaunch(
            targetURL: validFile,
            withinScope: canonicalWorkspace,
            preferredTerminal: .terminal,
            isITerm2Installed: true
        )
        let iTermInstalledResolution = try DesktopWorkspaceValidator.resolveTerminalLaunch(
            targetURL: validFile,
            withinScope: canonicalWorkspace,
            preferredTerminal: .iTerm2,
            isITerm2Installed: true
        )
        let iTermMissingResolution = try DesktopWorkspaceValidator.resolveTerminalLaunch(
            targetURL: validFile,
            withinScope: canonicalWorkspace,
            preferredTerminal: .iTerm2,
            isITerm2Installed: false
        )
        let adapterAuto = MacOSWorkspaceAdapter(preferredTerminal: .auto)

        // THEN valid sibling appears, escaping symlink count == 1, UI warns without failing, and .auto/.terminal prefer Apple Terminal
        #expect(diagnosticResult.entries.map(\.name) == ["valid.md"])
        #expect(diagnosticResult.skippedExternalSymlinkCount == 1)
        #expect(model.folderEntries.map(\.name) == ["valid.md"])
        #expect(model.statusBannerMessage == "Skipped 1 external symlink(s) outside workspace scope.")
        #expect(autoResolution.bundleIdentifier == TerminalLaunchResolution.appleTerminalBundleIdentifier)
        #expect(terminalResolution.bundleIdentifier == TerminalLaunchResolution.appleTerminalBundleIdentifier)
        #expect(iTermInstalledResolution.bundleIdentifier == TerminalLaunchResolution.iTerm2BundleIdentifier)
        #expect(iTermMissingResolution.bundleIdentifier == TerminalLaunchResolution.appleTerminalBundleIdentifier)
        #expect(adapterAuto.preferredTerminal == .auto)
    }

    @Test("N10 [Security]: Escaping child symlink triggers zero byte reads before confinement rejection, root escape throws even under .skipAndReport, and unallowlisted terminal bundle is blocked")
    func n10SecurityZeroReadOnEscapingChildRootEscapeThrowsAndTerminalAllowlist() throws {
        // GIVEN a workspace with one valid file, one escaping symlink pointing to an external secret file, and an escaping symlink folder root
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftEditN10-\(UUID().uuidString)", isDirectory: true)
        let workspace = tempRoot.appendingPathComponent("Workspace", isDirectory: true)
        let outsideDir = tempRoot.appendingPathComponent("OutsideSecret", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outsideDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let canonicalWorkspace = workspace.resolvingSymlinksInPath().standardizedFileURL
        let validFile = canonicalWorkspace.appendingPathComponent("inside.md")
        try Data("# Inside".utf8).write(to: validFile)

        let secretFile = outsideDir.appendingPathComponent("secret.bin")
        try Data([0x00, 0x01, 0x02, 0x03]).write(to: secretFile)
        let escapingChildLink = canonicalWorkspace.appendingPathComponent("leak.bin")
        try FileManager.default.createSymbolicLink(at: escapingChildLink, withDestinationURL: secretFile)

        let escapingFolderRoot = tempRoot.appendingPathComponent("EscapingRoot")
        try FileManager.default.createSymbolicLink(at: escapingFolderRoot, withDestinationURL: outsideDir)

        let readSpy = RecordingReadSpyFileSystem()
        let navigator = DotfileFolderNavigator(fileSystem: readSpy)

        // WHEN enumerating under .skipAndReport and probing fail-closed defaults & escaping folder roots
        let result = try navigator.listEntriesWithDiagnostics(
            in: canonicalWorkspace,
            withinScope: canonicalWorkspace,
            symlinkPolicy: .skipAndReport
        )

        // THEN zero readData calls occurred for escaping target or leak.bin, default .failClosed still throws, folder-root escape throws under .skipAndReport, and unallowlisted bundle throws
        let leakedReads = readSpy.readRequests.filter { req in
            let p = req.url.resolvingSymlinksInPath().standardizedFileURL.path
            return p.contains("secret.bin") || p.contains("leak.bin")
        }
        #expect(result.entries.map(\.name) == ["inside.md"])
        #expect(result.skippedExternalSymlinkCount == 1)
        #expect(leakedReads.isEmpty)
        #expect(readSpy.readRequests.count == 1)
        #expect(throws: DomainError.securityScopeViolation(path: escapingChildLink.path)) {
            _ = try navigator.listEntries(in: canonicalWorkspace, withinScope: canonicalWorkspace)
        }
        #expect(throws: DomainError.securityScopeViolation(path: escapingFolderRoot.path)) {
            _ = try navigator.listEntriesWithDiagnostics(
                in: escapingFolderRoot,
                withinScope: canonicalWorkspace,
                symlinkPolicy: .skipAndReport
            )
        }
        #expect(throws: DomainError.securityScopeViolation(path: "com.evil.shell")) {
            _ = try DesktopWorkspaceValidator.resolveTerminalLaunch(
                targetURL: validFile,
                withinScope: canonicalWorkspace,
                explicitBundleIdentifier: "com.evil.shell",
                preferredTerminal: .iTerm2,
                isITerm2Installed: true
            )
        }
    }
}
