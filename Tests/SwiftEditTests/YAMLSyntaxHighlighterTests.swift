import Foundation
import Testing
@testable import SwiftEditCore

@Suite("YAMLSyntaxHighlighterTests")
struct YAMLSyntaxHighlighterTests {

    private static func snapshot(_ text: String, binary: Bool = false, degraded: Bool = false) -> DocumentSnapshot {
        DocumentSession(text: text, isDegradedPlainText: degraded, isBinaryReadOnly: binary).snapshot
    }

    private static func fullRange(_ text: String) -> SwiftEditCore.TextRange { TextRange(location: 0, length: (text as NSString).length) }

    private static func spans(_ text: String, _ language: DocumentLanguage, range: SwiftEditCore.TextRange? = nil, binary: Bool = false, degraded: Bool = false) -> [MarkdownSyntaxSpan] {
        DocumentSyntaxHighlighter.spans(snapshot: snapshot(text, binary: binary, degraded: degraded), visibleRange: range ?? fullRange(text), language: language)
    }

    private static func text(_ span: MarkdownSyntaxSpan, in text: String) -> String {
        (text as NSString).substring(with: NSRange(location: span.range.location, length: span.range.length))
    }

    @Test("P3: a YAML file receives key and value spans only for the visible lines 10...30")
    func p3YAMLFileSpansAreViewportOnly() {
        // GIVEN a 200-line YAML document and a visible range covering lines 10...30 (0-based 9...29)
        let lines = (0..<200).map { "key\($0): value\($0)" }
        let text = lines.joined(separator: "\n")
        let index = MarkdownLineIndex(text: text)
        let start = index.lineRange(9).location
        let end = index.lineRange(29).upperBound
        // WHEN spans are requested for that range
        let spans = Self.spans(text, .yaml, range: TextRange(location: start, length: end - start))
        let keys = spans.filter { $0.kind == .yamlKey }.map { Self.text($0, in: text) }
        // THEN exactly the 21 visible keys are styled and every span stays inside the range
        #expect(keys.count == 21)
        #expect(keys.first == "key9")
        #expect(keys.last == "key29")
        #expect(spans.allSatisfy { $0.range.location >= start && $0.range.upperBound <= end })
        #expect(spans.contains { $0.kind == .yamlValue && Self.text($0, in: text) == "value9" })
    }

    @Test("P3b / P10: Markdown frontmatter lines receive YAML spans while the body keeps GFM spans")
    func p3bFrontmatterDelegationKeepsGFMBody() {
        // GIVEN a Markdown snapshot with a frontmatter block followed by a heading and bold text
        let text = "---\ntitle: Hi\ntags: [a]\n---\n# Heading\n**bold**"
        let bodyStart = ("---\ntitle: Hi\ntags: [a]\n---\n" as NSString).length
        // WHEN spans are computed for the whole document
        let spans = Self.spans(text, .markdown)
        let frontmatter = spans.filter { $0.range.location < bodyStart }
        let body = spans.filter { $0.range.location >= bodyStart }
        // THEN the frontmatter has only YAML kinds (keys title and tags, no thematic break) and the body keeps GFM kinds
        #expect(frontmatter.filter { $0.kind == .yamlKey }.map { Self.text($0, in: text) } == ["title", "tags"])
        #expect(frontmatter.contains { $0.kind == .yamlValue && Self.text($0, in: text) == "Hi" })
        #expect(!frontmatter.contains { $0.kind == .thematicBreak })
        #expect(frontmatter.allSatisfy { $0.kind.isYAML })
        #expect(body.contains { $0.kind == .heading(level: 1) })
        #expect(body.contains { $0.kind == .bold })
    }

    @Test("N3: plain text, binary and degraded snapshots receive no YAML spans")
    func n3PlainBinaryAndDegradedYieldNothing() {
        // GIVEN key/value text in a plain-text, a binary YAML and a degraded YAML snapshot
        let text = "key: value"
        // WHEN spans are requested
        // THEN all are empty
        #expect(Self.spans(text, .plainText).isEmpty)
        #expect(Self.spans(text, .yaml, binary: true).isEmpty)
        #expect(Self.spans(text, .yaml, degraded: true).isEmpty)
        #expect(Self.spans(text, .yaml, range: TextRange(location: 0, length: 0)).isEmpty)
    }

    @Test("N3b / N12: non-line-1 and unterminated delimiters stay GFM thematic breaks")
    func n3bNonLineOneAndUnterminatedFrontmatterStayGFM() {
        // GIVEN a '---' block starting on line 3 and a line-1 '---' that never closes within 200 lines
        let late = "intro\n\n---\ntitle: x\n---"
        let unterminated = "---\n" + Array(repeating: "a: b", count: 205).joined(separator: "\n")
        // WHEN spans are computed
        let lateSpans = Self.spans(late, .markdown)
        let openSpans = Self.spans(unterminated, .markdown)
        // THEN no YAML spans exist and the delimiters remain thematic breaks
        #expect(!lateSpans.contains { $0.kind.isYAML })
        #expect(lateSpans.filter { $0.kind == .thematicBreak }.count == 2)
        #expect(!openSpans.contains { $0.kind.isYAML })
        #expect(openSpans.first?.kind == .thematicBreak)
    }
}
