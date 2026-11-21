import Foundation
import Testing
@testable import SwiftEditCore

@Suite("FrontmatterPropertyParserTests")
struct FrontmatterPropertyParserTests {

    private static func parse(_ text: String) -> FrontmatterPropertyModel? {
        FrontmatterPropertyParser.parse(snapshot: DocumentSession(text: text).snapshot)
    }

    @Test("P7: scalars and block/flow lists are parsed as editable entries with exact line ranges")
    func p7ScalarsAndListsEditable() throws {
        // GIVEN a frontmatter with three scalars, a flow list and a block list
        let text = "---\ntitle: Hello\ndraft: false\ndate: 2026-11-21\ntags: [a, \"b, c\"]\naliases:\n  - x\n  - 'y'\n---\n# Body\n"
        // WHEN it is parsed
        let model = try #require(Self.parse(text))
        // THEN five editable entries carry their kinds and line ranges
        #expect(!model.isReadOnly)
        #expect(model.properties.map(\.key) == ["title", "draft", "date", "tags", "aliases"])
        #expect(model.properties.map(\.kind) == [.scalar("Hello"), .scalar("false"), .scalar("2026-11-21"), .list(["a", "b, c"]), .list(["x", "y"])])
        #expect(model.properties.allSatisfy { $0.isEditable })
        #expect(model.properties.map(\.lineRange) == [1..<2, 2..<3, 3..<4, 4..<5, 5..<8])
        #expect(model.closingDelimiterLine == 8)
    }

    @Test("P7b: comments are preserved outside entries and quoted scalars are unescaped")
    func p7bCommentsAndQuotedScalars() throws {
        // GIVEN a frontmatter with a standalone comment, a double-quoted scalar with escapes and an inline comment
        let text = "---\n# note\ntitle: \"Hi: \\\"x\\\"\"\nn: 3 # count\n---\n"
        // WHEN parsed
        let model = try #require(Self.parse(text))
        // THEN quotes are decoded and the inline comment is kept apart from the value
        #expect(model.properties.map(\.kind) == [.scalar("Hi: \"x\""), .scalar("3")])
        #expect(model.properties.last?.trailingComment == "# count")
        #expect(model.properties.first?.lineRange == 2..<3)
    }

    @Test("N7: nested maps, block scalars, aliases, anchors and tags are read-only and never expanded")
    func n7UnsupportedConstructsReadOnly() throws {
        // GIVEN unsupported YAML constructs inside a frontmatter
        let text = "---\nmeta:\n  a: 1\nbody: |\n  text\nbase: &b x\nref: *b\nobj: !!python/object x\nmap: {a: 1}\n---\n"
        // WHEN parsed
        let model = try #require(Self.parse(text))
        // THEN each entry is read-only with its kind and no alias value is materialized
        #expect(model.properties.map(\.kind) == [.nestedMap, .blockScalar, .aliased, .aliased, .tagged, .nestedMap])
        #expect(model.properties.allSatisfy { !$0.isEditable })
        #expect(!model.isReadOnly)
    }

    @Test("N7b: unterminated, malformed and oversized frontmatter yields a fully read-only model; no frontmatter yields nil")
    func n7bFailClosedModels() throws {
        // GIVEN an unterminated block, a tab-indented block, a duplicate-key block, 501 entries, and a plain document
        let unterminated = "---\ntitle: a\n# no closing delimiter"
        let tabbed = "---\nmeta:\n\ta: 1\n---\n"
        let duplicate = "---\ntitle: a\ntitle: b\n---\n"
        let oversized = "---\n" + (0..<501).map { "k\($0): v" }.joined(separator: "\n") + "\n---\n"
        // WHEN parsed
        let models = [unterminated, tabbed, duplicate].map(Self.parse)
        let big = try #require(Self.parse(oversized))
        // THEN every model is read-only; the oversized block exceeds the 200-line frontmatter scan, so it is treated as
        // unterminated and exposes nothing (the 500-entry cap is a second, defense-in-depth bound); a plain document has no model
        #expect(models.allSatisfy { $0?.isReadOnly == true })
        #expect(big.isReadOnly)
        #expect(big.properties.isEmpty)
        #expect(Self.parse("# Title\n") == nil)
        #expect(FrontmatterPropertyParser.parse(snapshot: DocumentSession(text: "---\na: 1\n---\n", isBinaryReadOnly: true).snapshot) == nil)
    }
}
