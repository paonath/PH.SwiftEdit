import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

#if os(macOS)
import AppKit
import SwiftUI

@Suite("Unit 5: Workspace Quick Open, Multi-File Search & Enhanced Find/Replace (REQ-007, REQ-008)")
struct WorkspaceQuickOpenAndEnhancedSearchTests {

    private func makeTempWorkspace() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftEditQuickOpen-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("docs", isDirectory: true), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("src", isDirectory: true), withIntermediateDirectories: true)
        return dir
    }

    @Test("P7: Cmd+T Quick Open ranks workspace files by filename/subpath and Ctrl+Shift+F Find in Folder jumps to file and line")
    @MainActor
    func p7QuickOpenRankingAndFindInFolderJump() throws {
        let ws = try makeTempWorkspace()
        defer { try? FileManager.default.removeItem(at: ws) }

        let readme = ws.appendingPathComponent("README.md")
        let guide = ws.appendingPathComponent("docs/guide.md")
        let parser = ws.appendingPathComponent("src/MarkdownParser.swift")
        try "# Project\nWelcome to SwiftEdit\n".write(to: readme, atomically: true, encoding: .utf8)
        try "Line 1\nTargetToken appears on line 2\nLine 3\n".write(to: guide, atomically: true, encoding: .utf8)
        try "struct MarkdownParser {\n    // TargetToken here on line 2\n}\n".write(to: parser, atomically: true, encoding: .utf8)

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: ws.appendingPathComponent(".recovery", isDirectory: true)
        )
        model.selectWorkspaceFolder(ws)

        // 1. Quick Open (`Cmd+T`) indexes files and ranks "guide" first
        model.toggleQuickOpen()
        #expect(model.quickOpenController.isQuickOpenPresented == true)
        model.updateQuickOpenQuery("guide")
        let top = try #require(model.quickOpenController.candidates.first)
        #expect(top.filename == "guide.md")
        model.confirmQuickOpenSelection(at: 0)
        #expect(model.quickOpenController.isQuickOpenPresented == false)
        #expect(model.activeDocumentSession?.fileURL?.lastPathComponent == "guide.md")

        // 2. Find in Folder (`Ctrl+Shift+F`) finds literal matches across subfolders and jumps to file + line
        model.toggleFindInFolder()
        #expect(model.quickOpenController.isFolderSearchPresented == true)
        model.quickOpenController.folderSearchQuery = "TargetToken"
        model.executeFindInFolder()
        let matches = model.quickOpenController.folderSearchResult.matches
        #expect(matches.count == 2)
        let parserMatch = try #require(matches.first { $0.filenameOrPathEndsWith("MarkdownParser.swift") })
        #expect(parserMatch.lineNumber == 2)

        model.openFolderSearchMatch(parserMatch)
        #expect(model.activeDocumentSession?.fileURL?.lastPathComponent == "MarkdownParser.swift")
        #expect(model.activeStatusBarMetrics.line == 2)
    }

    @Test("P8 & N9: Whole-Word, 1 of N active match counter, In-Selection Find/Replace, Opt+Cmd+E Use Selection for Find, and 0-of-0 / empty-selection / >1024-unit boundaries")
    @MainActor
    func p8AndN9WholeWordCounterInSelectionAndUseSelectionForFind() throws {
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: FileManager.default.temporaryDirectory.appendingPathComponent("find-\(UUID().uuidString)")
        )
        model.newUntitledTab()
        model.handleEditorTextChanged("cat catalog scatter cat\nsecond cat line\n")

        // 1. Whole-Word matches standalone "cat" (3 occurrences), excluding "catalog" and "scatter"
        model.presentFindBar(mode: .findAndReplace)
        model.findReplaceState.query = "cat"
        model.findReplaceState.isWholeWord = true
        model.executeFind()
        #expect(model.findReplaceState.matches.count == 3)
        #expect(model.findReplaceState.counterLabel == "1 of 3")
        model.findNextMatch()
        #expect(model.findReplaceState.counterLabel == "2 of 3")

        // 2. Opt+Cmd+E (`useSelectionForFind`) populates query from current selection and runs find
        model.findReplaceState.isWholeWord = false
        model.handleSelectionChanged(TextRange(location: 4, length: 7)) // "catalog"
        model.useSelectionForFind()
        #expect(model.findReplaceState.query == "catalog")
        #expect(model.findReplaceState.matches.count == 1)
        #expect(model.findReplaceState.counterLabel == "1 of 1")

        // 3. In-Selection Replace All mutates only inside the selected region (`second cat line`)
        let text = try #require(model.activeDocumentSession?.text)
        let nsText = text as NSString
        let secondLineRange = nsText.range(of: "second cat line")
        model.handleSelectionChanged(TextRange(location: secondLineRange.location, length: secondLineRange.length))
        model.findReplaceState.isInSelection = true
        model.findReplaceState.scopedSelectionRange = TextRange(location: secondLineRange.location, length: secondLineRange.length)
        model.findReplaceState.query = "cat"
        model.findReplaceState.replacement = "dog"
        model.executeFind()
        #expect(model.findReplaceState.matches.count == 1)
        model.executeReplaceAll()
        #expect(model.activeDocumentSession?.text == "cat catalog scatter cat\nsecond dog line\n")

        // 4. N9 boundaries: unmatched -> "0 of 0", empty selection In-Selection -> 0 matches, >1024 query rejected
        model.findReplaceState.isInSelection = false
        model.findReplaceState.scopedSelectionRange = nil
        model.findReplaceState.query = "nonexistent_xyz"
        model.executeFind()
        #expect(model.findReplaceState.counterLabel == "0 of 0")

        model.findReplaceState.isInSelection = true
        model.findReplaceState.scopedSelectionRange = TextRange(location: 0, length: 0)
        model.findReplaceState.query = "cat"
        model.executeFind()
        #expect(model.findReplaceState.matches.isEmpty)

        let overlong = String(repeating: "a", count: 1025)
        let outcome = DocumentSearchEngine.find(query: overlong, in: try #require(model.activeDocumentSession?.snapshot))
        if case .degradedOrTimedOut(.inputTooLarge) = outcome {} else {
            Issue.record("Expected .inputTooLarge for >1024 UTF-16 query")
        }
    }

    @Test("N8 [Security]: Escaping symlinks, internal symlink directory cycles, binary files, regex metacharacters, and 10k-file / 5k-match caps fail safe")
    @MainActor
    func n8SecuritySymlinksCycleBreakingBinarySkipLiteralRegexAndCaps() throws {
        let root = try makeTempWorkspace()
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("Out-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }

        let secret = outside.appendingPathComponent("secret.md")
        try "OUTSIDE SECRET (a+)+$".write(to: secret, atomically: true, encoding: .utf8)

        // 1. Escaping symlink inside workspace
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("escape.md"),
            withDestinationURL: secret
        )

        // 2. Internal directory symlink cycle (`src/loop -> root`, CWE-674)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("src/loop"),
            withDestinationURL: root
        )

        // 3. Binary file with NUL bytes + valid text file containing regex metacharacters
        try Data([0x00, 0x01, 0x02, 0x41]).write(to: root.appendingPathComponent("binary.dat"))
        let metaFile = root.appendingPathComponent("docs/meta.md")
        let repeatedLines = Array(repeating: "Literal pattern (a+)+$[0-9]* here", count: 25).joined(separator: "\n")
        try repeatedLines.write(to: metaFile, atomically: true, encoding: .utf8)

        let fs = LocalFileSystemAdapter()
        let indexed = WorkspaceFolderSearchEngine.indexWorkspaceFiles(rootURL: root, fileSystem: fs, maxFiles: 50)
        #expect(indexed.skippedExternalSymlinks >= 1)
        #expect(indexed.files.count == 1)
        #expect(indexed.files.first?.filename == "meta.md")

        // 4. Literal-only regex metacharacter search + match cap truncation (`CWE-1333`, `CWE-400`)
        let cappedSearch = WorkspaceFolderSearchEngine.searchInFolder(
            query: "(a+)+$[0-9]*",
            rootURL: root,
            fileSystem: fs,
            maxFiles: 5,
            maxMatches: 10
        )
        #expect(cappedSearch.matches.count == 10)
        #expect(cappedSearch.isTruncatedAtMatchCap == true)
    }

    @Test("P7b: QuickOpenAndFolderSearchView renders Quick Open and Find in Folder overlays and handles selection navigation and dismissal")
    @MainActor
    func p7bRenderQuickOpenAndFolderSearchViewsOffscreen() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("qo-ui-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try "alpha target\nbeta target\n".write(to: dir.appendingPathComponent("one.md"), atomically: true, encoding: .utf8)
        try "gamma target\n".write(to: dir.appendingPathComponent("two.md"), atomically: true, encoding: .utf8)

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: dir.appendingPathComponent("rec"),
            fileSystem: LocalFileSystemAdapter()
        )
        model.selectWorkspaceFolder(dir)

        func renderOverlay() {
            _ = NSApplication.shared
            let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 520), styleMask: [.titled], backing: .buffered, defer: false)
            win.isReleasedWhenClosed = false
            let host = NSHostingView(rootView: QuickOpenAndFolderSearchView(model: model))
            host.frame = NSRect(x: 0, y: 0, width: 720, height: 520)
            win.contentView = host
            host.layoutSubtreeIfNeeded()
            win.displayIfNeeded()
            win.contentView = nil
            win.orderOut(nil)
        }

        // Hidden state + Quick Open populated & empty states
        renderOverlay()
        model.toggleQuickOpen()
        model.moveQuickOpenSelection(delta: 1)
        model.moveQuickOpenSelection(delta: -1)
        renderOverlay()
        model.updateQuickOpenQuery("no_match_zzz")
        renderOverlay()
        model.updateQuickOpenQuery("one")
        model.confirmQuickOpenSelection()
        #expect(model.quickOpenController.isQuickOpenPresented == false)

        // Find in Folder populated & dismissal states
        model.toggleFindInFolder()
        model.quickOpenController.folderSearchQuery = "target"
        model.executeFindInFolder()
        renderOverlay()
        model.closeFindInFolder()
        #expect(model.quickOpenController.isFolderSearchPresented == false)
    }
}

private extension FolderSearchMatch {
    func filenameOrPathEndsWith(_ suffix: String) -> Bool {
        relativePath.hasSuffix(suffix) || fileURL.lastPathComponent == suffix
    }
}
#endif
