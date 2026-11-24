import Foundation

/// Line-coverage metrics for a single module target or aggregate production tree (`REQ-010`, `TEST-005`, `TEST-008`).
public struct TargetCoverageReport: Equatable, Sendable {
    public let targetName: String
    public let coveredLines: Int
    public let executableLines: Int

    public init(targetName: String, coveredLines: Int, executableLines: Int) {
        self.targetName = targetName
        self.coveredLines = max(0, coveredLines)
        self.executableLines = max(0, executableLines)
    }

    /// Percentage in `0.0...100.0` (`0.0` when `executableLines == 0`, failing closed).
    public var linePercent: Double {
        guard executableLines > 0 else { return 0.0 }
        return (Double(coveredLines) / Double(executableLines)) * 100.0
    }
}

/// Evaluated threshold verdict across `SwiftEditCore`, `SwiftEditUI`, and aggregate `Sources/` (`REQ-010`).
public struct CodeCoverageThresholdResult: Equatable, Sendable {
    public let swiftEditCore: TargetCoverageReport
    public let swiftEditUI: TargetCoverageReport
    public let aggregate: TargetCoverageReport
    public let minimumPercent: Double
    public let failingTargets: [String]

    public var passesGate: Bool {
        failingTargets.isEmpty
    }
}

/// Fail-closed LLVM code-coverage JSON threshold evaluator enforcing `>= 85.0%` per target and overall (`REQ-010`).
public enum CodeCoverageThresholdEvaluator {
    public static let defaultMinimumPercent: Double = 85.0

    private struct LLVMExportRoot: Decodable {
        let data: [LLVMExportDatum]
    }

    private struct LLVMExportDatum: Decodable {
        let files: [LLVMExportFile]
    }

    private struct LLVMExportFile: Decodable {
        let filename: String
        let summary: LLVMExportSummary
    }

    private struct LLVMExportSummary: Decodable {
        let lines: LLVMLineCounter
    }

    private struct LLVMLineCounter: Decodable {
        let count: Int
        let covered: Int
    }

    /// Parses `llvm-cov export` JSON data (`PH.SwiftEdit.json`) and verifies `SwiftEditCore`, `SwiftEditUI`, and aggregate `Sources/` meet `minimumPercent`.
    public static func evaluateLLVMExportJSON(
        _ jsonData: Data,
        minimumPercent: Double = defaultMinimumPercent
    ) throws -> CodeCoverageThresholdResult {
        let decoded = try JSONDecoder().decode(LLVMExportRoot.self, from: jsonData)
        var coreCovered = 0
        var coreTotal = 0
        var uiCovered = 0
        var uiTotal = 0

        for datum in decoded.data {
            for file in datum.files where file.filename.contains("/.build/") == false {
                if file.filename.contains("/Sources/SwiftEditCore/") {
                    coreCovered += file.summary.lines.covered
                    coreTotal += file.summary.lines.count
                } else if file.filename.contains("/Sources/SwiftEditUI/") {
                    uiCovered += file.summary.lines.covered
                    uiTotal += file.summary.lines.count
                }
            }
        }

        let coreReport = TargetCoverageReport(targetName: "SwiftEditCore", coveredLines: coreCovered, executableLines: coreTotal)
        let uiReport = TargetCoverageReport(targetName: "SwiftEditUI", coveredLines: uiCovered, executableLines: uiTotal)
        let aggReport = TargetCoverageReport(
            targetName: "AggregateSources",
            coveredLines: coreCovered + uiCovered,
            executableLines: coreTotal + uiTotal
        )

        let failing = [coreReport, uiReport, aggReport]
            .filter { $0.executableLines == 0 || $0.linePercent < minimumPercent }
            .map(\.targetName)

        return CodeCoverageThresholdResult(
            swiftEditCore: coreReport,
            swiftEditUI: uiReport,
            aggregate: aggReport,
            minimumPercent: minimumPercent,
            failingTargets: failing
        )
    }
}
