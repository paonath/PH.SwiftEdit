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

    static func scan(_ line: ArraySlice<UInt16>, base: Int, into out: inout [MarkdownSyntaxSpan]) {
        if logTryScanIndentedStackFrame(line, base: base, into: &out) {
            return
        }
        let end = line.endIndex
        var foundLevel = false
        var index = line.startIndex
        while index < end {
            let unit = line[index]
            if unit == 0x22 {
                index = logScanQuotedToken(line, at: index, base: base, foundLevel: &foundLevel, into: &out)
            } else if logCanStartNumericToken(line, at: index),
                      let next = logTryScanNumericToken(line, at: index, base: base, into: &out) {
                index = next
            } else if isLetter(unit) {
                index = logScanWordToken(line, at: index, base: base, foundLevel: &foundLevel, into: &out)
            } else {
                index += 1
            }
        }
    }

    /// `YYYY-MM-DD[T| ]HH:MM:SS[.f+][Z|±HH:MM]`, `YYYY/MM/DD`, or `HH:MM:SS[.f+]`.
    static func timestampEnd(_ line: ArraySlice<UInt16>, _ i: Int) -> Int? {
        if let dateEnd = logDatePrefixEnd(line, at: i) {
            if dateEnd < line.endIndex,
               line[dateEnd] == 0x54 || line[dateEnd] == 0x20,
               let fullEnd = timeEnd(line, dateEnd + 1) {
                return fullEnd
            }
            return dateEnd
        }
        return timeEnd(line, i)
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
            if !logIsGuidHyphenOffset(k - i) && !isHex(line[k]) {
                return nil
            }
            k += 1
        }
        return end
    }
}

private extension LogSyntaxHighlighter {
    static let levelWordsByLength: [[(literal: StaticString, level: LogLevel)]] = [
        [
            ("trc", .trace), ("vrb", .trace), ("dbg", .debug), ("inf", .info),
            ("wrn", .warn), ("err", .error), ("ftl", .critical),
        ],
        [("info", .info), ("warn", .warn), ("eror", .error), ("crit", .critical)],
        [
            ("trace", .trace), ("debug", .debug), ("error", .error), ("fatal", .critical),
            ("emerg", .critical), ("alert", .critical), ("panic", .critical),
        ],
        [("notice", .info)],
        [("verbose", .trace), ("warning", .warn)],
        [("critical", .critical)],
        [("emergency", .critical)],
        [],
        [("information", .info)],
    ]

    static let packedMonthCodes: Set<UInt64> = [
        0x006A_0061_006E, // jan
        0x0066_0065_0062, // feb
        0x006D_0061_0072, // mar
        0x0061_0070_0072, // apr
        0x006D_0061_0079, // may
        0x006A_0075_006E, // jun
        0x006A_0075_006C, // jul
        0x0061_0075_0067, // aug
        0x0073_0065_0070, // sep
        0x006F_0063_0074, // oct
        0x006E_006F_0076, // nov
        0x0064_0065_0063, // dec
    ]

    static func isLetter(_ u: UInt16) -> Bool { (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A) }
    static func isUpperASCII(_ u: UInt16) -> Bool { u >= 0x41 && u <= 0x5A }
    static func isLowerASCII(_ u: UInt16) -> Bool { u >= 0x61 && u <= 0x7A }
    static func lowerASCII(_ u: UInt16) -> UInt16 { (u >= 0x41 && u <= 0x5A) ? (u | 0x20) : u }
    static func isDigit(_ u: UInt16) -> Bool { u >= 0x30 && u <= 0x39 }
    static func isHex(_ u: UInt16) -> Bool { isDigit(u) || (u >= 0x41 && u <= 0x46) || (u >= 0x61 && u <= 0x66) }

