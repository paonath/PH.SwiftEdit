import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("YAMLSmartIndentEngineTests")
struct YAMLSmartIndentEngineTests {

    private static func newline(_ text: String, _ language: DocumentLanguage, caret: Int? = nil) -> String? {
        let snap = DocumentSession(text: text).snapshot
        let at = caret ?? (text as NSString).length
        guard let edit = YAMLSmartIndentEngine.evaluateNewline(in: snap, caretLocation: at, language: language) else { return nil }
        return (text as NSString).replacingCharacters(in: NSRange(location: edit.edit.range.location, length: edit.edit.range.length), with: edit.edit.replacement)
    }

    @Test("P6: Enter after 'key:' adds two spaces, Enter after a list item continues it, Tab inserts two spaces")
    func p6MappingIndentListContinuationAndTab() {
        // GIVEN carets at the end of '  services:' and '  - web', and an empty line
        // WHEN Enter and Tab are evaluated
        let mapping = Self.newline("root:\n  services:", .yaml)
        let list = Self.newline("items:\n  - web", .yaml)
        let tab = YAMLSmartIndentEngine.evaluateTab(in: DocumentSession(text: "a:\n").snapshot, selection: TextRange(location: 3, length: 0), outdent: false, language: .yaml)
        // THEN the new lines start with 4 spaces and '  - ', and Tab inserts exactly two spaces
        #expect(mapping == "root:\n  services:\n    ")
        #expect(list == "items:\n  - web\n  - ")
        #expect(tab == .edit(SmartListEdit(edits: [TextEdit(range: TextRange(location: 3, length: 0), replacement: "  ")], newSelection: TextRange(location: 5, length: 0))))
    }

    @Test("P6b: frontmatter lines in Markdown use the YAML engine")
    func p6bFrontmatterUsesYAMLEngine() {
        // GIVEN a caret at the end of 'tags:' inside frontmatter
        let text = "---\ntags:\n---\nbody"
        let caret = ("---\ntags:" as NSString).length
        // WHEN Enter is evaluated
        let result = Self.newline(text, .markdown, caret: caret)
        // THEN a two-space indented line is inserted
        #expect(result == "---\ntags:\n  \n---\nbody")
    }

    @Test("N6: non-YAML contexts fall back, empty markers exit, quoted colons get plain indentation, Tab never inserts \\t")
    func n6FallbacksAndExits() {
        // GIVEN a .txt tab, a Markdown body line, an empty '  - ' marker and a quoted colon
        let plain = Self.newline("key:", .plainText)
        let body = Self.newline("# T\nkey:", .markdown)
        let empty = Self.newline("items:\n  - ", .yaml)
        let quoted = Self.newline("  k: \"a:\"", .yaml)
        let tab = YAMLSmartIndentEngine.evaluateTab(in: DocumentSession(text: "a").snapshot, selection: TextRange(location: 1, length: 0), outdent: false, language: .plainText)
        // THEN each context is handled safely
        #expect(plain == nil)
        #expect(body == nil)
        #expect(empty == "items:\n  ")
        #expect(quoted == "  k: \"a:\"\n  ")
        #expect(tab == .notApplicable)
        #expect(!(Self.newline("a:", .yaml) ?? "").contains("\t"))
    }
}

@Suite("YAMLSmartIndentWorkbenchTests")
@MainActor
struct YAMLSmartIndentWorkbenchTests {

    @Test("P6c: workbench Enter in a YAML tab applies one revision with the indented caret")
    func p6cWorkbenchEnter() throws {
        // GIVEN an open YAML tab with the caret after 'root:'
        let (model, dir) = YAMLWorkbenchHarness.makeModel(opening: [("a.yml", "root:")])
        defer { try? FileManager.default.removeItem(at: dir) }
        let before = try #require(model.activeDocumentSession).revision
        // WHEN Enter is pressed at the end
        let caret = model.applySmartNewlineIfApplicable(at: 5)
        let after = try #require(model.activeDocumentSession)
        // THEN the line is indented and exactly one revision elapsed
        #expect(caret == 8)
        #expect(after.text == "root:\n  ")
        #expect(after.revision == before.next())
    }
}
