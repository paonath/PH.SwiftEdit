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
        let text = snapshot.text as NSString
        guard selection.location >= 0, selection.upperBound <= text.length else { return .notApplicable }
        let index = MarkdownLineIndex(text: snapshot.text)
        let caretLine = index.line(containing: selection.location)
        guard !index.isFenced(line: caretLine), isTableLine(index, caretLine) else { return .notApplicable }

        var top = caretLine
        while top > 0, isTableLine(index, top - 1), !index.isFenced(line: top - 1) { top -= 1 }
        var bottom = caretLine
        while bottom + 1 < index.lineCount, isTableLine(index, bottom + 1), !index.isFenced(line: bottom + 1) { bottom += 1 }
        guard bottom - top + 1 >= 2, bottom - top + 1 <= maxRows, isDelimiterRow(cells(index.lineSlice(top + 1))) else { return .notApplicable }

        var rows: [[String]] = []
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
        for (r, cellsInRow) in rows.enumerated() where r != 1 {
            for (c, cell) in cellsInRow.enumerated() { widths[c] = max(widths[c], (cell as NSString).length) }
        }
        var out = ""
        var target = TextRange(location: 0, length: 0)
        let blockStart = index.lineRange(top).location
        let blockEnd = index.lineRange(bottom).upperBound
        for (r, cellsInRow) in rows.enumerated() {
            if r > 0 { out += "\n" }
            out += "|"
            for c in 0..<columnCount {
                let content: String
                if r == 1 { content = String(repeating: "-", count: widths[c]) } else {
                    let raw = cellsInRow[c]
                    content = raw + String(repeating: " ", count: widths[c] - (raw as NSString).length)
                }
                out += " "
                if r == row, c == col {
                    target = TextRange(location: blockStart + (out as NSString).length, length: (cellsInRow[c] as NSString).length)
                }
                out += content + " |"
            }
        }
        let edit = TextEdit(range: TextRange(location: blockStart, length: blockEnd - blockStart), replacement: out)
        return .edit(MarkdownAuthoringEdit(edits: [edit], newSelection: target))
    }

    private static func isTableLine(_ index: MarkdownLineIndex, _ line: Int) -> Bool {
        let slice = index.lineSlice(line)
        var i = slice.startIndex
        while i < slice.endIndex, slice[i] == 0x20 { i += 1 }
        return i < slice.endIndex && slice[i] == 0x7C
    }

    /// Splits a pipe row into trimmed cells, honoring `\|` escapes and dropping the leading and trailing pipe.
    static func cells(_ line: ArraySlice<UInt16>) -> [String] {
        var result: [[UInt16]] = []
        var current: [UInt16] = []
        var started = false
        var prevBackslash = false
        for u in line {
            if !started { if u == 0x7C { started = true }; continue }
            if u == 0x7C, !prevBackslash { result.append(current); current = [] } else { current.append(u) }
            prevBackslash = (u == 0x5C)
        }
        if !current.allSatisfy({ $0 == 0x20 }) { result.append(current) }
        return result.map { String(decoding: $0, as: UTF16.self).trimmingCharacters(in: .whitespaces) }
    }

    static func isDelimiterRow(_ cells: [String]) -> Bool {
        !cells.isEmpty && cells.allSatisfy { cell in
            let t = cell.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            return !t.isEmpty && t.allSatisfy { $0 == "-" }
        }
    }
}
