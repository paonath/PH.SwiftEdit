import Foundation
import Testing
@testable import SwiftEditCore

@Suite("FontChoicePreferencesTests")
struct FontChoicePreferencesTests {

    @Test("P3: font choices round-trip per role and pre-017 preferences still load")
    func p3RoundTripAndLegacyLoad() {
        // GIVEN an in-memory store and a legacy store holding only appearance and zoom
        let store = InMemoryKeyValueStore()
        let prefs = EditorPreferencesStore(store: store)
        let legacyStore = InMemoryKeyValueStore()
        legacyStore.set("black", forKey: EditorPreferencesStore.appearanceModeKey)
        legacyStore.set(150, forKey: EditorPreferencesStore.zoomPercentKey)
        // WHEN choices are saved and both stores are loaded
        prefs.save(EditorPreferences(appearanceMode: .light, zoomPercent: 120, interfaceFont: .system(family: "Avenir Next"), editorFont: .openDyslexic))
        let loaded = prefs.load()
        let legacy = EditorPreferencesStore(store: legacyStore).load()
        // THEN choices round-trip and legacy values keep defaults for fonts
        #expect(loaded.interfaceFont == .system(family: "Avenir Next"))
        #expect(loaded.editorFont == .openDyslexic)
        #expect(loaded.font(for: .editor) == .openDyslexic)
        #expect(legacy.interfaceFont == .default)
        #expect(legacy.editorFont == .default)
        #expect(legacy.zoomPercent == 150)
        #expect(legacy.appearanceMode == .black)
    }

    @Test(
        "N3 [Security]: path-like, oversized, control-character and non-string values decode to default",
        arguments: [
            "../../../tmp/x.otf", "system:" + String(repeating: "A", count: 10_000), "system:Menlo\u{0}", "system:", "system:/Library/Fonts/x.ttf", "bogus",
        ]
    )
    func n3MaliciousValuesFailClosed(value: String) {
        // GIVEN a store holding a hostile editor font value
        let store = InMemoryKeyValueStore()
        store.set(value, forKey: EditorPreferencesStore.editorFontKey)
        // WHEN preferences are loaded
        let loaded = EditorPreferencesStore(store: store).load()
        // THEN the editor role resolves to the default font
        #expect(loaded.editorFont == .default)
    }

    @Test("N3b [Security]: a non-string stored value decodes to default")
    func n3bNonStringValueFailsClosed() {
        // GIVEN an integer stored under the interface font key
        let store = InMemoryKeyValueStore()
        store.set(42, forKey: EditorPreferencesStore.interfaceFontKey)
        // WHEN preferences are loaded
        // THEN the interface role is default
        #expect(EditorPreferencesStore(store: store).load().interfaceFont == .default)
    }

    @Test("P3b: storage values are stable and validated")
    func p3bStorageValues() {
        // GIVEN the three kinds of choice
        // WHEN they are encoded and decoded
        // THEN the storage format is explicit and round-trips
        #expect(FontChoice.default.storageValue == "default")
        #expect(FontChoice.openDyslexic.storageValue == "openDyslexic")
        #expect(FontChoice.system(family: "Menlo").storageValue == "system:Menlo")
        #expect(FontChoice.validated("system:Menlo") == .system(family: "Menlo"))
        #expect(FontChoice.validated("openDyslexic") == .openDyslexic)
    }
}
