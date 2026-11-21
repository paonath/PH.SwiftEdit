import Foundation
import Testing
@testable import SwiftEditCore

@Suite("MarkdownSmartNewlineEngineTests")
struct MarkdownSmartNewlineEngineTests {

    @Test("P2: MarkdownSmartNewlineEngine continues unordered, task, incremented ordered, and blockquote lines and exits on empty marker")
    func p2SmartNewlineContinuationAndEmptyMarkerExit() throws {
        // GIVEN Markdown buffers for unordered, task, ordered (dot & paren), blockquote, and empty list marker lines
        let bullet = DocumentSession(text: "  - alpha").snapshot
        let task = DocumentSession(text: "- [x] done").snapshot
        let orderedDot = DocumentSession(text: "3. third").snapshot
        let orderedParen = DocumentSession(text: "2) second").snapshot
        let quote = DocumentSession(text: "> quoted").snapshot
        let emptyMarker = DocumentSession(text: "  - ").snapshot

        // WHEN evaluating Enter at the end of each line
        let bulletEdit = try #require(MarkdownSmartNewlineEngine.evaluateNewline(in: bullet, caretLocation: bullet.text.utf16.count, isMarkdownDocument: true))
        let taskEdit = try #require(MarkdownSmartNewlineEngine.evaluateNewline(in: task, caretLocation: task.text.utf16.count, isMarkdownDocument: true))
        let dotEdit = try #require(MarkdownSmartNewlineEngine.evaluateNewline(in: orderedDot, caretLocation: orderedDot.text.utf16.count, isMarkdownDocument: true))
        let parenEdit = try #require(MarkdownSmartNewlineEngine.evaluateNewline(in: orderedParen, caretLocation: orderedParen.text.utf16.count, isMarkdownDocument: true))
        let quoteEdit = try #require(MarkdownSmartNewlineEngine.evaluateNewline(in: quote, caretLocation: quote.text.utf16.count, isMarkdownDocument: true))
        let emptyEdit = try #require(MarkdownSmartNewlineEngine.evaluateNewline(in: emptyMarker, caretLocation: emptyMarker.text.utf16.count, isMarkdownDocument: true))

        // THEN consistent next markers are proposed and empty marker is cleared to exit the list
        #expect(bulletEdit.edit == TextEdit(range: TextRange(location: 9, length: 0), replacement: "\n  - "))
        #expect(bulletEdit.newCaretLocation == 14)
        #expect(taskEdit.edit == TextEdit(range: TextRange(location: 10, length: 0), replacement: "\n- [ ] "))
        #expect(taskEdit.newCaretLocation == 17)
        #expect(dotEdit.edit == TextEdit(range: TextRange(location: 8, length: 0), replacement: "\n4. "))
        #expect(dotEdit.newCaretLocation == 12)
        #expect(parenEdit.edit == TextEdit(range: TextRange(location: 9, length: 0), replacement: "\n3) "))
        #expect(parenEdit.newCaretLocation == 13)
        #expect(quoteEdit.edit == TextEdit(range: TextRange(location: 8, length: 0), replacement: "\n> "))
        #expect(quoteEdit.newCaretLocation == 11)
        #expect(emptyEdit.edit == TextEdit(range: TextRange(location: 0, length: 4), replacement: ""))
        #expect(emptyEdit.newCaretLocation == 0)

        #expect(MarkdownSmartNewlineEngine.isMarkdownFilename("notes.md") == true)
        #expect(MarkdownSmartNewlineEngine.isMarkdownFilename("README.MARKDOWN") == true)
        #expect(MarkdownSmartNewlineEngine.isMarkdownFilename(nil) == true)
        #expect(MarkdownSmartNewlineEngine.isMarkdownFilename("Main.swift") == false)
    }

    @Test("N3: Fenced code blocks, non-Markdown documents, and plain prose lines return nil for standard newline")
    func n3FencedCodeBlockNonMarkdownAndProseReturnNil() {
        // GIVEN caret inside fenced block, non-Markdown buffer with bullet, and plain Markdown prose
        let fenced = DocumentSession(text: "```markdown\n- item").snapshot
        let nonMarkdown = DocumentSession(text: "- item").snapshot
        let plainProse = DocumentSession(text: "Just a normal paragraph").snapshot

        // WHEN evaluating Enter at the end of each buffer
        let fencedResult = MarkdownSmartNewlineEngine.evaluateNewline(in: fenced, caretLocation: fenced.text.utf16.count, isMarkdownDocument: true)
        let nonMdResult = MarkdownSmartNewlineEngine.evaluateNewline(in: nonMarkdown, caretLocation: nonMarkdown.text.utf16.count, isMarkdownDocument: false)
        let proseResult = MarkdownSmartNewlineEngine.evaluateNewline(in: plainProse, caretLocation: plainProse.text.utf16.count, isMarkdownDocument: true)

        // THEN all three return nil
        #expect(fencedResult == nil)
        #expect(nonMdResult == nil)
        #expect(proseResult == nil)
    }

    @Test("N4 [Security]: Binary read-only snapshots, out-of-range carets, and overlong lines return nil safely")
    func n4SecurityBinaryOutOfRangeCaretAndOverlongLineReturnNil() {
        // GIVEN binary snapshot, out-of-range carets, and a >4096 UTF-16 line
        let binary = DocumentSession(text: "- binary", isBinaryReadOnly: true).snapshot
        let normal = DocumentSession(text: "- item").snapshot
        let overlong = DocumentSession(text: "- " + String(repeating: "a", count: 4096)).snapshot
        let hugeNumber = DocumentSession(text: "9223372036854775807. overflow").snapshot

        // WHEN evaluating Enter across hostile inputs
        let binaryResult = MarkdownSmartNewlineEngine.evaluateNewline(in: binary, caretLocation: 8, isMarkdownDocument: true)
        let negativeCaret = MarkdownSmartNewlineEngine.evaluateNewline(in: normal, caretLocation: -1, isMarkdownDocument: true)
        let pastEndCaret = MarkdownSmartNewlineEngine.evaluateNewline(in: normal, caretLocation: 99, isMarkdownDocument: true)
        let overlongResult = MarkdownSmartNewlineEngine.evaluateNewline(in: overlong, caretLocation: overlong.text.utf16.count, isMarkdownDocument: true)
        let overflowResult = MarkdownSmartNewlineEngine.evaluateNewline(in: hugeNumber, caretLocation: hugeNumber.text.utf16.count, isMarkdownDocument: true)

        // THEN all hostile calls fail closed returning nil without crashing
        #expect(binaryResult == nil)
        #expect(negativeCaret == nil)
        #expect(pastEndCaret == nil)
        #expect(overlongResult == nil)
        #expect(overflowResult == nil)
    }
}
