import Foundation

/// Log severity, ordered from least to most severe (`trace` … `critical`).
public enum LogLevel: Int, Comparable, Sendable, CaseIterable {
    case trace, debug, info, warn, error, critical

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Zero-regex, linear, viewport-only log tokenizer modelled on VS Code's built-in `log` grammar (`BC-004`, `UI-012`).
///
/// Recognized tokens:
/// - level words: upper-case anywhere (`ERROR`, `WARN`, `INF`, `FATAL`), any case when delimited like a level field
///   (`[info]`, `|Warn|`, `level=debug`, `"level":"error"`, `<error>`);
/// - timestamps: ISO dates with optional time/fraction/zone, `HH:MM:SS(.fff)`, syslog `Mon DD`;
/// - GUIDs, double-quoted strings, `*Exception` names and indented `at ...` stack frames.
/// Lines over `MarkdownLineIndex.maxLineUTF16` are skipped (`CWE-400`).
public enum LogSyntaxHighlighter {

    static let levelWords: [String: LogLevel] = [
        "trace": .trace, "trc": .trace, "verbose": .trace, "vrb": .trace,
        "debug": .debug, "dbg": .debug,
        "info": .info, "inf": .info, "information": .info, "notice": .info,
        "warn": .warn, "warning": .warn, "wrn": .warn,
        "error": .error, "err": .error, "eror": .error,
        "fatal": .critical, "ftl": .critical, "critical": .critical, "crit": .critical,
        "emerg": .critical, "emergency": .critical, "alert": .critical, "panic": .critical,
    ]
    static let months: Set<String> = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]

    /// Spans for the lines intersecting `visibleRange`.
    public static func spans(index: MarkdownLineIndex, visibleRange: TextRange) -> [MarkdownSyntaxSpan] {
        guard visibleRange.length > 0, !index.units.isEmpty else { return [] }
        let first = index.line(containing: visibleRange.location)
        let last = index.line(containing: max(visibleRange.location, visibleRange.upperBound - 1))
        var out: [MarkdownSyntaxSpan] = []
        for line in first...last {
            let range = index.lineRange(line)
            guard range.length > 0, range.length <= MarkdownLineIndex.maxLineUTF16 else { continue }
            scan(index.lineSlice(line), base: range.location, into: &out)
        }
        return out
    }

    /// Severity of a single line: the first level token found, or `nil`.
    public static func level(of line: String) -> LogLevel? {
        var out: [MarkdownSyntaxSpan] = []
        scan(Array(line.utf16)[...], base: 0, into: &out)
        for span in out { if case .logLevel(let level) = span.kind { return level } }
        return nil
    }

    private static func isLetter(_ u: UInt16) -> Bool { (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A) }
    private static func isUpperASCII(_ u: UInt16) -> Bool { u >= 0x41 && u <= 0x5A }
    private static func isLowerASCII(_ u: UInt16) -> Bool { u >= 0x61 && u <= 0x7A }
    private static func lowerASCII(_ u: UInt16) -> UInt16 { (u >= 0x41 && u <= 0x5A) ? (u | 0x20) : u }
    private static func isDigit(_ u: UInt16) -> Bool { u >= 0x30 && u <= 0x39 }
    private static func isHex(_ u: UInt16) -> Bool { isDigit(u) || (u >= 0x41 && u <= 0x46) || (u >= 0x61 && u <= 0x66) }

    /// Allocation-free case-insensitive ASCII check against a static lowercase ASCII byte literal.
    @inline(__always)
    private static func equalsLowerASCII(_ slice: ArraySlice<UInt16>, _ literal: StaticString) -> Bool {
        let len = literal.utf8CodeUnitCount
        guard slice.count == len else { return false }
        let base = slice.startIndex
        return literal.withUTF8Buffer { buf in
            var idx = 0
            while idx < len {
                if lowerASCII(slice[base + idx]) != UInt16(buf[idx]) { return false }
                idx += 1
            }
            return true
        }
    }

