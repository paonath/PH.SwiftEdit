import Foundation

/// Single-pass line scanner implementing the `.allConstructs` rule catalog on a shared `MarkdownLineIndex` (`BC-004`, `SEC-004`, `SEC-012`).
///
/// Frontmatter lines are skipped, fenced interiors only receive fence rules, lines over `4096` UTF-16 units are opaque, and every fixable finding carries a minimal `TextEdit`. Security rules (`.unsafeLinkScheme`, `.unsafeImagePath`, `.emptyLinkTarget`) never carry a fix.
enum MarkdownAllConstructsLinter {
    static let allowedSchemes = MarkdownLintAndFormatEngine.allowedLinkSchemes

    static func diagnostics(index: MarkdownLineIndex, deadlineExceeded: () -> Bool) -> (diagnostics: [MarkdownLintDiagnostic], maskedLines: Int)? {
        let masked = YAMLFrontmatterScanner.maskedLineCount(in: index)
        var out: [MarkdownLintDiagnostic] = []
        let count = index.lineCount
        let maxLine = MarkdownLineIndex.maxLineUTF16

        func blank(_ i: Int) -> Bool { index.lineSlice(i).allSatisfy { $0 == 0x20 || $0 == 0x09 || $0 == 0x0D } }
        func add(_ rule: MarkdownLintRuleID, _ i: Int, _ message: String, _ range: TextRange, fix: TextEdit? = nil) {
            out.append(MarkdownLintDiagnostic(rule: rule, line: i + 1, message: message, range: range, quickFix: fix))
        }
        func lineStart(_ i: Int) -> Int { index.lineStarts[i] }
        func insertBlank(at i: Int) -> TextEdit { TextEdit(range: TextRange(location: lineStart(i), length: 0), replacement: "\n") }
        func isFenceBoundary(_ i: Int) -> Bool { index.isFenced(line: i) }

        var prevHeading = 0
        var inList = false
        var markerByIndent: [Int: UInt16] = [:]
        var orderedState: [Int: (first: Int, last: Int, onesStyle: Bool, items: Int)] = [:]
        var indentStack: [Int] = []
        var prevBlank = false
        var line = masked
        while line < count {
            if line % 256 == 0, deadlineExceeded() { return nil }
            let range = index.lineRange(line)
            let slice = index.lineSlice(line)
            let isBlankLine = blank(line)

            // Fenced code: only fence rules.
            if isFenceBoundary(line) {
                if let f = index.fences.first(where: { $0.open == line }) {
                    if line > masked, !blank(line - 1) { add(.blanksAroundFences, line, "Fenced code block should be surrounded by blank lines", range, fix: insertBlank(at: line)) }
                    var j = slice.startIndex
                    while j < slice.endIndex, slice[j] == 0x20 { j += 1 }
                    let ch = j < slice.endIndex ? slice[j] : 0
                    var k = j
                    while k < slice.endIndex, slice[k] == ch { k += 1 }
                    if slice[k...].allSatisfy({ $0 == 0x20 }) {
                        add(.missingFenceLanguage, line, "Fenced code block should declare a language", range,
                            fix: TextEdit(range: TextRange(location: range.location + (k - slice.startIndex), length: 0), replacement: "text"))
                    }
                    let closed = f.close > f.open
                    if closed, f.close + 1 < count, !blank(f.close + 1) {
                        add(.blanksAroundFences, f.close + 1, "Fenced code block should be surrounded by blank lines", index.lineRange(f.close + 1), fix: insertBlank(at: f.close + 1))
                    }
                }
                inList = false; markerByIndent = [:]; orderedState = [:]; indentStack = []; prevBlank = false
                line += 1
                continue
            }
            guard range.length <= maxLine else { prevBlank = false; line += 1; continue }

            // MD009 / MD010 / MD012
            var trailing = 0
            var e = slice.endIndex
            while e > slice.startIndex, slice[e - 1] == 0x20 { trailing += 1; e -= 1 }
            if trailing > 0, trailing != 2 || isBlankLine {
                add(.trailingSpaces, line, "Trailing spaces", TextRange(location: range.location + (e - slice.startIndex), length: trailing),
                    fix: TextEdit(range: TextRange(location: range.location + (e - slice.startIndex), length: trailing), replacement: ""))
            }
            if slice.contains(0x09) {
                let firstTab = slice.firstIndex(of: 0x09)! - slice.startIndex
                let lastTab = slice.lastIndex(of: 0x09)! - slice.startIndex
                let segment = String(decoding: slice[(slice.startIndex + firstTab)...(slice.startIndex + lastTab)], as: UTF16.self)
                add(.hardTabs, line, "Hard tabs", TextRange(location: range.location + firstTab, length: lastTab - firstTab + 1),
                    fix: TextEdit(range: TextRange(location: range.location + firstTab, length: lastTab - firstTab + 1),
                                  replacement: segment.replacingOccurrences(of: "\t", with: "    ")))
            }
            if isBlankLine {
                if prevBlank, line > masked {
                    let isLast = line == count - 1
                    let del = isLast
                        ? TextRange(location: max(0, range.location - 1), length: range.length + 1)
                        : TextRange(location: range.location, length: range.length + 1)
                    add(.multipleBlankLines, line, "Multiple consecutive blank lines", range, fix: TextEdit(range: del, replacement: ""))
                }
                prevBlank = true
                line += 1
                continue
            }
            let wasBlank = prevBlank
            prevBlank = false

            var idx = slice.startIndex
            while idx < slice.endIndex, slice[idx] == 0x20 { idx += 1 }
            let indent = idx - slice.startIndex
            let first = idx < slice.endIndex ? slice[idx] : 0

            // Tables.
            if first == 0x7C, indent < 4, line + 1 < count, GFMTableEditEngine.isDelimiterRow(GFMTableEditEngine.cells(index.lineSlice(line + 1))), !isFenceBoundary(line + 1) {
                if line > masked, !blank(line - 1) { add(.blanksAroundTables, line, "Tables should be surrounded by blank lines", range, fix: insertBlank(at: line)) }
                let headerCells = GFMTableEditEngine.cells(slice).count
                let headerEndsWithPipe = slice.last(where: { $0 != 0x20 }) == 0x7C
                var row = line
                while row < count, !isFenceBoundary(row), !blank(row), index.lineSlice(row).drop(while: { $0 == 0x20 }).first == 0x7C {
                    if row != line + 1 {
                        let rs = index.lineSlice(row)
                        let rr = index.lineRange(row)
                        let cells = GFMTableEditEngine.cells(rs).count
                        let endsWithPipe = rs.last(where: { $0 != 0x20 }) == 0x7C
                        if endsWithPipe != headerEndsWithPipe {
                            add(.tablePipeStyle, row, "Inconsistent table pipe style", rr)
                        }
                        if cells != headerCells {
                            var fix: TextEdit?
                            if cells < headerCells, endsWithPipe {
                                var end = rr.upperBound
                                while end > rr.location, index.units[end - 1] == 0x20 { end -= 1 }
                                fix = TextEdit(range: TextRange(location: end, length: 0), replacement: String(repeating: " |", count: headerCells - cells))
                            }
                            add(.tableColumnCountMismatch, row, "Table row has \(cells) cells but header has \(headerCells)", rr, fix: fix)
                        }
                    }
                    row += 1
                }
                if row < count, !blank(row) { add(.blanksAroundTables, row, "Tables should be surrounded by blank lines", index.lineRange(row), fix: insertBlank(at: row)) }
                inList = false; markerByIndent = [:]; orderedState = [:]; indentStack = []
                line = row
                continue
            }

            // Headings.
            if first == 0x23, indent < 4 {
                var level = 0
                var j = idx
                while j < slice.endIndex, slice[j] == 0x23 { level += 1; j += 1 }
                if level <= 6 {
                    let hashEnd = range.location + (j - slice.startIndex)
                    if j < slice.endIndex, slice[j] != 0x20, slice[j] != 0x09 {
                        add(.missingHeadingSpace, line, "ATX heading requires a space after '#' markers", range,
                            fix: TextEdit(range: TextRange(location: hashEnd, length: 0), replacement: " "))
                    } else {
                        var spaces = 0
                        var k = j
                        while k < slice.endIndex, slice[k] == 0x20 { spaces += 1; k += 1 }
                        if spaces > 1, k < slice.endIndex {
                            add(.multipleSpacesAfterHash, line, "Multiple spaces after heading '#'", range,
                                fix: TextEdit(range: TextRange(location: hashEnd, length: spaces), replacement: " "))
                        }
                    }
                    if j >= slice.endIndex || slice[j] == 0x20 || slice[j] == 0x09 || slice[j] != 0x20 {
                        if prevHeading > 0, level > prevHeading + 1 { add(.headingIncrement, line, "Heading level should increase by one", range) }
                        prevHeading = level
                        if line > masked, !blank(line - 1) { add(.blanksAroundHeadings, line, "Headings should be surrounded by blank lines", range, fix: insertBlank(at: line)) }
                        if line + 1 < count, !blank(line + 1) { add(.blanksAroundHeadings, line, "Headings should be surrounded by blank lines", range, fix: insertBlank(at: line + 1)) }
                    }
                    inList = false; markerByIndent = [:]; orderedState = [:]; indentStack = []
                    scanInline(slice, base: range.location, line: line, into: &out)
                    line += 1
                    continue
                }
            }

            // Blockquote.
            if first == 0x3E, indent < 4 {
                var j = idx + 1
                var spaces = 0
                while j < slice.endIndex, slice[j] == 0x20 { spaces += 1; j += 1 }
                if spaces > 1, j < slice.endIndex {
                    add(.multipleSpacesAfterBlockquote, line, "Multiple spaces after blockquote symbol", range,
                        fix: TextEdit(range: TextRange(location: range.location + (idx + 1 - slice.startIndex), length: spaces), replacement: " "))
                }
                scanInline(slice, base: range.location, line: line, into: &out)
                line += 1
                continue
            }

            // Lists.
            if let item = MarkdownListGrammar.parseListLine(slice) {
                let base = range.location
                let markerPos = base + item.indent
                // MD032: list start needs a preceding blank line (root lists only).
                if item.indent == 0, !inList, line > masked, !wasBlank, !blank(line - 1) {
                    add(.blanksAroundLists, line, "Lists should be surrounded by blank lines", range, fix: insertBlank(at: line))
                }
                inList = true
                // MD030
                let contentStart = item.prefixLength
                if contentStart < slice.count, slice[slice.startIndex + contentStart] == 0x20, item.markerLength < 6 {
                    var spaces = 0
                    var k = slice.startIndex + contentStart
                    while k < slice.endIndex, slice[k] == 0x20 { spaces += 1; k += 1 }
                    if k < slice.endIndex {
                        add(.listMarkerSpacing, line, "Multiple spaces after list marker", range,
                            fix: TextEdit(range: TextRange(location: base + contentStart, length: spaces), replacement: ""))
                    }
                }
                // Indent bookkeeping (MD005 / MD007).
                while let top = indentStack.last, top > item.indent { indentStack.removeLast() }
                markerByIndent = markerByIndent.filter { $0.key <= item.indent }
                orderedState = orderedState.filter { $0.key <= item.indent }
                if let top = indentStack.last, top < item.indent, item.indent != top + 4, item.indent % 4 == 0 {
                    // multi-level jump handled by MD007 only
                } else if let top = indentStack.last, top != item.indent, item.indent < top {
                    add(.inconsistentListIndent, line, "Inconsistent list item indentation", range)
                }
                if indentStack.last != item.indent {
                    if let top = indentStack.last, top > item.indent { add(.inconsistentListIndent, line, "Inconsistent list item indentation", range) }
                    indentStack.append(item.indent)
                }
                switch item.kind {
                case .bullet(let marker, let state):
                    if item.indent % 4 != 0 { add(.listIndentStep, line, "Nested list indentation should be a multiple of 4 spaces", range) }
                    if let existing = markerByIndent[item.indent], existing != marker {
                        add(.listMarkerStyle, line, "List marker style should be consistent", range,
                            fix: TextEdit(range: TextRange(location: markerPos, length: 1), replacement: String(UnicodeScalar(UInt8(truncatingIfNeeded: existing)))))
                    } else if markerByIndent[item.indent] == nil { markerByIndent[item.indent] = marker }
                    if state == nil {
                        let c = slice.startIndex + item.prefixLength
                        if c < slice.endIndex, slice[c] == 0x5B {
                            var close = c + 1
                            while close < slice.endIndex, close <= c + 3, slice[close] != 0x5D { close += 1 }
                            if close < slice.endIndex, slice[close] == 0x5D, close + 1 == slice.endIndex || slice[close + 1] == 0x20 {
                                add(.malformedTaskCheckbox, line, "Task checkbox must be [ ], [x] or [X]", TextRange(location: base + (c - slice.startIndex), length: close - c + 1))
                            }
                        }
                    }
                case .ordered(let number, _):
                    var expected = number
                    if var st = orderedState[item.indent] {
                        if st.items == 1 { st.onesStyle = (st.first == 1 && number == 1) }
                        expected = st.onesStyle ? 1 : st.last + 1
                        st.items += 1
                        st.last = expected
                        orderedState[item.indent] = st
                    } else {
                        orderedState[item.indent] = (number, number, false, 1)
                    }
                    if expected != number {
                        let digits = item.markerLength - 2
                        add(.orderedListPrefix, line, "Ordered list item prefix should be \(expected)", range,
                            fix: TextEdit(range: TextRange(location: markerPos, length: digits), replacement: String(expected)))
                    }
                }
                scanInline(slice, base: range.location, line: line, into: &out)
                line += 1
                continue
            }

            // Paragraph / continuation.
            if inList, indent >= 2 {
                scanInline(slice, base: range.location, line: line, into: &out)
                line += 1
                continue
            }
            if inList, !wasBlank, indent < 2, line > masked {
                add(.blanksAroundLists, line, "Lists should be surrounded by blank lines", range, fix: insertBlank(at: line))
            }
            inList = false; markerByIndent = [:]; orderedState = [:]; indentStack = []
            scanInline(slice, base: range.location, line: line, into: &out)
            line += 1
        }
        return (out, masked)
    }

