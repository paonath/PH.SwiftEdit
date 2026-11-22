import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("WindowConfigWordWrapAndDragDropTests", .serialized)
@MainActor
struct WindowConfigWordWrapAndDragDropTests {

    @Test("P-CFG1: JSONPreferencesStore creates .SwiftEdit directory and persists structured JSON settings round-trip")
    func pJSONSettingsStoreRoundTrip() throws {
        let fakeHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftedit-home-\(UUID().uuidString)", isDirectory: true)
        let settingsFile = fakeHome
            .appendingPathComponent(".SwiftEdit", isDirectory: true)
            .appendingPathComponent("settings.json")
        defer { try? FileManager.default.removeItem(at: fakeHome) }

        let jsonStore = JSONPreferencesStore(fileURL: settingsFile)
        let prefsStore = EditorPreferencesStore(store: jsonStore)
        let custom = EditorPreferences(
            appearanceMode: .black,
            zoomPercent: 140,
            interfaceFont: .openDyslexic,
            editorFont: .system(family: "Menlo"),
            preferredTerminalBundleID: nil,
            isWordWrapEnabled: false,
            launchInFullScreen: false,
            terminalPanelHeight: 360
        )
        prefsStore.save(custom)

        #expect(FileManager.default.fileExists(atPath: settingsFile.path))
        let rawJSON = try String(contentsOf: settingsFile, encoding: .utf8)
        #expect(rawJSON.contains("\"swiftedit.appearanceMode\""))
        #expect(rawJSON.contains("\"swiftedit.editor.wordWrap\""))
        #expect(rawJSON.contains("\"swiftedit.window.launchInFullScreen\""))

        // Reload from disk in a fresh store instance
        let reloaded = EditorPreferencesStore(store: JSONPreferencesStore(fileURL: settingsFile)).load()
        #expect(reloaded == custom)
    }

    @Test("P-CFG2: Default preferences enable launchInFullScreen=true and isWordWrapEnabled=true; Cmd+W toggles word wrap and persists")
    func pDefaultFullScreenAndWordWrapToggle() throws {
        let fakeHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftedit-wrap-\(UUID().uuidString)", isDirectory: true)
        let settingsFile = fakeHome.appendingPathComponent(".SwiftEdit/settings.json")
        defer { try? FileManager.default.removeItem(at: fakeHome) }

        let model = SwiftEditWorkbenchModel(
            preferencesStore: JSONPreferencesStore(fileURL: settingsFile),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: fakeHome.appendingPathComponent("recovery"),
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
        #expect(model.launchInFullScreen == true)
        #expect(model.isWordWrapEnabled == true)

        let handled = SwiftEditShortcutDispatcher.dispatch(
            ShortcutKeyEvent(characters: "w", modifiers: [.command]),
            model: model
        )
        #expect(handled)
        #expect(model.isWordWrapEnabled == false)
        #expect(model.statusBannerMessage == "Word Wrap: OFF")

        // Verify persisted to JSON
        let reloaded = EditorPreferencesStore(store: JSONPreferencesStore(fileURL: settingsFile)).load()
        #expect(reloaded.isWordWrapEnabled == false)
    }

    @Test("P-OCC2: Selecting a word in the workbench populates activeHighlightProjection.wordOccurrenceRanges with all other occurrences")
    func pWorkbenchSelectionHighlightsOtherWordOccurrences() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("occ-wb-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: dir,
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
        model.handleEditorTextChanged("SwiftEdit opens SwiftEdit fast with SwiftEdit highlight")
        model.handleSelectionChanged(TextRange(location: 0, length: 9)) // "SwiftEdit"
        let occurrences = model.activeHighlightProjection.wordOccurrenceRanges
        #expect(occurrences.count == 2)
        #expect(!occurrences.contains(TextRange(location: 0, length: 9)))
    }

    @Test("P-DROP1: Dragging a file opens it in a tab; dragging a folder opens it in the left Folder Navigator and expands sidebar")
    func pDragAndDropFilesAndFolders() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftedit-drop-\(UUID().uuidString)", isDirectory: true)
        let subFolder = root.appendingPathComponent("Docs", isDirectory: true)
        let fileA = root.appendingPathComponent("alpha.md")
        let fileB = subFolder.appendingPathComponent("beta.md")
        try FileManager.default.createDirectory(at: subFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "# Alpha".write(to: fileA, atomically: true, encoding: .utf8)
        try "# Beta".write(to: fileB, atomically: true, encoding: .utf8)

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: root.appendingPathComponent("recovery"),
            fileSystem: LocalFileSystemAdapter(),
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
        #expect(model.isLeftSidebarCollapsed == true)

        // Drop a file -> opens in a tab
        model.openDroppedURLs([fileA])
        #expect(model.activeTabTitle == "alpha.md")
        #expect(model.activeDocumentSession?.text == "# Alpha")

        // Drop a folder via lifecycle bridge (Dock/Finder icon drop) -> expands left navigator and loads folder
        let bridge = SwiftEditAppLifecycleBridge()
        bridge.attach(workbench: model)
        bridge.receiveExternalOpenURLs([subFolder])
        #expect(model.isLeftSidebarCollapsed == false)
        #expect(model.selectedFolderURL?.standardizedFileURL == subFolder.standardizedFileURL)
        #expect(model.folderEntries.contains { $0.name == "beta.md" })
    }

    @Test("P-NAV3: Identical setQuery never resets selectedIndex before Enter/click confirm")
    func pNavigatorIdenticalQueryPreservesSelectedIndex() {
        let md = "# First\n\n## Second\n\n## Third\n"
        var state = DocumentNavigatorState(headings: MarkdownHeadingOutlineEngine.outline(for: md))
        state.moveDown()
        state.moveDown()
        #expect(state.selectedIndex == 2)
        // Re-sending identical empty query (e.g. SwiftUI TextField commit/focus) must preserve selectedIndex == 2
        state.setQuery("")
        #expect(state.selectedIndex == 2)
        let target = state.confirm(documentLength: md.utf16.count)
        #expect(target == (md as NSString).range(of: "## Third").location)
    }

    @Test("P-CFG3: JSONPreferencesStore supports performBatch, double, data, and removeObject")
    func pJSONPreferencesStoreTypedOperations() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("json-types-\(UUID().uuidString)")
        let file = dir.appendingPathComponent(".SwiftEdit/settings.json")
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = JSONPreferencesStore(fileURL: file)
        store.performBatch {
            store.set(3.5, forKey: "ratio")
            store.set(Data("abc".utf8), forKey: "blob")
            store.set("hello", forKey: "greeting")
        }
        #expect(store.double(forKey: "ratio") == 3.5)
        #expect(store.data(forKey: "blob") == Data("abc".utf8))
        #expect(store.string(forKey: "greeting") == "hello")
        store.removeObject(forKey: "greeting")
        #expect(store.string(forKey: "greeting") == nil)
    }
}
