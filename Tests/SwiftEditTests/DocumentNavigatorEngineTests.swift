import Foundation
import Testing
@testable import SwiftEditCore

@Suite("DocumentNavigatorEngineTests")
struct DocumentNavigatorEngineTests {

    @Test("P1: H1..H6 extracted with level, title and UTF-16 offset")
    func p1Levels() {
        let text = "# A\n## B\n###### F\n"
        let outline = MarkdownHeadingOutlineEngine.outline(for: text)
        #expect(outline.map(\.level) == [1, 2, 6])
        #expect(outline.map(\.title) == ["A", "B", "F"])
        #expect(outline.map(\.utf16Offset) == [0, 4, 9])
    }

    @Test("P1: closing hashes stripped and emoji offsets are UTF-16")
    func p1ClosingAndUTF16() {
        let outline = MarkdownHeadingOutlineEngine.outline(for: "😀\n## Title ##\n")
        #expect(outline.first?.title == "Title")
        #expect(outline.first?.utf16Offset == 3)
    }

    @Test("N1: fences, frontmatter, #tag, 7 hashes and 4-space indent are ignored")
    func n1NonHeadings() {
        let text = "---\n# fm\n---\n```\n# code\n```\n#tag\n####### seven\n    # indented\n# Real\n"
        let outline = MarkdownHeadingOutlineEngine.outline(for: text)
        #expect(outline.map(\.title) == ["Real"])
    }

    @Test("N2 [Security]: heading flood is capped at 5000")
    func n2Cap() {
        let text = String(repeating: "# x\n", count: 100_000)
        #expect(MarkdownHeadingOutlineEngine.outline(for: text).count == MarkdownHeadingOutlineEngine.maxHeadings)
    }

    @Test("P1/P2: filter and wrap-around selection")
    func stateSelection() {
        var state = DocumentNavigatorState(headings: MarkdownHeadingOutlineEngine.outline(for: "# Alpha\n## Beta\n"))
        #expect(state.selectedIndex == 0)
        state.moveUp()
        #expect(state.selectedIndex == 1)
        state.moveDown()
        #expect(state.selectedIndex == 0)
        state.setQuery("bet")
        #expect(state.filtered.map(\.title) == ["Beta"])
        #expect(state.confirm(documentLength: 100) == 8)
    }

    @Test("N1 [Security]: empty or unmatched outline yields no jump and stale offsets clamp")
    func stateNegative() {
        var empty = DocumentNavigatorState(headings: [])
        empty.moveDown()
        #expect(empty.confirm(documentLength: 10) == nil)
        var state = DocumentNavigatorState(headings: MarkdownHeadingOutlineEngine.outline(for: "\n\n\n# Late\n"))
        state.setQuery("zzz")
        #expect(state.confirm(documentLength: 10) == nil)
        state.setQuery("")
        #expect(state.confirm(documentLength: 2) == 2)
    }
}
