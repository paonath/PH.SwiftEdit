import Foundation
import Testing
@testable import SwiftEditCore

@Suite("MarkdownOutlineContinuationAndLintTests")
struct MarkdownOutlineContinuationAndLintTests {

    private static func newline(_ text: String) -> SmartNewlineEdit? {
        MarkdownSmartNewlineEngine.evaluateNewline(
            in: DocumentSession(text: text).snapshot,
            caretLocation: (text as NSString).length,
            isMarkdownDocument: true
        )
    }

    private static func apply(_ edit: SmartNewlineEdit, to text: String) -> String {
        (text as NSString).replacingCharacters(
            in: NSRange(location: edit.edit.range.location, length: edit.edit.range.length),
            with: edit.edit.replacement
        )
    }

    @Test("P3: Return continues a. and 1.1 pseudo-outline markers and exits a nested empty ordered item in two stages")
    func p3PseudoOutlineContinuationAndTwoStageExit() {
        // GIVEN pseudo-outline items and a nested empty ordered item under "2. due"
        let letter = "    a. alpha"
        let decimal = "    1.1 uno"
        let nested = "2. due\n    1. "

        // WHEN pressing Return at the end of each, then once more on the outdented empty item
        let letterEdit = Self.newline(letter)
        let decimalEdit = Self.newline(decimal)
        let firstStage = Self.newline(nested)
        let afterFirst = firstStage.map { Self.apply($0, to: nested) }
        let secondStage = afterFirst.flatMap { text in Self.newline(text).map { Self.apply($0, to: text) } }

        // THEN markers continue as b. and 1.2, the nested item outdents to "3. " first, and the next Return clears it
        #expect(letterEdit?.edit.replacement == "\n    b. ")
        #expect(decimalEdit?.edit.replacement == "\n    1.2 ")
        #expect(afterFirst == "2. due\n3. ")
        #expect(secondStage == "2. due\n")
    }

    @Test("N3: nonStandardOutlineMarker flags a. and 1.1 inside list context outside fences and never valid markers or prose")
    func n3NonStandardOutlineMarkersAreFlaggedOutsideFencesOnly() throws {
        // GIVEN a list with pseudo-outline lines, a fenced pseudo line, and plain prose starting with "A."
        let listText = "1. ok\n    a. alpha\n    1.1 beta\n```\n    b. code\n```"
        let prose = "A. Smith wrote this\n\nSecond paragraph"

        // WHEN linting both snapshots
        let listResult = try #require(MarkdownLintAndFormatEngine.lint(snapshot: DocumentSession(text: listText).snapshot).completedValue)
        let proseResult = try #require(MarkdownLintAndFormatEngine.lint(snapshot: DocumentSession(text: prose).snapshot).completedValue)
        let flaggedLines = listResult.diagnostics.filter { $0.rule == .nonStandardOutlineMarker }.map(\.line)
        let proseFlags = proseResult.diagnostics.filter { $0.rule == .nonStandardOutlineMarker }

        // THEN only lines 2 and 3 are flagged and prose is untouched
        #expect(flaggedLines == [2, 3])
        #expect(proseFlags.isEmpty)
    }
}