    // MARK: Inline links and images (hardened)

    private static func scanInline(_ slice: ArraySlice<UInt16>, base: Int, line: Int, into out: inout [MarkdownLintDiagnostic]) {
        let start = slice.startIndex
        var i = start
        while i < slice.endIndex {
            if slice[i] == 0x60 { // skip inline code
                if let close = slice[(i + 1)...].firstIndex(of: 0x60) { i = close + 1; continue }
                break
            }
            let isImage = slice[i] == 0x21 && i + 1 < slice.endIndex && slice[i + 1] == 0x5B
            if slice[i] == 0x5B || isImage {
                let open = isImage ? i + 1 : i
                var close = open + 1
                var depth = 1
                while close < slice.endIndex {
                    if slice[close] == 0x5B { depth += 1 } else if slice[close] == 0x5D { depth -= 1; if depth == 0 { break } }
                    close += 1
                }
                if close < slice.endIndex, close + 1 < slice.endIndex, slice[close + 1] == 0x28 {
                    var p = close + 2
                    var pd = 1
                    while p < slice.endIndex {
                        if slice[p] == 0x28 { pd += 1 } else if slice[p] == 0x29 { pd -= 1; if pd == 0 { break } }
                        p += 1
                    }
                    if p < slice.endIndex {
                        let spanStart = isImage ? i : open
                        let range = TextRange(location: base + (spanStart - start), length: p - spanStart + 1)
                        let alt = String(decoding: slice[(open + 1)..<close], as: UTF16.self).trimmingCharacters(in: .whitespaces)
                        let raw = String(decoding: slice[(close + 2)..<p], as: UTF16.self)
                        let dest = destination(raw)
                        if isImage, alt.isEmpty {
                            out.append(MarkdownLintDiagnostic(rule: .missingImageAltText, line: line + 1, message: "Images should have alternate text", range: range))
                        }
                        if !isImage, dest.isEmpty {
                            out.append(MarkdownLintDiagnostic(rule: .emptyLinkTarget, line: line + 1, message: "Link target is empty", range: range))
                        }
                        let normalized = normalize(dest)
                        if hasUnsafeScheme(normalized) {
                            out.append(MarkdownLintDiagnostic(rule: .unsafeLinkScheme, line: line + 1, message: "Unsafe link scheme", range: range))
                        }
                        if isImage, hasUnsafeImagePath(normalized) {
                            out.append(MarkdownLintDiagnostic(rule: .unsafeImagePath, line: line + 1, message: "Unsafe image path", range: range))
                        }
                        i = p + 1
                        continue
                    }
                }
            }
            i += 1
        }
    }

