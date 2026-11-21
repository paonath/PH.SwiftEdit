import Foundation
@testable import SwiftEditCore
@testable import SwiftEditUI

/// Headless workbench factory opening in-memory files by name so language-dependent behavior is testable (`TEST-003`, `TEST-004`).
@MainActor
enum YAMLWorkbenchHarness {
    static let scope = URL(fileURLWithPath: "/fixtures/yaml-016")

    /// Builds an isolated model, seeds `files` into an in-memory filesystem, and opens them in order (last one active).
    static func makeModel(opening files: [(name: String, text: String)] = []) -> (SwiftEditWorkbenchModel, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("yaml016-\(UUID().uuidString)")
        let fs = InMemoryFileSystemFake()
        for file in files { fs.seed(url: scope.appendingPathComponent(file.name), data: Data(file.text.utf8)) }
        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: dir,
            fileSystem: fs,
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
        for file in files { model.openFile(at: scope.appendingPathComponent(file.name), withinScope: scope) }
        return (model, dir)
    }
}
