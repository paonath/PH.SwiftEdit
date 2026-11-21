import Foundation

/// Markdown authoring actions exposed by `CommandMenu("Markdown")` (`UI-007`).
public enum MarkdownAuthoringCommand: Equatable, Sendable {
    case bold, italic, strikethrough, inlineCode, codeFence, link, image, taskToggle, blockquote
    case heading(level: Int)
    case insertTable
}

/// Atomic edit batch for one authoring command; `newSelection` is expressed in post-edit coordinates (`BC-006`).
public struct MarkdownAuthoringEdit: Equatable, Sendable {
    public let edits: [TextEdit]
    public let newSelection: TextRange
    public init(edits: [TextEdit], newSelection: TextRange) { self.edits = edits; self.newSelection = newSelection }
}

/// Result of a table `Tab` request: `.notApplicable` defers to the next handler in the dispatch chain (list, then default).
public enum TableEditOutcome: Equatable, Sendable {
    case edit(MarkdownAuthoringEdit)
    case notApplicable
}

/// Pure single-batch Markdown authoring (`BC-004`, `BC-006`).
///
/// Binary, degraded and non-Markdown snapshots, selections inside fenced code, out-of-range selections and lines over `4096` UTF-16 units return `nil` so the caller never mutates quarantined or ambiguous text (`DATA-003`, `SEC-012`). Re-applying a wrapping command toggles it off.
public enum MarkdownAuthoringCommands {

    public static func evaluate(_ command: MarkdownAuthoringCommand, in snapshot: DocumentSnapshot, selection: TextRange, isMarkdownDocument: Bool) -> MarkdownAuthoringEdit? {
        guard isMarkdownDocument, !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText else { return nil }
        let text = snapshot.text as NSString
        guard selection.location >= 0, selection.length >= 0, selection.upperBound <= text.length else { return nil }
        let index = MarkdownLineIndex(text: snapshot.text)
        let firstLine = index.line(containing: selection.location)
        let lastLine = index.line(containing: selection.upperBound)
        for line in firstLine...lastLine {
            if index.isFenced(line: line) { return nil }
            if index.lineRange(line).length > MarkdownLineIndex.maxLineUTF16 { return nil }
        }
        switch command {
        case .bold: return wrap("**", text, selection)
        case .italic: return wrap("*", text, selection)
        case .strikethrough: return wrap("~~", text, selection)
        case .inlineCode: return wrap("`", text, selection)
        case .link: return bracketed(prefix: "[", suffix: "](url)", placeholder: "text", text, selection, selectsDestination: true)
        case .image: return bracketed(prefix: "![", suffix: "](src)", placeholder: "alt", text, selection, selectsDestination: true)
        case .heading(let level): return level >= 1 && level <= 6 ? heading(level, index, text, selection) : nil
        case .blockquote: return linePrefixToggle("> ", index, selection)
        case .taskToggle: return taskToggle(index, selection)
        case .codeFence: return fence(index, text, selection, firstLine, lastLine)
        case .insertTable:
            let table = "| Column 1 | Column 2 |\n| --- | --- |\n|  |  |"
            return MarkdownAuthoringEdit(edits: [TextEdit(range: selection, replacement: table)], newSelection: TextRange(location: selection.location + 2, length: 8))
        }
    }

