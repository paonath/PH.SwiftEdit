import Foundation

/// GFM construct classes the editor colors or styles (`BC-004`). Core never returns colors so prose stays `21:1` and `SwiftEditCore` stays free of `AppKit` (`AR-002`, `UI-002`).
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

    /// `true` for the four YAML kinds emitted by `YAMLSyntaxHighlighter`.
    public var isYAML: Bool {
        switch self {
        case .yamlKey, .yamlValue, .yamlPunctuation, .yamlComment: return true
        default: return false
        }
    }
}

/// A construct kind with its UTF-16 range in the document.
public struct MarkdownSyntaxSpan: Equatable, Sendable {
    public let kind: MarkdownSyntaxKind
    public let range: TextRange
    public init(kind: MarkdownSyntaxKind, range: TextRange) { self.kind = kind; self.range = range }
}

/// Zero-regex UTF-16 line table with fenced-code intervals, built once per revision and shared by the highlighter, the authoring engines, and the preview projector.
///
/// Fence membership is a binary search over closed intervals (`O(log F)`), so per-fragment queries never rescan the document.
public struct MarkdownLineIndex: Sendable {
    public static let maxLineUTF16 = 4096
    public let units: [UInt16]
    /// Start offset of every line; the final entry is a virtual start at `units.count + 1` bound.
    public let lineStarts: [Int]
    /// Inclusive `(openLine, closeLine)` pairs; an unclosed fence extends to the last line.
    public let fences: [(open: Int, close: Int)]
    /// Lines `0..<frontmatterLineCount` form a line-1 YAML frontmatter block (both delimiters included); `0` when absent.
    /// Computed once per revision (bounded by `YAMLFrontmatterScanner.maxLines`) so per-fragment queries never rescan it.
    public private(set) var frontmatterLineCount: Int = 0

    public init(text: String) {
        if let built = Self.buildFromContiguousUTF8(text) {
            self.units = built.units
            self.lineStarts = built.starts
            self.fences = built.fences
        } else {
            let units = Array(text.utf16)
            let unitCount = units.count
            var starts: [Int] = []
            starts.reserveCapacity(max(16, unitCount / 40))
            var found: [(Int, Int)] = []
            var open: (line: Int, char: UInt16, count: Int)?

            var lineStart = 0
            var lineIndex = 0
            var i = 0
            while i <= unitCount {
                if i == unitCount || units[i] == 0x0A {
                    starts.append(lineStart)
                    let slice = units[lineStart..<i]
                    if let o = open {
                        if Self.isFenceLine(slice, char: o.char, minCount: o.count, closing: true) {
                            found.append((o.line, lineIndex))
                            open = nil
                        }
                    } else if let f = Self.fenceOpening(slice) {
                        open = (lineIndex, f.char, f.count)
                    }
                    lineIndex += 1
                    lineStart = i + 1
                }
                i += 1
            }
            if let o = open { found.append((o.line, starts.count - 1)) }
            self.units = units
            self.lineStarts = starts
            self.fences = found
        }
        self.frontmatterLineCount = YAMLFrontmatterScanner.maskedLineCount(in: self)
    }