    private static func destination(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("<"), let end = s.firstIndex(of: ">") { return String(s[s.index(after: s.startIndex)..<end]) }
        if let space = s.firstIndex(where: { $0 == " " || $0 == "\t" }) { s = String(s[..<space]) }
        return s
    }

    /// Percent- and HTML-entity-decodes (bounded), strips control/C1/zero-width/BiDi scalars, and lowercases for scheme and path classification (`SEC-LINT-01`).
    static func normalize(_ input: String) -> String {
        var s = input
        for _ in 0..<2 { s = s.removingPercentEncoding ?? s }
        s = decodeEntities(s)
        let stripped = s.unicodeScalars.filter { u in
            let v = u.value
            if v < 0x20 || (v >= 0x7F && v <= 0x9F) { return false }
            if (v >= 0x200B && v <= 0x200F) || (v >= 0x202A && v <= 0x202E) || (v >= 0x2060 && v <= 0x2069) || v == 0xFEFF || v == 0x061C { return false }
            return true
        }
        var view = String.UnicodeScalarView()
        view.append(contentsOf: stripped)
        return String(view).lowercased()
    }

    private static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var result = ""
        var rest = Substring(s)
        while let amp = rest.firstIndex(of: "&") {
            result += rest[..<amp]
            let tail = rest[amp...]
            if let semi = tail.firstIndex(of: ";"), tail.distance(from: tail.startIndex, to: semi) <= 10 {
                let name = String(tail[tail.index(after: tail.startIndex)..<semi])
                var decoded: String?
                if name.hasPrefix("#x") || name.hasPrefix("#X"), let v = UInt32(name.dropFirst(2), radix: 16), let u = UnicodeScalar(v) { decoded = String(Character(u)) }
                else if name.hasPrefix("#"), let v = UInt32(name.dropFirst()), let u = UnicodeScalar(v) { decoded = String(Character(u)) }
                else if name == "colon" { decoded = ":" } else if name == "tab" || name == "newline" { decoded = "" }
                else if name == "amp" { decoded = "&" } else if name == "sol" { decoded = "/" }
                if let decoded { result += decoded; rest = tail[tail.index(after: semi)...]; continue }
            }
            result.append("&")
            rest = tail.dropFirst()
        }
        result += rest
        return result
    }

    private static func hasUnsafeScheme(_ s: String) -> Bool {
        if s.hasPrefix("//") { return true }
        var scheme = ""
        for ch in s {
            if ch == ":" { return !scheme.isEmpty && !allowedSchemes.contains(scheme) }
            if ch == "/" || ch == "?" || ch == "#" { return false }
            guard ch.isLetter || ch.isNumber || ch == "+" || ch == "." || ch == "-" else { return false }
            scheme.append(ch)
        }
        return false
    }

    private static func hasUnsafeImagePath(_ s: String) -> Bool {
        let path = String(s.prefix(while: { $0 != "?" && $0 != "#" }))
        if path.hasSuffix(".svg") || path.hasSuffix(".svgz") { return true }
        if path.contains("://") || path.hasPrefix("mailto:") { return false }
        return path.hasPrefix("/") || path.contains("\\") || path == ".." || path.hasPrefix("../") || path.contains("/../") || path.hasPrefix("..\\")
    }
}
