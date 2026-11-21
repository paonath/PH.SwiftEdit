import Foundation
import Testing
@testable import SwiftEditCore

@Suite("MarkdownAllConstructsLintTests")
struct MarkdownAllConstructsLintTests {

    private static func lint(_ text: String, _ profile: MarkdownLintProfile? = nil) -> MarkdownLintResult {
        let snap = DocumentSession(text: text).snapshot
        let outcome = profile.map { MarkdownLintAndFormatEngine.lint(snapshot: snap, profile: $0) } ?? MarkdownLintAndFormatEngine.lint(snapshot: snap)
        return outcome.completedValue!
    }

    @Test("P1: YAML frontmatter is clean while MD018, MD045 and MD056 are reported")
    func p1FrontmatterCleanAndRulesFire() {
        let text = "---\ntitle: x\n# a yaml comment\n---\n#Heading\n\n![](flow.png)\n\n| a | b |\n|---|---|\n| 1 |"
        let result = Self.lint(text, .allConstructs)
        let pairs = result.diagnostics.map { "\($0.rule.rawValue)@\($0.line)" }
        #expect(result.diagnostics.allSatisfy { $0.line > 4 })
        #expect(pairs.contains("missingHeadingSpace@5"))
        #expect(pairs.contains("missingImageAltText@7"))
        #expect(pairs.contains("tableColumnCountMismatch@11"))
        #expect(result.diagnostics.allSatisfy { $0.range != nil })
    }

    @Test("N1: the default profile is unchanged and tight nested sublists are not flagged")
    func n1DefaultUnchangedAndTightSublists() {
        let nested = Self.lint("- a\n    - b\n    - c", .allConstructs)
        #expect(!nested.diagnostics.contains { $0.rule == .blanksAroundLists })
        let defaultResult = Self.lint("#Heading")
        let legacy = Self.lint("#Heading", .legacyBaseline)
        #expect(defaultResult.diagnostics == legacy.diagnostics)
        #expect(defaultResult.diagnostics.map(\.rule) == [.missingHeadingSpace])
    }

    @Test("N7: a default lint call keeps the legacy rule set")
    func n7LegacyCallKeepsRuleSet() {
        let result = Self.lint("#Heading\n[x](javascript:alert(1))")
        #expect(result.diagnostics.map(\.rule) == [.missingHeadingSpace, .unsafeLinkScheme])
    }

    @Test("N2 [Security]: obfuscated URIs, traversal and SVG images are errors that survive the 1000 cap")
    func n2SecurityRulesSurviveCap() {
        let head = "[x](javascript%3Aalert(1))\n![x](../../etc/passwd)\n![x](pic.svg)\n[y](//evil.example)\n"
        let text = head + String(repeating: "warn \n", count: 1500)
        let result = Self.lint(text, .allConstructs)
        let errors = result.diagnostics.filter { $0.severity == .error }
        #expect(errors.contains { $0.rule == .unsafeLinkScheme && $0.line == 1 })
        #expect(errors.contains { $0.rule == .unsafeImagePath && $0.line == 2 })
        #expect(errors.contains { $0.rule == .unsafeImagePath && $0.line == 3 })
        #expect(errors.contains { $0.rule == .unsafeLinkScheme && $0.line == 4 })
        #expect(result.diagnostics.count <= 1000)
        #expect(result.isTruncated)
        #expect(errors.allSatisfy { $0.quickFix == nil })
    }
}
