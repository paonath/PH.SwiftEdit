import Foundation
import Testing
@testable import SwiftEditCore

@Suite("MarkdownSyntaxHighlighterTests")
struct MarkdownSyntaxHighlighterTests {

    private static func snapshot(_ text: String) -> DocumentSnapshot {
        DocumentSession(text: text).snapshot
    }

    private static func kinds(_ spans: [MarkdownSyntaxSpan]) -> [MarkdownSyntaxKind] { spans.map(\.kind) }

    @Test("P1: twelve GFM constructs are tokenized for the visible range only")
    func p1ConstructsTokenizedForVisibleRangeOnly() {
        // GIVEN a document with all constructs on lines 1...6 and a distinct heading on line 7
        let lines = [
            "# Title",
            "**bold** *it* ~~gone~~ `code`",
            "[link](https://example.com) ![img](./a.png) <b>",
            "- [x] done",
            "> quote",
            "| a | b |",
            "---",
            "## Hidden"
        ]
        let text = lines.joined(separator: "\n")
        let firstSixLength = (lines[0..<6].joined(separator: "\n") as NSString).length
        // WHEN spans are requested for the first six lines only
        let spans = MarkdownSyntaxHighlighter.spans(snapshot: Self.snapshot(text), visibleRange: TextRange(location: 0, length: firstSixLength))
        let found = Self.kinds(spans)
        // THEN the constructs of lines 1...6 are returned and nothing from lines 7...8
        #expect(found.contains(.heading(level: 1)))
        #expect(found.contains(.bold))
        #expect(found.contains(.italic))
        #expect(found.contains(.strikethrough))
        #expect(found.contains(.inlineCode))
        #expect(found.contains(.link))
        #expect(found.contains(.image))
        #expect(found.contains(.inlineHTML))
        #expect(found.contains(.task(checked: true)))
        #expect(found.contains(.blockquote))
        #expect(found.contains(.tableRow))
        #expect(!found.contains(.thematicBreak))
        #expect(!found.contains(.heading(level: 2)))
        let sixthEnd = firstSixLength
        #expect(spans.allSatisfy { $0.range.upperBound <= sixthEnd + 1 })
    }

    @Test("P1b: thematic break and a fenced block are classified")
    func p1bThematicBreakAndFence() {
        let text = "---\n```\ncode\n```"
        let spans = MarkdownSyntaxHighlighter.spans(snapshot: Self.snapshot(text), visibleRange: TextRange(location: 0, length: (text as NSString).length))
        #expect(Self.kinds(spans).contains(.thematicBreak))
        #expect(Self.kinds(spans).filter { $0 == .codeBlock }.count == 3)
    }

    @Test("N1: fenced interior, non-Markdown documents, and an empty range yield no construct spans")
    func n1FencedNonMarkdownAndEmptyRange() {
        // GIVEN a fenced bold text, a non-Markdown flag, and an empty visible range
        let fenced = "```\n**not bold**\n```"
        let full = TextRange(location: 0, length: (fenced as NSString).length)
        // WHEN spans run
        let fencedSpans = MarkdownSyntaxHighlighter.spans(snapshot: Self.snapshot(fenced), visibleRange: full)
        let notMarkdown = MarkdownSyntaxHighlighter.spans(snapshot: Self.snapshot("**b**"), visibleRange: TextRange(location: 0, length: 5), isMarkdownDocument: false)
        let empty = MarkdownSyntaxHighlighter.spans(snapshot: Self.snapshot("**b**"), visibleRange: TextRange(location: 0, length: 0))
        // THEN only code-block spans, nothing, and nothing
        #expect(!Self.kinds(fencedSpans).contains(.bold))
        #expect(Self.kinds(fencedSpans).allSatisfy { $0 == .codeBlock })
        #expect(!fencedSpans.isEmpty)
        #expect(notMarkdown.isEmpty)
        #expect(empty.isEmpty)
    }

    @Test("N2: binary, degraded, and overlong lines return no spans")
    func n2BinaryDegradedAndOverlongReturnNoSpans() {
        // GIVEN binary, degraded, and 4097-unit snapshots
        let binary = DocumentSnapshot(id: DocumentID(), revision: BufferRevision(0), text: "**b**", encoding: .utf8, lineEnding: .lf, isDegradedPlainText: false, isBinaryReadOnly: true)
        let degraded = DocumentSnapshot(id: DocumentID(), revision: BufferRevision(0), text: "**b**", encoding: .utf8, lineEnding: .lf, isDegradedPlainText: true, isBinaryReadOnly: false)
        let long = String(repeating: "*", count: 4097)
        // WHEN spans run
        let r = TextRange(location: 0, length: 4097)
        // THEN each is empty
        #expect(MarkdownSyntaxHighlighter.spans(snapshot: binary, visibleRange: TextRange(location: 0, length: 5)).isEmpty)
        #expect(MarkdownSyntaxHighlighter.spans(snapshot: degraded, visibleRange: TextRange(location: 0, length: 5)).isEmpty)
        #expect(MarkdownSyntaxHighlighter.spans(snapshot: Self.snapshot(long), visibleRange: r).isEmpty)
    }
}