    private static func wrap(_ marker: String, _ text: NSString, _ sel: TextRange) -> MarkdownAuthoringEdit {
        let m = (marker as NSString).length
        let selected = text.substring(with: NSRange(location: sel.location, length: sel.length))
        if sel.length >= 2 * m, selected.hasPrefix(marker), selected.hasSuffix(marker) {
            let inner = (selected as NSString).substring(with: NSRange(location: m, length: sel.length - 2 * m))
            return MarkdownAuthoringEdit(edits: [TextEdit(range: sel, replacement: inner)], newSelection: TextRange(location: sel.location, length: sel.length - 2 * m))
        }
        if sel.location >= m, sel.upperBound + m <= text.length,
           text.substring(with: NSRange(location: sel.location - m, length: m)) == marker,
           text.substring(with: NSRange(location: sel.upperBound, length: m)) == marker {
            let edits = [
                TextEdit(range: TextRange(location: sel.location - m, length: m), replacement: ""),
                TextEdit(range: TextRange(location: sel.upperBound, length: m), replacement: "")
            ]
            return MarkdownAuthoringEdit(edits: edits, newSelection: TextRange(location: sel.location - m, length: sel.length))
        }
        return MarkdownAuthoringEdit(edits: [TextEdit(range: sel, replacement: marker + selected + marker)], newSelection: TextRange(location: sel.location + m, length: sel.length))
    }

    private static func bracketed(prefix: String, suffix: String, placeholder: String, _ text: NSString, _ sel: TextRange, selectsDestination: Bool) -> MarkdownAuthoringEdit {
        let label = sel.length > 0 ? text.substring(with: NSRange(location: sel.location, length: sel.length)) : placeholder
        let labelLength = (label as NSString).length
        let destLocation = sel.location + (prefix as NSString).length + labelLength + 2
        return MarkdownAuthoringEdit(
            edits: [TextEdit(range: sel, replacement: prefix + label + suffix)],
            newSelection: TextRange(location: destLocation, length: (suffix as NSString).length - 3)
        )
    }

    private static func heading(_ level: Int, _ index: MarkdownLineIndex, _ text: NSString, _ sel: TextRange) -> MarkdownAuthoringEdit {
        let line = index.line(containing: sel.location)
        let range = index.lineRange(line)
        let slice = index.lineSlice(line)
        var hashes = 0
        var i = slice.startIndex
        while i < slice.endIndex, slice[i] == 0x23 { hashes += 1; i += 1 }
        var existing = 0
        if hashes > 0, hashes <= 6, i == slice.endIndex || slice[i] == 0x20 {
            existing = hashes + (i < slice.endIndex ? 1 : 0)
        }
        let newPrefix = (existing > 0 && hashes == level) ? "" : String(repeating: "#", count: level) + " "
        let delta = (newPrefix as NSString).length - existing
        let caret = max(range.location, sel.location + delta)
        return MarkdownAuthoringEdit(
            edits: [TextEdit(range: TextRange(location: range.location, length: existing), replacement: newPrefix)],
            newSelection: TextRange(location: caret, length: sel.length)
        )
    }

    private static func linePrefixToggle(_ prefix: String, _ index: MarkdownLineIndex, _ sel: TextRange) -> MarkdownAuthoringEdit {
        let line = index.line(containing: sel.location)
        let range = index.lineRange(line)
        let slice = index.lineSlice(line)
        let p = Array(prefix.utf16)
        let has = slice.count >= p.count && Array(slice.prefix(p.count)) == p
        let edit = TextEdit(range: TextRange(location: range.location, length: has ? p.count : 0), replacement: has ? "" : prefix)
        let delta = has ? -p.count : p.count
        return MarkdownAuthoringEdit(edits: [edit], newSelection: TextRange(location: max(range.location, sel.location + delta), length: sel.length))
    }

    private static func taskToggle(_ index: MarkdownLineIndex, _ sel: TextRange) -> MarkdownAuthoringEdit {
        let line = index.line(containing: sel.location)
        let range = index.lineRange(line)
        let slice = index.lineSlice(line)
        if let item = MarkdownListGrammar.parseListLine(slice), case .bullet(_, let state) = item.kind {
            let markerEnd = range.location + item.indent + 2
            if let state {
                let flipped = state == 0x20 ? "x" : " "
                return MarkdownAuthoringEdit(edits: [TextEdit(range: TextRange(location: markerEnd + 1, length: 1), replacement: flipped)], newSelection: sel)
            }
            return MarkdownAuthoringEdit(edits: [TextEdit(range: TextRange(location: markerEnd, length: 0), replacement: "[ ] ")], newSelection: TextRange(location: sel.location + 4, length: sel.length))
        }
        return MarkdownAuthoringEdit(edits: [TextEdit(range: TextRange(location: range.location, length: 0), replacement: "- [ ] ")], newSelection: TextRange(location: sel.location + 6, length: sel.length))
    }

