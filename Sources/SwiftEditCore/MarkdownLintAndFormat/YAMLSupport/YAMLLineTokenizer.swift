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
    /// Allocation-free structural view of a YAML line for `YAMLStructureLinter`.
    struct StructuralLine {
        let isIgnored: Bool
        let hasDash: Bool
        let keyRange: TextRange?
        let endsWithBlockScalar: Bool
    }

    static let space: UInt16 = 0x20, tab: UInt16 = 0x09, hash: UInt16 = 0x23, colon: UInt16 = 0x3A
    static let dash: UInt16 = 0x2D, dot: UInt16 = 0x2E, dquote: UInt16 = 0x22, squote: UInt16 = 0x27
    static let backslash: UInt16 = 0x5C, amp: UInt16 = 0x26, star: UInt16 = 0x2A, bang: UInt16 = 0x21
    static let pipe: UInt16 = 0x7C, gt: UInt16 = 0x3E, lbracket: UInt16 = 0x5B, rbracket: UInt16 = 0x5D
    static let lbrace: UInt16 = 0x7B, rbrace: UInt16 = 0x7D, comma: UInt16 = 0x2C, plus: UInt16 = 0x2B, cr: UInt16 = 0x0D

    /// `true` for YAML inline whitespace (space or tab).
    @inline(__always) static func isBlank(_ u: UInt16) -> Bool { u == space || u == tab }

    @inline(__always) static func isFlowOrDirectiveIndicator(_ u: UInt16) -> Bool {
        switch u {
        case lbracket, lbrace, amp, star, bang, pipe, gt, hash, 0x25, 0x40, 0x60, 0x3F: return true
        default: return false
        }
    }

    /// Allocation-free structural inspection matching `tokens(line:)` semantics for `YAMLStructureLinter`.
    static func inspectStructure(line: ArraySlice<UInt16>, indent: Int) -> StructuralLine {
        guard line.count <= YAMLSupportLimits.maxLineUTF16 else {
            return StructuralLine(isIgnored: true, hasDash: false, keyRange: nil, endsWithBlockScalar: false)
        }
        let base = line.startIndex
        let end = yamlTokenizerEffectiveEnd(line)
        if yamlTokenizerHasDocMarkerPrefix(line, end: end) {
            return StructuralLine(isIgnored: true, hasDash: false, keyRange: nil, endsWithBlockScalar: false)
        }
        var i = base + indent
        yamlTokenizerSkipBlanks(line, cursor: &i, end: end)
        let hasDash = yamlTokenizerConsumeSequenceDashes(line, cursor: &i, end: end)
        guard i < end, line[i] != hash else {
            return StructuralLine(isIgnored: true, hasDash: hasDash, keyRange: nil, endsWithBlockScalar: false)
        }
        guard let keyResult = keyEnd(line, from: i, end: end) else {
            return StructuralLine(isIgnored: false, hasDash: hasDash, keyRange: nil, endsWithBlockScalar: false)
        }
        let keyRange = TextRange(location: i - base, length: keyResult.keyUpper - i)
        let endsWithBlockScalar = yamlTokenizerInspectAfterColon(line, from: keyResult.colon + 1, end: end)
        return StructuralLine(isIgnored: false, hasDash: hasDash, keyRange: keyRange, endsWithBlockScalar: endsWithBlockScalar)
    }

    /// Convenience overload for tests and single lines.
    public static func tokens(line: String) -> [YAMLToken] { tokens(line: Array(line.utf16)[...]) }

    /// Tokenizes one line (without its newline). Ranges are relative to `line.startIndex`.
    public static func tokens(line: ArraySlice<UInt16>) -> [YAMLToken] {
        guard line.count <= YAMLSupportLimits.maxLineUTF16 else { return [] }
        let base = line.startIndex
        let end = yamlTokenizerEffectiveEnd(line)
        var out: [YAMLToken] = []
        var i = base

        // Document markers live at column 0 only.
        if yamlTokenizerHasDocMarkerPrefix(line, end: end) {
            yamlTokenizerAppendToken(.documentMarker, from: base, to: base + 3, base: base, into: &out)
            i = base + 3
            yamlTokenizerSkipBlanks(line, cursor: &i, end: end)
            scanValue(line, cursor: &i, end: end, base: base, into: &out)
            return out
        }

        yamlTokenizerSkipBlanks(line, cursor: &i, end: end)
        yamlTokenizerEmitSequenceDashes(line, cursor: &i, end: end, base: base, into: &out)
        guard i < end else { return out }
        if line[i] == hash {
            yamlTokenizerAppendToken(.comment, from: i, to: end, base: base, into: &out)
            return out
        }
        if let keyMatch = keyEnd(line, from: i, end: end) {
            yamlTokenizerAppendToken(.key, from: i, to: keyMatch.keyUpper, base: base, into: &out)
            yamlTokenizerAppendToken(.colon, from: keyMatch.colon, to: keyMatch.colon + 1, base: base, into: &out)
            i = keyMatch.colon + 1
            yamlTokenizerSkipBlanks(line, cursor: &i, end: end)
        }
        scanValue(line, cursor: &i, end: end, base: base, into: &out)
        return out
    }

    /// Returns the key's exclusive upper bound (trailing blanks trimmed) and the colon offset when a mapping key starts at `i`.
    static func keyEnd(_ line: ArraySlice<UInt16>, from i: Int, end: Int) -> (keyUpper: Int, colon: Int)? {
        let first = line[i]
        if first == dquote || first == squote {
            let close = quotedEnd(line, from: i, end: end)
            var k = close
            yamlTokenizerSkipBlanks(line, cursor: &k, end: end)
            return k < end && yamlTokenizerColonTerminates(line, at: k, end: end) ? (close, k) : nil
        }
        guard !isFlowOrDirectiveIndicator(first) else { return nil }
        return yamlTokenizerUnquotedKeyEnd(line, from: i, end: end)
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
    private static func scanValue(
        _ line: ArraySlice<UInt16>,
        cursor i: inout Int,
        end: Int,
        base: Int,
        into out: inout [YAMLToken]
    ) {
        yamlTokenizerConsumeNodeProperties(line, cursor: &i, end: end, base: base, into: &out)
        guard i < end else { return }
        if line[i] == hash {
            yamlTokenizerAppendToken(.comment, from: i, to: end, base: base, into: &out)
            i = end
            return
        }
        yamlTokenizerConsumePrimaryValue(line, cursor: &i, end: end, base: base, into: &out)
        yamlTokenizerSkipBlanks(line, cursor: &i, end: end)
        if i < end, line[i] == hash {
            yamlTokenizerAppendToken(.comment, from: i, to: end, base: base, into: &out)
            i = end
        }
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

extension YAMLLineTokenizer {
    @inline(__always)
    private static func yamlTokenizerEffectiveEnd(_ line: ArraySlice<UInt16>) -> Int {
        let base = line.startIndex
        let end = line.endIndex
        return (end > base && line[end - 1] == cr) ? (end - 1) : end
    }

    @inline(__always)
    private static func yamlTokenizerAppendToken(
        _ kind: YAMLTokenKind,
        from: Int,
        to: Int,
        base: Int,
        into out: inout [YAMLToken]
    ) {
        guard to > from else { return }
        out.append(YAMLToken(kind: kind, range: TextRange(location: from - base, length: to - from)))
    }

    @inline(__always)
    private static func yamlTokenizerSkipBlanks(_ line: ArraySlice<UInt16>, cursor i: inout Int, end: Int) {
        while i < end, isBlank(line[i]) { i += 1 }
    }

    private static func yamlTokenizerWordEnd(_ line: ArraySlice<UInt16>, from start: Int, end: Int) -> Int {
        var k = start
        while k < end, !isBlank(line[k]) { k += 1 }
        return k
    }

    @inline(__always)
    private static func yamlTokenizerColonTerminates(_ line: ArraySlice<UInt16>, at k: Int, end: Int) -> Bool {
        line[k] == colon && (k + 1 == end || isBlank(line[k + 1]))
    }

    private static func yamlTokenizerHasDocMarkerPrefix(_ line: ArraySlice<UInt16>, end: Int) -> Bool {
        let base = line.startIndex
        guard end - base >= 3, line[base] == dash || line[base] == dot else { return false }
        guard line[base + 1] == line[base], line[base + 2] == line[base] else { return false }
        return end - base == 3 || isBlank(line[base + 3])
    }

    private static func yamlTokenizerConsumeSequenceDashes(_ line: ArraySlice<UInt16>, cursor i: inout Int, end: Int) -> Bool {
        var hasDash = false
        while i < end, line[i] == dash, i + 1 == end || isBlank(line[i + 1]) {
            hasDash = true
            i += 1
            yamlTokenizerSkipBlanks(line, cursor: &i, end: end)
        }
        return hasDash
    }

    private static func yamlTokenizerEmitSequenceDashes(
        _ line: ArraySlice<UInt16>,
        cursor i: inout Int,
        end: Int,
        base: Int,
        into out: inout [YAMLToken]
    ) {
        while i < end, line[i] == dash, i + 1 == end || isBlank(line[i + 1]) {
            yamlTokenizerAppendToken(.listDash, from: i, to: i + 1, base: base, into: &out)
            i += 1
            yamlTokenizerSkipBlanks(line, cursor: &i, end: end)
        }
    }

    private static func yamlTokenizerInspectAfterColon(_ line: ArraySlice<UInt16>, from start: Int, end: Int) -> Bool {
        var v = start
        yamlTokenizerSkipBlanks(line, cursor: &v, end: end)
        while v < end, line[v] == amp || line[v] == bang {
            v = yamlTokenizerWordEnd(line, from: v, end: end)
            yamlTokenizerSkipBlanks(line, cursor: &v, end: end)
        }
        return v < end && (line[v] == pipe || line[v] == gt)
    }

    private static func yamlTokenizerUnquotedKeyEnd(
        _ line: ArraySlice<UInt16>,
        from i: Int,
        end: Int
    ) -> (keyUpper: Int, colon: Int)? {
        var k = i
        while k < end {
            if line[k] == hash, k > i, isBlank(line[k - 1]) { return nil }
            if yamlTokenizerColonTerminates(line, at: k, end: end) {
                var upper = k
                while upper > i, isBlank(line[upper - 1]) { upper -= 1 }
                return upper > i ? (upper, k) : nil
            }
            k += 1
        }
        return nil
    }

    private static func yamlTokenizerConsumeNodeProperties(
        _ line: ArraySlice<UInt16>,
        cursor i: inout Int,
        end: Int,
        base: Int,
        into out: inout [YAMLToken]
    ) {
        while i < end, line[i] == amp || line[i] == bang {
            let propEnd = yamlTokenizerWordEnd(line, from: i, end: end)
            yamlTokenizerAppendToken(line[i] == amp ? .anchor : .tag, from: i, to: propEnd, base: base, into: &out)
            i = propEnd
            yamlTokenizerSkipBlanks(line, cursor: &i, end: end)
        }
    }

    private static func yamlTokenizerConsumePrimaryValue(
        _ line: ArraySlice<UInt16>,
        cursor i: inout Int,
        end: Int,
        base: Int,
        into out: inout [YAMLToken]
    ) {
        let first = line[i]
        if first == star {
            let aliasEnd = yamlTokenizerWordEnd(line, from: i, end: end)
            yamlTokenizerAppendToken(.alias, from: i, to: aliasEnd, base: base, into: &out)
            i = aliasEnd
        } else if first == pipe || first == gt {
            let indEnd = yamlTokenizerBlockScalarHeaderEnd(line, afterIndicator: i + 1, end: end)
            yamlTokenizerAppendToken(.blockScalarIndicator, from: i, to: indEnd, base: base, into: &out)
            i = indEnd
        } else if first == dquote || first == squote {
            let strEnd = quotedEnd(line, from: i, end: end)
            yamlTokenizerAppendToken(.quotedString, from: i, to: strEnd, base: base, into: &out)
            i = strEnd
        } else if first == lbracket || first == lbrace {
            let colEnd = flowEnd(line, from: i, end: end)
            yamlTokenizerAppendToken(.value, from: i, to: colEnd, base: base, into: &out)
            i = colEnd
        } else {
            yamlTokenizerConsumePlainScalar(line, cursor: &i, end: end, base: base, into: &out)
        }
    }

    private static func yamlTokenizerBlockScalarHeaderEnd(_ line: ArraySlice<UInt16>, afterIndicator start: Int, end: Int) -> Int {
        var k = start
        while k < end, line[k] == plus || line[k] == dash || (line[k] >= 0x30 && line[k] <= 0x39) { k += 1 }
        return k
    }

    private static func yamlTokenizerConsumePlainScalar(
        _ line: ArraySlice<UInt16>,
        cursor i: inout Int,
        end: Int,
        base: Int,
        into out: inout [YAMLToken]
    ) {
        var k = i
        while k < end, !(line[k] == hash && k > i && isBlank(line[k - 1])) { k += 1 }
        var upper = k
        while upper > i, isBlank(line[upper - 1]) { upper -= 1 }
        yamlTokenizerAppendToken(.value, from: i, to: upper, base: base, into: &out)
        i = k
    }
}
