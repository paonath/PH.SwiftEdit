import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("Refactor019Pass3LintCacheTests", .serialized)
@MainActor
struct Refactor019Pass3LintCacheTests {

    private static func modelWithManyDiagnostics() async -> (SwiftEditWorkbenchModel, URL) {
        let text = (1...1200).map { "line \($0)   " }.joined(separator: "\n") // trailing spaces on every line
        let (model, dir) = YAMLWorkbenchHarness.makeModel(opening: [("many.md", text)])
        model.handleSelectionChanged(SwiftEditCore.TextRange(location: 0, length: 0))
        model.refreshDiagnosticsForActiveDocument()
        await model.awaitPendingDiagnostics()
        return (model, dir)
    }

    @Test("P-R3 [perf]: per-render lint reads (underlines, gutter severities, hover details) are at least 20% faster", .enabled(if: ReleasePipelineTestGate.shouldRunE2EUIAndStressTests))
    func pPerRenderLintReadsAreCached() async {
        // GIVEN a tab with ~1000 diagnostics
        let (model, dir) = await Self.modelWithManyDiagnostics()
        defer { try? FileManager.default.removeItem(at: dir) }
        let diagnostics = model.lintDiagnostics
        // WHEN ten renders read the three lint projections, legacy (array compare + rebuild) versus the workbench
        let legacy = PerfBench016.medianMilliseconds(runs: 7) {
            for _ in 0..<10 {
                let visible = ActiveLineLintSuppressionPolicy.visibleDiagnostics(diagnostics, caretLine: model.previewSourceLine)
                _ = visible == diagnostics
                _ = SwiftEditWorkbenchModel.lintDetails(visible)
            }
        }
        let optimized = PerfBench016.medianMilliseconds(runs: 7) {
            for _ in 0..<10 { _ = model.visibleLintDiagnostics; _ = model.gutterSeverityByLine; _ = model.gutterLintDetailsByLine }
        }
        print("REFACTOR019 pass3 legacy=\(legacy)ms optimized=\(optimized)ms diagnostics=\(diagnostics.count)")
        // THEN the cached reads are at least 20% faster
        #expect(diagnostics.count >= 900)
        #expect(optimized <= legacy * 0.8)
    }

    @Test("N-R3: the cache never serves stale data after new diagnostics or a caret move")
    func nCacheInvalidatesOnChanges() async {
        // GIVEN a tab with diagnostics on every line and a cached projection
        let (model, dir) = await Self.modelWithManyDiagnostics()
        defer { try? FileManager.default.removeItem(at: dir) }
        let before = model.gutterLintDetailsByLine
        // WHEN the text is fixed (no trailing spaces) and the caret moves
        model.handleEditorTextChanged("clean line\n")
        model.refreshDiagnosticsForActiveDocument()
        model.handleSelectionChanged(SwiftEditCore.TextRange(location: 3, length: 0))
        // THEN the projections reflect the new diagnostics immediately
        #expect(!before.isEmpty)
        #expect(model.gutterLintDetailsByLine.isEmpty)
        #expect(model.gutterSeverityByLine.isEmpty)
        #expect(model.visibleLintDiagnostics.isEmpty)
    }
}