    private static func fence(_ index: MarkdownLineIndex, _ text: NSString, _ sel: TextRange, _ first: Int, _ last: Int) -> MarkdownAuthoringEdit {
        let start = index.lineRange(first).location
        let end = index.lineRange(last).upperBound
        let body = text.substring(with: NSRange(location: start, length: end - start))
        return MarkdownAuthoringEdit(
            edits: [TextEdit(range: TextRange(location: start, length: end - start), replacement: "```\n" + body + "\n```")],
            newSelection: TextRange(location: sel.location + 4, length: sel.length)
        )
    }
}

/// GFM pipe-table `Tab` / `Shift+Tab` navigation with column auto-padding (`BC-004`, `SEC-012`).
///
/// The whole table block is rewritten in one `TextEdit` (one `BufferRevision`). Tables over `64` columns or `2000` rows, tables lacking a delimiter row, fenced content, and quarantined snapshots are `.notApplicable` (`CWE-400`, `DATA-003`).
public enum GFMTableEditEngine {
    public static let maxColumns = 64
    public static let maxRows = 2000

    public static func evaluateTab(in snapshot: DocumentSnapshot, selection: TextRange, backward: Bool, isMarkdownDocument: Bool) -> TableEditOutcome {
        guard isMarkdownDocument, !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText else { return .notApplicable }
        guard selection.location >= 0, selection.length >= 0 else { return .notApplicable }
        // O(lineLength) zero-allocation pre-check: if the caret line doesn't start with '|', skip building MarkdownLineIndex.
        guard caretLineStartsWithPipe(in: snapshot.text, caretUTF16: selection.location, upperBoundUTF16: selection.upperBound) else {
            return .notApplicable
        }
        let index = MarkdownLineIndex(text: snapshot.text)
        guard selection.upperBound <= index.units.count else { return .notApplicable }
        let caretLine = index.line(containing: selection.location)
        guard !index.isFenced(line: caretLine), isTableLine(index, caretLine) else { return .notApplicable }

        var top = caretLine
        while top > 0, isTableLine(index, top - 1), !index.isFenced(line: top - 1) { top -= 1 }
        var bottom = caretLine
        while bottom + 1 < index.lineCount, isTableLine(index, bottom + 1), !index.isFenced(line: bottom + 1) { bottom += 1 }
        guard bottom - top + 1 >= 2, bottom - top + 1 <= maxRows, isDelimiterRowSlice(index.lineSlice(top + 1)) else { return .notApplicable }

        var rows: [[String]] = []
        rows.reserveCapacity(bottom - top + 2)
        for line in top...bottom {
            let slice = index.lineSlice(line)
            if slice.count > MarkdownLineIndex.maxLineUTF16 { return .notApplicable }
            let c = cells(slice)
            if c.count > maxColumns { return .notApplicable }
            rows.append(c)
        }
        let columnCount = rows.map(\.count).max() ?? 0
        guard columnCount > 0 else { return .notApplicable }
        for r in rows.indices { while rows[r].count < columnCount { rows[r].append("") } }

        // Current cell from caret.
        let lineRange = index.lineRange(caretLine)
        let lineStartOffset = lineRange.location
        var pipes = 0
        var k = lineStartOffset
        while k < selection.location { if index.units[k] == 0x7C, !(k > lineStartOffset && index.units[k - 1] == 0x5C) { pipes += 1 }; k += 1 }
        var col = max(0, min(columnCount - 1, pipes - 1))
        var row = caretLine - top

        // Target cell.
        var appendRow = false
        if backward {
            col -= 1
            if col < 0 { row -= 1; col = columnCount - 1 }
            if row == 1 { row = 0 }
            if row < 0 { return .notApplicable }
        } else {
            col += 1
            if col >= columnCount { col = 0; row += 1 }
            if row == 1 { row = 2 }
            if row >= rows.count { appendRow = true; row = rows.count }
        }
        if appendRow { rows.append(Array(repeating: "", count: columnCount)) }
        guard rows.count <= maxRows else { return .notApplicable }

        var widths = Array(repeating: 3, count: columnCount)
        var cellLengths: [[Int]] = []
        cellLengths.reserveCapacity(rows.count)
        for (r, cellsInRow) in rows.enumerated() {
            var rowLens = Array(repeating: 0, count: columnCount)
            if r != 1 {
                for c in 0..<columnCount {
                    let len = cellsInRow[c].utf16.count
                    rowLens[c] = len
                    if len > widths[c] { widths[c] = len }
                }
            }
            cellLengths.append(rowLens)
        }
        let estimatedRowBytes = widths.reduce(2) { $0 + $1 + 3 }
        var out = ""
        out.reserveCapacity(estimatedRowBytes * rows.count)
        var outUTF16Count = 0
        var target = TextRange(location: 0, length: 0)
        let blockStart = index.lineRange(top).location
        let blockEnd = index.lineRange(bottom).upperBound
        let dashesByCol = widths.map { String(repeating: "-", count: $0) }

        for r in 0..<rows.count {
            if r > 0 {
                out.append("\n")
                outUTF16Count += 1
            }
            out.append("|")
            outUTF16Count += 1
            let cellsInRow = rows[r]
            let lensInRow = cellLengths[r]
            for c in 0..<columnCount {
                out.append(" ")
                outUTF16Count += 1
                if r == row, c == col {
                    target = TextRange(location: blockStart + outUTF16Count, length: lensInRow[c])
                }
                if r == 1 {
                    out.append(dashesByCol[c])
                    outUTF16Count += widths[c]
                } else {
                    let raw = cellsInRow[c]
                    let rawLen = lensInRow[c]
                    out.append(raw)
                    let pad = widths[c] - rawLen
                    if pad > 0 {
                        out.append(String(repeating: " ", count: pad))
                    }
                    outUTF16Count += widths[c]
                }
                out.append(" |")
                outUTF16Count += 2
            }
        }
        let edit = TextEdit(range: TextRange(location: blockStart, length: blockEnd - blockStart), replacement: out)
        return .edit(MarkdownAuthoringEdit(edits: [edit], newSelection: target))
    }