    /// Allocation-free case-sensitive ASCII suffix check.
    @inline(__always)
    private static func hasASCIISuffix(_ slice: ArraySlice<UInt16>, _ literal: StaticString) -> Bool {
        let len = literal.utf8CodeUnitCount
        guard slice.count >= len else { return false }
        let base = slice.endIndex - len
        return literal.withUTF8Buffer { buf in
            var idx = 0
            while idx < len {
                if slice[base + idx] != UInt16(buf[idx]) { return false }
                idx += 1
            }
            return true
        }
    }

    /// Allocation-free lookup matching `levelWords` directly on UTF-16 code units.
    private static func matchLevelWord(_ slice: ArraySlice<UInt16>) -> LogLevel? {
        let count = slice.count
        guard count >= 3 && count <= 11 else { return nil }
        switch lowerASCII(slice[slice.startIndex]) {
        case 0x61: // 'a'
            return equalsLowerASCII(slice, "alert") ? .critical : nil
        case 0x63: // 'c'
            if equalsLowerASCII(slice, "crit") || equalsLowerASCII(slice, "critical") { return .critical }
            return nil
        case 0x64: // 'd'
            if equalsLowerASCII(slice, "dbg") || equalsLowerASCII(slice, "debug") { return .debug }
            return nil
        case 0x65: // 'e'
            if equalsLowerASCII(slice, "err") || equalsLowerASCII(slice, "eror") || equalsLowerASCII(slice, "error") { return .error }
            if equalsLowerASCII(slice, "emerg") || equalsLowerASCII(slice, "emergency") { return .critical }
            return nil
        case 0x66: // 'f'
            if equalsLowerASCII(slice, "ftl") || equalsLowerASCII(slice, "fatal") { return .critical }
            return nil
        case 0x69: // 'i'
            if equalsLowerASCII(slice, "inf") || equalsLowerASCII(slice, "info") || equalsLowerASCII(slice, "information") { return .info }
            return nil
        case 0x6E: // 'n'
            return equalsLowerASCII(slice, "notice") ? .info : nil
        case 0x70: // 'p'
            return equalsLowerASCII(slice, "panic") ? .critical : nil
        case 0x74: // 't'
            if equalsLowerASCII(slice, "trc") || equalsLowerASCII(slice, "trace") { return .trace }
            return nil
        case 0x76: // 'v'
            if equalsLowerASCII(slice, "vrb") || equalsLowerASCII(slice, "verbose") { return .trace }
            return nil
        case 0x77: // 'w'
            if equalsLowerASCII(slice, "wrn") || equalsLowerASCII(slice, "warn") || equalsLowerASCII(slice, "warning") { return .warn }
            return nil
        default:
            return nil
        }
    }

    /// Allocation-free 3-letter English month check.
    private static func isMonthWord(_ slice: ArraySlice<UInt16>) -> Bool {
        guard slice.count == 3 else { return false }
        let s = slice.startIndex
        let c0 = lowerASCII(slice[s])
        let c1 = lowerASCII(slice[s + 1])
        let c2 = lowerASCII(slice[s + 2])
        switch (c0, c1, c2) {
        case (0x6A, 0x61, 0x6E), // jan
             (0x66, 0x65, 0x62), // feb
             (0x6D, 0x61, 0x72), // mar
             (0x61, 0x70, 0x72), // apr
             (0x6D, 0x61, 0x79), // may
             (0x6A, 0x75, 0x6E), // jun
             (0x6A, 0x75, 0x6C), // jul
             (0x61, 0x75, 0x67), // aug
             (0x73, 0x65, 0x70), // sep
             (0x6F, 0x63, 0x74), // oct
             (0x6E, 0x6F, 0x76), // nov
             (0x64, 0x65, 0x63): // dec
            return true
        default:
            return false
        }
    }

    /// Returns `true` when `slice` has no lowercase ASCII letters (equivalent to `word == word.uppercased()` for ASCII identifier slices).
    @inline(__always)
    private static func isAllUpperASCII(_ slice: ArraySlice<UInt16>) -> Bool {
        var idx = slice.startIndex
        let end = slice.endIndex
        while idx < end {
            if isLowerASCII(slice[idx]) { return false }
            idx += 1
        }
        return true
    }

