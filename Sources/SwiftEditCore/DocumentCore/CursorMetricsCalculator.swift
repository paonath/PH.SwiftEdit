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
        if let fast = text.utf8.withContiguousStorageIfAvailable({ buf in lineBreakScanAllContiguousRanges(buf) }) {
            return fast
        }
        return lineBreakScanAllUTF16Ranges(in: text.utf16)
    }

    /// Zero-allocation streaming lookup returning the UTF-16 `TextRange` for a 1-based `lineNumber`, terminating as soon as that line ends.
    static func lineContentRange(forLine lineNumber: Int, in text: String) -> TextRange? {
        guard lineNumber >= 1 else { return nil }
        if let fast = text.utf8.withContiguousStorageIfAvailable({ buf -> TextRange? in
            lineBreakFindSingleContiguousRange(forLine: lineNumber, in: buf)
        }) {
            return fast
        }
        let ranges = lineContentRanges(in: text)
        return lineNumber <= ranges.count ? ranges[lineNumber - 1] : nil
    }
}

extension UTF16LineBreakScanner {
    @inline(__always)
    fileprivate static func lineBreakUTF8ScalarStep(_ leadByte: UInt8) -> (bytes: Int, utf16Units: Int) {
        if leadByte < 0x80 { return (1, 1) }
        if leadByte < 0xE0 { return (2, 1) }
        if leadByte < 0xF0 { return (3, 1) }
        return (4, 2)
    }

    private static func lineBreakScanAllContiguousRanges(_ buf: UnsafeBufferPointer<UInt8>) -> [TextRange] {
        guard let base = buf.baseAddress, buf.count > 0 else {
            return [TextRange(location: 0, length: 0)]
        }
        var ranges: [TextRange] = []
        ranges.reserveCapacity(max(16, buf.count / 40))
        var lineStart = 0
        var utf16Offset = 0
        var index = 0
        while index < buf.count {
            lineBreakStepAllContiguous(
                base: base,
                count: buf.count,
                index: &index,
                utf16Offset: &utf16Offset,
                lineStart: &lineStart,
                ranges: &ranges
            )
        }
        ranges.append(TextRange(location: lineStart, length: utf16Offset - lineStart))
        return ranges
    }

    private static func lineBreakStepAllContiguous(
        base: UnsafePointer<UInt8>,
        count: Int,
        index: inout Int,
        utf16Offset: inout Int,
        lineStart: inout Int,
        ranges: inout [TextRange]
    ) {
        let b = base[index]
        if b == 0x0A || b == 0x0D {
            ranges.append(TextRange(location: lineStart, length: utf16Offset - lineStart))
            let step = (b == 0x0D && index + 1 < count && base[index + 1] == 0x0A) ? 2 : 1
            utf16Offset += step
            index += step
            lineStart = utf16Offset
            return
        }
        let adv = lineBreakUTF8ScalarStep(b)
        utf16Offset += adv.utf16Units
        index += adv.bytes
    }

    private static func lineBreakScanAllUTF16Ranges(in utf16: String.UTF16View) -> [TextRange] {
        var ranges: [TextRange] = []
        var lineStart = 0
        var offset = 0
        var index = utf16.startIndex
        while index < utf16.endIndex {
            lineBreakStepAllUTF16(
                utf16: utf16,
                index: &index,
                offset: &offset,
                lineStart: &lineStart,
                ranges: &ranges
            )
        }
        ranges.append(TextRange(location: lineStart, length: offset - lineStart))
        return ranges
    }

    private static func lineBreakStepAllUTF16(
        utf16: String.UTF16View,
        index: inout String.UTF16View.Index,
        offset: inout Int,
        lineStart: inout Int,
        ranges: inout [TextRange]
    ) {
        let codeUnit = utf16[index]
        let next = utf16.index(after: index)
        if codeUnit == 0x0A {
            ranges.append(TextRange(location: lineStart, length: offset - lineStart))
            index = next
            offset += 1
            lineStart = offset
        } else if codeUnit == 0x0D {
            ranges.append(TextRange(location: lineStart, length: offset - lineStart))
            let isCRLF = next < utf16.endIndex && utf16[next] == 0x0A
            index = isCRLF ? utf16.index(after: next) : next
            offset += isCRLF ? 2 : 1
            lineStart = offset
        } else {
            index = next
            offset += 1
        }
    }

    private static func lineBreakFindSingleContiguousRange(
        forLine lineNumber: Int,
        in buf: UnsafeBufferPointer<UInt8>
    ) -> TextRange? {
        guard let base = buf.baseAddress else {
            return lineNumber == 1 ? TextRange(location: 0, length: 0) : nil
        }
        var currentLine = 1
        var lineStart = 0
        var utf16Offset = 0
        var index = 0
        while index < buf.count {
            if let matched = lineBreakStepSingleContiguous(
                base: base,
                count: buf.count,
                targetLine: lineNumber,
                index: &index,
                currentLine: &currentLine,
                utf16Offset: &utf16Offset,
                lineStart: &lineStart
            ) {
                return matched
            }
        }
        return currentLine == lineNumber
            ? TextRange(location: lineStart, length: utf16Offset - lineStart)
            : nil
    }

