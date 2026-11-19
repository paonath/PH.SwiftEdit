import Foundation

/// Immutable 1-based status-bar cursor and document counters (`UI-001`, `BC-004`).
public struct CursorMetrics: Equatable, Sendable {
    /// 1-based line number at the caret (`>= 1`).
    public let line: Int
    /// 1-based UTF-16 column offset from the start of the current line (`>= 1`), aligned with `NSTextView` selection ranges.
    public let column: Int
    /// Total Unicode scalar count of the buffer (`text.unicodeScalars.count`).
    public let characterCount: Int

    public init(line: Int, column: Int, characterCount: Int) {
        self.line = line
        self.column = column
        self.characterCount = characterCount
    }
}

/// Shared UTF-16 line-break scanner treating `\r\n`, `\n`, and bare `\r` each as a single line break.
enum UTF16LineBreakScanner {
    /// Returns the number of UTF-16 code units (`1` or `2`) forming a line break at `index`, or `0` when `units[index]` is not a line terminator.
    static func lineBreakWidth(in units: [UInt16], at index: Int, limit: Int) -> Int {
        let codeUnit = units[index]
        if codeUnit == 0x0A {
            return 1
        }
        if codeUnit == 0x0D {
            if index + 1 < limit && units[index + 1] == 0x0A {
                return 2
            }
            return 1
        }
        return 0
    }

    /// Collects `(start, contentLength)` UTF-16 spans for every 1-based line in `text` (excluding trailing line terminators).
    static func lineContentRanges(in text: String) -> [TextRange] {
        let units = Array(text.utf16)
        var ranges: [TextRange] = []
        var lineStart = 0
        var index = 0
        while index < units.count {
            let breakWidth = lineBreakWidth(in: units, at: index, limit: units.count)
            if breakWidth > 0 {
                ranges.append(TextRange(location: lineStart, length: index - lineStart))
                index += breakWidth
                lineStart = index
            } else {
                index += 1
            }
        }
        ranges.append(TextRange(location: lineStart, length: units.count - lineStart))
        return ranges
    }
}

/// Stateless calculator computing status-bar `Line`, `Column`, and `Character count` in one pass up to `caretLocation` (`BC-004`, `BC-007`).
public enum CursorMetricsCalculator {
    /// Computes 1-based line, 1-based UTF-16 column, and Unicode scalar count for `caretLocation` in `text`.
    /// - Parameters:
    ///   - text: Document buffer string.
    ///   - caretLocation: UTF-16 code-unit caret index (`0...text.utf16.count`).
    /// - Returns: Resolved `CursorMetrics` value.
    /// - Throws: `DomainError.invalidTextRange` when `caretLocation < 0` or `caretLocation > text.utf16.count`.
    public static func metrics(in text: String, caretLocation: Int) throws -> CursorMetrics {
        let utf16Count = text.utf16.count
        guard caretLocation >= 0 && caretLocation <= utf16Count else {
            throw DomainError.invalidTextRange(TextRange(location: caretLocation, length: 0))
        }

        let units = Array(text.utf16)
        var line = 1
        var lineStartOffset = 0
        var index = 0
        while index < caretLocation {
            let breakWidth = UTF16LineBreakScanner.lineBreakWidth(in: units, at: index, limit: caretLocation)
            if breakWidth > 0 {
                line += 1
                index += breakWidth
                lineStartOffset = index
            } else {
                index += 1
            }
        }

        let column = (caretLocation - lineStartOffset) + 1
        return CursorMetrics(
            line: line,
            column: column,
            characterCount: text.unicodeScalars.count
        )
    }
}
