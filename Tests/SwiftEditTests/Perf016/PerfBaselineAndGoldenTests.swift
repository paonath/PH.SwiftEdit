import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("PerfBaselineAndGoldenTests")
@MainActor
struct PerfBaselineAndGoldenTests {
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @Test("P11: 20,000-line fixtures exist and the ranked analysis report lists at least three measured bottlenecks")
    func p11FixturesAndRankedReport() throws {
        // GIVEN the benchmark fixtures and the analysis report path
        let reportURL = Self.repoRoot.appendingPathComponent("docs/qa/perf-analysis-016.md")
        // WHEN the report is read
        let report = (try? String(contentsOf: reportURL, encoding: .utf8)) ?? ""
        let rankedRows = report.components(separatedBy: "\n").filter { $0.hasPrefix("| B") }
        // THEN both fixtures have 20,000 body lines and the report ranks at least three bottlenecks with baselines
        #expect(MarkdownLineIndex(text: PerfBench016.markdown).lineCount == 20_004)
        #expect(MarkdownLineIndex(text: PerfBench016.yaml).lineCount == 20_000)
        #expect(report.contains("## Ranked Bottlenecks"))
        #expect(rankedRows.count >= 3)
    }

    @Test("N11: golden fingerprints captured before pass 1 still match every observable output")
    func n11GoldenEquivalence() {
        // GIVEN the fingerprints recorded before any performance refactor
        // WHEN the current outputs are fingerprinted
        let current = PerfGolden016.current()
        // THEN every group matches exactly
        #expect(!PerfGolden016.recorded.isEmpty)
        #expect(current == PerfGolden016.recorded)
    }
}
