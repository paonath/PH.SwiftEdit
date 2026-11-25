import Foundation
import Testing
@testable import SwiftEditCore

@Suite("YAMLLineTokenizerTests")
struct YAMLLineTokenizerTests {

    private static func texts(_ line: String, _ kind: YAMLTokenKind) -> [String] {
        let ns = line as NSString
        return YAMLLineTokenizer.tokens(line: line).filter { $0.kind == kind }.map { ns.substring(with: NSRange(location: $0.range.location, length: $0.range.length)) }
    }

    @Test("P2: keys, quoted strings with # and :, comments, list dashes, URLs and flow lists tokenize correctly")
    func p2KeysValuesCommentsListsAndQuotedStrings() {
        // GIVEN four representative YAML lines
        let quoted = #"name: "a # not comment: x"  # real"#
        // WHEN each line is tokenized
        // THEN keys, values, quoted strings, comments and dashes are separated
        #expect(Self.texts(quoted, .key) == ["name"])
        #expect(Self.texts(quoted, .colon) == [":"])
        #expect(Self.texts(quoted, .quotedString) == [#""a # not comment: x""#])
        #expect(Self.texts(quoted, .comment) == ["# real"])
        #expect(Self.texts("  - item", .listDash) == ["-"])
        #expect(Self.texts("  - item", .value) == ["item"])
        #expect(Self.texts("url: http://x.y/z", .value) == ["http://x.y/z"])
        #expect(Self.texts("tags: [a, b]", .value) == ["[a, b]"])
        #expect(Self.texts("- key: v", .key) == ["key"])
    }

    @Test("P2b: document markers, block scalar indicators, anchors, aliases and tags are classified")
    func p2bMarkersIndicatorsAnchorsAliasesAndTags() {
        // GIVEN structural YAML lines
        // WHEN they are tokenized
        // THEN each construct receives its own kind
        #expect(Self.texts("---", .documentMarker) == ["---"])
        #expect(Self.texts("body: |-", .blockScalarIndicator) == ["|-"])
        #expect(Self.texts("base: &b x", .anchor) == ["&b"])
        #expect(Self.texts("ref: *b", .alias) == ["*b"])
        #expect(Self.texts("obj: !!python/object x", .tag) == ["!!python/object"])
        #expect(Self.texts("'it''s': 1", .key) == ["'it''s'"])
    }

    @Test("N2: overlong lines, unterminated quotes and alias bombs stay bounded and unexpanded")
    func n2OverlongUnterminatedAndAliasBombStayBounded() throws {
        // GIVEN a 4097-unit line, an unterminated quote and the 10-level alias bomb fixture
        let overlong = "k: " + String(repeating: "x", count: 4094)
        let bomb = try #require(YAMLFixtures016.all["alias-bomb.yml"])
        let bombLines = bomb.split(separator: "\n").map(String.init)
        // WHEN all lines are tokenized
        let overlongTokens = YAMLLineTokenizer.tokens(line: overlong)
        let unterminated = Self.texts(#"k: "unterminated"#, .quotedString)
        let bombTokenCounts = bombLines.map { YAMLLineTokenizer.tokens(line: $0).count }
        // THEN the overlong line yields nothing, the quote runs to end of line, and every bomb line yields exactly key, colon, anchor and one value
        #expect((overlong as NSString).length == 4097)
        #expect(overlongTokens.isEmpty)
        #expect(unterminated == [#""unterminated"#])
        #expect(bombTokenCounts == Array(repeating: 4, count: 10))
        #expect(Self.texts("ref: *b", .value).isEmpty)
    }

    @Test("N2b [Security]: empty and out-of-bounds ArraySlice inputs fail closed in keyEnd, quotedEnd, and inspectStructure without trapping")
    func n2bEmptyAndOutOfBoundsSlicesFailClosed() {
        // GIVEN an empty slice and a non-empty non-zero-based slice
        let units = Array("key: \"val\"\n".utf16)
        let emptySlice = units[5..<5]
        let subSlice = units[0..<10]

        // WHEN keyEnd, quotedEnd, and inspectStructure are called with empty or out-of-bounds indices
        let emptyKey = YAMLLineTokenizer.keyEnd(emptySlice, from: 5, end: 5)
        let oobHighKey = YAMLLineTokenizer.keyEnd(subSlice, from: 10, end: 10)
        let oobLowKey = YAMLLineTokenizer.keyEnd(subSlice, from: -1, end: 5)
        let oobEndKey = YAMLLineTokenizer.keyEnd(subSlice, from: 0, end: 99)

        let emptyQuote = YAMLLineTokenizer.quotedEnd(emptySlice, from: 5, end: 5)
        let oobQuote = YAMLLineTokenizer.quotedEnd(subSlice, from: 12, end: 12)

        let overIndented = YAMLLineTokenizer.inspectStructure(line: subSlice, indent: 50)
        let negativeIndent = YAMLLineTokenizer.inspectStructure(line: subSlice, indent: -3)
        let emptyStruct = YAMLLineTokenizer.inspectStructure(line: emptySlice, indent: 0)

        // THEN every call fails closed cleanly without Index out of bounds traps (CWE-125, CWE-129)
        #expect(emptyKey == nil)
        #expect(oobHighKey == nil)
        #expect(oobLowKey == nil)
        #expect(oobEndKey == nil)
        #expect(emptyQuote == 5)
        #expect(oobQuote == 10)
        #expect(overIndented.isIgnored == true)
        #expect(negativeIndent.isIgnored == true)
        #expect(emptyStruct.isIgnored == true)
    }
}
