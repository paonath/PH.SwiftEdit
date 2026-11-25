import Foundation

/// GFM, YAML, and Log construct classes styled by the editor (`BC-004`). Core never returns colors so prose stays `21:1` and `SwiftEditCore` stays free of `AppKit` (`AR-002`, `UI-002`).
public enum MarkdownSyntaxKind: Equatable, Sendable {
    case heading(level: Int)
    case bold, italic, strikethrough, inlineCode, link, image, inlineHTML
    case codeBlock
    case task(checked: Bool)
    case blockquote, tableRow, thematicBreak
    /// YAML key (grey, lighter weight), value (canvas text), structural punctuation and comment (`UI-002`, `REQ-010`).
    case yamlKey, yamlValue, yamlPunctuation, yamlComment
    /// Log tokens (`.log` tabs): severity word, timestamp, GUID, quoted string, exception name or stack frame.
    case logLevel(LogLevel), logTimestamp, logGuid, logString, logException
    /// JSON tokens (`.json`/`.jsonl` tabs): object key, string value, numeric literal, boolean/null literal, structural punctuation (`REQ-010`).
    case jsonKey, jsonString, jsonNumber, jsonLiteral, jsonPunctuation
    /// HTML tokens (`.html`/`.htm` tabs): tag name/brackets, attribute name, attribute string, comment, entity, doctype.
    case htmlTag, htmlAttribute, htmlString, htmlComment, htmlEntity, htmlDoctype

    /// `true` for the four YAML kinds emitted by `YAMLSyntaxHighlighter`.
    public var isYAML: Bool {
        switch self {
        case .yamlKey, .yamlValue, .yamlPunctuation, .yamlComment: return true
        default: return false
        }
    }
}

/// A construct kind with its UTF-16 range in the document (`BC-004`).
public struct MarkdownSyntaxSpan: Equatable, Sendable {
    public let kind: MarkdownSyntaxKind
    public let range: TextRange
    public init(kind: MarkdownSyntaxKind, range: TextRange) {
        self.kind = kind
        self.range = range
    }
}

/// Acyclic leaf UTF-16 line table with fenced-code intervals and YAML frontmatter masking, built once per revision and shared across highlighters, linters, authoring engines, and preview projectors (`AR-006`, `BC-001`, `REQ-006`).
///
/// Fence membership is a binary search over closed intervals (`O(log F)`), so per-fragment queries never rescan the document.
public struct MarkdownLineIndex: Sendable {
    public static let maxLineUTF16 = 4096
    public static let maxFrontmatterLines = 200
    public let units: [UInt16]
    /// Start offset of every line; the final entry is a virtual start at `units.count + 1` bound.
    public let lineStarts: [Int]
    /// Inclusive `(openLine, closeLine)` pairs; an unclosed fence extends to the last line.
    public let fences: [(open: Int, close: Int)]
    /// Lines `0..<frontmatterLineCount` form a line-1 YAML frontmatter block (both delimiters included); `0` when absent.
    public private(set) var frontmatterLineCount: Int = 0

    public init(text: String) {
        let built = Self.lineIndexBuildFromContiguousUTF8(text) ?? Self.lineIndexBuildFromUTF16Fallback(text)
        self.units = built.units
        self.lineStarts = built.starts
        self.fences = built.fences
        self.frontmatterLineCount = Self.lineIndexScanFrontmatterLineCount(units: built.units, starts: built.starts)
    }

    public var lineCount: Int { lineStarts.count }

    /// UTF-16 range of `line` excluding its terminating newline.
    public func lineRange(_ line: Int) -> TextRange {
        let start = lineStarts[line]
        let end = line + 1 < lineStarts.count ? lineStarts[line + 1] - 1 : units.count
        return TextRange(location: start, length: end - start)
    }

    public func lineSlice(_ line: Int) -> ArraySlice<UInt16> { Self.slice(units, lineStarts, line) }