    /// Allocation-free case-insensitive ASCII check against a static lowercase ASCII byte literal.
    @inline(__always)
    static func equalsLowerASCII(_ slice: ArraySlice<UInt16>, _ literal: StaticString) -> Bool {
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
    static func hasASCIISuffix(_ slice: ArraySlice<UInt16>, _ literal: StaticString) -> Bool {
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
    static func matchLevelWord(_ slice: ArraySlice<UInt16>) -> LogLevel? {
        let count = slice.count
        guard count >= 3 && count <= 11 else { return nil }
        for entry in levelWordsByLength[count - 3] where equalsLowerASCII(slice, entry.literal) {
            return entry.level
        }
        return nil
    }

    /// Allocation-free 3-letter English month check.
    static func isMonthWord(_ slice: ArraySlice<UInt16>) -> Bool {
        guard slice.count == 3 else { return false }
        let s = slice.startIndex
        let packed = (UInt64(lowerASCII(slice[s])) << 32)
            | (UInt64(lowerASCII(slice[s + 1])) << 16)
            | UInt64(lowerASCII(slice[s + 2]))
        return packedMonthCodes.contains(packed)
    }

    /// Returns `true` when `slice` has no lowercase ASCII letters.
    @inline(__always)
    static func isAllUpperASCII(_ slice: ArraySlice<UInt16>) -> Bool {
        var idx = slice.startIndex
        let end = slice.endIndex
        while idx < end {
            if isLowerASCII(slice[idx]) { return false }
            idx += 1
        }
        return true
    }
}

private extension LogSyntaxHighlighter {
    static func logAppendSpan(
        _ kind: MarkdownSyntaxKind,
        from: Int,
        to: Int,
        lineStart: Int,
        base: Int,
        into out: inout [MarkdownSyntaxSpan]
    ) {
        out.append(MarkdownSyntaxSpan(
            kind: kind,
            range: TextRange(location: base + (from - lineStart), length: to - from)
        ))
    }

    static func logTryScanIndentedStackFrame(
        _ line: ArraySlice<UInt16>,
        base: Int,
        into out: inout [MarkdownSyntaxSpan]
    ) -> Bool {
        let start = line.startIndex
        let end = line.endIndex
        var j = start
        while j < end, line[j] == 0x20 || line[j] == 0x09 { j += 1 }
        guard j > start, j + 3 <= end, line[j] == 0x61, line[j + 1] == 0x74, line[j + 2] == 0x20 else {
            return false
        }
        logAppendSpan(.logException, from: j, to: end, lineStart: start, base: base, into: &out)
        return true
    }

    static func logScanQuotedToken(
        _ line: ArraySlice<UInt16>,
        at i: Int,
        base: Int,
        foundLevel: inout Bool,
        into out: inout [MarkdownSyntaxSpan]
    ) -> Int {
        let start = line.startIndex
        let end = line.endIndex
        let k = logFindClosingQuote(line, after: i)
        let close = min(k + 1, end)
        let innerEnd = min(k, end)
        let inner = line[(i + 1)..<innerEnd]

        if !foundLevel, i > start, isLevelFieldContext(line, before: i), let level = matchLevelWord(inner) {
            logAppendSpan(.logLevel(level), from: i + 1, to: innerEnd, lineStart: start, base: base, into: &out)
            foundLevel = true
        } else if let first = inner.first, isDigit(first), let t = timestampEnd(line, i + 1), t == innerEnd {
            logAppendSpan(.logTimestamp, from: i + 1, to: t, lineStart: start, base: base, into: &out)
        } else {
            logAppendSpan(.logString, from: i, to: close, lineStart: start, base: base, into: &out)
        }
        return close
    }

    static func logFindClosingQuote(_ line: ArraySlice<UInt16>, after openQuote: Int) -> Int {
        var k = openQuote + 1
        while k < line.endIndex, line[k] != 0x22 {
            if line[k] == 0x5C { k += 1 }
            k += 1
        }
        return k
    }

    static func logCanStartNumericToken(_ line: ArraySlice<UInt16>, at i: Int) -> Bool {
        guard isDigit(line[i]) else { return false }
        guard i > line.startIndex else { return true }
        let prev = line[i - 1]
        return !isLetter(prev) && !isDigit(prev)
    }

    static func logTryScanNumericToken(
        _ line: ArraySlice<UInt16>,
        at i: Int,
        base: Int,
        into out: inout [MarkdownSyntaxSpan]
    ) -> Int? {
        if let e = guidEnd(line, i) {
            logAppendSpan(.logGuid, from: i, to: e, lineStart: line.startIndex, base: base, into: &out)
            return e
        }
        if let e = timestampEnd(line, i) {
            logAppendSpan(.logTimestamp, from: i, to: e, lineStart: line.startIndex, base: base, into: &out)
            return e
        }
        return nil
    }

    static func logScanWordToken(
        _ line: ArraySlice<UInt16>,
        at i: Int,
        base: Int,
        foundLevel: inout Bool,
        into out: inout [MarkdownSyntaxSpan]
    ) -> Int {
        let start = line.startIndex
        let k = logAdvanceWordEnd(line, from: i)
        let wordUnits = line[i..<k]

        if wordUnits.count >= 8, isHex(line[i]), let e = guidEnd(line, i) {
            logAppendSpan(.logGuid, from: i, to: e, lineStart: start, base: base, into: &out)
            return e
        }
        if !foundLevel, let level = logMatchContextualLevel(wordUnits, in: line, start: i, end: k) {
            logAppendSpan(.logLevel(level), from: i, to: k, lineStart: start, base: base, into: &out)
            foundLevel = true
            return k
        }
        if logIsExceptionOrErrorIdentifier(wordUnits, firstUnit: line[i]) {
            let e = logAdvanceDottedTypeChain(line, from: k)
            logAppendSpan(.logException, from: i, to: e, lineStart: start, base: base, into: &out)
            return e
        }
        if k - i == 3, isMonthWord(wordUnits), let e = syslogDateEnd(line, k) {
            logAppendSpan(.logTimestamp, from: i, to: e, lineStart: start, base: base, into: &out)
            return e
        }
        return k
    }

    static func logAdvanceWordEnd(_ line: ArraySlice<UInt16>, from start: Int) -> Int {
        var k = start
        while k < line.endIndex, isLetter(line[k]) || isDigit(line[k]) || line[k] == 0x5F {
            k += 1
        }
        return k
    }

    static func logMatchContextualLevel(
        _ wordUnits: ArraySlice<UInt16>,
        in line: ArraySlice<UInt16>,
        start: Int,
        end: Int
    ) -> LogLevel? {
        guard let level = matchLevelWord(wordUnits),
              isAllUpperASCII(wordUnits) || isDelimitedLevel(line, start, end) else {
            return nil
        }
        return level
    }

    static func logIsExceptionOrErrorIdentifier(_ wordUnits: ArraySlice<UInt16>, firstUnit: UInt16) -> Bool {
        if hasASCIISuffix(wordUnits, "Exception") { return true }
        return wordUnits.count > 5 && isUpperASCII(firstUnit) && hasASCIISuffix(wordUnits, "Error")
    }

    static func logAdvanceDottedTypeChain(_ line: ArraySlice<UInt16>, from start: Int) -> Int {
        var e = start
        while e < line.endIndex, line[e] == 0x2E || isLetter(line[e]) || isDigit(line[e]) {
            e += 1
        }
        return e
    }
}

private extension LogSyntaxHighlighter {
    static let openLevelDelimiters: Set<UInt16> = [0x5B, 0x7C, 0x3C, 0x28, 0x3D] // [ | < ( =
    static let closeLevelDelimiters: Set<UInt16> = [0x5D, 0x7C, 0x3E, 0x29, 0x3A] // ] | > ) :

    /// `[info]`, `|Info|`, `<warn>`, `(debug)`, `level=error`, `level: info`, ` info:` at line start.
    static func isDelimitedLevel(_ line: ArraySlice<UInt16>, _ s: Int, _ e: Int) -> Bool {
        let before: UInt16? = s > line.startIndex ? line[s - 1] : nil
        let after: UInt16? = e < line.endIndex ? line[e] : nil
        if let before, openLevelDelimiters.contains(before) {
            return after == nil || closeLevelDelimiters.contains(after!) || after == 0x20 || before == 0x3D
        }
        if before == nil || before == 0x20 { return after == 0x3A || after == 0x5D }
        return false
    }

    /// `"level":"error"` / `"@l":"Warning"` style JSON fields.
    static func isLevelFieldContext(_ line: ArraySlice<UInt16>, before quote: Int) -> Bool {
        var k = quote - 1
        while k >= line.startIndex, line[k] == 0x20 { k -= 1 }
        return k >= line.startIndex && line[k] == 0x3A
    }

    static func digits(_ line: ArraySlice<UInt16>, _ i: Int, _ n: Int) -> Bool {
        guard i + n <= line.endIndex else { return false }
        return (i..<(i + n)).allSatisfy { isDigit(line[$0]) }
    }

    static func logDatePrefixEnd(_ line: ArraySlice<UInt16>, at k: Int) -> Int? {
        guard k + 10 <= line.endIndex,
              digits(line, k, 4),
              line[k + 4] == 0x2D || line[k + 4] == 0x2F,
              digits(line, k + 5, 2),
              line[k + 7] == line[k + 4],
              digits(line, k + 8, 2) else {
            return nil
        }
        return k + 10
    }

    static func timeEnd(_ line: ArraySlice<UInt16>, _ i: Int) -> Int? {
        guard let hmsEnd = logHMSPrefixEnd(line, at: i) else { return nil }
        let afterFraction = logAdvanceFractionalSeconds(line, from: hmsEnd)
        return logAdvanceTimezoneSuffix(line, from: afterFraction)
    }

    static func logHMSPrefixEnd(_ line: ArraySlice<UInt16>, at i: Int) -> Int? {
        guard i + 8 <= line.endIndex,
              digits(line, i, 2),
              line[i + 2] == 0x3A,
              digits(line, i + 3, 2),
              line[i + 5] == 0x3A,
              digits(line, i + 6, 2) else {
            return nil
        }
        return i + 8
    }

    static func logAdvanceFractionalSeconds(_ line: ArraySlice<UInt16>, from k: Int) -> Int {
        guard k < line.endIndex, line[k] == 0x2E || line[k] == 0x2C else { return k }
        var m = k + 1
        while m < line.endIndex, isDigit(line[m]) { m += 1 }
        return m > k + 1 ? m : k
    }

    static func logAdvanceTimezoneSuffix(_ line: ArraySlice<UInt16>, from k: Int) -> Int {
        guard k < line.endIndex else { return k }
        if line[k] == 0x5A { return k + 1 }
        guard (line[k] == 0x2B || line[k] == 0x2D), digits(line, k + 1, 2) else { return k }
        let afterHours = k + 3
        if afterHours < line.endIndex, line[afterHours] == 0x3A, digits(line, afterHours + 1, 2) {
            return afterHours + 3
        }
        if digits(line, afterHours, 2) {
            return afterHours + 2
        }
        return afterHours
    }

    /// Syslog `Mon DD HH:MM:SS` continuing after the month word.
    static func syslogDateEnd(_ line: ArraySlice<UInt16>, _ afterMonth: Int) -> Int? {
        var k = afterMonth
        guard k < line.endIndex, line[k] == 0x20 else { return nil }
        k += 1
        if k < line.endIndex, line[k] == 0x20 { k += 1 }
        guard k < line.endIndex, isDigit(line[k]) else { return nil }
        while k < line.endIndex, isDigit(line[k]) { k += 1 }
        guard k < line.endIndex, line[k] == 0x20, let t = timeEnd(line, k + 1) else { return nil }
        return t
    }

    static func logIsGuidHyphenOffset(_ offset: Int) -> Bool {
        offset == 8 || offset == 13 || offset == 18 || offset == 23
    }
}
