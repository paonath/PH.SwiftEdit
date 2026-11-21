import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

enum SwiftPackageDumpRunner {
    static func dumpPackageJSON(at repoRoot: URL) throws -> Data {
        let scratchDir = repoRoot.appendingPathComponent(".tmp/test-results/dump-scratch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratchDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratchDir) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = [
            "swift", "package", "dump-package",
            "--package-path", repoRoot.path,
            "--scratch-path", scratchDir.path,
        ]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        try process.run()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return data
    }
}

@Suite("ArchitectureFitnessTests")
struct ArchitectureFitnessTests {

    @Test("P1: swift package dump-package confirms .macOS(.v26), .iOS(.v26), allowlisted swift-markdown, and clean SwiftEditCore imports")
    func p1PackageManifestDumpAndPlatformBridge() throws {
        // GIVEN the repository root and live SwiftEditCore source directory
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        // WHEN executing swift package dump-package and scanning Sources/SwiftEditCore
        let dumpData = try SwiftPackageDumpRunner.dumpPackageJSON(at: repoRoot)
        let summary = try PackageManifestDumpValidator.validateDumpPackageJSON(dumpData)
        let coreViolations = try ArchitectureImportScanner.scanDirectory(
            at: repoRoot.appendingPathComponent("Sources/SwiftEditCore")
        )

        // THEN platforms, targets, external dependencies, UI bridge, and core imports satisfy AR-001..AR-006 & TEST-006
        #expect(summary.platforms == ["macos": "26.0", "ios": "26.0"])
        #expect(summary.externalDependencies == ["swift-markdown"])
        #expect(Set(summary.targetNames) == Set(["SwiftEditCore", "SwiftEditUI", "SwiftEditTests"]))
        #expect(summary.violations.isEmpty)
        #expect(SwiftEditUIBridge.activePlatform == .macOS)
        #expect(coreViolations.isEmpty)
    }

    @Test(
        "N1: ArchitectureImportScanner rejects forbidden UI, reactive, and network imports in SwiftEditCore",
        arguments: ["AppKit", "UIKit", "SwiftUI", "WebKit", "Combine", "Network", "SwiftEditUI"]
    )
    func n1ForbiddenImportInSwiftEditCoreIsRejected(forbiddenModule: String) {
        // GIVEN a SwiftEditCore source snippet importing a forbidden framework
        let snippet = """
        import Foundation
        import \(forbiddenModule)

        public struct IllegalAdapter {}
        """

        // WHEN scanning the source text
        let violations = ArchitectureImportScanner.scanSwiftEditCoreSource(
            content: snippet,
            filePath: "Sources/SwiftEditCore/IllegalAdapter.swift"
        )

        // THEN at least one architecture fitness violation is reported for that module
        #expect(violations.count == 1)
        #expect(violations.first?.reason.contains(forbiddenModule) == true)
    }

    @Test("N1: PackageManifestDumpValidator rejects unapproved external packages and inward-layer violations in dump-package JSON")
    func n1DumpPackageValidatorRejectsForbiddenDependencyOrLayerInversion() throws {
        // GIVEN a dump-package JSON where SwiftEditCore depends on SwiftEditUI and unapproved alamofire is declared
        let illegalDumpJSON = Data("""
        {
          "platforms": [{ "platformName": "macos", "version": "26.0" }],
          "dependencies": [{ "sourceControl": [{ "identity": "alamofire" }] }],
          "targets": [
            { "name": "SwiftEditCore", "type": "regular", "dependencies": [{ "byName": ["SwiftEditUI", null] }] },
            { "name": "SwiftEditUI", "type": "regular", "dependencies": [] },
            { "name": "SwiftEditTests", "type": "test", "dependencies": [] }
          ]
        }
        """.utf8)

        // WHEN validating the dump-package JSON
        let summary = try PackageManifestDumpValidator.validateDumpPackageJSON(illegalDumpJSON)

        // THEN missing iOS 26 platform, unapproved alamofire, and SwiftEditCore -> SwiftEditUI cycle are all flagged
        #expect(summary.violations.count == 3)
    }
}
