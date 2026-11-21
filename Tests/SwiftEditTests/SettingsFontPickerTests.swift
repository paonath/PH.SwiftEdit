import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

private struct FixedFamilies: FontFamilySource {
    func familyNames() -> [String] { ["Avenir Next", "Helvetica", "Menlo"] }
}

@Suite("SettingsFontPickerTests")
@MainActor
struct SettingsFontPickerTests {

    private static func makeModel(store: InMemoryKeyValueStore) -> (SwiftEditWorkbenchModel, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("settings017-\(UUID().uuidString)")
        let model = SwiftEditWorkbenchModel(preferencesStore: store, recentFilesStore: InMemoryKeyValueStore(), recoveryDirectoryURL: dir,
                                            systemDarkDetector: { false }, savePanelProvider: { _ in nil })
        return (model, dir)
    }

    @Test("P7: selecting fonts applies live, persists, survives a zoom save, and never touches buffers")
    func p7SelectAppliesLiveAndPersists() throws {
        // GIVEN a dirty Markdown tab and the Settings view model
        let store = InMemoryKeyValueStore()
        let (model, dir) = Self.makeModel(store: store)
        defer { try? FileManager.default.removeItem(at: dir) }
        model.newUntitledTab()
        model.handleEditorTextChanged("# a")
        model.handleEditorTextChanged("# ab")
        let before = try #require(model.activeDocumentSession)
        let settings = SettingsViewModel(model: model, catalog: SystemFontCatalog(source: FixedFamilies(), isOpenDyslexicAvailable: { true }))
        // WHEN fonts are chosen and zoom changes afterwards
        settings.select(.system(family: "Avenir Next"), for: .interface)
        settings.select(.openDyslexic, for: .editor)
        model.zoomController.zoomIn()
        let reloaded = EditorPreferencesStore(store: store).load()
        let after = try #require(model.activeDocumentSession)
        // THEN typography, persistence and buffers behave as specified
        #expect(model.typography.choice(for: .interface) == .system(family: "Avenir Next"))
        #expect(model.typography.choice(for: .editor) == .openDyslexic)
        #expect(model.editorFont == .openDyslexic)
        #expect(reloaded.interfaceFont == .system(family: "Avenir Next"))
        #expect(reloaded.editorFont == .openDyslexic)
        #expect(after.text == before.text)
        #expect(after.revision == before.revision)
        #expect(after.isDirty == before.isDirty)
    }

    @Test("N7: unavailable OpenDyslexic is not offered, rows are labelled and keyboard selection works")
    func n7UnavailableHiddenLabelledKeyboard() {
        // GIVEN a Settings view model whose bundle is unverified
        let (model, dir) = Self.makeModel(store: InMemoryKeyValueStore())
        defer { try? FileManager.default.removeItem(at: dir) }
        let settings = SettingsViewModel(model: model, catalog: SystemFontCatalog(source: FixedFamilies(), isOpenDyslexicAvailable: { false }))
        // WHEN editor rows are built and the keyboard moves down twice then confirms
        let rows = settings.rows(for: .editor)
        settings.moveHighlight(by: 2, for: .editor)
        settings.confirmHighlight(for: .editor)
        // THEN OpenDyslexic is absent, labels name the families, and the third row (Helvetica) was selected
        #expect(rows.map(\.title) == ["Default", "Avenir Next", "Helvetica", "Menlo"])
        #expect(rows.first?.accessibilityLabel == "Editor font Default, selected")
        #expect(rows.dropFirst().first?.accessibilityLabel == "Editor font Avenir Next")
        #expect(model.editorFont == .system(family: "Helvetica"))
    }
}
