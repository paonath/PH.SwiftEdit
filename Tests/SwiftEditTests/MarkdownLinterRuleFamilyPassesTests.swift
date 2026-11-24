import Foundation
import Testing
@testable import SwiftEditCore

@Suite("MarkdownLinterRuleFamilyPassesTests")
struct MarkdownLinterRuleFamilyPassesTests {

    private static let repoRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static func approxMaxMethodCyclomaticComplexity(in source: String) -> (method: String, complexity: Int) {
        let lines = source.components(separatedBy: "\n")
        var maxMethod = ""
        var maxCC = 0
        var i = 0
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.contains("func ") && !trimmed.hasPrefix("//") && trimmed.contains("{") {
                let name = trimmed
                var depth = 0
                var cc = 1
                var j = i
                var started = false
                while j < lines.count {
                    let line = lines[j]
                    let clean = line.trimmingCharacters(in: .whitespaces)
                    if !clean.hasPrefix("//") {
                        for ch in clean {
                            if ch == "{" { depth += 1; started = true }
                            else if ch == "}" { depth -= 1 }
                        }
                        let tokens = ["if ", "else if ", "guard ", "while ", "for ", "case ", "catch ", "&&", "||", "? "]
                        for token in tokens where clean.contains(token) {
                            cc += 1
                        }
                    }
                    if started && depth == 0 { break }
                    j += 1
                }
                if cc > maxCC {
                    maxCC = cc
                    maxMethod = name
                }
                i = j + 1
                continue
            }
            i += 1
        }
        return (maxMethod, maxCC)
    }

    @Test("P5: Package topology holds and MarkdownAllConstructsLinter delegates to modular rule-family passes within CC <= 15")
    func p5ModularRuleFamilyPassesEmitIdenticalDiagnosticsWithinComplexityBudget() throws {
        // GIVEN the MarkdownAllConstructsLinter and MarkdownLinterRuleFamilyPasses source files and a multi-construct Markdown document
        let linterDir = Self.repoRoot.appendingPathComponent("Sources/SwiftEditCore/MarkdownLintAndFormat")
        let linterURL = linterDir.appendingPathComponent("MarkdownAllConstructsLinter.swift")
        let passesURL = linterDir.appendingPathComponent("MarkdownLinterRuleFamilyPasses.swift")

        let sample = """
        ---
        title: Spec
        ---
        #Title
        ### Skipped
        Paragraph
        ```
        code
        ```
        | A | B |
        | --- | --- |
        | 1 |
        >  Quoted
        - item 1
        * item 2
        1. first
        3. third
        Trailing   
        \tTab
        """
        let index = MarkdownLineIndex(text: sample)

        // WHEN running all-constructs diagnostics and checking file decomposition and complexity
        let result = try #require(MarkdownAllConstructsLinter.diagnostics(index: index, deadlineExceeded: { false }))
        let rules = Set(result.diagnostics.map(\.rule))

        // THEN all expected rule families fire, MarkdownLinterRuleFamilyPasses.swift exists, both files are <= 800 lines, and diagnostics orchestrator CC <= 15
        #expect(result.maskedLines == 3)
        #expect(rules.contains(.missingHeadingSpace))
        #expect(rules.contains(.headingIncrement))
        #expect(rules.contains(.missingFenceLanguage))
        #expect(rules.contains(.blanksAroundFences))
        #expect(rules.contains(.tableColumnCountMismatch))
        #expect(rules.contains(.multipleSpacesAfterBlockquote))
        #expect(rules.contains(.listMarkerStyle))
        #expect(rules.contains(.orderedListPrefix))
        #expect(rules.contains(.trailingSpaces))
        #expect(rules.contains(.hardTabs))

        #expect(FileManager.default.fileExists(atPath: passesURL.path))
        let linterSource = try String(contentsOf: linterURL, encoding: .utf8)
        let passesSource = try String(contentsOf: passesURL, encoding: .utf8)
        #expect(linterSource.components(separatedBy: "\n").count <= 800)
        #expect(passesSource.components(separatedBy: "\n").count <= 800)

        let linterMax = Self.approxMaxMethodCyclomaticComplexity(in: linterSource)
        let passesMax = Self.approxMaxMethodCyclomaticComplexity(in: passesSource)
        #expect(linterMax.complexity <= 15, "Method \(linterMax.method) has complexity \(linterMax.complexity)")
        #expect(passesMax.complexity <= 15, "Method \(passesMax.method) has complexity \(passesMax.complexity)")
    }

    @Test("N6 [Security]: Exceeded deadline fails closed and unsafe link/image payloads are flagged across modular passes")
    func n6DeadlineExhaustionAndUnsafePayloadsFailClosed() throws {
        // GIVEN a document with unsafe schemes, parent traversal images, and a large line count for deadline interruption
        let unsafeDoc = """
        ---
        title: "[ignored](javascript:alert(1))"
        ---
        ```markdown
        [ignored-in-fence](javascript:alert(2))
        ```
        [js](javascript:alert(1))
        [vb](vbscript:msgbox(1))
        [data](data:text/html,<script>1</script>)
        [local](file:///etc/passwd)
        ![escape](../secret.png)
        """
        let index = MarkdownLineIndex(text: unsafeDoc)

        // WHEN running full and security-only passes normally and with an expired deadline
        let full = try #require(MarkdownAllConstructsLinter.diagnostics(index: index, deadlineExceeded: { false }))
        let secOnly = try #require(MarkdownAllConstructsLinter.securityOnlyDiagnostics(index: index, deadlineExceeded: { false }))
        let timedOut = MarkdownAllConstructsLinter.diagnostics(index: index, deadlineExceeded: { true })

        // THEN expired deadline aborts fail-closed (nil) and all 5 unsafe payloads are caught while frontmatter/fences stay masked
        #expect(timedOut == nil)
        let fullUnsafeLinks = full.diagnostics.filter { $0.rule == .unsafeLinkScheme }
        let fullUnsafeImages = full.diagnostics.filter { $0.rule == .unsafeImagePath }
        #expect(fullUnsafeLinks.count == 4)
        #expect(fullUnsafeImages.count == 1)
        #expect(secOnly.diagnostics.filter { $0.rule == .unsafeLinkScheme }.count == 4)
        #expect(secOnly.diagnostics.filter { $0.rule == .unsafeImagePath }.count == 1)
    }
}
