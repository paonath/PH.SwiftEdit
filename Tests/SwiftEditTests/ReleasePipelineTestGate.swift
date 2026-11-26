import Foundation
import Testing

/// Environment gate used by `.github/workflows/release.yml` (`SWIFTEDIT_RELEASE_PIPELINE=1`)
/// to keep the release pipeline lean by skipping E2E UI window tests and timing stress benchmarks
/// while running every functional, regression, golden, and security test.
enum ReleasePipelineTestGate {
    static let environmentKey = "SWIFTEDIT_RELEASE_PIPELINE"

    static func isReleasePipeline(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        guard let raw = environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }
        return raw == "1" || raw == "true" || raw == "yes"
    }

    static var shouldRunE2EUIAndStressTests: Bool {
        !isReleasePipeline()
    }
}

@Suite("ReleasePipelineTestGateTests")
struct ReleasePipelineTestGateTests {

    @Test(
        "P1: ReleasePipelineTestGate enables release mode for truthy values and disables it for falsy or absent values",
        arguments: [
            ("1", true),
            ("true", true),
            ("TRUE", true),
            (" yes ", true),
            ("0", false),
            ("false", false),
            ("no", false),
            ("", false),
        ]
    )
    func p1ReleaseGateParsesEnvironmentValues(value: String, expected: Bool) {
        let env = [ReleasePipelineTestGate.environmentKey: value]
        #expect(ReleasePipelineTestGate.isReleasePipeline(environment: env) == expected)
    }

    @Test("N1: Absent environment variable keeps E2E UI and timing stress tests enabled by default")
    func n1AbsentEnvironmentDefaultsToFullSuite() {
        #expect(ReleasePipelineTestGate.isReleasePipeline(environment: [:]) == false)
    }

    @Test("P2: release.yml gates E2E UI and timing stress tests, preserves Release optimizations, and test.yml keeps full suite")
    func p2WorkflowConfigurationMatchesReleasePolicy() throws {
        let root = RepoRootLocator.rootURL
        let releaseYAML = try String(contentsOf: root.appendingPathComponent(".github/workflows/release.yml"), encoding: .utf8)
        let testYAML = try String(contentsOf: root.appendingPathComponent(".github/workflows/test.yml"), encoding: .utf8)
        let buildScript = try String(contentsOf: root.appendingPathComponent("Scripts/build-app.sh"), encoding: .utf8)

        #expect(releaseYAML.contains("SWIFTEDIT_RELEASE_PIPELINE: \"1\""))
        #expect(releaseYAML.contains("swift test --no-parallel"))
        #expect(!releaseYAML.contains("swift test --parallel"))
        #expect(releaseYAML.contains("./Scripts/build-app.sh --configuration Release --clean --derived-data .tmp/DerivedData"))
        #expect(releaseYAML.contains("rm -rf .tmp"))
        #expect(!testYAML.contains("SWIFTEDIT_RELEASE_PIPELINE"))

        // Verify Release optimization flags remain intact in Scripts/build-app.sh.
        #expect(buildScript.contains("SWIFT_COMPILATION_MODE=wholemodule"))
        #expect(buildScript.contains("SWIFT_OPTIMIZATION_LEVEL=-Osize"))
        #expect(buildScript.contains("DEAD_CODE_STRIPPING=YES"))
        #expect(buildScript.contains("LLVM_LTO=YES_THIN"))
    }

    @Test("N2 [Security]: Security test suites are never gated by ReleasePipelineTestGate")
    func n2SecuritySuitesNeverGatedInRelease() throws {
        let testsDir = RepoRootLocator.rootURL.appendingPathComponent("Tests/SwiftEditTests")
        let securityFiles = [
            "DocumentSecurityQuarantineTests.swift",
            "XcodeAppShellAndPackagingFitnessTests.swift",
            "PerformanceCachingAndSecurityLintTests.swift",
        ]
        for file in securityFiles {
            let source = try String(contentsOf: testsDir.appendingPathComponent(file), encoding: .utf8)
            #expect(!source.contains("ReleasePipelineTestGate"), "\(file) must never be skipped in release")
        }
    }
}
