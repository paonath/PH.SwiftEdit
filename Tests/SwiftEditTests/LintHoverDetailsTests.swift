import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("LintHoverDetailsTests")
@MainActor
struct LintHoverDetailsTests {

    @Test("P-HOVER1: hovering a gutter lint dot shows the rule code, message and an English explanation per diagnostic")
    func pHoverDetailsForLine() {
        // GIVEN a Markdown tab with a missing heading space and an unsafe link on line 1 and 3
        let (model, dir) = YAMLWorkbenchHarness.makeModel(opening: [("a.md", "#Title\n\n[x](javascript:alert(1))\n")])
        defer { try? FileManager.default.removeItem(at: dir) }
        model.handleSelectionChanged(SwiftEditCore.TextRange(location: 0, length: 0))
        model.refreshDiagnosticsForActiveDocument()
        // WHEN gutter hover details are built
        let details = model.gutterLintDetailsByLine
        // THEN each flagged line carries the code, the message and the English explanation
        #expect(details[3]?.contains("unsafeLinkScheme") == true)
        #expect(details[3]?.contains("only http, https, mailto and relative links are allowed") == true)
        #expect(details.values.allSatisfy { !$0.isEmpty })
    }

    @Test("N-HOVER1: every rule has a non-empty English explanation and lines without diagnostics have no hover text")
    func nEveryRuleExplainedAndCleanLinesEmpty() {
        // GIVEN all rule identifiers and a clean diagnostic list
        // WHEN explanations and details are inspected
        let missing = MarkdownLintRuleID.allCases.filter { $0.explanation.count < 20 }
        // THEN no rule lacks an explanation and an empty list maps to no hover text
        #expect(missing.isEmpty)
        #expect(SwiftEditWorkbenchModel.lintDetails([]).isEmpty)
        #expect(MarkdownLintRuleID.allCases.allSatisfy { $0.explanation.unicodeScalars.allSatisfy { $0.isASCII || $0 == "’" } })
    }
}
