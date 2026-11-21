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

/// Shared UTF-16 line-break scanner treating `\r\n`, `\n`, and bare `\r` each as a single line break without copying the buffer.
enum UTF16LineBreakScanner {
    /// Collects `(start, contentLength)` UTF-16 spans for every 1-based line in `text` (excluding trailing line terminators) in one raw UTF-8 pass.
    static func lineContentRanges(in text: String) -> [TextRange] {
        if let fast = text.utf8.withContiguousStorageIfAvailable({ buf -> [TextRange] in
            let count = buf.count
            guard let base = buf.baseAddress, count > 0 else {
                return [TextRange(location: 0, length: 0)]
            }
            var ranges: [TextRange] = []
            ranges.reserveCapacity(max(16, count / 40))
            var lineStart = 0
            var utf16Offset = 0
            var i = 0
            while i < count {
                let b = base[i]
                if b == 0x0A {
                    ranges.append(TextRange(location: lineStart, length: utf16Offset - lineStart))
                    utf16Offset += 1
                    lineStart = utf16Offset
                    i += 1
                } else if b == 0x0D {
                    ranges.append(TextRange(location: lineStart, length: utf16Offset - lineStart))
                    if i + 1 < count && base[i + 1] == 0x0A {
                        utf16Offset += 2
                        i += 2
                    } else {
                        utf16Offset += 1
                        i += 1
                    }
                    lineStart = utf16Offset
                } else if b < 0x80 {
                    utf16Offset += 1
                    i += 1
                } else if b < 0xE0 {
                    utf16Offset += 1
                    i += 2
                } else if b < 0xF0 {
                    utf16Offset += 1
                    i += 3
                } else {
                    utf16Offset += 2
                    i += 4
                }
            }
            ranges.append(TextRange(location: lineStart, length: utf16Offset - lineStart))
            return ranges
        }) {
            return fast
        }
        let utf16 = text.utf16
        var ranges: [TextRange] = []
        var lineStart = 0
        var offset = 0
        var index = utf16.startIndex
        while index < utf16.endIndex {
            let codeUnit = utf16[index]
            if codeUnit == 0x0A {
                ranges.append(TextRange(location: lineStart, length: offset - lineStart))
                index = utf16.index(after: index)
                offset += 1
                lineStart = offset
            } else if codeUnit == 0x0D {
                ranges.append(TextRange(location: lineStart, length: offset - lineStart))
                let next = utf16.index(after: index)
                if next < utf16.endIndex && utf16[next] == 0x0A {
                    index = utf16.index(after: next)
                    offset += 2
                } else {
                    index = next
                    offset += 1
                }
                lineStart = offset
            } else {
                index = utf16.index(after: index)
                offset += 1
            }
        }
        ranges.append(TextRange(location: lineStart, length: offset - lineStart))
        return ranges
    }

    /// Zero-allocation streaming lookup returning the UTF-16 `TextRange` for a 1-based `lineNumber`, terminating as soon as that line ends.
    static func lineContentRange(forLine lineNumber: Int, in text: String) -> TextRange? {
        guard lineNumber >= 1 else { return nil }
        if let fast = text.utf8.withContiguousStorageIfAvailable({ buf -> TextRange? in
            let count = buf.count
            guard let base = buf.baseAddress else {
                return lineNumber == 1 ? TextRange(location: 0, length: 0) : nil
            }
            var currentLine = 1
            var lineStart = 0
            var utf16Offset = 0
            var i = 0
            while i < count {
                let b = base[i]
                if b == 0x0A {
                    if currentLine == lineNumber {
                        return TextRange(location: lineStart, length: utf16Offset - lineStart)
                    }
                    currentLine += 1
                    utf16Offset += 1
                    lineStart = utf16Offset
                    i += 1
                } else if b == 0x0D {
                    if currentLine == lineNumber {
                        return TextRange(location: lineStart, length: utf16Offset - lineStart)
                    }
                    currentLine += 1
                    if i + 1 < count && base[i + 1] == 0x0A {
                        utf16Offset += 2
                        i += 2
                    } else {
                        utf16Offset += 1
                        i += 1
                    }
                    lineStart = utf16Offset
                } else if b < 0x80 {
                    utf16Offset += 1
                    i += 1
                } else if b < 0xE0 {
                    utf16Offset += 1
                    i += 2
                } else if b < 0xF0 {
                    utf16Offset += 1
                    i += 3
                } else {
                    utf16Offset += 2
                    i += 4
                }
            }
            if currentLine == lineNumber {
                return TextRange(location: lineStart, length: utf16Offset - lineStart)
            }
            return nil
        }) {
            return fast
        }
        let ranges = lineContentRanges(in: text)
        return lineNumber <= ranges.count ? ranges[lineNumber - 1] : nil
    }
}

