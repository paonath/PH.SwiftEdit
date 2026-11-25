import Foundation

/// Mutable single-pass state shared across decomposed Markdown linter rule-family evaluators.
struct MarkdownLinterPassContext {
    let index: MarkdownLineIndex
    let masked: Int
    let securityOnly: Bool
    var fenceCursor: Int = 0
    var prevHeading: Int = 0
    var inList: Bool = false
    var markerByIndent: [Int: UInt16] = [:]
    var orderedState: [Int: (first: Int, last: Int, onesStyle: Bool, items: Int)] = [:]
    var indentStack: [Int] = []
    var prevBlank: Bool = false
    var scratch = MarkdownAllConstructsLinter.InlineScanScratch()
    var out: [MarkdownLintDiagnostic] = []

    init(index: MarkdownLineIndex, masked: Int, securityOnly: Bool) {
        self.index = index
        self.masked = masked
        self.securityOnly = securityOnly
    }

    mutating func currentFence(at line: Int) -> (open: Int, close: Int)? {
        let fences = index.fences
        while fenceCursor < fences.count && fences[fenceCursor].close < line {
            fenceCursor += 1
        }
        if fenceCursor < fences.count && fences[fenceCursor].open <= line {
            return fences[fenceCursor]
        }
        return nil
    }

    func isBlank(_ line: Int) -> Bool {
        index.lineSlice(line).allSatisfy { $0 == 0x20 || $0 == 0x09 || $0 == 0x0D }
    }

    func lineStart(_ line: Int) -> Int {
        index.lineStarts[line]
    }

    func insertBlank(at line: Int) -> TextEdit {
        TextEdit(range: TextRange(location: lineStart(line), length: 0), replacement: "\n")
    }

    mutating func add(
        _ rule: MarkdownLintRuleID,
        _ line: Int,
        _ message: String,
        _ range: TextRange,
        fix: TextEdit? = nil
    ) {
        guard !securityOnly else { return }
        out.append(MarkdownLintDiagnostic(rule: rule, line: line + 1, message: message, range: range, quickFix: fix))
    }

    mutating func resetListState() {
        guard inList else { return }
        inList = false
        markerByIndent.removeAll(keepingCapacity: true)
        orderedState.removeAll(keepingCapacity: true)
        indentStack.removeAll(keepingCapacity: true)
    }
}

/// Pure rule-family pass evaluators decomposed from `MarkdownAllConstructsLinter.diagnostics`
/// to keep per-method cyclomatic complexity bounded (`<= 15`) while preserving zero-allocation scans.
enum MarkdownLinterRuleFamilyPasses {

    /// Evaluates fenced code block surrounding-blank and info-string rules (`MD031`, `MD040`)
    /// and returns the next line index strictly past the closing fence.
    static func evaluateFenceBlock(
        at line: Int,
        range: TextRange,
        slice: ArraySlice<UInt16>,
        fence: (open: Int, close: Int),
        context: inout MarkdownLinterPassContext
    ) -> Int {
        if fence.open == line {
            if line > context.masked, !context.isBlank(line - 1) {
                context.add(.blanksAroundFences, line, "Fenced code block should be surrounded by blank lines", range, fix: context.insertBlank(at: line))
            }
            var j = slice.startIndex
            while j < slice.endIndex, slice[j] == 0x20 { j += 1 }
            let ch = j < slice.endIndex ? slice[j] : 0
            var k = j
            while k < slice.endIndex, slice[k] == ch { k += 1 }
            if slice[k...].allSatisfy({ $0 == 0x20 }) {
                context.add(
                    .missingFenceLanguage,
                    line,
                    "Fenced code block should declare a language",
                    range,
                    fix: TextEdit(range: TextRange(location: range.location + (k - slice.startIndex), length: 0), replacement: "text")
                )
            }
            let closed = fence.close > fence.open
            if closed, fence.close + 1 < context.index.lineCount, !context.isBlank(fence.close + 1) {
                context.add(
                    .blanksAroundFences,
                    fence.close + 1,
                    "Fenced code block should be surrounded by blank lines",
                    context.index.lineRange(fence.close + 1),
                    fix: context.insertBlank(at: fence.close + 1)
                )
            }
        }
        context.resetListState()
        context.prevBlank = false
        return fence.close + 1
    }

