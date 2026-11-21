import Foundation

/// Single-pass line scanner implementing the `.allConstructs` rule catalog on a shared `MarkdownLineIndex` (`BC-004`, `SEC-004`, `SEC-012`).
///
/// Frontmatter lines are skipped, fenced interiors only receive fence rules, lines over `4096` UTF-16 units are opaque, and every fixable finding carries a minimal `TextEdit`. Security rules (`.unsafeLinkScheme`, `.unsafeImagePath`, `.emptyLinkTarget`) never carry a fix.
enum MarkdownAllConstructsLinter {
    static let allowedSchemes = MarkdownLintAndFormatEngine.allowedLinkSchemes

    static func diagnostics(index: MarkdownLineIndex, deadlineExceeded: () -> Bool) -> (diagnostics: [MarkdownLintDiagnostic], maskedLines: Int)? {
        diagnostics(index: index, securityOnly: false, deadlineExceeded: deadlineExceeded)
    }

    /// Bounded linear scanner retaining only security URI/image rules (`.unsafeLinkScheme`, `.unsafeImagePath`, `.emptyLinkTarget`) for large non-degraded documents (`PERF-006`, `N11`).
    static func securityOnlyDiagnostics(index: MarkdownLineIndex, deadlineExceeded: () -> Bool) -> (diagnostics: [MarkdownLintDiagnostic], maskedLines: Int)? {
        diagnostics(index: index, securityOnly: true, deadlineExceeded: deadlineExceeded)
    }

    /// Zero-index single-pass UTF-8 byte streamer for `securityOnly` URI scanning (`< 5 ms` on `~1 MB` Debug buffers without allocating `MarkdownLineIndex`) (`PERF-006`, `N11`, `SEC-004`).
    static func securityOnlyDiagnostics(text: String, deadlineExceeded: () -> Bool) -> [MarkdownLintDiagnostic]? {
        var mutableText = text
        return mutableText.withUTF8 { buffer in
            scanSecurityUTF8(buffer, deadlineExceeded: deadlineExceeded)
        }
    }

    private static func scanSecurityUTF8(
        _ buffer: UnsafeBufferPointer<UInt8>,
        deadlineExceeded: () -> Bool
    ) -> [MarkdownLintDiagnostic]? {
        let count = buffer.count
        guard count > 0 else { return [] }
        let maxLine = MarkdownLineIndex.maxLineUTF16

        // 1. Resolve YAML frontmatter mask length (at most 200 lines) only if line 0 opens with '---'.
        let maskedLines = detectYAMLFrontmatterMaskedLinesUTF8(buffer)

        var out: [MarkdownLintDiagnostic] = []
        var openFence: (char: UInt8, count: Int)?
        var lineIndex = 0
        var pos = 0
        var utf16Cursor = 0

        while pos < count {
            if lineIndex % 256 == 0, deadlineExceeded() { return nil }

            let lineStartByte = pos
            let lineStartUTF16 = utf16Cursor
            var sawBracket = false
            var sawParen = false

            while pos < count {
                let b = buffer[pos]
                if b == 0x0A { break }
                if b == 0x5B { sawBracket = true } else if b == 0x28 { sawParen = true }
                if b < 0x80 {
                    utf16Cursor += 1
                } else if b >= 0xF0 {
                    utf16Cursor += 2
                } else if b >= 0xC0 {
                    utf16Cursor += 1
                }
                pos += 1
            }

            let lineEndByte = pos
            let lineUTF16Len = utf16Cursor - lineStartUTF16

            // Consume trailing '\n'
            if pos < count && buffer[pos] == 0x0A {
                pos += 1
                utf16Cursor += 1
            }

            if lineIndex >= maskedLines {
                let lineSlice = UnsafeBufferPointer(rebasing: buffer[lineStartByte..<lineEndByte])
                if let fence = openFence {
                    if isClosingFenceUTF8(lineSlice, char: fence.char, minCount: fence.count) {
                        openFence = nil
                    }
                } else if let opened = fenceOpeningUTF8(lineSlice) {
                    openFence = opened
                } else if sawBracket && sawParen && lineUTF16Len <= maxLine {
                    let lineString = String(decoding: lineSlice, as: UTF8.self)
                    let utf16Line = Array(lineString.utf16)
                    scanInline(utf16Line[...], base: lineStartUTF16, line: lineIndex, securityOnly: true, into: &out)
                }
            }

            lineIndex += 1
        }
        return out
    }

