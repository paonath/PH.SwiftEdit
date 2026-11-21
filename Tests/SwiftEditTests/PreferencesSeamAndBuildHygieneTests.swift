import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

private struct InMemoryTestBookmarkCoder: SecurityScopedBookmarkCoding {
    func makeBookmark(for url: URL) throws -> Data {
        Data(url.standardizedFileURL.path.utf8)
    }

    func resolveBookmark(_ data: Data) throws -> URL {
        guard let path = String(data: data, encoding: .utf8), !path.isEmpty else {
            throw DomainError.ioFailure("invalid bookmark")
        }
        return URL(fileURLWithPath: path)
    }
}

private extension PreferencesSeamAndBuildHygieneTests {
    static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static func forbiddenDomainRemovalCallSites() throws -> [String] {
        let forbiddenSymbol = "removePersistent" + "Domain"
        let testsDir = repositoryRoot().appendingPathComponent("Tests/SwiftEditTests", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(at: testsDir, includingPropertiesForKeys: nil)
        return files
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { fileURL in
                guard let content = try? String(contentsOf: fileURL, encoding: .utf8),
                      content.contains(forbiddenSymbol) else {
                    return nil
                }
                return fileURL.lastPathComponent
            }
    }

    private static let change015TestFiles = [
        "AppLifecycleAndDirtyTerminationTests.swift",
        "PerTabUndoAndLifecycleTests.swift",
        "PerformanceCachingAndSecurityLintTests.swift",
        "PreferencesSeamAndBuildHygieneTests.swift",
        "PreviewDiffLineEndingHardeningTests.swift",
        "ShortcutsFindGutterAndAccessibilityTests.swift",
        "SidebarSymlinkPolicyAndTerminalTests.swift",
        "TransientBinaryInspectionTests.swift",
        "TranslucentHeaderBrandSubmenuTests.swift",
    ]

    static func change015SuiteNameLeakFiles() throws -> [String] {
        let suiteToken = "preferencesSuite" + "Name:"
        let testsDir = repositoryRoot().appendingPathComponent("Tests/SwiftEditTests", isDirectory: true)
        return change015TestFiles.filter { name in
            let url = testsDir.appendingPathComponent(name)
            let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            return content.contains(suiteToken)
        }
    }

    static func repoTmpDirectoryLeakFiles() throws -> [String] {
        let forbiddenTmpPath = ".tmp/" + "test-results"
        let testsDir = repositoryRoot().appendingPathComponent("Tests/SwiftEditTests", isDirectory: true)
        return change015TestFiles.filter { name in
            let url = testsDir.appendingPathComponent(name)
            let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            return content.contains(forbiddenTmpPath)
        }
    }
}

@Suite("PreferencesSeamAndBuildHygieneTests")
struct PreferencesSeamAndBuildHygieneTests {

    @MainActor
    @Test("P9: PreferencesProviding + InMemoryKeyValueStore isolate EditorPreferencesStore, RecentFilesStore, and SwiftEditWorkbenchModel without cfprefsd")
    func p9InMemoryPreferencesProvidingRoundTripAndWorkbenchIsolation() throws {
        // GIVEN an InMemoryKeyValueStore, InMemoryFileSystemFake, and isolated session recovery directory
        let prefsKV = InMemoryKeyValueStore()
        let recentKV = InMemoryKeyValueStore()
        let fs = InMemoryFileSystemFake()
        let sampleURL = URL(fileURLWithPath: "/ws/doc.md")
        fs.seed(url: sampleURL, data: Data("# Hi".utf8))

        let tempRec = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftEditP9-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRec) }

        let prefsStore = EditorPreferencesStore(store: prefsKV)
        let recentsStore = RecentFilesStore(store: recentKV, fileSystem: fs, bookmarkCoder: InMemoryTestBookmarkCoder())

        // WHEN persisting clamped preferences, recording a recent file, and launching SwiftEditWorkbenchModel against injected stores
        prefsStore.save(EditorPreferences(appearanceMode: .black, zoomPercent: 500))
        let loadedPrefs = prefsStore.load()
        let recorded = try recentsStore.record(url: sampleURL)
        let resolvedURL = try recentsStore.resolve(entry: try #require(recorded.first))

        let model = SwiftEditWorkbenchModel(
            preferencesStore: prefsKV,
            recentFilesStore: recentKV,
            recoveryDirectoryURL: tempRec,
            fileSystem: fs,
            bookmarkCoder: InMemoryTestBookmarkCoder()
        )

        // THEN preferences clamp cleanly to 300%, recents round-trip through memory without disk defaults, and workbench adopts them
        #expect(loadedPrefs == EditorPreferences(appearanceMode: .black, zoomPercent: 300))
        #expect(resolvedURL.standardizedFileURL.path == "/ws/doc.md")
        #expect(model.appearanceMode == .black)
        #expect(model.zoomController.zoomPercent == 300)
        #expect(model.recentFiles.count == 1)
    }

    @Test("N12: Corrupted recents fail closed in InMemoryKeyValueStore, zero tests call persistent domain teardown, and Xcode pbxproj fixes search paths & Stamp outputs")
    func n12SecurityFailClosedCorruptRecentsZeroPersistentDomainAndXcodeBuildHygiene() throws {
        // GIVEN corrupted payload in InMemoryKeyValueStore plus repository test & Xcode project files
        let kv = InMemoryKeyValueStore()
        kv.set(Data("{invalid-json".utf8), forKey: RecentFilesStore.recentFilesKey)
        let recentsStore = RecentFilesStore(store: kv, fileSystem: InMemoryFileSystemFake(), bookmarkCoder: InMemoryTestBookmarkCoder())

        let pbxprojURL = Self.repositoryRoot().appendingPathComponent("XcodeApp/PH.SwiftEdit.xcodeproj/project.pbxproj")
        let pbxprojText = try String(contentsOf: pbxprojURL, encoding: .utf8)

        // WHEN reading recents from corrupted store and scanning Tests/SwiftEditTests + project.pbxproj
        let entries = recentsStore.entries()
        let keyCleared = (kv.object(forKey: RecentFilesStore.recentFilesKey) == nil)
        let forbiddenCallSites = try Self.forbiddenDomainRemovalCallSites()
        let suiteNameLeaks = try Self.change015SuiteNameLeakFiles()
        let repoTmpLeaks = try Self.repoTmpDirectoryLeakFiles()
        let alwaysSearchNoCount = pbxprojText.components(separatedBy: "ALWAYS_SEARCH_USER_PATHS = NO;").count - 1

        // THEN corrupt payload fails closed, zero persistent-domain or repository-tmp leaks remain across 015 suites, and pbxproj declares deterministic outputs & search-path hygiene
        #expect(entries.isEmpty)
        #expect(keyCleared == true)
        #expect(forbiddenCallSites.isEmpty)
        #expect(suiteNameLeaks.isEmpty)
        #expect(repoTmpLeaks.isEmpty)
        #expect(alwaysSearchNoCount >= 2)
        #expect(!pbxprojText.contains("alwaysOutOfDate = 1;"))
        #expect(pbxprojText.contains("stamp-info-plist.done"))
    }
}