    private static func caretLineStartsWithPipe(in text: String, caretUTF16: Int, upperBoundUTF16: Int) -> Bool {
        let utf16 = text.utf16
        guard let caretIdx = utf16.index(utf16.startIndex, offsetBy: caretUTF16, limitedBy: utf16.endIndex) else {
            return false
        }
        if upperBoundUTF16 > caretUTF16 {
            guard utf16.index(caretIdx, offsetBy: upperBoundUTF16 - caretUTF16, limitedBy: utf16.endIndex) != nil else {
                return false
            }
        }
        let utf8 = text.utf8
        var cursor = caretIdx
        while cursor > utf8.startIndex {
            let prev = utf8.index(before: cursor)
            if utf8[prev] == 0x0A { break }
            cursor = prev
        }
        while cursor < utf8.endIndex && utf8[cursor] == 0x20 {
            cursor = utf8.index(after: cursor)
        }
        return cursor < utf8.endIndex && utf8[cursor] == 0x7C
    }

    private static func isTableLine(_ index: MarkdownLineIndex, _ line: Int) -> Bool {
        let slice = index.lineSlice(line)
        var i = slice.startIndex
        while i < slice.endIndex, slice[i] == 0x20 { i += 1 }
        return i < slice.endIndex && slice[i] == 0x7C
    }

