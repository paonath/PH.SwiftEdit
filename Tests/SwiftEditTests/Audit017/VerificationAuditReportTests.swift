import Foundation
import Testing

@Suite("VerificationAuditReportTests")
struct VerificationAuditReportTests {

    @Test("P11: the verification report has 3 runs, all sections, a baseline comparison and zero open P0–P2 findings")
    func p11VerificationReportIsClean() {
        // GIVEN the committed verification report
        let report = AuditReportFitness.read("docs/qa/debug-verification-report-017.md")
        // WHEN structure, findings and comparison are checked
        // THEN everything passes
        #expect(!report.isEmpty)
        #expect(AuditReportFitness.structuralIssues(report).isEmpty, "\(AuditReportFitness.structuralIssues(report))")
        #expect(AuditReportFitness.openSevereFindings(report).isEmpty)
        #expect(report.contains("## Comparison"))
        #expect(AuditReportFitness.regressions(report).isEmpty, "\(AuditReportFitness.regressions(report))")
    }

    @Test("N12: a >10% regression or an open P1 finding fails verification")
    func n12RegressionOrOpenSevereFails() {
        // GIVEN a comparison with an 11% regression and a findings table with an open P1
        let report = """
        ## Comparison
        | Metric | Baseline | Final | Delta % |
        | :--- | ---: | ---: | ---: |
        | keystroke | 2.000 | 2.220 | +11.0 |
        | caret | 1.000 | 1.050 | +5.0 |
        ## Findings
        | ID | Severity | Title | Repro | Measured | Status |
        | :--- | :--- | :--- | :--- | :--- | :--- |
        | F-017-11 | P1 | t | r | m | open |
        """
        // WHEN it is checked
        // THEN the regression and the open finding are both named
        #expect(AuditReportFitness.regressions(report) == ["keystroke: 2.000 -> 2.220"])
        #expect(AuditReportFitness.openSevereFindings(report) == ["F-017-11"])
    }
}