    private static func lineBreakStepSingleContiguous(
        base: UnsafePointer<UInt8>,
        count: Int,
        targetLine: Int,
        index: inout Int,
        currentLine: inout Int,
        utf16Offset: inout Int,
        lineStart: inout Int
    ) -> TextRange? {
        let b = base[index]
        if b == 0x0A || b == 0x0D {
            if currentLine == targetLine {
                return TextRange(location: lineStart, length: utf16Offset - lineStart)
            }
            let step = (b == 0x0D && index + 1 < count && base[index + 1] == 0x0A) ? 2 : 1
            currentLine += 1
            utf16Offset += step
            lineStart = utf16Offset
            index += step
            return nil
        }
        let adv = lineBreakUTF8ScalarStep(b)
        utf16Offset += adv.utf16Units
        index += adv.bytes
        return nil
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
            cursorMetricsComputeContiguous(in: buf, caretLocation: caretLocation)
        }) {
            guard let resolved = fast else {
                throw DomainError.invalidTextRange(TextRange(location: caretLocation, length: 0))
            }
            return resolved
        }

        return try cursorMetricsComputeUTF16Fallback(in: text, caretLocation: caretLocation)
    }
}

private extension CursorMetricsCalculator {
    struct CursorMetricsScanState {
        var line = 1
        var lineStartOffset = 0
        var utf16Offset = 0
        var scalarCount = 0
        var byteIndex = 0
    }

    static func cursorMetricsComputeContiguous(
        in buf: UnsafeBufferPointer<UInt8>,
        caretLocation: Int
    ) -> CursorMetrics? {
        guard let base = buf.baseAddress, buf.count > 0 else {
            return caretLocation == 0 ? CursorMetrics(line: 1, column: 1, characterCount: 0) : nil
        }
        var state = CursorMetricsScanState()

        while state.byteIndex < buf.count && state.utf16Offset < caretLocation {
            cursorMetricsAdvanceBeforeCaret(
                base: base,
                count: buf.count,
                caretLocation: caretLocation,
                state: &state
            )
        }
        cursorMetricsAdvanceTailAfterCaret(base: base, count: buf.count, state: &state)

        guard caretLocation <= state.utf16Offset else { return nil }
        return CursorMetrics(
            line: state.line,
            column: (caretLocation - state.lineStartOffset) + 1,
            characterCount: state.scalarCount
        )
    }

    static func cursorMetricsAdvanceBeforeCaret(
        base: UnsafePointer<UInt8>,
        count: Int,
        caretLocation: Int,
        state: inout CursorMetricsScanState
    ) {
        let b = base[state.byteIndex]
        if b == 0x0A {
            state.line += 1
            state.utf16Offset += 1
            state.lineStartOffset = state.utf16Offset
            state.scalarCount += 1
            state.byteIndex += 1
            return
        }
        if b == 0x0D {
            let step = cursorMetricsCarriageReturnStep(
                base: base,
                count: count,
                index: state.byteIndex,
                utf16Offset: state.utf16Offset,
                caretLocation: caretLocation
            )
            state.line += 1
            state.utf16Offset += step
            state.scalarCount += step
            state.byteIndex += step
            state.lineStartOffset = state.utf16Offset
            return
        }
        let adv = UTF16LineBreakScanner.lineBreakUTF8ScalarStep(b)
        state.utf16Offset += adv.utf16Units
        state.scalarCount += 1
        state.byteIndex += adv.bytes
    }

    static func cursorMetricsCarriageReturnStep(
        base: UnsafePointer<UInt8>,
        count: Int,
        index: Int,
        utf16Offset: Int,
        caretLocation: Int
    ) -> Int {
        (index + 1 < count && base[index + 1] == 0x0A && utf16Offset + 1 < caretLocation) ? 2 : 1
    }

    static func cursorMetricsAdvanceTailAfterCaret(
        base: UnsafePointer<UInt8>,
        count: Int,
        state: inout CursorMetricsScanState
    ) {
        while state.byteIndex < count {
            let adv = UTF16LineBreakScanner.lineBreakUTF8ScalarStep(base[state.byteIndex])
            state.utf16Offset += adv.utf16Units
            state.scalarCount += 1
            state.byteIndex += adv.bytes
        }
    }

    static func cursorMetricsComputeUTF16Fallback(
        in text: String,
        caretLocation: Int
    ) throws -> CursorMetrics {
        let utf16 = text.utf16
        guard caretLocation <= utf16.count else {
            throw DomainError.invalidTextRange(TextRange(location: caretLocation, length: 0))
        }

        var line = 1
        var lineStartOffset = 0
        var offset = 0
        var index = utf16.startIndex
        while index < utf16.endIndex && offset < caretLocation {
            cursorMetricsStepUTF16Fallback(
                utf16: utf16,
                caretLocation: caretLocation,
                index: &index,
                offset: &offset,
                line: &line,
                lineStartOffset: &lineStartOffset
            )
        }

        return CursorMetrics(
            line: line,
            column: (caretLocation - lineStartOffset) + 1,
            characterCount: text.unicodeScalars.count
        )
    }

    static func cursorMetricsStepUTF16Fallback(
        utf16: String.UTF16View,
        caretLocation: Int,
        index: inout String.UTF16View.Index,
        offset: inout Int,
        line: inout Int,
        lineStartOffset: inout Int
    ) {
        let codeUnit = utf16[index]
        let next = utf16.index(after: index)
        if codeUnit == 0x0A {
            line += 1
            index = next
            offset += 1
            lineStartOffset = offset
        } else if codeUnit == 0x0D {
            line += 1
            let isJoinedCRLF = next < utf16.endIndex && utf16[next] == 0x0A && offset + 1 < caretLocation
            index = isJoinedCRLF ? utf16.index(after: next) : next
            offset += isJoinedCRLF ? 2 : 1
            lineStartOffset = offset
        } else {
            index = next
            offset += 1
        }
    }
}
