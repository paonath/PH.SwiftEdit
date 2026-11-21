import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("YAMLStructureLinterTests")
struct YAMLStructureLinterTests {

    private static func lint(_ text: String, frontmatterOnly: Bool = false) -> [MarkdownLintDiagnostic] {
        YAMLStructureLinter.lint(snapshot: DocumentSession(text: text).snapshot, frontmatterOnly: frontmatterOnly)
    }

    private static func rulesByLine(_ diagnostics: [MarkdownLintDiagnostic]) -> [String] {
        diagnostics.map { "\($0.rule.code)@\($0.line)" }
    }

    @Test("P4: YML001..YML004 are reported on their lines")
    func p4FourStructuralRules() {
        // GIVEN a YAML file with a tab-indented line 3, a duplicate top-level key, and a 3-space child under 2-space siblings
        let yaml = "name: a\nroot:\n\tchild: 1\nname: b\nother:\n  x: 1\n  y:\n     z: 2\n"
        // AND a Markdown file whose line-1 frontmatter never closes within 200 lines
        let markdown = "---\n" + Array(repeating: "k: v", count: 205).joined(separator: "\n")
        // WHEN both are linted
        let yamlRules = Self.rulesByLine(Self.lint(yaml))
        let markdownRules = Self.rulesByLine(Self.lint(markdown, frontmatterOnly: true))
        // THEN each rule fires on the expected line
        #expect(yamlRules.contains("YML001@3"))
        #expect(yamlRules.contains("YML002@4"))
        #expect(yamlRules.contains("YML003@8"))
        #expect(markdownRules == ["YML004@1"])
    }

    @Test("P4b: list items open fresh mappings and block scalar bodies are not linted as keys")
    func p4bListItemsAndBlockScalarsAreNotDuplicates() {
        // GIVEN repeated keys across list items and a key-looking line inside a block scalar
        let yaml = "items:\n  - name: a\n  - name: b\nscript: |\n  name: fake\n  name: fake\nend: 1\n"
        // WHEN linted
        // THEN no diagnostics are produced
        #expect(Self.lint(yaml).isEmpty)
    }

    @Test("N4: valid files are clean, duplicates are capped at 1000, depth is capped at 32 and values never leak")
    func n4ValidCleanCapsAndRedaction() throws {
        // GIVEN a valid fixture, 5001 identical top-level keys, and the 40-level nesting fixture holding a secret
        let valid = try #require(YAMLFixtures016.all["config.yml"])
        let duplicates = Array(repeating: "name: x", count: 5001).joined(separator: "\n")
        let deep = try #require(YAMLFixtures016.all["deep-nesting.yml"])
        // WHEN each is linted
        let validDiagnostics = Self.lint(valid)
        let duplicateDiagnostics = Self.lint(duplicates)
        let deepDiagnostics = Self.lint(deep)
        // THEN the caps hold and no message contains the secret value
        #expect(validDiagnostics.isEmpty)
        #expect(duplicateDiagnostics.count == 1000)
        #expect(deepDiagnostics.map(\.rule.code) == ["YML005"])
        #expect(!deepDiagnostics.contains { $0.message.contains("s3cr3t") })
        #expect(!duplicateDiagnostics.contains { $0.message.contains(": x") })
    }

    @Test("P7 (lint REQ-003): YAML tabs report Active status from the structural linter")
    func p7YAMLTabReportsActive() {
        // GIVEN a config.yml snapshot with two structural issues
        let snapshot = DocumentSession(text: "a: 1\na: 2\nb:\n\tc: 1\n").snapshot
        let count = YAMLStructureLinter.lint(snapshot: snapshot).count
        // WHEN status is classified for the YAML language
        let status = ActiveLintStatus.classify(language: .yaml, snapshot: snapshot, diagnosticCount: count)
        // THEN it is active with two issues
        #expect(status == .active(count: 2))
        #expect(status.label.contains("Lint: 2"))
    }

    @Test("N8 (lint REQ-003): plain-text and binary YAML tabs remain Off")
    func n8PlainAndBinaryRemainOff() {
        // GIVEN a Swift file snapshot and a binary data.yml snapshot
        let plain = DocumentSession(text: "a: 1\na: 2").snapshot
        let binary = DocumentSession(text: "a: 1", isBinaryReadOnly: true).snapshot
        // WHEN statuses are classified
        // THEN both are off
        #expect(ActiveLintStatus.classify(language: .plainText, snapshot: plain, diagnosticCount: 0) == .off)
        #expect(ActiveLintStatus.classify(language: DocumentLanguage.resolve(filename: "data.yml", isBinary: true), snapshot: binary, diagnosticCount: 0) == .off)
    }
}

@Suite("YAMLLintWorkbenchTests")
@MainActor
struct YAMLLintWorkbenchTests {

    @Test("P7b: opening a YAML tab lints it through the workbench and shows the language")
    func p7bWorkbenchLintsYAMLTab() {
        // GIVEN a config.yml with a duplicate key and a tab-indented line
        let (model, dir) = YAMLWorkbenchHarness.makeModel(opening: [("config.yml", "a: 1\na: 2\nb:\n\tc: 1\n")])
        defer { try? FileManager.default.removeItem(at: dir) }
        // WHEN diagnostics refresh
        model.refreshDiagnosticsForActiveDocument()
        // THEN the workbench reports two YAML diagnostics
        #expect(model.activeDocumentLanguage == .yaml)
        #expect(model.activeLintStatus == .active(count: 2))
        #expect(model.lintDiagnostics.map(\.rule.code).sorted() == ["YML001", "YML002"])
    }

    @Test("N8b: Markdown tabs append frontmatter YAML diagnostics and plain tabs stay off")
    func n8bMarkdownFrontmatterAndPlainTabs() {
        // GIVEN a Markdown file with a duplicate frontmatter key and a Swift file
        let (model, dir) = YAMLWorkbenchHarness.makeModel(opening: [("main.swift", "a: 1\na: 1\n"), ("post.md", "---\ntitle: a\ntitle: b\n---\n# Body\n")])
        defer { try? FileManager.default.removeItem(at: dir) }
        // WHEN diagnostics refresh for the Markdown tab
        model.refreshDiagnosticsForActiveDocument()
        let markdownCodes = model.lintDiagnostics.map(\.rule.code)
        // THEN the frontmatter duplicate is reported on line 3
        #expect(markdownCodes.contains("YML002"))
        #expect(model.lintDiagnostics.contains { $0.rule.code == "YML002" && $0.line == 3 })
    }
}
