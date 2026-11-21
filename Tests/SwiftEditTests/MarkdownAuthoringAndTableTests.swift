import Foundation
import Testing
@testable import SwiftEditCore

@Suite("MarkdownAuthoringAndTableTests")
struct MarkdownAuthoringAndTableTests {

    private static func snapshot(_ text: String) -> DocumentSnapshot { DocumentSession(text: text).snapshot }

    private static func apply(_ edit: MarkdownAuthoringEdit, to text: String) -> String {
        let m = NSMutableString(string: text)
        for e in edit.edits.sorted(by: { $0.range.location > $1.range.location }) {
            m.replaceCharacters(in: NSRange(location: e.range.location, length: e.range.length), with: e.replacement)
        }
        return m as String
    }

    private static func run(_ cmd: MarkdownAuthoringCommand, _ text: String, _ sel: SwiftEditCore.TextRange, markdown: Bool = true) -> (String, SwiftEditCore.TextRange)? {
        guard let e = MarkdownAuthoringCommands.evaluate(cmd, in: snapshot(text), selection: sel, isMarkdownDocument: markdown) else { return nil }
        return (apply(e, to: text), e.newSelection)
    }

    private static func tab(_ text: String, at caret: Int, backward: Bool = false) -> (String, SwiftEditCore.TextRange)? {
        let out = GFMTableEditEngine.evaluateTab(in: snapshot(text), selection: TextRange(location: caret, length: 0), backward: backward, isMarkdownDocument: true)
        guard case .edit(let e) = out else { return nil }
        return (apply(e, to: text), e.newSelection)
    }

    @Test("P2: Bold, Italic, Link and Heading apply in one batch and toggle off")
    func p2AuthoringCommandsApplyAndToggle() {
        let sel = TextRange(location: 0, length: 4)
        #expect(Self.run(.bold, "word", sel)?.0 == "**word**")
        #expect(Self.run(.italic, "word", sel)?.0 == "*word*")
        #expect(Self.run(.link, "word", sel)?.0 == "[word](url)")
        #expect(Self.run(.heading(level: 2), "word", sel)?.0 == "## word")
        #expect(Self.run(.heading(level: 2), "## word", TextRange(location: 3, length: 0))?.0 == "word")
        #expect(Self.run(.bold, "**word**", TextRange(location: 0, length: 8))?.0 == "word")
        #expect(Self.run(.taskToggle, "- [ ] a", TextRange(location: 0, length: 0))?.0 == "- [x] a")
        #expect(Self.run(.bold, "", TextRange(location: 0, length: 0))?.0 == "****")
        #expect(Self.run(.bold, "word", sel)?.1 == TextRange(location: 2, length: 4))
    }

    @Test("P3: Tab pads columns, moves between cells, and appends a row at the last cell")
    func p3TableTabNavigation() {
        let table = "| a | bb |\n|---|---|\n| 1 | 2 |"
        let lastCell = (table as NSString).length - 2
        let appended = Self.tab(table, at: lastCell)
        #expect(appended?.0 == "| a   | bb  |\n| --- | --- |\n| 1   | 2   |\n|     |     |")
        let firstOfLast = (appended!.0 as NSString).range(of: "|     |").location + 2
        #expect(appended?.1.location == firstOfLast)
        let next = Self.tab(table, at: 2)
        #expect(next != nil)
        let back = Self.tab(table, at: (table as NSString).range(of: "| 1").location + 2, backward: true)
        #expect(back != nil)
        #expect((back!.0 as NSString).substring(with: NSRange(location: back!.1.location, length: back!.1.length)) == "bb")
    }

    @Test("N3: commands inside fences and non-Markdown documents are not applied")
    func n3FenceAndNonMarkdown() {
        let fenced = "```\nword\n```"
        #expect(Self.run(.bold, fenced, TextRange(location: 4, length: 4)) == nil)
        #expect(Self.run(.bold, "word", TextRange(location: 0, length: 4), markdown: false) == nil)
    }

    @Test("N8: Tab outside tables is not applicable")
    func n8TabOutsideTable() {
        #expect(GFMTableEditEngine.evaluateTab(in: Self.snapshot("plain text"), selection: TextRange(location: 2, length: 0), backward: false, isMarkdownDocument: true) == .notApplicable)
        let fenced = "```\n| a | b |\n|---|---|\n```"
        #expect(GFMTableEditEngine.evaluateTab(in: Self.snapshot(fenced), selection: TextRange(location: 6, length: 0), backward: false, isMarkdownDocument: true) == .notApplicable)
    }

    @Test("N4: oversized tables and binary snapshots return no edit")
    func n4OversizedAndBinary() {
        let wide = "|" + String(repeating: " a |", count: 65) + "\n|" + String(repeating: "---|", count: 65)
        #expect(Self.tab(wide, at: 2) == nil)
        let tall = "| a |\n|---|\n" + String(repeating: "| x |\n", count: 2001)
        #expect(Self.tab(tall, at: 2) == nil)
        let binary = DocumentSnapshot(id: DocumentID(), revision: BufferRevision(0), text: "| a |\n|---|", encoding: .utf8, lineEnding: .lf, isDegradedPlainText: false, isBinaryReadOnly: true)
        #expect(GFMTableEditEngine.evaluateTab(in: binary, selection: TextRange(location: 2, length: 0), backward: false, isMarkdownDocument: true) == .notApplicable)
        #expect(MarkdownAuthoringCommands.evaluate(.bold, in: binary, selection: TextRange(location: 0, length: 1), isMarkdownDocument: true) == nil)
    }
}
