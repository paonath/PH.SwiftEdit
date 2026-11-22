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
    private static func isDigit(_ u: UInt16) -> Bool { u >= 0x30 && u <= 0x39 }
    private static func isHex(_ u: UInt16) -> Bool { isDigit(u) || (u >= 0x41 && u <= 0x46) || (u >= 0x61 && u <= 0x66) }

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
                let inner = line[(i + 1)..<min(k, end)]
                if !foundLevel, let level = levelWords[String(decoding: inner, as: UTF16.self).lowercased()], i > start, isLevelFieldContext(line, before: i) {
                    add(.logLevel(level), i + 1, min(k, end)); foundLevel = true
                } else if !inner.isEmpty, isDigit(inner.first!), let t = timestampEnd(line, i + 1), t == min(k, end) {
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
                let word = String(decoding: wordUnits, as: UTF16.self)
                let lower = word.lowercased()
                if !foundLevel, let level = levelWords[lower], word == word.uppercased() || isDelimitedLevel(line, i, k) {
                    add(.logLevel(level), i, k); foundLevel = true
                } else if word.hasSuffix("Exception") || word.hasSuffix("Error") && word.count > 5 && word.first!.isUppercase {
                    var e = k
                    while e < end, line[e] == 0x2E || isLetter(line[e]) || isDigit(line[e]) { e += 1 }
                    add(.logException, i, e); i = e; continue
                } else if months.contains(lower), k - i == 3, let e = syslogDateEnd(line, k) {
                    add(.logTimestamp, i, e); i = e; continue
                }
                i = k; continue
            }
            i += 1
        }
    }

    /// `[info]`, `|Info|`, `<warn>`, `(debug)`, `level=error`, `level: info`, ` info:` at line start.
    private static func isDelimitedLevel(_ line: ArraySlice<UInt16>, _ s: Int, _ e: Int) -> Bool {
        let before: UInt16? = s > line.startIndex ? line[s - 1] : nil
        let after: UInt16? = e < line.endIndex ? line[e] : nil
        let open: Set<UInt16> = [0x5B, 0x7C, 0x3C, 0x28, 0x3D] // [ | < ( =
        let close: Set<UInt16> = [0x5D, 0x7C, 0x3E, 0x29, 0x3A] // ] | > ) :
        if let before, open.contains(before) { return after == nil || close.contains(after!) || after == 0x20 || before == 0x3D }
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
        var k = i
        for (n, group) in [8, 4, 4, 4, 12].enumerated() {
            guard k + group <= line.endIndex, (k..<(k + group)).allSatisfy({ isHex(line[$0]) }) else { return nil }
            k += group
            if n < 4 { guard k < line.endIndex, line[k] == 0x2D else { return nil }; k += 1 }
        }
        if k < line.endIndex, isHex(line[k]) { return nil }
        return k
    }
}
