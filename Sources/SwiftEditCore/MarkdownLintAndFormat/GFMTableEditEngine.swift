import Foundation

/// GFM pipe-table `Tab` / `Shift+Tab` navigation with column auto-padding (`BC-004`, `REQ-009`, `SEC-012`).
///
/// The whole table block is rewritten in one `TextEdit` (one `BufferRevision`). Tables over `64` columns or `2000` rows, tables lacking a delimiter row, fenced content, and quarantined snapshots are `.notApplicable` (`CWE-400`, `DATA-003`).
public enum GFMTableEditEngine {
    public static let maxColumns = 64
    public static let maxRows = 2000

    public static func evaluateTab(in snapshot: DocumentSnapshot, selection: TextRange, backward: Bool, isMarkdownDocument: Bool) -> TableEditOutcome {
        guard isAdmissibleTableTabRequest(in: snapshot, selection: selection, isMarkdownDocument: isMarkdownDocument) else {
            return .notApplicable
        }
        let index = MarkdownLineIndex(text: snapshot.text)
        guard selection.upperBound <= index.units.count else { return .notApplicable }
        let caretLine = index.line(containing: selection.location)
        guard let bounds = locateEditableTableBounds(in: index, caretLine: caretLine),
              var grid = parseNormalizedTableGrid(in: index, top: bounds.top, bottom: bounds.bottom) else {
            return .notApplicable
        }

        let currentCol = currentTableColumnIndex(in: index, caretLine: caretLine, caretOffset: selection.location, columnCount: grid.columnCount)
        let currentRow = caretLine - bounds.top
        guard let targetCell = resolveTabTargetCell(row: currentRow, col: currentCol, rowCount: grid.rows.count, columnCount: grid.columnCount, backward: backward) else {
            return .notApplicable
        }
        if targetCell.appendRow {
            grid.rows.append(Array(repeating: "", count: grid.columnCount))
        }
        guard grid.rows.count <= maxRows else { return .notApplicable }

        let metrics = measureTableColumnWidthsAndLengths(grid.rows, columnCount: grid.columnCount)
        let blockStart = index.lineRange(bounds.top).location
        let blockEnd = index.lineRange(bounds.bottom).upperBound
        let rendered = renderFormattedTableBlock(
            grid.rows,
            widths: metrics.widths,
            cellLengths: metrics.cellLengths,
            targetCell: (targetCell.row, targetCell.col),
            blockStart: blockStart
        )
        let edit = TextEdit(range: TextRange(location: blockStart, length: blockEnd - blockStart), replacement: rendered.text)
        return .edit(MarkdownAuthoringEdit(edits: [edit], newSelection: rendered.selection))
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
        var foundCells = 0
        var started = false
        var prevBackslash = false
        var segStart = line.startIndex
        var idx = line.startIndex

        while idx < line.endIndex {
            let u = line[idx]
            if !started {
                if u == 0x7C {
                    started = true
                    segStart = idx + 1
                }
            } else if u == 0x7C, !prevBackslash {
                guard isValidTableDelimiterCell(line, from: segStart, to: idx) else { return false }
                foundCells += 1
                segStart = idx + 1
                prevBackslash = false
            } else {
                prevBackslash = (u == 0x5C)
            }
            idx += 1
        }

        if started, hasNonSpaceUnit(in: line, from: segStart) {
            guard isValidTableDelimiterCell(line, from: segStart, to: line.endIndex) else { return false }
            foundCells += 1
        }
        return foundCells > 0
    }

