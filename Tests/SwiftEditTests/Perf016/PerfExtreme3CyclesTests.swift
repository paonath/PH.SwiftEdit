import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("PerfExtreme3CyclesTests", .serialized)
@MainActor
struct PerfExtreme3CyclesTests {

    private static var cycleBudgets: (mdLint: Double, mdSec: Double, mdOutline: Double, yamlLint: Double, yamlOutline: Double, mdIndex: Double, docIndex: Double) {
        #if DEBUG
        return (150.0, 150.0, 10.0, 160.0, 15.0, 25.0, 20.0)
        #else
        return (10.0, 8.0, 2.0, 12.0, 2.0, 5.0, 3.0)
        #endif
    }

    @Test("Cycle 1-3: Markdown lint/outline, YAML lint/outline, and index construction stay fast and preserve all 016+017 goldens")
    func allThreeOptimizationCyclesBenchmarkAndGolden() {
        // GIVEN 20k-line Markdown and YAML fixtures plus pre-computed indices
        let mdSnap = DocumentSession(text: PerfBench016.markdown).snapshot
        let mdIndex = MarkdownLineIndex(text: PerfBench016.markdown)
        let ymlIndex = MarkdownLineIndex(text: PerfBench016.yaml)
        let budgets = Self.cycleBudgets

        // WHEN all three optimization cycles' target functions are benchmarked on 20k-line fixtures
        let cycle1MdLintMs = PerfBench016.medianMilliseconds(runs: 7) {
            _ = MarkdownAllConstructsLinter.diagnostics(index: mdIndex, deadlineExceeded: { false })
        }
        let cycle1MdSecurityMs = PerfBench016.medianMilliseconds(runs: 7) {
            _ = MarkdownAllConstructsLinter.securityOnlyDiagnostics(text: mdSnap.text, deadlineExceeded: { false })
        }
        let cycle1MdOutlineMs = PerfBench016.medianMilliseconds(runs: 7) {
            _ = MarkdownHeadingOutlineEngine.outline(index: mdIndex)
        }
        let cycle2YamlLintMs = PerfBench016.medianMilliseconds(runs: 7) {
            _ = YAMLStructureLinter.lint(index: ymlIndex)
        }
        let cycle2YamlOutlineMs = PerfBench016.medianMilliseconds(runs: 7) {
            _ = YAMLOutlineEngine.outline(index: ymlIndex)
        }
        let cycle3MdLineIndexMs = PerfBench016.medianMilliseconds(runs: 7) {
            _ = MarkdownLineIndex(text: mdSnap.text)
        }
        let cycle3DocTextIndexMs = PerfBench016.medianMilliseconds(runs: 7) {
            _ = DocumentTextIndex(text: mdSnap.text)
        }

        print(
            "PERF_3_CYCLES mdLint=\(cycle1MdLintMs)ms mdSec=\(cycle1MdSecurityMs)ms mdOutline=\(cycle1MdOutlineMs)ms " +
            "yamlLint=\(cycle2YamlLintMs)ms yamlOutline=\(cycle2YamlOutlineMs)ms " +
            "mdIndex=\(cycle3MdLineIndexMs)ms docIndex=\(cycle3DocTextIndexMs)ms"
        )

        // THEN all 016 and 017 golden fingerprints match identically and every 20k-line function finishes within budget
        #expect(PerfGolden016.current() == PerfGolden016.recorded)
        #expect(PerfGolden017.current() == PerfGolden017.recorded)
        #expect(cycle1MdLintMs < budgets.mdLint)
        #expect(cycle1MdSecurityMs < budgets.mdSec)
        #expect(cycle1MdOutlineMs < budgets.mdOutline)
        #expect(cycle2YamlLintMs < budgets.yamlLint)
        #expect(cycle2YamlOutlineMs < budgets.yamlOutline)
        #expect(cycle3MdLineIndexMs < budgets.mdIndex)
        #expect(cycle3DocTextIndexMs < budgets.docIndex)
    }

    @Test("Cycle 3 edge case: DocumentTextIndex handles leading CRLF followed by LF identically to full scan")
    func cycle3LeadingCRLFLazyArray() {
        // GIVEN a document whose very first line break is CRLF followed by LF and standalone CR
        let text = "first\r\nsecond\nthird\rend 😀"
        let snap = DocumentSession(text: text).snapshot

        // WHEN indexed via DocumentTextIndex and queried at boundaries
        let index = DocumentTextIndex(text: text)

        // THEN breakStarts, isCRLF, gutterActiveLine, and cursorLineAndColumn match exact UTF-16 semantics
        #expect(index.isCRLF == [true, false, false])
        #expect(index.gutterActiveLine(caret: 5) == 1)
        #expect(index.gutterActiveLine(caret: 6) == 1)
        #expect(index.gutterActiveLine(caret: 7) == 2)
        #expect(index.cursorLineAndColumn(caret: 7)?.line == 2)
        #expect(index.cursorLineAndColumn(caret: 7)?.column == 1)
        #expect(StatusBarMetricsProjection.evaluate(snapshot: snap, index: index, caretLocation: 26) ==
                StatusBarMetricsProjection.evaluate(snapshot: snap, caretLocation: 26))
    }

    @Test("Cycle 1 & 2 edge cases: obfuscated link destinations, image traversal, quoted YAML keys and duplicates remain exact")
    func cycle1And2EdgeCasesExact() {
        // GIVEN adversarial Markdown links/images and YAML quoted duplicate keys
        let mdText = """
        [ok](https://example.com)
        [encoded](%6aavascript:alert(1))
        [entity](&#x6a;avascript:alert(1))
        ![](  )
        ![alt](../secret.png)
        ![svg](icon.svg)
        """
        let ymlText = """
        "dup": 1
        'dup': 2
        block: |
          not_a_key: value
        "dup": 3
        """

        // WHEN linted via the optimized scanners
        let mdDiags = MarkdownAllConstructsLinter.diagnostics(index: MarkdownLineIndex(text: mdText), deadlineExceeded: { false })?.diagnostics ?? []
        let ymlDiags = YAMLStructureLinter.lint(index: MarkdownLineIndex(text: ymlText))

        // THEN every security and duplicate diagnostic is preserved accurately
        #expect(mdDiags.filter { $0.rule == .unsafeLinkScheme }.count == 2)
        #expect(mdDiags.filter { $0.rule == .missingImageAltText }.count == 1)
        #expect(mdDiags.filter { $0.rule == .unsafeImagePath }.count == 2)
        #expect(ymlDiags.filter { $0.rule == .yamlDuplicateKey }.count == 2)
    }
}