/// Stateless calculator computing status-bar `Line`, `Column`, and `Character count` in one allocation-free UTF-8 pass (`BC-004`, `BC-007`, `PERF-007`).
public enum CursorMetricsCalculator {
    /// Computes 1-based line, 1-based UTF-16 column, and Unicode scalar count for `caretLocation` in `text`.
    /// - Parameters:
    ///   - text: Document buffer string.
    ///   - caretLocation: UTF-16 code-unit caret index (`0...text.utf16.count`).
    /// - Returns: Resolved `CursorMetrics` value.
    /// - Throws: `DomainError.invalidTextRange` when `caretLocation < 0` or `caretLocation > text.utf16.count`.
    public static func metrics(in text: String, caretLocation: Int) throws -> CursorMetrics {
        guard caretLocation >= 0 else {
            throw DomainError.invalidTextRange(TextRange(location: caretLocation, length: 0))
        }

        if let fast = text.utf8.withContiguousStorageIfAvailable({ buf -> CursorMetrics? in
            let count = buf.count
            guard let base = buf.baseAddress, count > 0 else {
                return caretLocation == 0 ? CursorMetrics(line: 1, column: 1, characterCount: 0) : nil
            }
            var line = 1
            var lineStartOffset = 0
            var utf16Offset = 0
            var scalarCount = 0
            var i = 0

            // Phase 1: track line/lineStartOffset while advancing up to caretLocation.
            while i < count && utf16Offset < caretLocation {
                let b = base[i]
                if b == 0x0A {
                    line += 1
                    utf16Offset += 1
                    lineStartOffset = utf16Offset
                    scalarCount += 1
                    i += 1
                } else if b == 0x0D {
                    line += 1
                    if i + 1 < count && base[i + 1] == 0x0A && utf16Offset + 1 < caretLocation {
                        utf16Offset += 2
                        scalarCount += 2
                        i += 2
                    } else {
                        utf16Offset += 1
                        scalarCount += 1
                        i += 1
                    }
                    lineStartOffset = utf16Offset
                } else if b < 0x80 {
                    utf16Offset += 1
                    scalarCount += 1
                    i += 1
                } else if b < 0xE0 {
                    utf16Offset += 1
                    scalarCount += 1
                    i += 2
                } else if b < 0xF0 {
                    utf16Offset += 1
                    scalarCount += 1
                    i += 3
                } else {
                    utf16Offset += 2
                    scalarCount += 1
                    i += 4
                }
            }

            // Phase 2: tight raw-byte tail pass counting remaining UTF-16 units & scalars.
            while i < count {
                let b = base[i]
                if b < 0x80 {
                    utf16Offset += 1
                    scalarCount += 1
                    i += 1
                } else if b < 0xE0 {
                    utf16Offset += 1
                    scalarCount += 1
                    i += 2
                } else if b < 0xF0 {
                    utf16Offset += 1
                    scalarCount += 1
                    i += 3
                } else {
                    utf16Offset += 2
                    scalarCount += 1
                    i += 4
                }
            }

            guard caretLocation <= utf16Offset else { return nil }
            return CursorMetrics(
                line: line,
                column: (caretLocation - lineStartOffset) + 1,
                characterCount: scalarCount
            )
        }) {
            guard let resolved = fast else {
                throw DomainError.invalidTextRange(TextRange(location: caretLocation, length: 0))
            }
            return resolved
        }

        let utf16 = text.utf16
        let utf16Count = utf16.count
        guard caretLocation <= utf16Count else {
            throw DomainError.invalidTextRange(TextRange(location: caretLocation, length: 0))
        }

        var line = 1
        var lineStartOffset = 0
        var offset = 0
        var index = utf16.startIndex
        while index < utf16.endIndex && offset < caretLocation {
            let codeUnit = utf16[index]
            if codeUnit == 0x0A {
                line += 1
                index = utf16.index(after: index)
                offset += 1
                lineStartOffset = offset
            } else if codeUnit == 0x0D {
                line += 1
                let next = utf16.index(after: index)
                if next < utf16.endIndex && utf16[next] == 0x0A && offset + 1 < caretLocation {
                    index = utf16.index(after: next)
                    offset += 2
                } else {
                    index = next
                    offset += 1
                }
                lineStartOffset = offset
            } else {
                index = utf16.index(after: index)
                offset += 1
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