    /// Splits a pipe row into trimmed cells, honoring `\|` escapes and dropping the leading and trailing pipe.
    static func cells(_ line: ArraySlice<UInt16>) -> [String] {
        var result: [String] = []
        var current: [UInt16] = []
        var started = false
        var prevBackslash = false
        for u in line {
            if !started {
                if u == 0x7C { started = true }
                continue
            }
            if u == 0x7C, !prevBackslash {
                appendTrimmedTableCell(&current, into: &result)
            } else {
                current.append(u)
            }
            prevBackslash = (u == 0x5C)
        }
        if !current.allSatisfy({ $0 == 0x20 }) {
            appendTrimmedTableCell(&current, into: &result)
        }
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

extension GFMTableEditEngine {
    private static func isAdmissibleTableTabRequest(
        in snapshot: DocumentSnapshot,
        selection: TextRange,
        isMarkdownDocument: Bool
    ) -> Bool {
        guard isMarkdownDocument, !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText else { return false }
        guard selection.location >= 0, selection.length >= 0 else { return false }
        return caretLineStartsWithPipe(in: snapshot.text, caretUTF16: selection.location, upperBoundUTF16: selection.upperBound)
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

    private static func locateEditableTableBounds(in index: MarkdownLineIndex, caretLine: Int) -> (top: Int, bottom: Int)? {
        guard !index.isFenced(line: caretLine), isTableLine(index, caretLine) else { return nil }
        var top = caretLine
        while top > 0, isTableLine(index, top - 1), !index.isFenced(line: top - 1) { top -= 1 }
        var bottom = caretLine
        while bottom + 1 < index.lineCount, isTableLine(index, bottom + 1), !index.isFenced(line: bottom + 1) { bottom += 1 }
        let rowCount = bottom - top + 1
        guard rowCount >= 2, rowCount <= maxRows, isDelimiterRowSlice(index.lineSlice(top + 1)) else { return nil }
        return (top, bottom)
    }

    private static func parseNormalizedTableGrid(
        in index: MarkdownLineIndex,
        top: Int,
        bottom: Int
    ) -> (rows: [[String]], columnCount: Int)? {
        var tableRows: [[String]] = []
        tableRows.reserveCapacity(bottom - top + 2)
        var columnCount = 0
        for line in top...bottom {
            let slice = index.lineSlice(line)
            guard slice.count <= MarkdownLineIndex.maxLineUTF16 else { return nil }
            let rowCells = cells(slice)
            guard rowCells.count <= maxColumns else { return nil }
            if rowCells.count > columnCount { columnCount = rowCells.count }
            tableRows.append(rowCells)
        }
        guard columnCount > 0 else { return nil }
        padTableRows(&tableRows, toColumnCount: columnCount)
        return (tableRows, columnCount)
    }

    private static func padTableRows(_ tableRows: inout [[String]], toColumnCount columnCount: Int) {
        for r in tableRows.indices where tableRows[r].count < columnCount {
            tableRows[r].append(contentsOf: repeatElement("", count: columnCount - tableRows[r].count))
        }
    }

    private static func currentTableColumnIndex(
        in index: MarkdownLineIndex,
        caretLine: Int,
        caretOffset: Int,
        columnCount: Int
    ) -> Int {
        let lineStartOffset = index.lineRange(caretLine).location
        var pipes = 0
        var k = lineStartOffset
        while k < caretOffset {
            if index.units[k] == 0x7C, !(k > lineStartOffset && index.units[k - 1] == 0x5C) {
                pipes += 1
            }
            k += 1
        }
        return max(0, min(columnCount - 1, pipes - 1))
    }

    private static func resolveTabTargetCell(
        row: Int,
        col: Int,
        rowCount: Int,
        columnCount: Int,
        backward: Bool
    ) -> (row: Int, col: Int, appendRow: Bool)? {
        if backward {
            var nextCol = col - 1
            var nextRow = row
            if nextCol < 0 { nextRow -= 1; nextCol = columnCount - 1 }
            if nextRow == 1 { nextRow = 0 }
            guard nextRow >= 0 else { return nil }
            return (nextRow, nextCol, false)
        }
        var nextCol = col + 1
        var nextRow = row
        if nextCol >= columnCount { nextCol = 0; nextRow += 1 }
        if nextRow == 1 { nextRow = 2 }
        if nextRow >= rowCount {
            return (rowCount, nextCol, true)
        }
        return (nextRow, nextCol, false)
    }
}

extension GFMTableEditEngine {
    private static func measureTableColumnWidthsAndLengths(
        _ tableRows: [[String]],
        columnCount: Int
    ) -> (widths: [Int], cellLengths: [[Int]]) {
        var widths = Array(repeating: 3, count: columnCount)
        var cellLengths: [[Int]] = []
        cellLengths.reserveCapacity(tableRows.count)
        for (r, cellsInRow) in tableRows.enumerated() {
            cellLengths.append(measureSingleTableRow(cellsInRow, isDelimiterRow: r == 1, columnCount: columnCount, widths: &widths))
        }
        return (widths, cellLengths)
    }

    private static func measureSingleTableRow(
        _ cellsInRow: [String],
        isDelimiterRow: Bool,
        columnCount: Int,
        widths: inout [Int]
    ) -> [Int] {
        var rowLens = Array(repeating: 0, count: columnCount)
        guard !isDelimiterRow else { return rowLens }
        for c in 0..<columnCount {
            let len = cellsInRow[c].utf16.count
            rowLens[c] = len
            if len > widths[c] { widths[c] = len }
        }
        return rowLens
    }

    private static func renderFormattedTableBlock(
        _ tableRows: [[String]],
        widths: [Int],
        cellLengths: [[Int]],
        targetCell: (row: Int, col: Int),
        blockStart: Int
    ) -> (text: String, selection: TextRange) {
        let estimatedRowBytes = widths.reduce(2) { $0 + $1 + 3 }
        var out = ""
        out.reserveCapacity(estimatedRowBytes * tableRows.count)
        var outUTF16Count = 0
        var selection = TextRange(location: 0, length: 0)
        let dashesByCol = widths.map { String(repeating: "-", count: $0) }

        for r in 0..<tableRows.count {
            if r > 0 {
                out.append("\n")
                outUTF16Count += 1
            }
            out.append("|")
            outUTF16Count += 1
            appendFormattedTableRowCells(
                rowIndex: r,
                cellsInRow: tableRows[r],
                lensInRow: cellLengths[r],
                widths: widths,
                dashesByCol: dashesByCol,
                targetCell: targetCell,
                blockStart: blockStart,
                out: &out,
                outUTF16Count: &outUTF16Count,
                selection: &selection
            )
        }
        return (out, selection)
    }

    private static func appendFormattedTableRowCells(
        rowIndex: Int,
        cellsInRow: [String],
        lensInRow: [Int],
        widths: [Int],
        dashesByCol: [String],
        targetCell: (row: Int, col: Int),
        blockStart: Int,
        out: inout String,
        outUTF16Count: inout Int,
        selection: inout TextRange
    ) {
        for c in 0..<widths.count {
            out.append(" ")
            outUTF16Count += 1
            if rowIndex == targetCell.row, c == targetCell.col {
                selection = TextRange(location: blockStart + outUTF16Count, length: lensInRow[c])
            }
            if rowIndex == 1 {
                out.append(dashesByCol[c])
            } else {
                out.append(cellsInRow[c])
                let pad = widths[c] - lensInRow[c]
                if pad > 0 { out.append(String(repeating: " ", count: pad)) }
            }
            outUTF16Count += widths[c]
            out.append(" |")
            outUTF16Count += 2
        }
    }

    private static func isValidTableDelimiterCell(_ line: ArraySlice<UInt16>, from start: Int, to end: Int) -> Bool {
        var lo = start
        var hi = end
        while lo < hi, isTableBlankUnit(line[lo]) { lo += 1 }
        while hi > lo, isTableBlankUnit(line[hi - 1]) { hi -= 1 }
        while lo < hi, line[lo] == 0x3A { lo += 1 }
        while hi > lo, line[hi - 1] == 0x3A { hi -= 1 }
        guard lo < hi else { return false }
        for k in lo..<hi where line[k] != 0x2D {
            return false
        }
        return true
    }

    private static func hasNonSpaceUnit(in line: ArraySlice<UInt16>, from start: Int) -> Bool {
        for k in start..<line.endIndex where line[k] != 0x20 {
            return true
        }
        return false
    }

    private static func appendTrimmedTableCell(_ current: inout [UInt16], into result: inout [String]) {
        var lo = 0
        var hi = current.count
        while lo < hi, isTableBlankUnit(current[lo]) { lo += 1 }
        while hi > lo, isTableBlankUnit(current[hi - 1]) { hi -= 1 }
        result.append(lo < hi ? String(decoding: current[lo..<hi], as: UTF16.self) : "")
        current.removeAll(keepingCapacity: true)
    }

    @inline(__always)
    private static func isTableBlankUnit(_ u: UInt16) -> Bool {
        u == 0x20 || u == 0x09
    }
}
