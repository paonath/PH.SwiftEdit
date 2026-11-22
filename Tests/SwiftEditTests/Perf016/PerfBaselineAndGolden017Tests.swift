import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("PerfBaselineAndGolden017Tests")
struct PerfBaselineAndGolden017Tests {

    @Test("P10: the 017 analysis report ranks at least three measured bottlenecks with baselines")
    func p10RankedReport() {
        // GIVEN the 017 performance analysis report
        let report = AuditReportFitness.read("docs/qa/perf-analysis-017.md")
        // WHEN ranked rows are counted
        let ranked = report.components(separatedBy: "\n").filter { $0.hasPrefix("| B") }
        // THEN at least three bottlenecks are ranked
        #expect(report.contains("## Ranked Bottlenecks"))
        #expect(ranked.count >= 3)
    }

    @MainActor
    @Test("N10: 017 golden fingerprints captured before pass 1 still match")
    func n10Golden017Equivalence() {
        // GIVEN fingerprints recorded before the 017 passes
        // WHEN current outputs are fingerprinted
        let current = PerfGolden017.current()
        // THEN every group matches
        #expect(!PerfGolden017.recorded.isEmpty)
        #expect(current == PerfGolden017.recorded)
    }
}
