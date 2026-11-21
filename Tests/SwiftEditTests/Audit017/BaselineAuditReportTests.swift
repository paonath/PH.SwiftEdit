import Foundation
import Testing

@Suite("BaselineAuditReportTests")
struct BaselineAuditReportTests {
    private static let validFixture = """
    ## Runs
    | Run | Date | Commit |
    | :--- | :--- | :--- |
    | R1 | d | c |
    | R2 | d | c |
    | R3 | d | c |
    ## CPU
    ## Memory
    ## Latency
    ## Functional
    ## Human Metrics
    ## Accessibility
    ## Findings
    | ID | Severity | Title | Repro | Measured | Status |
    | :--- | :--- | :--- | :--- | :--- | :--- |
    | F-017-01 | P2 | t | steps | 3 ms | open |
    """

    @Test("P1: the baseline report has 3 runs, all six sections and fully classified findings")
    func p1BaselineReportIsComplete() {
        // GIVEN the committed baseline report
        let report = AuditReportFitness.read("docs/qa/debug-audit-report-017-baseline.md")
        // WHEN its structure is checked
        let issues = AuditReportFitness.structuralIssues(report)
        // THEN it is complete and lists at least one classified finding
        #expect(!report.isEmpty)
        #expect(issues.isEmpty, "\(issues)")
        #expect(!AuditReportFitness.findings(report).isEmpty)
    }

    @Test("N1: two runs, a missing section or leaked fixture text fail the report gate")
    func n1IncompleteOrLeakingReportsFail() {
        // GIVEN three corrupted variants of a valid report
        let twoRuns = Self.validFixture.replacingOccurrences(of: "| R3 | d | c |\n", with: "")
        let noAccessibility = Self.validFixture.replacingOccurrences(of: "## Accessibility\n", with: "")
        let leaking = Self.validFixture + "\nline with \(AuditReportFitness.fixtureMarker) text"
        // WHEN each is checked
        // THEN the valid fixture passes and each corruption is named
        #expect(AuditReportFitness.structuralIssues(Self.validFixture).isEmpty)
        #expect(AuditReportFitness.structuralIssues(twoRuns) == ["runs: expected 3, found 2"])
        #expect(AuditReportFitness.structuralIssues(noAccessibility) == ["missing section: Accessibility"])
        #expect(AuditReportFitness.structuralIssues(leaking).first?.hasPrefix("leaked fixture content") == true)
    }
}
