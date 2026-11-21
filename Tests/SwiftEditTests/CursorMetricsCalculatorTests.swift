import Foundation
import Testing
@testable import SwiftEditCore

@Suite("CursorMetricsCalculatorTests")
struct CursorMetricsCalculatorTests {

    @Test("P2: CursorMetricsCalculator computes 1-based line, UTF-16 column, and Unicode scalar count across LF, CRLF, and CR")
    func p2LineColumnAndCharacterCountAcrossMixedLineBreaks() throws {
        // GIVEN an 11-scalar buffer containing LF, CRLF, and Classic Mac CR breaks
        let buffer = "ab\ncd\r\nef\rg"

        // WHEN computing metrics at caret 8 ('f' on line 3) and caret 10 ('g' on line 4)
        let atEight = try CursorMetricsCalculator.metrics(in: buffer, caretLocation: 8)
        let atTen = try CursorMetricsCalculator.metrics(in: buffer, caretLocation: 10)

        // THEN line, UTF-16 column, and total scalar character count match 1-based status bar semantics
        #expect(atEight == CursorMetrics(line: 3, column: 2, characterCount: 11))
        #expect(atTen == CursorMetrics(line: 4, column: 1, characterCount: 11))
    }

    @Test("N2: Out-of-range caret locations throw DomainError.invalidTextRange", arguments: [-1, 12])
    func n2OutOfRangeCaretThrowsInvalidTextRange(invalidCaret: Int) {
        // GIVEN an 11-unit UTF-16 buffer
        let buffer = "ab\ncd\r\nef\rg"

        // WHEN requesting cursor metrics at an out-of-range caret offset
        // THEN DomainError.invalidTextRange is thrown
        #expect(throws: DomainError.invalidTextRange(TextRange(location: invalidCaret, length: 0))) {
            _ = try CursorMetricsCalculator.metrics(in: buffer, caretLocation: invalidCaret)
        }
    }
}