    private static func buildFromContiguousUTF8(_ text: String) -> (units: [UInt16], starts: [Int], fences: [(Int, Int)])? {
        text.utf8.withContiguousStorageIfAvailable { utf8Buf -> (units: [UInt16], starts: [Int], fences: [(Int, Int)])? in
            let byteCount = utf8Buf.count
            guard let src = utf8Buf.baseAddress else {
                return ([], [0], [])
            }
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
                var open: (line: Int, char: UInt16, count: Int)?
                var lineStart = 0
                var lineIndex = 0
                var leadingSpaces = 0
                var sawNonSpace = false
                var firstNonSpace: UInt16 = 0
                var u = 0
                var i = 0

                while i < byteCount {
                    let b = src[i]
                    if b < 0x80 {
                        dst[u] = UInt16(b)
                        if b == 0x0A {
                            starts.append(lineStart)
                            if sawNonSpace && leadingSpaces < 4 {
                                if let o = open {
                                    if firstNonSpace == o.char && Self.isFenceLinePtr(dst, from: lineStart, to: u, char: o.char, minCount: o.count) {
                                        found.append((o.line, lineIndex))
                                        open = nil
                                    }
                                } else if (firstNonSpace == 0x60 || firstNonSpace == 0x7E),
                                          let f = Self.fenceOpeningPtr(dst, from: lineStart, to: u) {
                                    open = (lineIndex, f.char, f.count)
                                }
                            }
                            lineIndex += 1
                            lineStart = u + 1
                            leadingSpaces = 0
                            sawNonSpace = false
                            firstNonSpace = 0
                        } else if !sawNonSpace {
                            if b == 0x20 {
                                leadingSpaces += 1
                            } else {
                                sawNonSpace = true
                                firstNonSpace = UInt16(b)
                            }
                        }
                        u += 1
                        i += 1
                    } else if b < 0xE0 {
                        guard b >= 0xC2, i + 1 < byteCount else { malformed = true; initializedCount = u; return }
                        let cp = (UInt16(b & 0x1F) << 6) | UInt16(src[i + 1] & 0x3F)
                        dst[u] = cp
                        if !sawNonSpace { sawNonSpace = true; firstNonSpace = cp }
                        u += 1
                        i += 2
                    } else if b < 0xF0 {
                        guard i + 2 < byteCount else { malformed = true; initializedCount = u; return }
                        let cp = (UInt16(b & 0x0F) << 12) | (UInt16(src[i + 1] & 0x3F) << 6) | UInt16(src[i + 2] & 0x3F)
                        dst[u] = cp
                        if !sawNonSpace { sawNonSpace = true; firstNonSpace = cp }
                        u += 1
                        i += 3
                    } else {
                        guard b <= 0xF4, i + 3 < byteCount else { malformed = true; initializedCount = u; return }
                        let scalar = (UInt32(b & 0x07) << 18) | (UInt32(src[i + 1] & 0x3F) << 12) | (UInt32(src[i + 2] & 0x3F) << 6) | UInt32(src[i + 3] & 0x3F)
                        let adjusted = scalar - 0x10000
                        let high = UInt16(0xD800 + (adjusted >> 10))
                        let low = UInt16(0xDC00 + (adjusted & 0x3FF))
                        dst[u] = high
                        dst[u + 1] = low
                        if !sawNonSpace { sawNonSpace = true; firstNonSpace = high }
                        u += 2
                        i += 4
                    }
                }

                // Flush final line (matches `while i <= unitCount` at `i == unitCount`).
                starts.append(lineStart)
                if sawNonSpace && leadingSpaces < 4 {
                    if let o = open {
                        if firstNonSpace == o.char && Self.isFenceLinePtr(dst, from: lineStart, to: u, char: o.char, minCount: o.count) {
                            found.append((o.line, lineIndex))
                            open = nil
                        }
                    } else if (firstNonSpace == 0x60 || firstNonSpace == 0x7E),
                              let f = Self.fenceOpeningPtr(dst, from: lineStart, to: u) {
                        open = (lineIndex, f.char, f.count)
                    }
                }
                if let o = open { found.append((o.line, starts.count - 1)) }
                initializedCount = u
            }

            if malformed { return nil }
            return (units, starts, found)
        } ?? nil
    }

    private static func fenceOpeningPtr(_ buf: UnsafePointer<UInt16>, from start: Int, to end: Int) -> (char: UInt16, count: Int)? {
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

    private static func isFenceLinePtr(_ buf: UnsafePointer<UInt16>, from start: Int, to end: Int, char: UInt16, minCount: Int) -> Bool {
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

/// Viewport-only GFM tokenizer (`BC-004`, `SEC-012`).
///
/// Only lines intersecting `visibleRange` are scanned, so per-keystroke cost is bounded by the viewport rather than the document. Binary and degraded snapshots, non-Markdown documents, and lines over `4096` UTF-16 units return no spans (`CWE-400`, `DATA-003`). Fenced interiors get only `.codeBlock` spans so `**x**` inside code is never styled.
public enum MarkdownSyntaxHighlighter {

    public static func spans(snapshot: DocumentSnapshot, visibleRange: TextRange, isMarkdownDocument: Bool = true) -> [MarkdownSyntaxSpan] {
        guard isMarkdownDocument, !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText, visibleRange.length > 0 else { return [] }
        return spans(index: MarkdownLineIndex(text: snapshot.text), visibleRange: visibleRange)
    }

    /// Variant reusing a cached `MarkdownLineIndex` (one per `BufferRevision`).
    public static func spans(index: MarkdownLineIndex, visibleRange: TextRange) -> [MarkdownSyntaxSpan] {
        guard visibleRange.length > 0, !index.units.isEmpty else { return [] }
        let first = index.line(containing: visibleRange.location)
        let last = index.line(containing: max(visibleRange.location, visibleRange.upperBound - 1))
        var out: [MarkdownSyntaxSpan] = []
        out.reserveCapacity(max(16, (last - first + 1) * 2))

        // Frontmatter lines are YAML, not GFM: delegate them and start the GFM scan after the closing delimiter.
        let frontmatter = index.frontmatterLineCount
        if first < frontmatter {
            out += YAMLSyntaxHighlighter.spans(index: index, visibleRange: visibleRange, lineLimit: frontmatter)
        }
        let gfmFirst = max(first, frontmatter)
        guard gfmFirst <= last else { return out }

        // Locate initial fence cursor via binary search, then advance monotonically in O(1) amortized.
        let fences = index.fences
        var fenceCursor = 0
        if !fences.isEmpty {
            var lo = 0, hi = fences.count
            while lo < hi {
                let mid = lo + (hi - lo) / 2
                if fences[mid].close < gfmFirst { lo = mid + 1 } else { hi = mid }
            }
            fenceCursor = lo
        }

        for line in gfmFirst...last {
            while fenceCursor < fences.count && fences[fenceCursor].close < line {
                fenceCursor += 1
            }
            let range = index.lineRange(line)
            guard range.length > 0, range.length <= MarkdownLineIndex.maxLineUTF16 else { continue }
            if fenceCursor < fences.count && fences[fenceCursor].open <= line {
                out.append(MarkdownSyntaxSpan(kind: .codeBlock, range: range))
                continue
            }
            scanLine(index.lineSlice(line), base: range.location, into: &out)
        }
        return out
    }

    private static func scanLine(_ line: ArraySlice<UInt16>, base: Int, into out: inout [MarkdownSyntaxSpan]) {
        let start = line.startIndex
        func abs(_ i: Int) -> Int { base + (i - start) }
        func add(_ kind: MarkdownSyntaxKind, _ from: Int, _ to: Int) {
            out.append(MarkdownSyntaxSpan(kind: kind, range: TextRange(location: abs(from), length: to - from)))
        }
        var idx = start
        while idx < line.endIndex, line[idx] == 0x20 { idx += 1 }
        guard idx < line.endIndex else { return }
        let first = line[idx]

        if isThematicBreak(line[idx...]) { add(.thematicBreak, start, line.endIndex); return }
        if first == 0x23 {
            var level = 0
            var j = idx
            while j < line.endIndex, line[j] == 0x23 { level += 1; j += 1 }
            if level <= 6, j == line.endIndex || line[j] == 0x20 { add(.heading(level: level), start, line.endIndex) }
        } else if first == 0x3E {
            add(.blockquote, start, line.endIndex)
        } else if first == 0x7C, line[(idx + 1)...].contains(0x7C) {
            add(.tableRow, start, line.endIndex)
        } else if first == 0x2D || first == 0x2A || first == 0x2B {
            if let item = MarkdownListGrammar.parseListLine(line), case .bullet(_, let state?) = item.kind {
                let box = start + item.indent + 2
                add(.task(checked: state != 0x20), box, box + 3)
            }
        }
        scanInline(line, add: add)
    }

    private static func isThematicBreak(_ line: ArraySlice<UInt16>) -> Bool {
        var marker: UInt16 = 0
        var count = 0
        for u in line {
            if u == 0x20 { continue }
            if marker == 0 { guard u == 0x2D || u == 0x2A || u == 0x5F else { return false }; marker = u }
            guard u == marker else { return false }
            count += 1
        }
        return count >= 3
    }

    /// Strictly linear `O(L)` inline scanner: memoizes failed closer lookups per delimiter so unmatched delimiters never re-scan to EOL.
    private static func scanInline(_ line: ArraySlice<UInt16>, add: (MarkdownSyntaxKind, Int, Int) -> Void) {
        var i = line.startIndex
        let end = line.endIndex
        var noBacktick = false
        var noDoubleStar = false
        var noDoubleTilde = false
        var noStar = false
        var noUnderscore = false
        var noCloseAngle = false
        var noLinkCloseBracket = false
        var noLinkCloseParen = false
        var failedCloseBracketIndex = -1

        func find(_ unit: UInt16, from: Int) -> Int? {
            var k = from
            while k < end { if line[k] == unit { return k }; k += 1 }
            return nil
        }
        func findPair(_ unit: UInt16, from: Int) -> Int? {
            var k = from
            while k + 1 < end { if line[k] == unit, line[k + 1] == unit { return k }; k += 1 }
            return nil
        }
        func linkEndLinear(openBracket: Int) -> Int? {
            guard !noLinkCloseBracket && !noLinkCloseParen else { return nil }
            // Any '[' before a previously failed ']' (not followed by '(') hits the same non-link ']': skip in O(1).
            if openBracket < failedCloseBracketIndex { return nil }
            var k = openBracket + 1
            while k < end, line[k] != 0x5D { k += 1 }
            guard k < end else {
                noLinkCloseBracket = true
                return nil
            }
            guard k + 1 < end, line[k + 1] == 0x28 else {
                failedCloseBracketIndex = k
                return nil
            }
            var m = k + 2
            while m < end, line[m] != 0x29 { m += 1 }
            if m < end { return m }
            noLinkCloseParen = true
            return nil
        }

        while i < end {
            let c = line[i]
            switch c {
            case 0x60:
                if !noBacktick {
                    if let close = find(0x60, from: i + 1) {
                        if close > i + 1 { add(.inlineCode, i, close + 1); i = close + 1; continue }
                    } else {
                        noBacktick = true
                    }
                }
            case 0x21 where i + 1 < end && line[i + 1] == 0x5B:
                if let r = linkEndLinear(openBracket: i + 1) { add(.image, i, r + 1); i = r + 1; continue }
            case 0x5B:
                if let r = linkEndLinear(openBracket: i) { add(.link, i, r + 1); i = r + 1; continue }
            case 0x2A where i + 1 < end && line[i + 1] == 0x2A:
                if !noDoubleStar {
                    if let close = findPair(0x2A, from: i + 2) {
                        if close > i + 2 { add(.bold, i, close + 2); i = close + 2; continue }
                    } else {
                        noDoubleStar = true
                    }
                }
            case 0x7E where i + 1 < end && line[i + 1] == 0x7E:
                if !noDoubleTilde {
                    if let close = findPair(0x7E, from: i + 2) {
                        if close > i + 2 { add(.strikethrough, i, close + 2); i = close + 2; continue }
                    } else {
                        noDoubleTilde = true
                    }
                }
            case 0x2A:
                if !noStar, i + 1 < end, line[i + 1] != 0x20 {
                    if let close = find(0x2A, from: i + 1) {
                        if close > i + 1, line[close - 1] != 0x20 { add(.italic, i, close + 1); i = close + 1; continue }
                    } else {
                        noStar = true
                    }
                }
            case 0x5F:
                if !noUnderscore, i + 1 < end, line[i + 1] != 0x20 {
                    if let close = find(0x5F, from: i + 1) {
                        if close > i + 1, line[close - 1] != 0x20 { add(.italic, i, close + 1); i = close + 1; continue }
                    } else {
                        noUnderscore = true
                    }
                }
            case 0x3C:
                if !noCloseAngle, i + 1 < end, (line[i + 1] >= 0x41 && line[i + 1] <= 0x5A) || (line[i + 1] >= 0x61 && line[i + 1] <= 0x7A) || line[i + 1] == 0x2F {
                    if let close = find(0x3E, from: i + 1) { add(.inlineHTML, i, close + 1); i = close + 1; continue }
                    noCloseAngle = true
                }
            default: break
            }
            i += 1
        }
    }

    /// Returns the index of the closing `)` of `[text](dest)` starting at `openBracket`, or `nil`.
    static func linkEnd(_ line: ArraySlice<UInt16>, openBracket: Int) -> Int? {
        var k = openBracket + 1
        while k < line.endIndex, line[k] != 0x5D { k += 1 }
        guard k + 1 < line.endIndex, line[k + 1] == 0x28 else { return nil }
        var m = k + 2
        while m < line.endIndex, line[m] != 0x29 { m += 1 }
        return m < line.endIndex ? m : nil
    }
}