    /// Zero-allocation cell count matching `cells(line).count`.
    static func cellCount(_ line: ArraySlice<UInt16>) -> Int {
        var count = 0
        var started = false
        var prevBackslash = false
        var currentHasNonSpace = false
        for u in line {
            if !started {
                if u == 0x7C { started = true }
                continue
            }
            if u == 0x7C, !prevBackslash {
                count += 1
                currentHasNonSpace = false
            } else if u != 0x20 {
                currentHasNonSpace = true
            }
            prevBackslash = (u == 0x5C)
        }
        if currentHasNonSpace { count += 1 }
        return count
    }

    /// Zero-allocation delimiter-row check matching `isDelimiterRow(cells(line))`.
    static func isDelimiterRowSlice(_ line: ArraySlice<UInt16>) -> Bool {
        var cellCount = 0
        var started = false
        var prevBackslash = false
        var segStart = line.startIndex

        func isValidDelimiterCell(_ start: Int, _ end: Int) -> Bool {
            var lo = start
            var hi = end
            while lo < hi, line[lo] == 0x20 || line[lo] == 0x09 { lo += 1 }
            while hi > lo, line[hi - 1] == 0x20 || line[hi - 1] == 0x09 { hi -= 1 }
            while lo < hi, line[lo] == 0x3A { lo += 1 } // ':'
            while hi > lo, line[hi - 1] == 0x3A { hi -= 1 }
            guard lo < hi else { return false }
            var k = lo
            while k < hi {
                if line[k] != 0x2D { return false } // '-'
                k += 1
            }
            return true
        }

        var idx = line.startIndex
        while idx < line.endIndex {
            let u = line[idx]
            if !started {
                if u == 0x7C {
                    started = true
                    segStart = idx + 1
                }
                idx += 1
                continue
            }
            if u == 0x7C, !prevBackslash {
                if !isValidDelimiterCell(segStart, idx) { return false }
                cellCount += 1
                segStart = idx + 1
                prevBackslash = false
            } else {
                prevBackslash = (u == 0x5C)
            }
            idx += 1
        }
        if started {
            var hasNonSpace = false
            var k = segStart
            while k < line.endIndex {
                if line[k] != 0x20 { hasNonSpace = true; break }
                k += 1
            }
            if hasNonSpace {
                if !isValidDelimiterCell(segStart, line.endIndex) { return false }
                cellCount += 1
            }
        }
        return cellCount > 0
    }

    /// Splits a pipe row into trimmed cells, honoring `\|` escapes and dropping the leading and trailing pipe.
    static func cells(_ line: ArraySlice<UInt16>) -> [String] {
        var result: [String] = []
        var current: [UInt16] = []
        var started = false
        var prevBackslash = false
        func finishCell() {
            var lo = 0
            var hi = current.count
            while lo < hi && (current[lo] == 0x20 || current[lo] == 0x09) { lo += 1 }
            while hi > lo && (current[hi - 1] == 0x20 || current[hi - 1] == 0x09) { hi -= 1 }
            if lo < hi {
                result.append(String(decoding: current[lo..<hi], as: UTF16.self))
            } else {
                result.append("")
            }
            current.removeAll(keepingCapacity: true)
        }
        for u in line {
            if !started { if u == 0x7C { started = true }; continue }
            if u == 0x7C, !prevBackslash { finishCell() } else { current.append(u) }
            prevBackslash = (u == 0x5C)
        }
        if !current.allSatisfy({ $0 == 0x20 }) { finishCell() }
        return result
    }

    private static let colonCharacterSet = CharacterSet(charactersIn: ":")

    static func isDelimiterRow(_ cells: [String]) -> Bool {
        !cells.isEmpty && cells.allSatisfy { cell in
            let t = cell.trimmingCharacters(in: Self.colonCharacterSet)
            return !t.isEmpty && t.allSatisfy { $0 == "-" }
        }
    }
}
