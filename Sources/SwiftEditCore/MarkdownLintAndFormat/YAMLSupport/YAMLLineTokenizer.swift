import Foundation

/// Token classes of the YAML subset understood by the editor (`BC-004`).
///
/// Anchors, aliases and tags are classified but never resolved: the editor needs token boundaries, not an object graph,
/// which makes every YAML engine immune to alias-expansion ("billion laughs", `CWE-776`) and tag-driven code paths.
public enum YAMLTokenKind: Equatable, Sendable {
    case key, colon, value, quotedString, comment, listDash, anchor, alias, tag, documentMarker, blockScalarIndicator
}

/// A token with its UTF-16 range relative to the start of the scanned line.
public struct YAMLToken: Equatable, Sendable {
    public let kind: YAMLTokenKind
    public let range: TextRange
    public init(kind: YAMLTokenKind, range: TextRange) { self.kind = kind; self.range = range }
}

/// Zero-regex, single-pass `O(L)` YAML line tokenizer (`AR-002`, `SEC-012`).
///
/// Lines longer than `YAMLSupportLimits.maxLineUTF16` return no tokens. Unterminated quotes extend to end of line instead
/// of failing, so malformed input degrades to plain styling and never throws.
public enum YAMLLineTokenizer {
    static let space: UInt16 = 0x20, tab: UInt16 = 0x09, hash: UInt16 = 0x23, colon: UInt16 = 0x3A
    static let dash: UInt16 = 0x2D, dot: UInt16 = 0x2E, dquote: UInt16 = 0x22, squote: UInt16 = 0x27
    static let backslash: UInt16 = 0x5C, amp: UInt16 = 0x26, star: UInt16 = 0x2A, bang: UInt16 = 0x21
    static let pipe: UInt16 = 0x7C, gt: UInt16 = 0x3E, lbracket: UInt16 = 0x5B, rbracket: UInt16 = 0x5D
    static let lbrace: UInt16 = 0x7B, rbrace: UInt16 = 0x7D, comma: UInt16 = 0x2C, plus: UInt16 = 0x2B, cr: UInt16 = 0x0D

    /// `true` for YAML inline whitespace (space or tab).
    @inline(__always) static func isBlank(_ u: UInt16) -> Bool { u == space || u == tab }

    /// Convenience overload for tests and single lines.
    public static func tokens(line: String) -> [YAMLToken] { tokens(line: Array(line.utf16)[...]) }

    /// Tokenizes one line (without its newline). Ranges are relative to `line.startIndex`.
    public static func tokens(line: ArraySlice<UInt16>) -> [YAMLToken] {
        guard line.count <= YAMLSupportLimits.maxLineUTF16 else { return [] }
        let base = line.startIndex
        var end = line.endIndex
        if end > base, line[end - 1] == cr { end -= 1 }
        var out: [YAMLToken] = []
        func add(_ kind: YAMLTokenKind, _ from: Int, _ to: Int) {
            guard to > from else { return }
            out.append(YAMLToken(kind: kind, range: TextRange(location: from - base, length: to - from)))
        }
        func skipBlanks(_ i: inout Int) { while i < end, isBlank(line[i]) { i += 1 } }

        var i = base
        // Document markers live at column 0 only.
        if end - base >= 3, (line[base] == dash || line[base] == dot),
           line[base + 1] == line[base], line[base + 2] == line[base],
           end - base == 3 || isBlank(line[base + 3]) {
            add(.documentMarker, base, base + 3)
            i = base + 3
            skipBlanks(&i)
            scanValue(line, &i, end, add)
            return out
        }
        skipBlanks(&i)
        // Block-sequence dashes (`- - x`).
        while i < end, line[i] == dash, i + 1 == end || isBlank(line[i + 1]) {
            add(.listDash, i, i + 1)
            i += 1
            skipBlanks(&i)
        }
        guard i < end else { return out }
        if line[i] == hash { add(.comment, i, end); return out }
        if let keyEnd = keyEnd(line, from: i, end: end) {
            add(.key, i, keyEnd.keyUpper)
            add(.colon, keyEnd.colon, keyEnd.colon + 1)
            i = keyEnd.colon + 1
            skipBlanks(&i)
        }
        scanValue(line, &i, end, add)
        return out
    }

