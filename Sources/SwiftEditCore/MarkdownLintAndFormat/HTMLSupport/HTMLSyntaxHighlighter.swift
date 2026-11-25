import Foundation

/// Zero-regex, viewport-only UTF-16 HTML syntax highlighter (`.html`/`.htm`) (`AR-002`, `BC-004`, `SEC-012`).
///
/// Scans only lines intersecting `visibleRange`, skips lines longer than `MarkdownLineIndex.maxLineUTF16` (`4096`),
/// and emits semantic spans for `<!DOCTYPE ...>`, `<!-- comments -->`, `<tags>`, attribute names, quoted strings, and `&entities;`.
public enum HTMLSyntaxHighlighter {
    private static let lt: UInt16 = 0x3C
    private static let gt: UInt16 = 0x3E
    private static let slash: UInt16 = 0x2F
    private static let bang: UInt16 = 0x21
    private static let dash: UInt16 = 0x2D
    private static let eq: UInt16 = 0x3D
    private static let dquote: UInt16 = 0x22
    private static let squote: UInt16 = 0x27
    private static let amp: UInt16 = 0x26
    private static let semi: UInt16 = 0x3B
    private static let space: UInt16 = 0x20
    private static let tab: UInt16 = 0x09

    /// Emits HTML syntax spans for lines intersecting `visibleRange`.
    public static func spans(index: MarkdownLineIndex, visibleRange: TextRange) -> [MarkdownSyntaxSpan] {
        let total = index.units.count
        guard total > 0, visibleRange.length > 0, index.lineCount > 0 else { return [] }
        let clampedStart = max(0, min(visibleRange.location, total - 1))
        let clampedEnd = max(clampedStart, min(visibleRange.location + visibleRange.length - 1, total - 1))
        let firstLine = index.line(containing: clampedStart)
        let lastLine = index.line(containing: clampedEnd)

        var out: [MarkdownSyntaxSpan] = []
        for lineIdx in firstLine...lastLine {
            let lineRange = index.lineRange(lineIdx)
            guard lineRange.length > 0, lineRange.length <= MarkdownLineIndex.maxLineUTF16 else { continue }
            scanLine(units: index.units, start: lineRange.location, end: lineRange.location + lineRange.length, into: &out)
        }
        return out
    }

    private static func scanLine(units: [UInt16], start: Int, end: Int, into out: inout [MarkdownSyntaxSpan]) {
        var i = start
        while i < end {
            let ch = units[i]
            if ch == lt {
                i = scanAngleConstruct(units: units, from: i, end: end, into: &out)
            } else if ch == amp {
                i = scanEntity(units: units, from: i, end: end, into: &out)
            } else {
                i += 1
            }
        }
    }

    private static func scanAngleConstruct(units: [UInt16], from start: Int, end: Int, into out: inout [MarkdownSyntaxSpan]) -> Int {
        // HTML comment `<!-- ... -->`
        if start + 3 < end, units[start + 1] == bang, units[start + 2] == dash, units[start + 3] == dash {
            var k = start + 4
            while k + 2 < end {
                if units[k] == dash, units[k + 1] == dash, units[k + 2] == gt {
                    let close = k + 3
                    out.append(MarkdownSyntaxSpan(kind: .htmlComment, range: TextRange(location: start, length: close - start)))
                    return close
                }
                k += 1
            }
            out.append(MarkdownSyntaxSpan(kind: .htmlComment, range: TextRange(location: start, length: end - start)))
            return end
        }
        // `<!DOCTYPE ...>` or declaration `<!...>`
        if start + 1 < end, units[start + 1] == bang {
            var k = start + 2
            while k < end, units[k] != gt { k += 1 }
            let close = min(end, k + 1)
            out.append(MarkdownSyntaxSpan(kind: .htmlDoctype, range: TextRange(location: start, length: close - start)))
            return close
        }
        return scanTagAndAttributes(units: units, from: start, end: end, into: &out)
    }

    private static func scanTagAndAttributes(units: [UInt16], from start: Int, end: Int, into out: inout [MarkdownSyntaxSpan]) -> Int {
        var i = start + 1
        if i < end, units[i] == slash { i += 1 }
        let nameStart = i
        while i < end, isNameChar(units[i]) { i += 1 }
        guard i > nameStart else { return start + 1 }
        out.append(MarkdownSyntaxSpan(kind: .htmlTag, range: TextRange(location: start, length: i - start)))

        while i < end {
            skipWhitespace(units: units, cursor: &i, end: end)
            guard i < end else { break }
            if units[i] == gt {
                out.append(MarkdownSyntaxSpan(kind: .htmlTag, range: TextRange(location: i, length: 1)))
                return i + 1
            }
            if units[i] == slash, i + 1 < end, units[i + 1] == gt {
                out.append(MarkdownSyntaxSpan(kind: .htmlTag, range: TextRange(location: i, length: 2)))
                return i + 2
            }
            i = scanAttribute(units: units, from: i, end: end, into: &out)
        }
        return i
    }

    private static func scanAttribute(units: [UInt16], from start: Int, end: Int, into out: inout [MarkdownSyntaxSpan]) -> Int {
        var i = start
        while i < end, isNameChar(units[i]) { i += 1 }
        guard i > start else { return start + 1 }
        out.append(MarkdownSyntaxSpan(kind: .htmlAttribute, range: TextRange(location: start, length: i - start)))
        skipWhitespace(units: units, cursor: &i, end: end)
        guard i < end, units[i] == eq else { return i }
        i += 1
        skipWhitespace(units: units, cursor: &i, end: end)
        guard i < end else { return i }
        if units[i] == dquote || units[i] == squote {
            let quote = units[i]
            let valStart = i
            i += 1
            while i < end, units[i] != quote { i += 1 }
            let valEnd = i < end ? i + 1 : end
            out.append(MarkdownSyntaxSpan(kind: .htmlString, range: TextRange(location: valStart, length: valEnd - valStart)))
            return valEnd
        }
        let bareStart = i
        while i < end, units[i] != space, units[i] != tab, units[i] != gt { i += 1 }
        if i > bareStart {
            out.append(MarkdownSyntaxSpan(kind: .htmlString, range: TextRange(location: bareStart, length: i - bareStart)))
        }
        return i
    }

    private static func scanEntity(units: [UInt16], from start: Int, end: Int, into out: inout [MarkdownSyntaxSpan]) -> Int {
        var k = start + 1
        let maxEntityEnd = min(end, start + 12)
        while k < maxEntityEnd, units[k] != semi, isEntityChar(units[k]) { k += 1 }
        if k > start + 1, k < maxEntityEnd, units[k] == semi {
            let close = k + 1
            out.append(MarkdownSyntaxSpan(kind: .htmlEntity, range: TextRange(location: start, length: close - start)))
            return close
        }
        return start + 1
    }

    @inline(__always)
    private static func skipWhitespace(units: [UInt16], cursor i: inout Int, end: Int) {
        while i < end, units[i] == space || units[i] == tab { i += 1 }
    }

    @inline(__always)
    private static func isNameChar(_ u: UInt16) -> Bool {
        (u >= 0x41 && u <= 0x5A)
            || (u >= 0x61 && u <= 0x7A)
            || (u >= 0x30 && u <= 0x39)
            || u == dash || u == 0x5F || u == 0x3A || u == 0x2E
    }

    @inline(__always)
    private static func isEntityChar(_ u: UInt16) -> Bool {
        (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A) || (u >= 0x30 && u <= 0x39) || u == 0x23
    }
}
