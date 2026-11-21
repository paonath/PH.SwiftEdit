import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("PerfPass1NativeTextBoundaryTests", .serialized)
@MainActor
struct PerfPass1NativeTextBoundaryTests {

    private static func isNativeContiguous(_ text: String) -> Bool {
        text.utf8.withContiguousStorageIfAvailable { _ in true } ?? false
    }

    @Test("P11 pass 1: normalizing TextKit's bridged buffer at the boundary is at least 20% faster than storing it bridged")
    func p11NativeBoundaryBeatsBridgedStorage() throws {
        // GIVEN the 20k-line Markdown buffer as TextKit hands it over (NSString-bridged) and a session at the previous revision
        let (_, bridged) = PerfBench016.bridgedFromTextView(PerfBench016.markdown + "x")
        let base = DocumentSession(text: PerfBench016.markdown)
        let caret = (bridged as NSString).length / 2
        // WHEN the keystroke path (store + gutter + status bar) runs on the bridged buffer versus the normalized buffer
        let legacy = PerfBench016.medianMilliseconds(runs: 5) {
            var session = base
            _ = try? session.replaceFullTextIfChanged(bridged)
            _ = LineNumberGutterProjection.evaluate(text: session.text, caretLocation: caret, fontSizePoints: 13)
            _ = StatusBarMetricsProjection.evaluate(snapshot: session.snapshot, caretLocation: caret)
        }
        let optimized = PerfBench016.medianMilliseconds(runs: 5) {
            var session = base
            _ = try? session.replaceFullTextIfChanged(NativeTextNormalizer.native(bridged))
            _ = LineNumberGutterProjection.evaluate(text: session.text, caretLocation: caret, fontSizePoints: 13)
            _ = StatusBarMetricsProjection.evaluate(snapshot: session.snapshot, caretLocation: caret)
        }
        print("PERF016 pass1 legacy=\(legacy)ms optimized=\(optimized)ms")
        // THEN the optimized path needs at most 80% of the legacy time
        #expect(optimized <= legacy * 0.8, "optimized \(optimized) ms vs legacy \(legacy) ms")
    }

    @Test("N11 pass 1: the workbench stores native contiguous text with identical content after an editor change")
    func n11WorkbenchStoresNativeText() throws {
        // GIVEN an open Markdown tab and a bridged editor buffer
        let (model, dir) = YAMLWorkbenchHarness.makeModel(opening: [("big.md", "# a\n")])
        defer { try? FileManager.default.removeItem(at: dir) }
        let (_, bridged) = PerfBench016.bridgedFromTextView("# a\nb ✓ é\n")
        // WHEN the editor reports the change
        model.handleEditorTextChanged(bridged)
        let session = try #require(model.activeDocumentSession)
        // THEN the session text is native contiguous UTF-8 and equal to the editor content
        #expect(Self.isNativeContiguous(session.text))
        #expect(session.text == "# a\nb ✓ é\n")
        #expect(NativeTextNormalizer.native(bridged) == bridged)
    }
}