    /// Evaluates trailing-space, hard-tab, and consecutive-blank-line rules (`MD009`, `MD010`, `MD012`).
    /// Returns `true` when the line is blank and the caller should advance directly to the next line.
    static func evaluateWhitespaceAndBlankLine(
        at line: Int,
        range: TextRange,
        slice: ArraySlice<UInt16>,
        isBlankLine: Bool,
        context: inout MarkdownLinterPassContext
    ) -> Bool {
        var trailing = 0
        var end = slice.endIndex
        while end > slice.startIndex, slice[end - 1] == 0x20 {
            trailing += 1
            end -= 1
        }
        if trailing > 0, trailing != 2 || isBlankLine {
            let offset = range.location + (end - slice.startIndex)
            context.add(
                .trailingSpaces,
                line,
                "Trailing spaces",
                TextRange(location: offset, length: trailing),
                fix: TextEdit(range: TextRange(location: offset, length: trailing), replacement: "")
            )
        }
        if let firstTabIdx = slice.firstIndex(of: 0x09) {
            let firstTab = firstTabIdx - slice.startIndex
            let lastTab = slice.lastIndex(of: 0x09)! - slice.startIndex
            let segment = String(decoding: slice[firstTabIdx...(slice.startIndex + lastTab)], as: UTF16.self)
            context.add(
                .hardTabs,
                line,
                "Hard tabs",
                TextRange(location: range.location + firstTab, length: lastTab - firstTab + 1),
                fix: TextEdit(
                    range: TextRange(location: range.location + firstTab, length: lastTab - firstTab + 1),
                    replacement: segment.replacingOccurrences(of: "\t", with: "    ")
                )
            )
        }
        guard isBlankLine else { return false }
        if context.prevBlank, line > context.masked {
            let isLast = line == context.index.lineCount - 1
            let del = isLast
                ? TextRange(location: max(0, range.location - 1), length: range.length + 1)
                : TextRange(location: range.location, length: range.length + 1)
            context.add(.multipleBlankLines, line, "Multiple consecutive blank lines", range, fix: TextEdit(range: del, replacement: ""))
        }
        context.prevBlank = true
        return true
    }

    /// Evaluates GFM pipe table surrounding blanks, pipe style, and column count consistency.
    /// Returns the next line index after the table when matched, or `nil` if the line does not start a table.
    static func evaluateTableBlock(
        at line: Int,
        range: TextRange,
        slice: ArraySlice<UInt16>,
        first: UInt16,
        indent: Int,
        context: inout MarkdownLinterPassContext
    ) -> Int? {
        let count = context.index.lineCount
        guard first == 0x7C,
              indent < 4,
              line + 1 < count,
              GFMTableEditEngine.isDelimiterRowSlice(context.index.lineSlice(line + 1)),
              context.currentFence(at: line + 1) == nil
        else { return nil }

        if line > context.masked, !context.isBlank(line - 1) {
            context.add(.blanksAroundTables, line, "Tables should be surrounded by blank lines", range, fix: context.insertBlank(at: line))
        }
        let headerCells = GFMTableEditEngine.cellCount(slice)
        let headerEndsWithPipe = slice.last(where: { $0 != 0x20 }) == 0x7C
        var row = line
        while row < count,
              context.currentFence(at: row) == nil,
              !context.isBlank(row),
              context.index.lineSlice(row).drop(while: { $0 == 0x20 }).first == 0x7C {
            if row != line + 1 {
                evaluateTableRow(row: row, headerCells: headerCells, headerEndsWithPipe: headerEndsWithPipe, context: &context)
            }
            row += 1
        }
        if row < count, !context.isBlank(row) {
            context.add(.blanksAroundTables, row, "Tables should be surrounded by blank lines", context.index.lineRange(row), fix: context.insertBlank(at: row))
        }
        context.resetListState()
        return row
    }

