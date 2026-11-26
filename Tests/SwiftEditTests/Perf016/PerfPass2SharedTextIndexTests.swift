import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("PerfPass2SharedTextIndexTests", .serialized)
struct PerfPass2SharedTextIndexTests {

    @Test("P11 pass 2: caret moves answered from the per-revision index are at least 20% faster than full rescans", .enabled(if: ReleasePipelineTestGate.shouldRunE2EUIAndStressTests))
    func p11CaretMovesUseSharedIndex() {
        // GIVEN the 20k-line Markdown snapshot, its per-revision index, and 5 caret positions
        let snapshot = DocumentSession(text: PerfBench016.markdown).snapshot
        let length = (PerfBench016.markdown as NSString).length
        let carets = (0..<5).map { $0 * length / 5 }
        let index = DocumentTextIndex(text: snapshot.text)
        // WHEN gutter and status bar are evaluated per caret by rescanning versus by index lookup
        let legacy = PerfBench016.medianMilliseconds(runs: 5) {
            for caret in carets {
                _ = LineNumberGutterProjection.evaluate(text: snapshot.text, caretLocation: caret, fontSizePoints: 13)
                _ = StatusBarMetricsProjection.evaluate(snapshot: snapshot, caretLocation: caret)
            }
        }
        let optimized = PerfBench016.medianMilliseconds(runs: 5) {
            for caret in carets {
                _ = LineNumberGutterProjection.evaluate(index: index, caretLocation: caret, fontSizePoints: 13)
                _ = StatusBarMetricsProjection.evaluate(snapshot: snapshot, index: index, caretLocation: caret)
            }
        }
        let frontmatterLegacy = PerfBench016.medianMilliseconds(runs: 5) {
            _ = YAMLStructureLinter.lint(index: MarkdownLineIndex(text: snapshot.text), frontmatterOnly: true)
        }
        let frontmatterOptimized = PerfBench016.medianMilliseconds(runs: 5) {
            _ = YAMLStructureLinter.lint(snapshot: snapshot, frontmatterOnly: true)
        }
        let build = PerfBench016.medianMilliseconds(runs: 5) { _ = DocumentTextIndex(text: snapshot.text) }
        print("PERF016 pass2 indexBuild=\(build)ms caret legacy=\(legacy)ms optimized=\(optimized)ms frontmatter legacy=\(frontmatterLegacy)ms optimized=\(frontmatterOptimized)ms")
        // THEN both optimized paths need at most 80% of the legacy time
        #expect(optimized <= legacy * 0.8)
        #expect(frontmatterOptimized <= frontmatterLegacy * 0.8)
    }

    @Test("N11 pass 2: index-based gutter and cursor metrics equal the full-scan results for LF, CRLF and CR at every caret")
    func n11IndexMatchesFullScanEverywhere() {
        // GIVEN mixed line-ending text with multi-byte scalars and every caret position
        let text = "a\nb\r\nc\rd é😀\r\n\r\nend\n"
        let snapshot = DocumentSession(text: text).snapshot
        let index = DocumentTextIndex(text: text)
        let carets = Array(0...(text as NSString).length)
        // WHEN both paths evaluate every caret
        let legacy = carets.map { (LineNumberGutterProjection.evaluate(text: text, caretLocation: $0, fontSizePoints: 13), StatusBarMetricsProjection.evaluate(snapshot: snapshot, caretLocation: $0)) }
        let indexed = carets.map { (LineNumberGutterProjection.evaluate(index: index, caretLocation: $0, fontSizePoints: 13), StatusBarMetricsProjection.evaluate(snapshot: snapshot, index: index, caretLocation: $0)) }
        // THEN results are identical
        #expect(legacy.map(\.0) == indexed.map(\.0))
        #expect(legacy.map(\.1) == indexed.map(\.1))
    }

    @MainActor
    @Test("N12 pass 2: the shared index never serves a previous revision after a same-length edit")
    func n12NoStaleIndexAfterSameLengthEdit() throws {
        // GIVEN an open tab whose index was built at one revision
        let (model, dir) = YAMLWorkbenchHarness.makeModel(opening: [("a.md", "ab\ncd")])
        defer { try? FileManager.default.removeItem(at: dir) }
        model.handleSelectionChanged(TextRange(location: 4, length: 0))
        let before = model.activeLineNumberGutter
        // WHEN a same-length edit moves the line break and the caret stays at offset 4
        model.handleEditorTextChanged("abc\nd")
        let after = model.activeLineNumberGutter
        let metrics = model.activeStatusBarMetrics
        let cache = DocumentTextIndexCache()
        let session = try #require(model.activeDocumentSession)
        let first = cache.index(for: DocumentSession(id: session.id, revision: BufferRevision(9), text: "ab\ncd").snapshot)
        let second = cache.index(for: DocumentSession(id: session.id, revision: BufferRevision(10), text: "abc\nd").snapshot)
        // THEN the gutter, the status bar and the cache all reflect the new revision
        #expect(before.activeLine == 2)
        #expect(after.activeLine == 2)
        #expect(metrics.column == 1)
        #expect(first.breakStarts == [2])
        #expect(second.breakStarts == [3])
    }
}