    static func scan(_ line: ArraySlice<UInt16>, base: Int, into out: inout [MarkdownSyntaxSpan]) {
        let start = line.startIndex, end = line.endIndex
        func add(_ kind: MarkdownSyntaxKind, _ from: Int, _ to: Int) {
            out.append(MarkdownSyntaxSpan(kind: kind, range: TextRange(location: base + (from - start), length: to - from)))
        }
        // Indented stack frame: "   at Foo.Bar()" / "\tat ..."
        var j = start
        while j < end, line[j] == 0x20 || line[j] == 0x09 { j += 1 }
        if j > start, j + 3 <= end, line[j] == 0x61, line[j + 1] == 0x74, line[j + 2] == 0x20 {
            add(.logException, j, end)
            return
        }
        var foundLevel = false
        var i = start
        while i < end {
            let u = line[i]
            if u == 0x22 { // "string"
                var k = i + 1
                while k < end, line[k] != 0x22 { if line[k] == 0x5C { k += 1 }; k += 1 }
                let close = min(k + 1, end)
                // JSON "level":"error" → level token inside the string
                let innerEnd = min(k, end)
                let inner = line[(i + 1)..<innerEnd]
                if !foundLevel, i > start, isLevelFieldContext(line, before: i), let level = matchLevelWord(inner) {
                    add(.logLevel(level), i + 1, innerEnd); foundLevel = true
                } else if !inner.isEmpty, isDigit(inner.first!), let t = timestampEnd(line, i + 1), t == innerEnd {
                    add(.logTimestamp, i + 1, t) // JSON "time":"2026-…Z"
                } else {
                    add(.logString, i, close)
                }
                i = close; continue
            }
            if isDigit(u), i == start || !isLetter(line[i - 1]) && !isDigit(line[i - 1]) {
                if let e = guidEnd(line, i) { add(.logGuid, i, e); i = e; continue }
                if let e = timestampEnd(line, i) { add(.logTimestamp, i, e); i = e; continue }
            }
            if isLetter(u) {
                var k = i
                while k < end, isLetter(line[k]) || isDigit(line[k]) || line[k] == 0x5F { k += 1 }
                let wordUnits = line[i..<k]
                if wordUnits.count >= 8, isHex(u), let e = guidEnd(line, i) { add(.logGuid, i, e); i = e; continue }
                if !foundLevel, let level = matchLevelWord(wordUnits), isAllUpperASCII(wordUnits) || isDelimitedLevel(line, i, k) {
                    add(.logLevel(level), i, k); foundLevel = true
                } else if hasASCIISuffix(wordUnits, "Exception") || (wordUnits.count > 5 && isUpperASCII(u) && hasASCIISuffix(wordUnits, "Error")) {
                    var e = k
                    while e < end, line[e] == 0x2E || isLetter(line[e]) || isDigit(line[e]) { e += 1 }
                    add(.logException, i, e); i = e; continue
                } else if k - i == 3, isMonthWord(wordUnits), let e = syslogDateEnd(line, k) {
                    add(.logTimestamp, i, e); i = e; continue
                }
                i = k; continue
            }
            i += 1
        }
    }

    @inline(__always)
    private static func isOpenLevelDelimiter(_ u: UInt16) -> Bool {
        switch u {
        case 0x5B, 0x7C, 0x3C, 0x28, 0x3D: return true // [ | < ( =
        default: return false
        }
    }

    @inline(__always)
    private static func isCloseLevelDelimiter(_ u: UInt16) -> Bool {
        switch u {
        case 0x5D, 0x7C, 0x3E, 0x29, 0x3A: return true // ] | > ) :
        default: return false
        }
    }

    /// `[info]`, `|Info|`, `<warn>`, `(debug)`, `level=error`, `level: info`, ` info:` at line start.
    private static func isDelimitedLevel(_ line: ArraySlice<UInt16>, _ s: Int, _ e: Int) -> Bool {
        let before: UInt16? = s > line.startIndex ? line[s - 1] : nil
        let after: UInt16? = e < line.endIndex ? line[e] : nil
        if let before, isOpenLevelDelimiter(before) {
            return after == nil || isCloseLevelDelimiter(after!) || after == 0x20 || before == 0x3D
        }
        if before == nil || before == 0x20 { return after == 0x3A || after == 0x5D }
        return false
    }