    /// Returns the key's exclusive upper bound (trailing blanks trimmed) and the colon offset when a mapping key starts at `i`.
    static func keyEnd(_ line: ArraySlice<UInt16>, from i: Int, end: Int) -> (keyUpper: Int, colon: Int)? {
        let first = line[i]
        func colonTerminates(_ k: Int) -> Bool { line[k] == colon && (k + 1 == end || isBlank(line[k + 1])) }
        if first == dquote || first == squote {
            let close = quotedEnd(line, from: i, end: end)
            var k = close
            while k < end, isBlank(line[k]) { k += 1 }
            return k < end && colonTerminates(k) ? (close, k) : nil
        }
        let indicators: Set<UInt16> = [lbracket, lbrace, amp, star, bang, pipe, gt, hash, 0x25, 0x40, 0x60, 0x3F]
        guard !indicators.contains(first) else { return nil }
        var k = i
        while k < end {
            if line[k] == hash, k > i, isBlank(line[k - 1]) { return nil }
            if colonTerminates(k) {
                var upper = k
                while upper > i, isBlank(line[upper - 1]) { upper -= 1 }
                return upper > i ? (upper, k) : nil
            }
            k += 1
        }
        return nil
    }

    /// Exclusive end of a quoted scalar starting at `i`; an unterminated quote ends at `end`.
    static func quotedEnd(_ line: ArraySlice<UInt16>, from i: Int, end: Int) -> Int {
        let q = line[i]
        var k = i + 1
        while k < end {
            let u = line[k]
            if q == dquote, u == backslash { k += 2; continue }
            if u == q {
                if q == squote, k + 1 < end, line[k + 1] == squote { k += 2; continue }
                return k + 1
            }
            k += 1
        }
        return end
    }

    /// Scans the value part: properties (`&a`, `!t`), alias, block-scalar indicator, quoted/flow/plain scalar, then comment.
    private static func scanValue(_ line: ArraySlice<UInt16>, _ i: inout Int, _ end: Int, _ add: (YAMLTokenKind, Int, Int) -> Void) {
        func wordEnd(_ from: Int) -> Int { var k = from; while k < end, !isBlank(line[k]) { k += 1 }; return k }
        func skipBlanks() { while i < end, isBlank(line[i]) { i += 1 } }
        // Node properties may precede the content in any order.
        while i < end, line[i] == amp || line[i] == bang {
            let e = wordEnd(i)
            add(line[i] == amp ? .anchor : .tag, i, e)
            i = e
            skipBlanks()
        }
        guard i < end else { return }
        let first = line[i]
        if first == hash { add(.comment, i, end); i = end; return }
        if first == star {
            let e = wordEnd(i)
            add(.alias, i, e)
            i = e
        } else if first == pipe || first == gt {
            var k = i + 1
            while k < end, line[k] == plus || line[k] == dash || (line[k] >= 0x30 && line[k] <= 0x39) { k += 1 }
            add(.blockScalarIndicator, i, k)
            i = k
        } else if first == dquote || first == squote {
            let e = quotedEnd(line, from: i, end: end)
            add(.quotedString, i, e)
            i = e
        } else if first == lbracket || first == lbrace {
            let e = flowEnd(line, from: i, end: end)
            add(.value, i, e)
            i = e
        } else {
            var k = i
            while k < end, !(line[k] == hash && k > i && isBlank(line[k - 1])) { k += 1 }
            var upper = k
            while upper > i, isBlank(line[upper - 1]) { upper -= 1 }
            add(.value, i, upper)
            i = k
        }
        skipBlanks()
        if i < end, line[i] == hash { add(.comment, i, end); i = end }
    }

    /// Exclusive end of a flow collection (bracket depth tracked, quotes honored); unbalanced input ends at `end`.
    static func flowEnd(_ line: ArraySlice<UInt16>, from i: Int, end: Int) -> Int {
        var depth = 0
        var k = i
        while k < end {
            let u = line[k]
            if u == dquote || u == squote { k = quotedEnd(line, from: k, end: end); continue }
            if u == lbracket || u == lbrace { depth += 1 }
            if u == rbracket || u == rbrace {
                depth -= 1
                if depth == 0 { return k + 1 }
            }
            k += 1
        }
        return end
    }
}