    private static func evaluateTableRow(
        row: Int,
        headerCells: Int,
        headerEndsWithPipe: Bool,
        context: inout MarkdownLinterPassContext
    ) {
        let rs = context.index.lineSlice(row)
        let rr = context.index.lineRange(row)
        let cells = GFMTableEditEngine.cellCount(rs)
        let endsWithPipe = rs.last(where: { $0 != 0x20 }) == 0x7C
        if endsWithPipe != headerEndsWithPipe {
            context.add(.tablePipeStyle, row, "Inconsistent table pipe style", rr)
        }
        if cells != headerCells {
            var fix: TextEdit?
            if cells < headerCells, endsWithPipe {
                var end = rr.upperBound
                while end > rr.location, context.index.units[end - 1] == 0x20 { end -= 1 }
                fix = TextEdit(range: TextRange(location: end, length: 0), replacement: String(repeating: " |", count: headerCells - cells))
            }
            context.add(.tableColumnCountMismatch, row, "Table row has \(cells) cells but header has \(headerCells)", rr, fix: fix)
        }
    }

    /// Evaluates ATX heading spacing, level increment, and surrounding blank lines.
    static func evaluateHeadingLine(
        at line: Int,
        range: TextRange,
        slice: ArraySlice<UInt16>,
        first: UInt16,
        indent: Int,
        idx: ArraySlice<UInt16>.Index,
        context: inout MarkdownLinterPassContext
    ) -> Bool {
        guard first == 0x23, indent < 4 else { return false }
        var level = 0
        var afterHashes = idx
        while afterHashes < slice.endIndex, slice[afterHashes] == 0x23 { level += 1; afterHashes += 1 }
        guard level <= 6 else { return false }

        evaluateHeadingSpacing(at: line, range: range, slice: slice, afterHashes: afterHashes, context: &context)
        evaluateHeadingSurroundingRules(at: line, range: range, level: level, context: &context)
        context.resetListState()
        MarkdownAllConstructsLinter.scanInline(slice, base: range.location, line: line, scratch: &context.scratch, into: &context.out)
        return true
    }

    private static func evaluateHeadingSpacing(
        at line: Int,
        range: TextRange,
        slice: ArraySlice<UInt16>,
        afterHashes: ArraySlice<UInt16>.Index,
        context: inout MarkdownLinterPassContext
    ) {
        guard afterHashes < slice.endIndex else { return }
        let hashEnd = range.location + (afterHashes - slice.startIndex)
        let firstAfter = slice[afterHashes]
        if firstAfter != 0x20, firstAfter != 0x09 {
            context.add(
                .missingHeadingSpace,
                line,
                "ATX heading requires a space after '#' markers",
                range,
                fix: TextEdit(range: TextRange(location: hashEnd, length: 0), replacement: " ")
            )
            return
        }
        var spaces = 0
        var k = afterHashes
        while k < slice.endIndex, slice[k] == 0x20 { spaces += 1; k += 1 }
        if spaces > 1, k < slice.endIndex {
            context.add(
                .multipleSpacesAfterHash,
                line,
                "Multiple spaces after heading '#'",
                range,
                fix: TextEdit(range: TextRange(location: hashEnd, length: spaces), replacement: " ")
            )
        }
    }

