import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("SidebarInteractionAndCopyPathTests")
@MainActor
struct SidebarInteractionAndCopyPathTests {

    @Test("P1: Single click selects folders without entering them while double click navigates into the folder")
    func p1SingleClickSelectsFolderAndDoubleClickOpensIt() throws {
        // GIVEN an isolated workspace folder containing a nested subfolder and a Markdown file
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftEditSidebarClick-\(UUID().uuidString)", isDirectory: true)
        let subFolder = tempRoot.appendingPathComponent("SubFolder", isDirectory: true)
        let childFile = subFolder.appendingPathComponent("inside.md")
        try FileManager.default.createDirectory(at: subFolder, withIntermediateDirectories: true)
        try Data("# Inside\n".utf8).write(to: childFile)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: tempRoot.appendingPathComponent("recovery", isDirectory: true),
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
        model.selectWorkspaceFolder(tempRoot)
        let folderEntry = try #require(model.folderEntries.first { $0.isDirectory && $0.name == "SubFolder" })

        // WHEN single-clicking the folder row
        model.sidebarPrimaryClick(folderEntry)
        let folderAfterSingleClick = model.selectedFolderURL
        let selectionAfterSingleClick = model.selectedSidebarEntryURL

        // AND double-clicking the folder row
        model.sidebarDoubleClick(folderEntry)
        let folderAfterDoubleClick = model.selectedFolderURL
        let insideEntry = try #require(model.folderEntries.first { !$0.isDirectory && $0.name == "inside.md" })

        // AND single-clicking a regular file inside the opened folder
        model.sidebarPrimaryClick(insideEntry)

        // THEN single click keeps the parent folder mounted and highlights the row, double click opens the subfolder, and single click opens files
        #expect(folderAfterSingleClick == tempRoot.standardizedFileURL)
        #expect(selectionAfterSingleClick == subFolder.standardizedFileURL)
        #expect(folderAfterDoubleClick == subFolder.standardizedFileURL)
        #expect(model.selectedSidebarEntryURL == nil || model.selectedSidebarEntryURL == insideEntry.url.standardizedFileURL)
        #expect(model.activeTabTitle == "inside.md")
    }

    @Test("P2: Copy Path to Clipboard copies standardized path for regular files, binary files, dotfiles, and folders")
    func p2CopyPathToClipboardWorksForAllFilesBinaryAndFolders() throws {
        // GIVEN an isolated workspace containing a folder, a binary file, a dotfile, and a text file
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftEditCopyPath-\(UUID().uuidString)", isDirectory: true)
        let subFolder = tempRoot.appendingPathComponent("Assets", isDirectory: true)
        let binaryFile = tempRoot.appendingPathComponent("image.bin")
        let dotFile = tempRoot.appendingPathComponent(".env")
        let textFile = tempRoot.appendingPathComponent("notes.md")
        try FileManager.default.createDirectory(at: subFolder, withIntermediateDirectories: true)
        try Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0x01]).write(to: binaryFile)
        try Data("APP_ENV=dev\n".utf8).write(to: dotFile)
        try Data("# Notes\n".utf8).write(to: textFile)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        var copiedPaths: [String] = []
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: tempRoot.appendingPathComponent("recovery", isDirectory: true),
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil },
            clipboardWriter: { text in copiedPaths.append(text) }
        )
        model.selectWorkspaceFolder(tempRoot)

        // WHEN invoking sidebarCopyPathToClipboard on binary file, dotfile, text file, and folder
        model.sidebarCopyPathToClipboard(at: binaryFile)
        model.sidebarCopyPathToClipboard(at: dotFile)
        model.sidebarCopyPathToClipboard(at: textFile)
        model.sidebarCopyPathToClipboard(at: subFolder)

        // THEN every standardized path is copied to the pasteboard and binary files are never blocked
        #expect(copiedPaths == [
            binaryFile.standardizedFileURL.path,
            dotFile.standardizedFileURL.path,
            textFile.standardizedFileURL.path,
            subFolder.standardizedFileURL.path,
        ])
        #expect(model.statusBannerMessage == "Copied path to clipboard.")
    }
}
