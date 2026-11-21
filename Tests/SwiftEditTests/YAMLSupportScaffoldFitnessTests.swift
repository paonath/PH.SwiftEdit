import Foundation
import Testing
@testable import SwiftEditCore

@Suite("YAMLSupportScaffoldFitnessTests")
struct YAMLSupportScaffoldFitnessTests {
    private static let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static let yamlSupportDir = repoRoot.appendingPathComponent("Sources/SwiftEditCore/MarkdownLintAndFormat/YAMLSupport")

    @Test("P1: YAMLSupport folder exists inside SwiftEditCore and imports no UI or network frameworks")
    func p1YAMLSupportFolderIsPureFoundation() throws {
        // GIVEN the SwiftEditCore YAMLSupport folder
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: Self.yamlSupportDir.path)) ?? []
        // WHEN its Swift sources are scanned for forbidden imports
        let violations = try ArchitectureImportScanner.scanDirectory(at: Self.yamlSupportDir)
        // THEN the folder holds Swift sources and none imports AppKit, UIKit, SwiftUI or WebKit
        #expect(entries.contains { $0.hasSuffix(".swift") })
        #expect(violations.isEmpty)
    }

    @Test("N1: the four change-016 fixtures load byte-identically through FileSystemProviding")
    func n1FixturesLoadThroughFileSystemSeam() throws {
        // GIVEN the fixtures seeded into an in-memory filesystem fake
        let fs = YAMLFixtures016.seededFileSystem()
        // WHEN each required fixture is read back
        let names = ["config.yml", "frontmatter.md", "alias-bomb.yml", "deep-nesting.yml"]
        let loaded = names.compactMap { try? fs.readData(at: YAMLFixtures016.url($0), maxBytes: nil, withinScope: nil) }
        // THEN every fixture is present and identical to its source literal
        #expect(loaded.count == names.count)
        #expect(loaded.map { String(decoding: $0, as: UTF8.self) } == names.compactMap { YAMLFixtures016.all[$0] })
    }
}