    /// `"level":"error"` / `"@l":"Warning"` style JSON fields.
    private static func isLevelFieldContext(_ line: ArraySlice<UInt16>, before quote: Int) -> Bool {
        var k = quote - 1
        while k >= line.startIndex, line[k] == 0x20 { k -= 1 }
        return k >= line.startIndex && line[k] == 0x3A
    }

    private static func digits(_ line: ArraySlice<UInt16>, _ i: Int, _ n: Int) -> Bool {
        guard i + n <= line.endIndex else { return false }
        return (i..<(i + n)).allSatisfy { isDigit(line[$0]) }
    }

    /// `YYYY-MM-DD[T| ]HH:MM:SS[.f+][Z|±HH:MM]`, `YYYY/MM/DD`, or `HH:MM:SS[.f+]`.
    static func timestampEnd(_ line: ArraySlice<UInt16>, _ i: Int) -> Int? {
        var k = i
        if digits(line, k, 4), k + 4 < line.endIndex, line[k + 4] == 0x2D || line[k + 4] == 0x2F, digits(line, k + 5, 2),
           k + 7 < line.endIndex, line[k + 7] == line[k + 4], digits(line, k + 8, 2) {
            k += 10
            if k < line.endIndex, line[k] == 0x54 || line[k] == 0x20, let t = timeEnd(line, k + 1) { k = t }
            return k
        }
        return timeEnd(line, i)
    }

    private static func timeEnd(_ line: ArraySlice<UInt16>, _ i: Int) -> Int? {
        guard digits(line, i, 2), i + 2 < line.endIndex, line[i + 2] == 0x3A, digits(line, i + 3, 2),
              i + 5 < line.endIndex, line[i + 5] == 0x3A, digits(line, i + 6, 2) else { return nil }
        var k = i + 8
        if k < line.endIndex, line[k] == 0x2E || line[k] == 0x2C {
            var m = k + 1
            while m < line.endIndex, isDigit(line[m]) { m += 1 }
            if m > k + 1 { k = m }
        }
        if k < line.endIndex, line[k] == 0x5A { k += 1 }
        else if k < line.endIndex, line[k] == 0x2B || line[k] == 0x2D, digits(line, k + 1, 2) {
            k += 3
            if k < line.endIndex, line[k] == 0x3A, digits(line, k + 1, 2) { k += 3 } else if digits(line, k, 2) { k += 2 }
        }
        return k
    }

    /// Syslog `Mon DD HH:MM:SS` continuing after the month word.
    private static func syslogDateEnd(_ line: ArraySlice<UInt16>, _ afterMonth: Int) -> Int? {
        var k = afterMonth
        guard k < line.endIndex, line[k] == 0x20 else { return nil }
        k += 1
        if k < line.endIndex, line[k] == 0x20 { k += 1 }
        guard k < line.endIndex, isDigit(line[k]) else { return nil }
        while k < line.endIndex, isDigit(line[k]) { k += 1 }
        guard k < line.endIndex, line[k] == 0x20, let t = timeEnd(line, k + 1) else { return nil }
        return t
    }

    /// 8-4-4-4-12 hexadecimal GUID.
    static func guidEnd(_ line: ArraySlice<UInt16>, _ i: Int) -> Int? {
        let end = i + 36
        guard end <= line.endIndex,
              line[i + 8] == 0x2D,
              line[i + 13] == 0x2D,
              line[i + 18] == 0x2D,
              line[i + 23] == 0x2D else { return nil }
        if end < line.endIndex, isHex(line[end]) { return nil }
        var k = i
        while k < end {
            if k != i + 8 && k != i + 13 && k != i + 18 && k != i + 23 {
                if !isHex(line[k]) { return nil }
            }
            k += 1
        }
        return end
    }
}
