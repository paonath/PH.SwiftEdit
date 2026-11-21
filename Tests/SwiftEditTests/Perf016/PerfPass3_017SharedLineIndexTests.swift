import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("PerfPass3_017SharedLineIndexTests", .serialized)
@MainActor
struct PerfPass3_017SharedLineIndexTests {

    @Test("P10 pass 3: editor and navigator share one per-revision line index instead of building two")
    func p10SharedIndexBeatsDuplicateBuilds() {
        // GIVEN a 20k-line tab
        let (model, dir) = YAMLWorkbenchHarness.makeModel(opening: [("big.md", PerfBench016.markdown)])
        defer { try? FileManager.default.removeItem(at: dir) }
        var text = model.activeDocumentSession!.text
        // WHEN a revision is followed by the editor index build and a navigator open, legacy versus shared
        let legacy = PerfBench016.medianMilliseconds(runs: 5) {
            text += "x"; model.handleEditorTextChanged(text)
            _ = MarkdownLineIndex(text: model.activeDocumentSession!.text)
            _ = DocumentNavigatorState(headings: MarkdownHeadingOutlineEngine.outline(for: model.activeDocumentSession!.text))
        }
        let optimized = PerfBench016.medianMilliseconds(runs: 5) {
            text += "y"; model.handleEditorTextChanged(text)
            _ = model.activeLineIndex()
            model.toggleDocumentNavigator(); model.closeDocumentNavigator()
        }
        print("PERF017 pass3 legacy=\(legacy)ms optimized=\(optimized)ms")
        // THEN the per-revision main-actor index work drops by at least 20%
        #expect(optimized <= legacy * 0.8)
    }

    @Test("N10 pass 3: the shared index is revision-exact and the navigator outline is unchanged")
    func n10SharedIndexIsRevisionExact() throws {
        // GIVEN a tab whose index was cached, then a same-length edit
        let (model, dir) = YAMLWorkbenchHarness.makeModel(opening: [("a.md", "# A\nab\n## B")])
        defer { try? FileManager.default.removeItem(at: dir) }
        let first = try #require(model.activeLineIndex())
        model.handleEditorTextChanged("# A\n## B\nab")
        // WHEN the index and the outline are requested again
        let second = try #require(model.activeLineIndex())
        model.toggleDocumentNavigator()
        let titles = model.navigatorState?.filtered.map(\.title)
        // THEN the new index reflects the new revision and the outline matches the engine on the raw text
        #expect(first.lineStarts == [0, 4, 7])
        #expect(second.lineStarts == [0, 4, 9])
        #expect(titles == MarkdownHeadingOutlineEngine.outline(for: "# A\n## B\nab").map(\.title))
    }
}