    private static func detectYAMLFrontmatterMaskedLinesUTF8(_ buffer: UnsafeBufferPointer<UInt8>) -> Int {
        func lineBounds(from start: Int) -> (slice: UnsafeBufferPointer<UInt8>, nextStart: Int)? {
            guard start < buffer.count else { return nil }
            var end = start
            while end < buffer.count && buffer[end] != 0x0A { end += 1 }
            let next = end < buffer.count ? end + 1 : end
            return (UnsafeBufferPointer(rebasing: buffer[start..<end]), next)
        }
        func isYAMLDelimiter(_ slice: UnsafeBufferPointer<UInt8>, opening: Bool) -> Bool {
            var end = slice.count
            while end > 0 && (slice[end - 1] == 0x20 || slice[end - 1] == 0x0D) { end -= 1 }
            guard end == 3 else { return false }
            if slice[0] == 0x2D && slice[1] == 0x2D && slice[2] == 0x2D { return true }
            return !opening && slice[0] == 0x2E && slice[1] == 0x2E && slice[2] == 0x2E
        }
        guard let first = lineBounds(from: 0),
              first.nextStart < buffer.count,
              isYAMLDelimiter(first.slice, opening: true) else {
            return 0
        }
        var cursor = first.nextStart
        var line = 1
        while line <= YAMLFrontmatterScanner.maxLines, let nextLine = lineBounds(from: cursor) {
            if isYAMLDelimiter(nextLine.slice, opening: false) {
                return line + 1
            }
            if nextLine.nextStart == cursor { break }
            cursor = nextLine.nextStart
            line += 1
        }
        return 0
    }

    private static func fenceOpeningUTF8(_ slice: UnsafeBufferPointer<UInt8>) -> (char: UInt8, count: Int)? {
        var idx = 0
        var spaces = 0
        while idx < slice.count && slice[idx] == 0x20 && spaces < 4 { idx += 1; spaces += 1 }
        guard spaces < 4, idx < slice.count, slice[idx] == 0x60 || slice[idx] == 0x7E else { return nil }
        let ch = slice[idx]
        var count = 0
        while idx < slice.count && slice[idx] == ch { idx += 1; count += 1 }
        guard count >= 3 else { return nil }
        if ch == 0x60 {
            var scan = idx
            while scan < slice.count {
                if slice[scan] == 0x60 { return nil }
                scan += 1
            }
        }
        return (ch, count)
    }

    private static func isClosingFenceUTF8(_ slice: UnsafeBufferPointer<UInt8>, char: UInt8, minCount: Int) -> Bool {
        var idx = 0
        var spaces = 0
        while idx < slice.count && slice[idx] == 0x20 && spaces < 4 { idx += 1; spaces += 1 }
        guard spaces < 4 else { return false }
        var count = 0
        while idx < slice.count && slice[idx] == char { idx += 1; count += 1 }
        guard count >= minCount else { return false }
        while idx < slice.count {
            if slice[idx] != 0x20 { return false }
            idx += 1
        }
        return true
    }