    private static func evaluateHeadingSurroundingRules(
        at line: Int,
        range: TextRange,
        level: Int,
        context: inout MarkdownLinterPassContext
    ) {
        if context.prevHeading > 0, level > context.prevHeading + 1 {
            context.add(.headingIncrement, line, "Heading level should increase by one", range)
        }
        context.prevHeading = level
        if line > context.masked, !context.isBlank(line - 1) {
            context.add(.blanksAroundHeadings, line, "Headings should be surrounded by blank lines", range, fix: context.insertBlank(at: line))
        }
        if line + 1 < context.index.lineCount, !context.isBlank(line + 1) {
            context.add(.blanksAroundHeadings, line, "Headings should be surrounded by blank lines", range, fix: context.insertBlank(at: line + 1))
        }
    }
}

extension MarkdownLinterRuleFamilyPasses {
    /// Evaluates blockquote marker spacing and inline constructs.
    static func evaluateBlockquoteLine(
        at line: Int,
        range: TextRange,
        slice: ArraySlice<UInt16>,
        first: UInt16,
        indent: Int,
        idx: ArraySlice<UInt16>.Index,
        context: inout MarkdownLinterPassContext
    ) -> Bool {
        guard first == 0x3E, indent < 4 else { return false }
        var j = idx + 1
        var spaces = 0
        while j < slice.endIndex, slice[j] == 0x20 { spaces += 1; j += 1 }
        if spaces > 1, j < slice.endIndex {
            context.add(
                .multipleSpacesAfterBlockquote,
                line,
                "Multiple spaces after blockquote symbol",
                range,
                fix: TextEdit(range: TextRange(location: range.location + (idx + 1 - slice.startIndex), length: spaces), replacement: " ")
            )
        }
        MarkdownAllConstructsLinter.scanInline(slice, base: range.location, line: line, scratch: &context.scratch, into: &context.out)
        return true
    }

    /// Evaluates bullet, task, and ordered list rules (`MD004`, `MD005`, `MD007`, `MD029`, `MD030`, `MD032`).
    static func evaluateListItemLine(
        at line: Int,
        range: TextRange,
        slice: ArraySlice<UInt16>,
        wasBlank: Bool,
        context: inout MarkdownLinterPassContext
    ) -> Bool {
        guard let item = MarkdownListGrammar.parseListLine(slice) else { return false }
        let base = range.location
        let markerPos = base + item.indent
        if item.indent == 0, !context.inList, line > context.masked, !wasBlank, !context.isBlank(line - 1) {
            context.add(.blanksAroundLists, line, "Lists should be surrounded by blank lines", range, fix: context.insertBlank(at: line))
        }
        context.inList = true
        evaluateListMarkerSpacing(item: item, line: line, base: base, range: range, slice: slice, context: &context)
        reconcileListIndentStack(indent: item.indent, line: line, range: range, context: &context)
        switch item.kind {
        case .bullet(let marker, let state):
            evaluateBulletListItem(item: item, marker: marker, state: state, line: line, base: base, markerPos: markerPos, range: range, slice: slice, context: &context)
        case .ordered(let number, _):
            evaluateOrderedListItem(item: item, number: number, line: line, markerPos: markerPos, range: range, context: &context)
        }
        MarkdownAllConstructsLinter.scanInline(slice, base: range.location, line: line, scratch: &context.scratch, into: &context.out)
        return true
    }

    private static func evaluateListMarkerSpacing(
        item: MarkdownListLine,
        line: Int,
        base: Int,
        range: TextRange,
        slice: ArraySlice<UInt16>,
        context: inout MarkdownLinterPassContext
    ) {
        let contentStart = item.prefixLength
        guard contentStart < slice.count, slice[slice.startIndex + contentStart] == 0x20, item.markerLength < 6 else { return }
        var spaces = 0
        var k = slice.startIndex + contentStart
        while k < slice.endIndex, slice[k] == 0x20 { spaces += 1; k += 1 }
        if k < slice.endIndex {
            context.add(
                .listMarkerSpacing,
                line,
                "Multiple spaces after list marker",
                range,
                fix: TextEdit(range: TextRange(location: base + contentStart, length: spaces), replacement: "")
            )
        }
    }