    /// Index of the line containing `offset` (clamped).
    public func line(containing offset: Int) -> Int {
        var lo = 0, hi = lineStarts.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if lineStarts[mid] <= offset { lo = mid } else { hi = mid - 1 }
        }
        return lo
    }

    /// `true` when `line` is a fence delimiter or lies inside a fenced block.
    public func isFenced(line: Int) -> Bool {
        var lo = 0, hi = fences.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            let f = fences[mid]
            if line < f.open { hi = mid - 1 } else if line > f.close { lo = mid + 1 } else { return true }
        }
        return false
    }

    static func slice(_ units: [UInt16], _ starts: [Int], _ line: Int) -> ArraySlice<UInt16> {
        let start = starts[line]
        let end = line + 1 < starts.count ? starts[line + 1] - 1 : units.count
        return units[start..<max(start, end)]
    }

    static func fenceOpening(_ line: ArraySlice<UInt16>) -> (char: UInt16, count: Int)? {
        var idx = line.startIndex
        var spaces = 0
        while idx < line.endIndex, line[idx] == 0x20, spaces < 4 { idx += 1; spaces += 1 }
        guard spaces < 4, idx < line.endIndex, line[idx] == 0x60 || line[idx] == 0x7E else { return nil }
        let ch = line[idx]
        var count = 0
        while idx < line.endIndex, line[idx] == ch { idx += 1; count += 1 }
        guard count >= 3 else { return nil }
        if ch == 0x60, line[idx...].contains(0x60) { return nil }
        return (ch, count)
    }

    static func isFenceLine(_ line: ArraySlice<UInt16>, char: UInt16, minCount: Int, closing: Bool) -> Bool {
        var idx = line.startIndex
        var spaces = 0
        while idx < line.endIndex, line[idx] == 0x20, spaces < 4 { idx += 1; spaces += 1 }
        guard spaces < 4 else { return false }
        var count = 0
        while idx < line.endIndex, line[idx] == char { idx += 1; count += 1 }
        guard count >= minCount else { return false }
        while idx < line.endIndex { if line[idx] != 0x20 { return false }; idx += 1 }
        return true
    }
}

extension MarkdownLineIndex {
    private struct LineIndexUTF8ScanState {
        var open: (line: Int, char: UInt16, count: Int)?
        var lineStart: Int = 0
        var lineIndex: Int = 0
        var leadingSpaces: Int = 0
        var sawNonSpace: Bool = false
        var firstNonSpace: UInt16 = 0
        var utf16Pos: Int = 0
        var bytePos: Int = 0
    }

    private static func lineIndexBuildFromUTF16Fallback(_ text: String) -> (units: [UInt16], starts: [Int], fences: [(Int, Int)]) {
        let units = Array(text.utf16)
        let unitCount = units.count
        var starts: [Int] = []
        starts.reserveCapacity(max(16, unitCount / 40))
        var found: [(Int, Int)] = []
        var open: (line: Int, char: UInt16, count: Int)?
        var lineStart = 0
        var lineIndex = 0

        for i in 0...unitCount where i == unitCount || units[i] == 0x0A {
            starts.append(lineStart)
            lineIndexAdvanceUTF16FenceState(units[lineStart..<i], lineIndex: lineIndex, open: &open, fences: &found)
            lineIndex += 1
            lineStart = i + 1
        }
        if let o = open { found.append((o.line, starts.count - 1)) }
        return (units, starts, found)
    }

    private static func lineIndexAdvanceUTF16FenceState(
        _ slice: ArraySlice<UInt16>,
        lineIndex: Int,
        open: inout (line: Int, char: UInt16, count: Int)?,
        fences: inout [(Int, Int)]
    ) {
        if let o = open {
            if isFenceLine(slice, char: o.char, minCount: o.count, closing: true) {
                fences.append((o.line, lineIndex))
                open = nil
            }
        } else if let f = fenceOpening(slice) {
            open = (lineIndex, f.char, f.count)
        }
    }

    private static func lineIndexScanFrontmatterLineCount(units: [UInt16], starts: [Int]) -> Int {
        guard starts.count > 1, lineIndexIsFrontmatterDelimiter(slice(units, starts, 0), opening: true) else { return 0 }
        let limit = min(starts.count - 1, maxFrontmatterLines)
        guard limit >= 1 else { return 0 }
        for line in 1...limit where lineIndexIsFrontmatterDelimiter(slice(units, starts, line), opening: false) {
            return line + 1
        }
        return 0
    }