    private static func diagnostics(index: MarkdownLineIndex, securityOnly: Bool, deadlineExceeded: () -> Bool) -> (diagnostics: [MarkdownLintDiagnostic], maskedLines: Int)? {
        let masked = YAMLFrontmatterScanner.maskedLineCount(in: index)
        var out: [MarkdownLintDiagnostic] = []
        let count = index.lineCount
        let maxLine = MarkdownLineIndex.maxLineUTF16
        let fences = index.fences
        var fenceCursor = 0

        func currentFence(at line: Int) -> (open: Int, close: Int)? {
            while fenceCursor < fences.count && fences[fenceCursor].close < line {
                fenceCursor += 1
            }
            if fenceCursor < fences.count && fences[fenceCursor].open <= line {
                return fences[fenceCursor]
            }
            return nil
        }

        func blank(_ i: Int) -> Bool { index.lineSlice(i).allSatisfy { $0 == 0x20 || $0 == 0x09 || $0 == 0x0D } }
        func add(_ rule: MarkdownLintRuleID, _ i: Int, _ message: String, _ range: TextRange, fix: TextEdit? = nil) {
            guard !securityOnly else { return }
            out.append(MarkdownLintDiagnostic(rule: rule, line: i + 1, message: message, range: range, quickFix: fix))
        }
        func lineStart(_ i: Int) -> Int { index.lineStarts[i] }
        func insertBlank(at i: Int) -> TextEdit { TextEdit(range: TextRange(location: lineStart(i), length: 0), replacement: "\n") }
        func resetListState() {
            guard inList else { return }
            inList = false
            markerByIndent.removeAll(keepingCapacity: true)
            orderedState.removeAll(keepingCapacity: true)
            indentStack.removeAll(keepingCapacity: true)
        }

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
            if securityOnly {
                if let f = currentFence(at: line) {
                    line = f.close + 1
                    continue
                }
                if range.length <= maxLine, slice.contains(0x28), slice.contains(0x5B) {
                    scanInline(slice, base: range.location, line: line, securityOnly: true, into: &out)
                }
                line += 1
                continue
            }
            let isBlankLine = blank(line)

            // Fenced code: only fence rules; jump directly past f.close in O(1) amortized.
            if let f = currentFence(at: line) {
                if f.open == line {
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
                resetListState()
                prevBlank = false
                line = f.close + 1
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
            if let firstTabIdx = slice.firstIndex(of: 0x09) {
                let firstTab = firstTabIdx - slice.startIndex
                let lastTab = slice.lastIndex(of: 0x09)! - slice.startIndex
                let segment = String(decoding: slice[firstTabIdx...(slice.startIndex + lastTab)], as: UTF16.self)
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
            if first == 0x7C, indent < 4, line + 1 < count, GFMTableEditEngine.isDelimiterRowSlice(index.lineSlice(line + 1)), currentFence(at: line + 1) == nil {
                if line > masked, !blank(line - 1) { add(.blanksAroundTables, line, "Tables should be surrounded by blank lines", range, fix: insertBlank(at: line)) }
                let headerCells = GFMTableEditEngine.cellCount(slice)
                let headerEndsWithPipe = slice.last(where: { $0 != 0x20 }) == 0x7C
                var row = line
                while row < count, currentFence(at: row) == nil, !blank(row), index.lineSlice(row).drop(while: { $0 == 0x20 }).first == 0x7C {
                    if row != line + 1 {
                        let rs = index.lineSlice(row)
                        let rr = index.lineRange(row)
                        let cells = GFMTableEditEngine.cellCount(rs)
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
                resetListState()
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
                    resetListState()
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
                // Indent bookkeeping (MD005 / MD007): prune popped indent keys in-place without reallocating dictionaries.
                while let top = indentStack.last, top > item.indent {
                    indentStack.removeLast()
                    markerByIndent.removeValue(forKey: top)
                    orderedState.removeValue(forKey: top)
                }
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
            resetListState()
            scanInline(slice, base: range.location, line: line, into: &out)
            line += 1
        }
        return (out, masked)
    }

    // MARK: Inline links and images (hardened, strictly O(L))

    private static func scanInline(_ slice: ArraySlice<UInt16>, base: Int, line: Int, securityOnly: Bool = false, into out: inout [MarkdownLintDiagnostic]) {
        let start = slice.startIndex
        let end = slice.endIndex
        let length = end - start
        guard length >= 4 else { return }

        // Fast-skip lines containing no `[` or `(` (vast majority of lines).
        var hasBracket = false
        var hasParen = false
        var k = start
        while k < end {
            let u = slice[k]
            if u == 0x5B { hasBracket = true }
            else if u == 0x28 { hasParen = true }
            if hasBracket && hasParen { break }
            k += 1
        }
        guard hasBracket && hasParen else { return }

        // Precompute balanced `[` -> `]` and `(` -> `)` matches in a single O(L) stack pass so adversarial `[[[[...` / `((((...` never goes O(L²).
        var matchBracket = Array(repeating: -1, count: length)
        var matchParen = Array(repeating: -1, count: length)
        var bracketStack: [Int] = []
        var parenStack: [Int] = []
        var idx = start
        while idx < end {
            let rel = idx - start
            let u = slice[idx]
            if u == 0x5B {
                bracketStack.append(rel)
            } else if u == 0x5D, let openRel = bracketStack.popLast() {
                matchBracket[openRel] = rel
            } else if u == 0x28 {
                parenStack.append(rel)
            } else if u == 0x29, let openRel = parenStack.popLast() {
                matchParen[openRel] = rel
            }
            idx += 1
        }

        var i = start
        while i < end {
            if slice[i] == 0x60 { // skip inline code
                if let close = slice[(i + 1)...].firstIndex(of: 0x60) { i = close + 1; continue }
                break
            }
            let isImage = slice[i] == 0x21 && i + 1 < end && slice[i + 1] == 0x5B
            if slice[i] == 0x5B || isImage {
                let open = isImage ? i + 1 : i
                let closeRel = matchBracket[open - start]
                if closeRel >= 0 {
                    let close = start + closeRel
                    if close + 1 < end, slice[close + 1] == 0x28 {
                        let pRel = matchParen[close + 1 - start]
                        if pRel >= 0 {
                            let p = start + pRel
                            let spanStart = isImage ? i : open
                            let range = TextRange(location: base + (spanStart - start), length: p - spanStart + 1)
                            let raw = String(decoding: slice[(close + 2)..<p], as: UTF16.self)
                            let dest = destination(raw)
                            if !securityOnly, isImage {
                                let alt = String(decoding: slice[(open + 1)..<close], as: UTF16.self).trimmingCharacters(in: .whitespaces)
                                if alt.isEmpty {
                                    out.append(MarkdownLintDiagnostic(rule: .missingImageAltText, line: line + 1, message: "Images should have alternate text", range: range))
                                }
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
        // Fast-path clean lowercase ASCII URIs with no `%`, `&`, control bytes, or uppercase letters.
        var needsDecodeOrClean = false
        for b in s.utf8 {
            if b < 0x20 || b >= 0x7F || b == 0x25 || b == 0x26 || (b >= 0x41 && b <= 0x5A) {
                needsDecodeOrClean = true
                break
            }
        }
        if !needsDecodeOrClean { return s }

        if s.utf8.contains(0x25) {
            for _ in 0..<2 {
                let decoded = s.removingPercentEncoding ?? s
                if decoded == s { break }
                s = decoded
            }
        }
        s = decodeEntities(s)
        var view = String.UnicodeScalarView()
        view.reserveCapacity(s.utf8.count)
        for u in s.unicodeScalars {
            let v = u.value
            if v < 0x20 || (v >= 0x7F && v <= 0x9F) { continue }
            if (v >= 0x200B && v <= 0x200F) || (v >= 0x202A && v <= 0x202E) || (v >= 0x2060 && v <= 0x2069) || v == 0xFEFF || v == 0x061C { continue }
            view.append(u)
        }
        return String(view).lowercased()
    }

    private static func decodeEntities(_ s: String) -> String {
        guard s.utf8.contains(0x26) else { return s }
        var result = ""
        result.reserveCapacity(s.utf8.count)
        var rest = Substring(s)
        while let amp = rest.firstIndex(of: "&") {
            result += rest[..<amp]
            let tail = rest[amp...]
            // Bounded lookahead of at most 10 characters to prevent O(L²) scans on query strings with many '&'.
            var semi: Substring.Index?
            var cursor = tail.index(after: tail.startIndex)
            var steps = 1
            while cursor < tail.endIndex && steps <= 10 {
                if tail[cursor] == ";" {
                    semi = cursor
                    break
                }
                cursor = tail.index(after: cursor)
                steps += 1
            }
            if let semi {
                let name = tail[tail.index(after: tail.startIndex)..<semi]
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
        var idx = s.startIndex
        while idx < s.endIndex {
            let ch = s[idx]
            if ch == ":" {
                guard idx > s.startIndex else { return false }
                let scheme = String(s[..<idx])
                return !allowedSchemes.contains(scheme)
            }
            if ch == "/" || ch == "?" || ch == "#" { return false }
            guard ch.isLetter || ch.isNumber || ch == "+" || ch == "." || ch == "-" else { return false }
            idx = s.index(after: idx)
        }
        return false
    }

    private static func hasUnsafeImagePath(_ s: String) -> Bool {
        let end = s.firstIndex(where: { $0 == "?" || $0 == "#" }) ?? s.endIndex
        let path = s[..<end]
        if path.hasSuffix(".svg") || path.hasSuffix(".svgz") { return true }
        if path.contains("://") || path.hasPrefix("mailto:") { return false }
        return path.hasPrefix("/") || path.contains("\\") || path == ".." || path.hasPrefix("../") || path.contains("/../") || path.hasPrefix("..\\")
    }
}
