import Foundation

/// Viewport-only zero-regex JSON syntax highlighter for `.json` and `.jsonl` tabs (`REQ-010`, `BC-004`, `UI-012`, `CWE-1333`).
///
/// Reuses the per-revision `MarkdownLineIndex` and skips lines exceeding `maxLineUTF16` (`4096`) to guarantee `< 16 ms` keystroke latency (`CWE-400`).
public enum JSONSyntaxHighlighter {
    public static let maxLineUTF16 = 4096

    public static func spans(index: MarkdownLineIndex, visibleRange: TextRange) -> [MarkdownSyntaxSpan] {
        guard visibleRange.length > 0, !index.units.isEmpty else { return [] }
        let first = index.line(containing: visibleRange.location)
        let last = index.line(containing: max(visibleRange.location, visibleRange.upperBound - 1))
        guard first <= last else { return [] }
        var out: [MarkdownSyntaxSpan] = []
        out.reserveCapacity((last - first + 1) * 4)
        for line in first...last {
            let lineRange = index.lineRange(line)
            guard lineRange.length > 0, lineRange.length <= maxLineUTF16 else { continue }
            tokenizeLine(index.lineSlice(line), baseOffset: lineRange.location, into: &out)
        }
        return out
    }

    private static func tokenizeLine(_ slice: ArraySlice<UInt16>, baseOffset: Int, into out: inout [MarkdownSyntaxSpan]) {
        var idx = slice.startIndex
        let end = slice.endIndex
        while idx < end {
            let u = slice[idx]
            if u == 0x20 || u == 0x09 {
                idx += 1
            } else if u == 0x22 { // '"'
                idx = consumeQuotedToken(slice, from: idx, baseOffset: baseOffset, into: &out)
            } else if isPunctuation(u) {
                out.append(MarkdownSyntaxSpan(kind: .jsonPunctuation, range: TextRange(location: baseOffset + (idx - slice.startIndex), length: 1)))
                idx += 1
            } else if u == 0x2D || (u >= 0x30 && u <= 0x39) {
                idx = consumeNumberToken(slice, from: idx, baseOffset: baseOffset, into: &out)
            } else if (u >= 0x61 && u <= 0x7A) || (u >= 0x41 && u <= 0x5A) {
                idx = consumeKeywordToken(slice, from: idx, baseOffset: baseOffset, into: &out)
            } else {
                idx += 1
            }
        }
    }

    private static func isPunctuation(_ u: UInt16) -> Bool {
        u == 0x7B || u == 0x7D || u == 0x5B || u == 0x5D || u == 0x3A || u == 0x2C
    }

    private static func consumeQuotedToken(
        _ slice: ArraySlice<UInt16>,
        from start: Int,
        baseOffset: Int,
        into out: inout [MarkdownSyntaxSpan]
    ) -> Int {
        var i = start + 1
        let end = slice.endIndex
        while i < end {
            if slice[i] == 0x5C { // '\'
                i = min(end, i + 2)
                continue
            }
            if slice[i] == 0x22 {
                i += 1
                break
            }
            i += 1
        }
        var probe = i
        while probe < end, slice[probe] == 0x20 || slice[probe] == 0x09 { probe += 1 }
        let kind: MarkdownSyntaxKind = (probe < end && slice[probe] == 0x3A) ? .jsonKey : .jsonString
        out.append(MarkdownSyntaxSpan(
            kind: kind,
            range: TextRange(location: baseOffset + (start - slice.startIndex), length: i - start)
        ))
        return i
    }

    private static func consumeNumberToken(
        _ slice: ArraySlice<UInt16>,
        from start: Int,
        baseOffset: Int,
        into out: inout [MarkdownSyntaxSpan]
    ) -> Int {
        var i = start + 1
        let end = slice.endIndex
        while i < end, isNumberContinuation(slice[i]) { i += 1 }
        out.append(MarkdownSyntaxSpan(
            kind: .jsonNumber,
            range: TextRange(location: baseOffset + (start - slice.startIndex), length: i - start)
        ))
        return i
    }

    private static func isNumberContinuation(_ u: UInt16) -> Bool {
        (u >= 0x30 && u <= 0x39) || u == 0x2E || u == 0x65 || u == 0x45 || u == 0x2B || u == 0x2D
    }

    private static func consumeKeywordToken(
        _ slice: ArraySlice<UInt16>,
        from start: Int,
        baseOffset: Int,
        into out: inout [MarkdownSyntaxSpan]
    ) -> Int {
        var i = start
        let end = slice.endIndex
        while i < end, (slice[i] >= 0x61 && slice[i] <= 0x7A) || (slice[i] >= 0x41 && slice[i] <= 0x5A) {
            i += 1
        }
        let word = String(decoding: slice[start..<i], as: UTF16.self)
        if word == "true" || word == "false" || word == "null" {
            out.append(MarkdownSyntaxSpan(
                kind: .jsonLiteral,
                range: TextRange(location: baseOffset + (start - slice.startIndex), length: i - start)
            ))
        }
        return i
    }
}