    private static func lineIndexIsFrontmatterDelimiter(_ lineSlice: ArraySlice<UInt16>, opening: Bool) -> Bool {
        var end = lineSlice.endIndex
        while end > lineSlice.startIndex {
            let prev = end - 1
            if lineSlice[prev] == 0x20 || lineSlice[prev] == 0x0D {
                end = prev
            } else {
                break
            }
        }
        guard end - lineSlice.startIndex == 3 else { return false }
        let s = lineSlice.startIndex
        if lineSlice[s] == 0x2D && lineSlice[s + 1] == 0x2D && lineSlice[s + 2] == 0x2D {
            return true
        }
        return !opening && lineSlice[s] == 0x2E && lineSlice[s + 1] == 0x2E && lineSlice[s + 2] == 0x2E
    }

    private static func lineIndexBuildFromContiguousUTF8(_ text: String) -> (units: [UInt16], starts: [Int], fences: [(Int, Int)])? {
        text.utf8.withContiguousStorageIfAvailable { utf8Buf -> (units: [UInt16], starts: [Int], fences: [(Int, Int)])? in
            let byteCount = utf8Buf.count
            guard let src = utf8Buf.baseAddress else { return ([], [0], []) }
            var starts: [Int] = []
            starts.reserveCapacity(max(16, byteCount / 40))
            var found: [(Int, Int)] = []
            var malformed = false

            let units = Array<UInt16>(unsafeUninitializedCapacity: byteCount) { dstBuf, initializedCount in
                guard let dst = dstBuf.baseAddress else {
                    initializedCount = 0
                    starts.append(0)
                    return
                }
                if let count = lineIndexDecodeUTF8Stream(src: src, byteCount: byteCount, dst: dst, starts: &starts, fences: &found) {
                    initializedCount = count
                } else {
                    malformed = true
                    initializedCount = 0
                }
            }
            return malformed ? nil : (units, starts, found)
        } ?? nil
    }

    private static func lineIndexDecodeUTF8Stream(
        src: UnsafePointer<UInt8>,
        byteCount: Int,
        dst: UnsafeMutablePointer<UInt16>,
        starts: inout [Int],
        fences: inout [(Int, Int)]
    ) -> Int? {
        var state = LineIndexUTF8ScanState()
        while state.bytePos < byteCount {
            let byte = src[state.bytePos]
            if byte < 0x80 {
                lineIndexConsumeASCIIByte(byte, dst: dst, state: &state, starts: &starts, fences: &fences)
            } else if lineIndexConsumeMultibyteUTF8(firstByte: byte, src: src, byteCount: byteCount, dst: dst, state: &state) == false {
                return nil
            }
        }
        starts.append(state.lineStart)
        lineIndexUpdatePtrFenceState(dst: dst, lineEnd: state.utf16Pos, state: &state, fences: &fences)
        if let o = state.open { fences.append((o.line, starts.count - 1)) }
        return state.utf16Pos
    }

    private static func lineIndexConsumeASCIIByte(
        _ byte: UInt8,
        dst: UnsafeMutablePointer<UInt16>,
        state: inout LineIndexUTF8ScanState,
        starts: inout [Int],
        fences: inout [(Int, Int)]
    ) {
        dst[state.utf16Pos] = UInt16(byte)
        if byte == 0x0A {
            starts.append(state.lineStart)
            lineIndexUpdatePtrFenceState(dst: dst, lineEnd: state.utf16Pos, state: &state, fences: &fences)
            state.lineIndex += 1
            state.lineStart = state.utf16Pos + 1
            state.leadingSpaces = 0
            state.sawNonSpace = false
            state.firstNonSpace = 0
        } else if !state.sawNonSpace {
            if byte == 0x20 {
                state.leadingSpaces += 1
            } else {
                state.sawNonSpace = true
                state.firstNonSpace = UInt16(byte)
            }
        }
        state.utf16Pos += 1
        state.bytePos += 1
    }

