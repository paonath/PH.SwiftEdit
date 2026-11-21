import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("PerfPass1_017PreviewTests", .serialized)
@MainActor
struct PerfPass1_017PreviewTests {

    private static func openLarge() -> (SwiftEditWorkbenchModel, URL) {
        let (model, dir) = YAMLWorkbenchHarness.makeModel(opening: [("big.md", PerfBench016.markdown)])
        model.toggleMarkdownPreview()
        return (model, dir)
    }

    @Test("P10 pass 1: keystrokes with the preview open no longer project the whole document on the main actor")
    func p10PreviewProjectionLeavesMainActor() {
        // GIVEN a 20k-line Markdown tab with the preview open
        let (model, dir) = Self.openLarge()
        defer { try? FileManager.default.removeItem(at: dir) }
        var text = model.activeDocumentSession!.text
        // WHEN the keystroke path runs with the legacy synchronous projection versus the workbench preview path
        let legacy = PerfBench016.medianMilliseconds(runs: 5) {
            text += "x"; model.handleEditorTextChanged(text)
            _ = MarkdownPreviewProjector.project(snapshot: model.activeDocumentSession!.snapshot, showPreview: true)
        }
        let optimized = PerfBench016.medianMilliseconds(runs: 5) {
            text += "y"; model.handleEditorTextChanged(text); _ = model.markdownPreviewDocument
        }
        print("PERF017 pass1 legacy=\(legacy)ms optimized=\(optimized)ms")
        // THEN the main-actor cost drops by at least 20%
        #expect(optimized <= legacy * 0.8)
    }

    @Test("N10 pass 1: the background projection equals the synchronous projection for the settled revision")
    func n10BackgroundProjectionMatchesSync() async {
        // GIVEN a 20k-line tab with the preview open and one edit
        let (model, dir) = Self.openLarge()
        defer { try? FileManager.default.removeItem(at: dir) }
        model.handleEditorTextChanged(model.activeDocumentSession!.text + "\n# Tail")
        // WHEN the pending projection settles
        await model.awaitPendingPreview()
        let settled = model.markdownPreviewDocument
        let expected = MarkdownPreviewProjector.project(snapshot: model.activeDocumentSession!.snapshot, showPreview: true)
        // THEN it equals the synchronous projection of the same revision
        #expect(settled != nil)
        #expect(settled == expected)
    }
}