    private static func reconcileListIndentStack(
        indent: Int,
        line: Int,
        range: TextRange,
        context: inout MarkdownLinterPassContext
    ) {
        while let top = context.indentStack.last, top > indent {
            context.indentStack.removeLast()
            context.markerByIndent.removeValue(forKey: top)
            context.orderedState.removeValue(forKey: top)
        }
        if let top = context.indentStack.last, top != indent, indent < top {
            context.add(.inconsistentListIndent, line, "Inconsistent list item indentation", range)
        }
        if context.indentStack.last != indent {
            context.indentStack.append(indent)
        }
    }

    private static func evaluateBulletListItem(
        item: MarkdownListLine,
        marker: UInt16,
        state: UInt16?,
        line: Int,
        base: Int,
        markerPos: Int,
        range: TextRange,
        slice: ArraySlice<UInt16>,
        context: inout MarkdownLinterPassContext
    ) {
        if item.indent % 4 != 0 {
            context.add(.listIndentStep, line, "Nested list indentation should be a multiple of 4 spaces", range)
        }
        if let existing = context.markerByIndent[item.indent], existing != marker {
            context.add(
                .listMarkerStyle,
                line,
                "List marker style should be consistent",
                range,
                fix: TextEdit(range: TextRange(location: markerPos, length: 1), replacement: String(UnicodeScalar(UInt8(truncatingIfNeeded: existing))))
            )
        } else if context.markerByIndent[item.indent] == nil {
            context.markerByIndent[item.indent] = marker
        }
        guard state == nil else { return }
        let c = slice.startIndex + item.prefixLength
        guard c < slice.endIndex, slice[c] == 0x5B else { return }
        var close = c + 1
        while close < slice.endIndex, close <= c + 3, slice[close] != 0x5D { close += 1 }
        if close < slice.endIndex, slice[close] == 0x5D, close + 1 == slice.endIndex || slice[close + 1] == 0x20 {
            context.add(
                .malformedTaskCheckbox,
                line,
                "Task checkbox must be [ ], [x] or [X]",
                TextRange(location: base + (c - slice.startIndex), length: close - c + 1)
            )
        }
    }

    private static func evaluateOrderedListItem(
        item: MarkdownListLine,
        number: Int,
        line: Int,
        markerPos: Int,
        range: TextRange,
        context: inout MarkdownLinterPassContext
    ) {
        var expected = number
        if var st = context.orderedState[item.indent] {
            if st.items == 1 { st.onesStyle = (st.first == 1 && number == 1) }
            expected = st.onesStyle ? 1 : st.last + 1
            st.items += 1
            st.last = expected
            context.orderedState[item.indent] = st
        } else {
            context.orderedState[item.indent] = (number, number, false, 1)
        }
        if expected != number {
            let digits = item.markerLength - 2
            context.add(
                .orderedListPrefix,
                line,
                "Ordered list item prefix should be \(expected)",
                range,
                fix: TextEdit(range: TextRange(location: markerPos, length: digits), replacement: String(expected))
            )
        }
    }

    /// Evaluates paragraph lines, list continuations, and missing trailing blank lines after lists.
    static func evaluateParagraphLine(
        at line: Int,
        range: TextRange,
        slice: ArraySlice<UInt16>,
        indent: Int,
        wasBlank: Bool,
        context: inout MarkdownLinterPassContext
    ) {
        if context.inList, indent >= 2 {
            MarkdownAllConstructsLinter.scanInline(slice, base: range.location, line: line, scratch: &context.scratch, into: &context.out)
            return
        }
        if context.inList, !wasBlank, indent < 2, line > context.masked {
            context.add(.blanksAroundLists, line, "Lists should be surrounded by blank lines", range, fix: context.insertBlank(at: line))
        }
        context.resetListState()
        MarkdownAllConstructsLinter.scanInline(slice, base: range.location, line: line, scratch: &context.scratch, into: &context.out)
    }
}