    private static func lineIndexConsumeMultibyteUTF8(
        firstByte b: UInt8,
        src: UnsafePointer<UInt8>,
        byteCount: Int,
        dst: UnsafeMutablePointer<UInt16>,
        state: inout LineIndexUTF8ScanState
    ) -> Bool {
        let i = state.bytePos
        if b < 0xE0 {
            guard b >= 0xC2, i + 1 < byteCount else { return false }
            let cp = (UInt16(b & 0x1F) << 6) | UInt16(src[i + 1] & 0x3F)
            lineIndexRecordDecodedUnit(cp, byteAdvance: 2, dst: dst, state: &state)
            return true
        }
        if b < 0xF0 {
            guard i + 2 < byteCount else { return false }
            let cp = (UInt16(b & 0x0F) << 12) | (UInt16(src[i + 1] & 0x3F) << 6) | UInt16(src[i + 2] & 0x3F)
            lineIndexRecordDecodedUnit(cp, byteAdvance: 3, dst: dst, state: &state)
            return true
        }
        guard b <= 0xF4, i + 3 < byteCount else { return false }
        let scalar = (UInt32(b & 0x07) << 18) | (UInt32(src[i + 1] & 0x3F) << 12) | (UInt32(src[i + 2] & 0x3F) << 6) | UInt32(src[i + 3] & 0x3F)
        let adjusted = scalar - 0x10000
        let high = UInt16(0xD800 + (adjusted >> 10))
        dst[state.utf16Pos] = high
        dst[state.utf16Pos + 1] = UInt16(0xDC00 + (adjusted & 0x3FF))
        if !state.sawNonSpace {
            state.sawNonSpace = true
            state.firstNonSpace = high
        }
        state.utf16Pos += 2
        state.bytePos += 4
        return true
    }

    @inline(__always)
    private static func lineIndexRecordDecodedUnit(
        _ unit: UInt16,
        byteAdvance: Int,
        dst: UnsafeMutablePointer<UInt16>,
        state: inout LineIndexUTF8ScanState
    ) {
        dst[state.utf16Pos] = unit
        if !state.sawNonSpace {
            state.sawNonSpace = true
            state.firstNonSpace = unit
        }
        state.utf16Pos += 1
        state.bytePos += byteAdvance
    }

    private static func lineIndexUpdatePtrFenceState(
        dst: UnsafePointer<UInt16>,
        lineEnd: Int,
        state: inout LineIndexUTF8ScanState,
        fences: inout [(Int, Int)]
    ) {
        guard state.sawNonSpace, state.leadingSpaces < 4 else { return }
        if let o = state.open {
            if state.firstNonSpace == o.char,
               lineIndexIsFenceLinePtr(dst, from: state.lineStart, to: lineEnd, char: o.char, minCount: o.count) {
                fences.append((o.line, state.lineIndex))
                state.open = nil
            }
            return
        }
        guard state.firstNonSpace == 0x60 || state.firstNonSpace == 0x7E else { return }
        if let f = lineIndexFenceOpeningPtr(dst, from: state.lineStart, to: lineEnd) {
            state.open = (state.lineIndex, f.char, f.count)
        }
    }

    private static func lineIndexFenceOpeningPtr(_ buf: UnsafePointer<UInt16>, from start: Int, to end: Int) -> (char: UInt16, count: Int)? {
        var idx = start
        var spaces = 0
        while idx < end, buf[idx] == 0x20, spaces < 4 { idx += 1; spaces += 1 }
        guard spaces < 4, idx < end, buf[idx] == 0x60 || buf[idx] == 0x7E else { return nil }
        let ch = buf[idx]
        var count = 0
        while idx < end, buf[idx] == ch { idx += 1; count += 1 }
        guard count >= 3 else { return nil }
        if ch == 0x60 {
            var scan = idx
            while scan < end {
                if buf[scan] == 0x60 { return nil }
                scan += 1
            }
        }
        return (ch, count)
    }

    private static func lineIndexIsFenceLinePtr(_ buf: UnsafePointer<UInt16>, from start: Int, to end: Int, char: UInt16, minCount: Int) -> Bool {
        var idx = start
        var spaces = 0
        while idx < end, buf[idx] == 0x20, spaces < 4 { idx += 1; spaces += 1 }
        guard spaces < 4 else { return false }
        var count = 0
        while idx < end, buf[idx] == char { idx += 1; count += 1 }
        guard count >= minCount else { return false }
        while idx < end {
            if buf[idx] != 0x20 { return false }
            idx += 1
        }
        return true
    }
}
