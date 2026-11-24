import Foundation

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

        let fences = index.fences
        var fenceCursor = initialFenceCursor(in: fences, targetLine: gfmFirst)

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
        var idx = start
        while idx < line.endIndex, line[idx] == 0x20 { idx += 1 }
        guard idx < line.endIndex else { return }

        if isThematicBreak(line[idx...]) {
            appendHighlightSpan(.thematicBreak, from: start, to: line.endIndex, lineStart: start, base: base, into: &out)
            return
        }
        emitBlockLineHighlightSpan(line, firstNonSpaceIdx: idx, base: base, into: &out)
        scanInline(line, lineStart: start, base: base, into: &out)
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
    private static func scanInline(
        _ line: ArraySlice<UInt16>,
        lineStart: Int,
        base: Int,
        into out: inout [MarkdownSyntaxSpan]
    ) {
        var memo = InlineHighlightMemo()
        var i = line.startIndex
        while i < line.endIndex {
            if let matched = matchInlineSyntaxConstruct(in: line, at: i, memo: &memo) {
                appendHighlightSpan(matched.kind, from: i, to: matched.end, lineStart: lineStart, base: base, into: &out)
                i = matched.end
            } else {
                i += 1
            }
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

extension MarkdownSyntaxHighlighter {
    private struct InlineHighlightMemo {
        var noBacktick = false
        var noDoubleStar = false
        var noDoubleTilde = false
        var noStar = false
        var noUnderscore = false
        var noCloseAngle = false
        var noLinkCloseBracket = false
        var noLinkCloseParen = false
        var failedCloseBracketIndex = -1
    }

    @inline(__always)
    private static func appendHighlightSpan(
        _ kind: MarkdownSyntaxKind,
        from: Int,
        to: Int,
        lineStart: Int,
        base: Int,
        into out: inout [MarkdownSyntaxSpan]
    ) {
        out.append(MarkdownSyntaxSpan(kind: kind, range: TextRange(location: base + (from - lineStart), length: to - from)))
    }

    private static func initialFenceCursor(in fences: [(open: Int, close: Int)], targetLine: Int) -> Int {
        guard !fences.isEmpty else { return 0 }
        var lo = 0
        var hi = fences.count
        while lo < hi {
            let mid = lo + (hi - lo) / 2
            if fences[mid].close < targetLine { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }

    private static func emitBlockLineHighlightSpan(
        _ line: ArraySlice<UInt16>,
        firstNonSpaceIdx idx: Int,
        base: Int,
        into out: inout [MarkdownSyntaxSpan]
    ) {
        let start = line.startIndex
        let first = line[idx]
        if first == 0x23 {
            emitATXHeadingHighlightSpan(line, hashStart: idx, base: base, into: &out)
        } else if first == 0x3E {
            appendHighlightSpan(.blockquote, from: start, to: line.endIndex, lineStart: start, base: base, into: &out)
        } else if first == 0x7C, line[(idx + 1)...].contains(0x7C) {
            appendHighlightSpan(.tableRow, from: start, to: line.endIndex, lineStart: start, base: base, into: &out)
        } else if first == 0x2D || first == 0x2A || first == 0x2B {
            if let item = MarkdownListGrammar.parseListLine(line), case .bullet(_, let state?) = item.kind {
                let box = start + item.indent + 2
                appendHighlightSpan(.task(checked: state != 0x20), from: box, to: box + 3, lineStart: start, base: base, into: &out)
            }
        }
    }

    private static func emitATXHeadingHighlightSpan(
        _ line: ArraySlice<UInt16>,
        hashStart: Int,
        base: Int,
        into out: inout [MarkdownSyntaxSpan]
    ) {
        var level = 0
        var j = hashStart
        while j < line.endIndex, line[j] == 0x23 { level += 1; j += 1 }
        if level <= 6, j == line.endIndex || line[j] == 0x20 {
            appendHighlightSpan(.heading(level: level), from: line.startIndex, to: line.endIndex, lineStart: line.startIndex, base: base, into: &out)
        }
    }
}

extension MarkdownSyntaxHighlighter {
    private static func matchInlineSyntaxConstruct(
        in line: ArraySlice<UInt16>,
        at i: Int,
        memo: inout InlineHighlightMemo
    ) -> (kind: MarkdownSyntaxKind, end: Int)? {
        let end = line.endIndex
        switch line[i] {
        case 0x60:
            return matchInlineCodeSpan(in: line, at: i, noBacktick: &memo.noBacktick)
        case 0x21 where i + 1 < end && line[i + 1] == 0x5B:
            return findLinearLinkEnd(in: line, openBracket: i + 1, memo: &memo).map { (.image, $0 + 1) }
        case 0x5B:
            return findLinearLinkEnd(in: line, openBracket: i, memo: &memo).map { (.link, $0 + 1) }
        case 0x2A:
            return matchStarEmphasisOrBold(in: line, at: i, memo: &memo)
        case 0x7E where i + 1 < end && line[i + 1] == 0x7E:
            return matchPairedDelimiterSpan(unit: 0x7E, kind: .strikethrough, in: line, at: i, disabled: &memo.noDoubleTilde)
        case 0x5F:
            return matchSingleItalicSpan(unit: 0x5F, in: line, at: i, disabled: &memo.noUnderscore)
        case 0x3C:
            return matchInlineHTMLTagSpan(in: line, at: i, noCloseAngle: &memo.noCloseAngle)
        default:
            return nil
        }
    }

    private static func matchStarEmphasisOrBold(
        in line: ArraySlice<UInt16>,
        at i: Int,
        memo: inout InlineHighlightMemo
    ) -> (kind: MarkdownSyntaxKind, end: Int)? {
        if i + 1 < line.endIndex, line[i + 1] == 0x2A {
            return matchPairedDelimiterSpan(unit: 0x2A, kind: .bold, in: line, at: i, disabled: &memo.noDoubleStar)
        }
        return matchSingleItalicSpan(unit: 0x2A, in: line, at: i, disabled: &memo.noStar)
    }

    private static func matchInlineCodeSpan(
        in line: ArraySlice<UInt16>,
        at i: Int,
        noBacktick: inout Bool
    ) -> (kind: MarkdownSyntaxKind, end: Int)? {
        guard !noBacktick else { return nil }
        guard let close = findHighlightUnit(0x60, in: line, from: i + 1) else {
            noBacktick = true
            return nil
        }
        return close > i + 1 ? (.inlineCode, close + 1) : nil
    }

    private static func matchPairedDelimiterSpan(
        unit: UInt16,
        kind: MarkdownSyntaxKind,
        in line: ArraySlice<UInt16>,
        at i: Int,
        disabled: inout Bool
    ) -> (kind: MarkdownSyntaxKind, end: Int)? {
        guard !disabled else { return nil }
        guard let close = findHighlightUnitPair(unit, in: line, from: i + 2) else {
            disabled = true
            return nil
        }
        return close > i + 2 ? (kind, close + 2) : nil
    }

    private static func matchSingleItalicSpan(
        unit: UInt16,
        in line: ArraySlice<UInt16>,
        at i: Int,
        disabled: inout Bool
    ) -> (kind: MarkdownSyntaxKind, end: Int)? {
        guard !disabled, i + 1 < line.endIndex, line[i + 1] != 0x20 else { return nil }
        guard let close = findHighlightUnit(unit, in: line, from: i + 1) else {
            disabled = true
            return nil
        }
        guard close > i + 1, line[close - 1] != 0x20 else { return nil }
        return (.italic, close + 1)
    }

    private static func matchInlineHTMLTagSpan(
        in line: ArraySlice<UInt16>,
        at i: Int,
        noCloseAngle: inout Bool
    ) -> (kind: MarkdownSyntaxKind, end: Int)? {
        guard !noCloseAngle, i + 1 < line.endIndex, isHTMLTagFollowUnit(line[i + 1]) else { return nil }
        if let close = findHighlightUnit(0x3E, in: line, from: i + 1) {
            return (.inlineHTML, close + 1)
        }
        noCloseAngle = true
        return nil
    }

    @inline(__always)
    private static func isHTMLTagFollowUnit(_ u: UInt16) -> Bool {
        (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A) || u == 0x2F
    }

    private static func findHighlightUnit(_ unit: UInt16, in line: ArraySlice<UInt16>, from start: Int) -> Int? {
        var k = start
        while k < line.endIndex {
            if line[k] == unit { return k }
            k += 1
        }
        return nil
    }

    private static func findHighlightUnitPair(_ unit: UInt16, in line: ArraySlice<UInt16>, from start: Int) -> Int? {
        var k = start
        while k + 1 < line.endIndex {
            if line[k] == unit, line[k + 1] == unit { return k }
            k += 1
        }
        return nil
    }

    private static func findLinearLinkEnd(
        in line: ArraySlice<UInt16>,
        openBracket: Int,
        memo: inout InlineHighlightMemo
    ) -> Int? {
        guard !memo.noLinkCloseBracket, !memo.noLinkCloseParen, openBracket >= memo.failedCloseBracketIndex else {
            return nil
        }
        let end = line.endIndex
        guard let closeBracket = findHighlightUnit(0x5D, in: line, from: openBracket + 1) else {
            memo.noLinkCloseBracket = true
            return nil
        }
        guard closeBracket + 1 < end, line[closeBracket + 1] == 0x28 else {
            memo.failedCloseBracketIndex = closeBracket
            return nil
        }
        if let closeParen = findHighlightUnit(0x29, in: line, from: closeBracket + 2) {
            return closeParen
        }
        memo.noLinkCloseParen = true
        return nil
    }
}
