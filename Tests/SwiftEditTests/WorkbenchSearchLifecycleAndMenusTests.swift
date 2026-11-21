import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

private struct DeterministicBookmarkCoderFake: SecurityScopedBookmarkCoding {
    func makeBookmark(for url: URL) throws -> Data {
        Data(url.standardizedFileURL.path.utf8)
    }

    func resolveBookmark(_ data: Data) throws -> URL {
        let path = String(decoding: data, as: UTF8.self)
        return URL(fileURLWithPath: path)
    }
}

@Suite("WorkbenchSearchLifecycleAndMenusTests")
struct WorkbenchSearchLifecycleAndMenusTests {

    @MainActor
    @Test("P3: Find, Replace All, Go to Line, 3-way LineEnding switching, 10-entry MRU reopen without duplicate, and dirty close (.dontSave) unlink recovery snapshot")
    func p3FindReplaceGoToLineLineEndingSwitchMRUAndConfirmedDirtyClose() throws {
        // GIVEN an isolated workspace folder, a deterministic bookmark coder, and a workbench model
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftEditLifecycle-\(UUID().uuidString)", isDirectory: true)
        let recoveryDir = tempRoot.appendingPathComponent("Recovery", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let notesURL = tempRoot.appendingPathComponent("notes.md")
        try Data("one\ntwo\none".utf8).write(to: notesURL)

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: recoveryDir,
            bookmarkCoder: DeterministicBookmarkCoderFake()
        )

        // WHEN opening notes.md twice (checking MRU dedupe), running Find + Replace All ("one" -> "ONE"), jumping to line 2, switching line ending to .cr, saving, editing dirty again, and closing with .dontSave
        model.openFile(at: notesURL, withinScope: tempRoot)
        let notesTabID = try #require(model.tabSession.activeTabID)
        model.openFile(at: notesURL, withinScope: tempRoot)
        let recentCountAfterReopen = model.recentFiles.count

        model.presentFindBar(mode: .findAndReplace)
        model.findReplaceState.query = "one"
        model.findReplaceState.replacement = "ONE"
        model.executeFind()
        let foundMatchCount = model.findReplaceState.matches.count
        model.executeReplaceAll()
        model.presentFindBar(mode: .goToLine)
        model.findReplaceState.goToLineText = "2"
        model.executeGoToLine()
        let lineTwoSelection = model.currentSelection

        model.setActiveDocumentLineEnding(.cr)
        model.saveDocument(to: notesURL)
        let savedWireBytes = try Data(contentsOf: notesURL)

        model.handleEditorTextChanged("unsaved draft")
        model.requestCloseTab(id: notesTabID)
        let pendingPromptBeforeDecision = model.pendingDirtyCloseTabID
        model.resolvePendingDirtyClose(.dontSave)
        let recoveryFileAfterDontSave = recoveryDir.appendingPathComponent("\(notesTabID.rawValue.uuidString).recovery")

        // THEN MRU holds 1 deduplicated entry, Replace All updated both occurrences, Go to Line moved to offset 4, CR wire bytes saved, and .dontSave closed tab and unlinked recovery file
        #expect(recentCountAfterReopen == 1)
        #expect(foundMatchCount == 2)
        #expect(lineTwoSelection == SwiftEditCore.TextRange(location: 4, length: 3))
        #expect(savedWireBytes == Data("ONE\rtwo\rONE".utf8))
        #expect(pendingPromptBeforeDecision == notesTabID)
        #expect(model.tabSession.tabs.contains(where: { $0.id == notesTabID }) == false)
        #expect(FileManager.default.fileExists(atPath: recoveryFileAfterDontSave.path) == false)
    }

    @MainActor
    @Test("N4: Canceling dirty close or app quit preserves dirty tab, and batch open above 50 files pauses until confirmed")
    func n4CancelDirtyCloseOrQuitPreservesTabAndOver50BatchAwaitsConfirmation() throws {
        // GIVEN a folder with 52 shallow text files and a workbench with a dirty tab
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftEditBatch-\(UUID().uuidString)", isDirectory: true)
        let batchFolder = tempRoot.appendingPathComponent("ManyFiles", isDirectory: true)
        try FileManager.default.createDirectory(at: batchFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        for idx in 1...52 {
            let fileURL = batchFolder.appendingPathComponent(String(format: "file-%02d.txt", idx))
            try Data("item \(idx)".utf8).write(to: fileURL)
        }

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: tempRoot.appendingPathComponent("Recovery", isDirectory: true),
            bookmarkCoder: DeterministicBookmarkCoderFake()
        )

        model.newUntitledTab()
        let dirtyTabID = try #require(model.tabSession.activeTabID)
        model.handleEditorTextChanged("keep my edits")
        let tabCountBeforeBatch = model.tabSession.tabs.count

        // WHEN requesting close and choosing .cancel, requesting app termination and choosing .cancel, and invoking openAllFilesInFolder before confirming
        model.requestCloseTab(id: dirtyTabID)
        model.resolvePendingDirtyClose(.cancel)
        let shouldTerminateImmediate = model.requestApplicationTermination()
        model.resolvePendingDirtyClose(.cancel)

        model.openAllFilesInFolder(batchFolder)
        let tabCountWhileAwaitingBatchConfirm = model.tabSession.tabs.count
        let pendingBatchCount = model.pendingBatchOpenPlan?.files.count
        model.confirmPendingBatchOpen()

        // THEN .cancel kept the dirty tab open and vetoed termination, and the 52 files opened only after confirmPendingBatchOpen()
        #expect(shouldTerminateImmediate == false)
        #expect(model.tabSession.tabs.contains(where: { $0.id == dirtyTabID }) == true)
        #expect(model.sessionsByID[dirtyTabID]?.text == "keep my edits")
        #expect(tabCountWhileAwaitingBatchConfirm == tabCountBeforeBatch)
        #expect(pendingBatchCount == 52)
        #expect(model.isLeftSidebarCollapsed == false)
        #expect(model.tabSession.tabs.count == tabCountBeforeBatch + 52)
    }

