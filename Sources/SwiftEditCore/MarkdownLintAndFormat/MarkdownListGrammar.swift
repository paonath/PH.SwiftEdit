import Foundation

/// A parsed Markdown list line (UTF-16 offsets relative to the line start).
struct MarkdownListLine: Equatable {
    enum Kind: Equatable {
        case bullet(marker: UInt16, taskState: UInt16?)
        case ordered(number: Int, delimiter: UInt16)
    }

    let indent: Int
    let kind: Kind
    /// Length of the marker including its trailing space (excluding indent).
    let markerLength: Int
    var prefixLength: Int { indent + markerLength }
}

/// Shared zero-regex leaf list-line grammar used by the list engine, smart newline engine, authoring commands, and linter rules (`BC-004`, `BC-011`, `REQ-009`).
enum MarkdownListGrammar {
    static let space: UInt16 = 0x20
    static let maxOrderedNumber = 999_999_999
    static let maxLineUTF16 = 4096

    /// Parses `line` as a CommonMark list item (`- `, `* `, `+ `, task checkbox, or `N. ` / `N) `); leading tabs make a line non-list.
    static func parseListLine(_ line: ArraySlice<UInt16>) -> MarkdownListLine? {
        var idx = line.startIndex
        while idx < line.endIndex, line[idx] == space { idx += 1 }
        let indent = idx - line.startIndex
        guard idx < line.endIndex else { return nil }
        let first = line[idx]

        if first == 0x2D || first == 0x2A || first == 0x2B {
            return parseBulletListLine(line, at: idx, indent: indent, marker: first)
        }
        return parseOrderedListLine(line, at: idx, indent: indent)
    }

    private static func parseBulletListLine(
        _ line: ArraySlice<UInt16>,
        at idx: Int,
        indent: Int,
        marker: UInt16
    ) -> MarkdownListLine? {
        guard idx + 1 < line.endIndex, line[idx + 1] == space else { return nil }
        if idx + 5 < line.endIndex,
           line[idx + 2] == 0x5B, line[idx + 4] == 0x5D, line[idx + 5] == space,
           isTaskCheckboxStateUnit(line[idx + 3]) {
            return MarkdownListLine(indent: indent, kind: .bullet(marker: marker, taskState: line[idx + 3]), markerLength: 6)
        }
        return MarkdownListLine(indent: indent, kind: .bullet(marker: marker, taskState: nil), markerLength: 2)
    }

    @inline(__always)
    private static func isTaskCheckboxStateUnit(_ u: UInt16) -> Bool {
        u == space || u == 0x78 || u == 0x58
    }

    private static func parseOrderedListLine(_ line: ArraySlice<UInt16>, at idx: Int, indent: Int) -> MarkdownListLine? {
        var number = 0
        var digits = 0
        var cursor = idx
        while cursor < line.endIndex, line[cursor] >= 0x30, line[cursor] <= 0x39 {
            digits += 1
            guard digits <= 9 else { return nil }
            number = number * 10 + Int(line[cursor] - 0x30)
            cursor += 1
        }
        guard digits > 0, cursor + 1 < line.endIndex,
              line[cursor] == 0x2E || line[cursor] == 0x29,
              line[cursor + 1] == space else { return nil }
        return MarkdownListLine(indent: indent, kind: .ordered(number: number, delimiter: line[cursor]), markerLength: digits + 2)
    }

    /// Returns `true` when `line` begins (after `>= 2` spaces) with a pseudo-outline marker: one letter `a...y` / `A...Y` followed by `. `, or `D.D `.
    static func isPseudoOutlineMarker(_ line: ArraySlice<UInt16>) -> Bool {
        pseudoOutlineContinuation(line) != nil
    }

    /// Parses a pseudo-outline marker and returns `(markerLength, nextMarker)` for the next sibling (`a.` -> `b.`, `1.1` -> `1.2`), or `nil` when absent or not continuable.
    static func pseudoOutlineContinuation(_ line: ArraySlice<UInt16>) -> (indent: Int, markerLength: Int, nextMarker: String)? {
        var idx = line.startIndex
        while idx < line.endIndex, line[idx] == space { idx += 1 }
        let indent = idx - line.startIndex
        guard indent >= 2, idx < line.endIndex else { return nil }
        let first = line[idx]

        let isLower = first >= 0x61 && first <= 0x79
        let isUpper = first >= 0x41 && first <= 0x59
        if isLower || isUpper {
            guard idx + 2 < line.endIndex, line[idx + 1] == 0x2E, line[idx + 2] == space else { return nil }
            let next = String(UnicodeScalar(UInt8(first + 1)))
            return (indent, 3, next + ". ")
        }

        return parseNumericOutlineContinuation(line, at: idx, indent: indent, first: first)
    }

    private static func parseNumericOutlineContinuation(
        _ line: ArraySlice<UInt16>,
        at idx: Int,
        indent: Int,
        first: UInt16
    ) -> (indent: Int, markerLength: Int, nextMarker: String)? {
        guard first >= 0x30, first <= 0x39 else { return nil }
        var cursor = idx
        var majorDigits = 0
        while cursor < line.endIndex, line[cursor] >= 0x30, line[cursor] <= 0x39 {
            majorDigits += 1
            guard majorDigits <= 9 else { return nil }
            cursor += 1
        }
        guard cursor < line.endIndex, line[cursor] == 0x2E else { return nil }
        let majorEnd = cursor
        cursor += 1
        var minor = 0
        var minorDigits = 0
        while cursor < line.endIndex, line[cursor] >= 0x30, line[cursor] <= 0x39 {
            minorDigits += 1
            guard minorDigits <= 9 else { return nil }
            minor = minor * 10 + Int(line[cursor] - 0x30)
            cursor += 1
        }
        guard minorDigits > 0, cursor < line.endIndex, line[cursor] == space else { return nil }
        let major = String(decoding: line[idx..<majorEnd], as: UTF16.self)
        let (nextMinor, overflow) = minor.addingReportingOverflow(1)
        guard overflow == false, nextMinor <= maxOrderedNumber else { return nil }
        return (indent, cursor + 1 - idx, "\(major).\(nextMinor) ")
    }
}
