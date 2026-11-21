import Foundation
import Testing
@testable import SwiftEditCore

final class RecordingSecurityScopeFake: SecurityScopedResourceAccessing, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var startCount: Int = 0
    private(set) var stopCount: Int = 0

    func startAccessing(url: URL) -> Bool {
        _ = url
        lock.lock()
        defer { lock.unlock() }
        startCount += 1
        return true
    }

    func stopAccessing(url: URL) {
        _ = url
        lock.lock()
        defer { lock.unlock() }
        stopCount += 1
    }
}

enum NavigatorTestSandbox {
    static func makeWorkspace(label: String) throws -> URL {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let ws = repoRoot.appendingPathComponent(".tmp/test-results/nav-\(label)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: ws, withIntermediateDirectories: true)
        return ws
    }
}

@Suite("DotfileNavigatorAndPreferencesTests")
struct DotfileNavigatorAndPreferencesTests {

    @Test("P3: DotfileFolderNavigator lists shallow dotfiles sorted directories-first with balanced scope access and EditorPreferencesStore round-trips settings")
    func p3ShallowDotfileEnumerationAndPreferencesRoundTrip() throws {
        // GIVEN a workspace folder with a subdirectory, regular file, and hidden dotfiles plus an isolated UserDefaults suite
        let workspace = try NavigatorTestSandbox.makeWorkspace(label: "p3")
        defer { try? FileManager.default.removeItem(at: workspace) }
        try FileManager.default.createDirectory(at: workspace.appendingPathComponent("src"), withIntermediateDirectories: true)
        try Data("nested".utf8).write(to: workspace.appendingPathComponent("src/IgnoredChild.swift"))
        try Data("# Readme".utf8).write(to: workspace.appendingPathComponent("README.md"))
        try Data("PORT=8080".utf8).write(to: workspace.appendingPathComponent(".env"))
        try Data(".build/".utf8).write(to: workspace.appendingPathComponent(".gitignore"))

        let scopeFake = RecordingSecurityScopeFake()
        let navigator = DotfileFolderNavigator(securityScope: scopeFake)

        let prefsStore = EditorPreferencesStore(store: InMemoryKeyValueStore())

        // WHEN enumerating shallow entries and saving/loading EditorPreferences
        let entries = try navigator.listEntries(in: workspace, withinScope: workspace)
        prefsStore.save(EditorPreferences(appearanceMode: .black, zoomPercent: 150))
        let loadedPrefs = prefsStore.load()

        // THEN directories come first, hidden dotfiles are included without descending into 'src', scope calls balance, and preferences round-trip
        #expect(entries.map(\.name) == ["src", ".env", ".gitignore", "README.md"])
        #expect(entries.map(\.isDirectory) == [true, false, false, false])
        #expect(entries.map(\.isHiddenDotfile) == [false, true, true, false])
        #expect(scopeFake.startCount == 1)
        #expect(scopeFake.stopCount == 1)
        #expect(loadedPrefs == EditorPreferences(appearanceMode: .black, zoomPercent: 150))
    }

    @Test("N5: EditorPreferences and EditorPreferencesStore clamp out-of-range zoom values to 50...300 and fallback unknown appearance strings to .auto")
    func n5OutOfBoundsZoomAndInvalidAppearanceStringsAreClamped() throws {
        // GIVEN isolated InMemoryKeyValueStores seeded with out-of-bounds zoom values and an invalid appearance raw value
        let lowKV = InMemoryKeyValueStore()
        lowKV.set("invalid-theme", forKey: EditorPreferencesStore.appearanceModeKey)
        lowKV.set(10, forKey: EditorPreferencesStore.zoomPercentKey)

        let highKV = InMemoryKeyValueStore()
        highKV.set("light", forKey: EditorPreferencesStore.appearanceModeKey)
        highKV.set(900, forKey: EditorPreferencesStore.zoomPercentKey)

        // WHEN loading from both stores and constructing out-of-bounds EditorPreferences directly
        let lowLoaded = EditorPreferencesStore(store: lowKV).load()
        let highLoaded = EditorPreferencesStore(store: highKV).load()
        let unseededLoaded = EditorPreferencesStore(store: InMemoryKeyValueStore()).load()
        let decodedFromJSON = try JSONDecoder().decode(EditorPreferences.self, from: Data(#"{"appearanceMode":"unknown","zoomPercent":999}"#.utf8))
        let directLow = EditorPreferences(appearanceMode: .black, zoomPercent: -25)
        let directHigh = EditorPreferences(appearanceMode: .light, zoomPercent: 450)

        // THEN zoom values clamp to 50...300 and invalid appearance strings default to .auto
        #expect(lowLoaded == EditorPreferences(appearanceMode: .auto, zoomPercent: 50))
        #expect(highLoaded == EditorPreferences(appearanceMode: .light, zoomPercent: 300))
        #expect(unseededLoaded == EditorPreferences(appearanceMode: .auto, zoomPercent: 100))
        #expect(decodedFromJSON == EditorPreferences(appearanceMode: .auto, zoomPercent: 300))
        #expect(directLow.zoomPercent == 50)
        #expect(directHigh.zoomPercent == 300)
    }

    @Test("N6 [Security]: DotfileFolderNavigator rejects outside-scope directories and escaping symlinks while guaranteeing stopAccessing in defer")
    func n6SecurityFolderNavigatorSymlinkEscapeAndBalancedScopeRelease() throws {
        // GIVEN a granted workspace folder containing a hidden symlink pointing outside the granted scope
        let root = try NavigatorTestSandbox.makeWorkspace(label: "n6")
        defer { try? FileManager.default.removeItem(at: root) }
        let grantedScope = root.appendingPathComponent("granted")
        let outsideZone = root.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: grantedScope, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outsideZone, withIntermediateDirectories: true)
        let outsideSecret = outsideZone.appendingPathComponent("secret.env")
        try Data("SECRET=1".utf8).write(to: outsideSecret)

        let escapingSymlink = grantedScope.appendingPathComponent(".escape-env")
        try FileManager.default.createSymbolicLink(at: escapingSymlink, withDestinationURL: outsideSecret)

        let scopeFake = RecordingSecurityScopeFake()
        let navigator = DotfileFolderNavigator(securityScope: scopeFake)

        // WHEN / THEN both outside-scope expansion and child symlink escape throw securityScopeViolation and release security scope
        #expect(throws: DomainError.securityScopeViolation(path: outsideZone.path)) {
            _ = try navigator.listEntries(in: outsideZone, withinScope: grantedScope)
        }
        #expect(throws: DomainError.securityScopeViolation(path: escapingSymlink.path)) {
            _ = try navigator.listEntries(in: grantedScope, withinScope: grantedScope)
        }
        #expect(scopeFake.startCount == 2)
        #expect(scopeFake.stopCount == 2)
    }
}