    @Test("P4: KeyboardShortcutsCheatSheetCatalog covers File, Edit, View, Navigation, and Sidebar (including '...') and AboutSheetDescriptor resolves version.json + GitHub prompt")
    func p4CheatSheetCatalogAndValidatedAboutGitHubLink() throws {
        // GIVEN the repository root version.json and KeyboardShortcutsCheatSheetCatalog
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let versionData = try Data(contentsOf: repoRoot.appendingPathComponent("version.json"))

        // WHEN resolving the CheatSheet sections and AboutSheetDescriptor
        let sections = KeyboardShortcutsCheatSheetCatalog.allSections
        let allItems = sections.flatMap(\.items)
        let about = try AboutSheetDescriptor.resolve(versionManifestData: versionData)
        let repoPrompt = try #require(AboutSheetDescriptor.prepareRepositoryLinkConfirmation(rawURI: AboutSheetDescriptor.officialRepositoryURL))

        // THEN all 5 categories, required keyboard shortcuts (including Opt+Cmd+F & Shift+Cmd+Z), sidebar '...' entry, and confirmed GitHub HTTPS prompt are present
        #expect(sections.map(\.category) == ["File", "Edit", "Navigation", "View", "Sidebar"])
        #expect(allItems.contains(where: { $0.shortcut == "Cmd+N" }))
        #expect(allItems.contains(where: { $0.shortcut == "Cmd+O" }))
        #expect(allItems.contains(where: { $0.shortcut == "Cmd+Shift+O" }))
        #expect(allItems.contains(where: { $0.shortcut == "Cmd+Shift+Option+O" }))
        #expect(allItems.contains(where: { $0.shortcut == "Cmd+S" }))
        #expect(allItems.contains(where: { $0.shortcut == "Cmd+Shift+S" }))
        #expect(allItems.contains(where: { $0.shortcut == "Cmd+W" }))
        #expect(allItems.contains(where: { $0.shortcut == "Cmd+Q" }))
        #expect(allItems.contains(where: { $0.shortcut == "Cmd+Z" }))
        #expect(allItems.contains(where: { $0.shortcut == "Shift+Cmd+Z" }))
        #expect(!allItems.contains(where: { $0.shortcut == "Cmd+Y" }))
        #expect(allItems.contains(where: { $0.shortcut == "Cmd+D" }))
        #expect(allItems.contains(where: { $0.shortcut == "Cmd+F" }))
        #expect(allItems.contains(where: { $0.shortcut == "Opt+Cmd+F" }))
        #expect(!allItems.contains(where: { $0.shortcut == "Cmd+H" }))
        #expect(allItems.contains(where: { $0.shortcut == "Cmd+G" }))
        #expect(allItems.contains(where: { $0.title.contains("Diff") }))
        #expect(allItems.contains(where: { $0.title == "Bold" }))
        #expect(allItems.contains(where: { $0.shortcut == "..." }))
        let expectedStamp = try InfoPlistVersionStamper.parseVersionDescriptor(from: versionData)
        #expect(about.fullVersion == expectedStamp.fullBuildVersionString)
        #expect(about.shortVersion == expectedStamp.shortVersionString)
        #expect(repoPrompt == ExternalURIConfirmationPrompt(
            scheme: "https",
            canonicalURI: "https://github.com/paoloinnocenti/PH.SwiftEdit",
            requiresUserConfirmation: true
        ))
    }

    @Test("N5 [Security]: Tampered or non-HTTPS About/external URIs are rejected by prepareRepositoryLinkConfirmation")
    func n5SecurityTamperedAboutURIsRejected() {
        // GIVEN dangerous or hostless external URI candidates
        let jsResult = AboutSheetDescriptor.prepareRepositoryLinkConfirmation(rawURI: "javascript:alert(1)")
        let fileResult = AboutSheetDescriptor.prepareRepositoryLinkConfirmation(rawURI: "file:///etc/passwd")
        let hostlessResult = AboutSheetDescriptor.prepareRepositoryLinkConfirmation(rawURI: "https://")

        // THEN all three return nil and prevent external handoff
        #expect(jsResult == nil)
        #expect(fileResult == nil)
        #expect(hostlessResult == nil)
    }
}
