import Foundation

/// Atomic single-revision line transformation result (`REQ-009`).
public struct LineCommandOutcome: Equatable, Sendable {
    public let edits: [TextEdit]
    public let newSelection: TextRange

    public init(edits: [TextEdit], newSelection: TextRange) {
        self.edits = edits
        self.newSelection = newSelection
    }
}

/// Pure `SwiftEditCore` line manipulation engine preserving document `LineEnding` in one atomic `BufferRevision` (`REQ-009`, `BC-003`, `DATA-004`).
public enum LineEditCommands {
    private struct LogicalLine {
        let contentLocation: Int
        let contentLength: Int
        let fullLength: Int
        let content: String
        let breakSeq: String
    }

    /// Moves the selected line(s) one row up (`Option+Up`) or down (`Option+Down`) in one `TextEdit` (`REQ-009`).
    public static func moveLines(in snapshot: DocumentSnapshot, selection: TextRange, up: Bool) -> LineCommandOutcome? {
        guard !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText, !snapshot.text.isEmpty else { return nil }
        let lines = parseLines(in: snapshot.text)
        let realCount = effectiveLineCount(lines)
        guard realCount > 1 else { return nil }
        let (start, end) = selectedLineSpan(in: lines, selection: selection, maxLine: realCount - 1)
        let sep = activeBreakSequence(in: snapshot)

        if up {
            guard start > 0 else { return nil }
            let above = lines[start - 1]
            let blockText = (start...end).map { lines[$0].content }.joined(separator: sep)
            let tailBreak = lines[end].breakSeq
            let replacement = blockText + sep + above.content + tailBreak
            let replaceStart = above.contentLocation
            let replaceEnd = lines[end].contentLocation + lines[end].fullLength
            let offsetInBlock = max(0, selection.location - lines[start].contentLocation)
            return LineCommandOutcome(
                edits: [TextEdit(range: TextRange(location: replaceStart, length: replaceEnd - replaceStart), replacement: replacement)],
                newSelection: TextRange(location: replaceStart + offsetInBlock, length: selection.length)
            )
        }

        guard end + 1 < realCount else { return nil }
        let below = lines[end + 1]
        let blockText = (start...end).map { lines[$0].content }.joined(separator: sep)
        let tailBreak = below.breakSeq
        let replacement = below.content + sep + blockText + tailBreak
        let replaceStart = lines[start].contentLocation
        let replaceEnd = below.contentLocation + below.fullLength
        let shiftedStart = replaceStart + (below.content as NSString).length + (sep as NSString).length
        let offsetInBlock = max(0, selection.location - lines[start].contentLocation)
        return LineCommandOutcome(
            edits: [TextEdit(range: TextRange(location: replaceStart, length: replaceEnd - replaceStart), replacement: replacement)],
            newSelection: TextRange(location: shiftedStart + offsetInBlock, length: selection.length)
        )
    }

    /// Deletes the active or selected line(s) (`Ctrl+Shift+K`) in one `TextEdit` (`REQ-009`).
    public static func deleteLines(in snapshot: DocumentSnapshot, selection: TextRange) -> LineCommandOutcome? {
        guard !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText, !snapshot.text.isEmpty else { return nil }
        let lines = parseLines(in: snapshot.text)
        let realCount = effectiveLineCount(lines)
        guard realCount > 0 else { return nil }
        let (start, end) = selectedLineSpan(in: lines, selection: selection, maxLine: realCount - 1)
        var deleteStart = lines[start].contentLocation
        let deleteEnd = lines[end].contentLocation + lines[end].fullLength
        if lines[end].breakSeq.isEmpty, start > 0 {
            deleteStart -= (lines[start - 1].breakSeq as NSString).length
        }
        guard deleteEnd > deleteStart else { return nil }
        return LineCommandOutcome(
            edits: [TextEdit(range: TextRange(location: deleteStart, length: deleteEnd - deleteStart), replacement: "")],
            newSelection: TextRange(location: deleteStart, length: 0)
        )
    }

    /// Joins the active line with the following line (or all lines spanning `selection`) using a single space (`Ctrl+J`, `REQ-009`).
    public static func joinLines(in snapshot: DocumentSnapshot, selection: TextRange) -> LineCommandOutcome? {
        guard !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText, !snapshot.text.isEmpty else { return nil }
        let lines = parseLines(in: snapshot.text)
        let realCount = effectiveLineCount(lines)
        guard realCount > 1 else { return nil }
        var (start, end) = selectedLineSpan(in: lines, selection: selection, maxLine: realCount - 1)
        if start == end {
            guard start + 1 < realCount else { return nil }
            end = start + 1
        }
        var joined = trimHorizontalTrailing(lines[start].content)
        for idx in (start + 1)...end {
            let rhs = trimHorizontalLeading(lines[idx].content)
            if joined.isEmpty {
                joined = rhs
            } else if !rhs.isEmpty {
                joined += " " + rhs
            }
        }
        let replaceStart = lines[start].contentLocation
        let replaceEnd = lines[end].contentLocation + lines[end].contentLength
        return LineCommandOutcome(
            edits: [TextEdit(range: TextRange(location: replaceStart, length: replaceEnd - replaceStart), replacement: joined)],
            newSelection: TextRange(location: replaceStart + (joined as NSString).length, length: 0)
        )
    }

    /// Lexicographically sorts selected lines (or all document lines when `selection.length == 0`) ascending or descending (`REQ-009`).
    public static func sortLines(in snapshot: DocumentSnapshot, selection: TextRange, ascending: Bool) -> LineCommandOutcome? {
        guard !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText, !snapshot.text.isEmpty else { return nil }
        let lines = parseLines(in: snapshot.text)
        let realCount = effectiveLineCount(lines)
        guard realCount > 1 else { return nil }
        let (start, end) = selection.length > 0
            ? selectedLineSpan(in: lines, selection: selection, maxLine: realCount - 1)
            : (0, realCount - 1)
        guard end > start else { return nil }
        let originals = (start...end).map { lines[$0].content }
        let sorted = originals.sorted { ascending ? ($0 < $1) : ($0 > $1) }
        guard sorted != originals else { return nil }
        let sep = activeBreakSequence(in: snapshot)
        let replacement = sorted.joined(separator: sep) + lines[end].breakSeq
        let replaceStart = lines[start].contentLocation
        let replaceEnd = lines[end].contentLocation + lines[end].fullLength
        return LineCommandOutcome(
            edits: [TextEdit(range: TextRange(location: replaceStart, length: replaceEnd - replaceStart), replacement: replacement)],
            newSelection: TextRange(location: replaceStart, length: (replacement as NSString).length)
        )
    }

    /// Computes non-overlapping `[TextEdit]` spans removing trailing spaces (`U+0020`) and tabs (`U+0009`) on every line (`REQ-009`).
    public static func trimTrailingWhitespace(in snapshot: DocumentSnapshot) -> [TextEdit] {
        guard !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText, !snapshot.text.isEmpty else { return [] }
        let lines = parseLines(in: snapshot.text)
        var edits: [TextEdit] = []
        for line in lines where line.contentLength > 0 {
            let trimmed = trimHorizontalTrailing(line.content)
            let trimmedLen = (trimmed as NSString).length
            if trimmedLen < line.contentLength {
                edits.append(TextEdit(
                    range: TextRange(location: line.contentLocation + trimmedLen, length: line.contentLength - trimmedLen),
                    replacement: ""
                ))
            }
        }
        return edits
    }
}

extension LineEditCommands {
    private static func activeBreakSequence(in snapshot: DocumentSnapshot) -> String {
        if snapshot.text.utf8.contains(0x0D) {
            return LineEnding.detect(in: snapshot.text).rawValue
        }
        return "\n"
    }

    private static func effectiveLineCount(_ lines: [LogicalLine]) -> Int {
        guard lines.count > 1,
              let last = lines.last,
              last.contentLength == 0,
              last.breakSeq.isEmpty,
              !lines[lines.count - 2].breakSeq.isEmpty else {
            return lines.count
        }
        return lines.count - 1
    }

    private static func selectedLineSpan(in lines: [LogicalLine], selection: TextRange, maxLine: Int) -> (Int, Int) {
        let start = min(maxLine, lineIndex(in: lines, at: max(0, selection.location)))
        guard selection.length > 0 else { return (start, start) }
        let rawEnd = lineIndex(in: lines, at: selection.upperBound)
        if rawEnd > start, lines[rawEnd].contentLocation == selection.upperBound {
            return (start, min(maxLine, rawEnd - 1))
        }
        return (start, min(maxLine, rawEnd))
    }

    private static func lineIndex(in lines: [LogicalLine], at utf16Offset: Int) -> Int {
        for (idx, line) in lines.enumerated() {
            if utf16Offset < line.contentLocation + line.fullLength {
                return idx
            }
        }
        return max(0, lines.count - 1)
    }

    private static func parseLines(in text: String) -> [LogicalLine] {
        let units = Array(text.utf16)
        var out: [LogicalLine] = []
        var cursor = 0
        while cursor <= units.count {
            let start = cursor
            while cursor < units.count, units[cursor] != 0x0A, units[cursor] != 0x0D {
                cursor += 1
            }
            let contentLen = cursor - start
            let content = String(decoding: units[start..<cursor], as: UTF16.self)
            var breakLen = 0
            if cursor < units.count {
                if units[cursor] == 0x0D, cursor + 1 < units.count, units[cursor + 1] == 0x0A {
                    breakLen = 2
                } else {
                    breakLen = 1
                }
            }
            let breakSeq = breakLen == 0 ? "" : String(decoding: units[cursor..<(cursor + breakLen)], as: UTF16.self)
            out.append(LogicalLine(
                contentLocation: start,
                contentLength: contentLen,
                fullLength: contentLen + breakLen,
                content: content,
                breakSeq: breakSeq
            ))
            if breakLen == 0 { break }
            cursor += breakLen
        }
        return out
    }

    private static func trimHorizontalTrailing(_ s: String) -> String {
        var idx = s.endIndex
        while idx > s.startIndex {
            let prev = s.index(before: idx)
            if s[prev] == " " || s[prev] == "\t" { idx = prev } else { break }
        }
        return String(s[..<idx])
    }

    private static func trimHorizontalLeading(_ s: String) -> String {
        var idx = s.startIndex
        while idx < s.endIndex, s[idx] == " " || s[idx] == "\t" {
            idx = s.index(after: idx)
        }
        return String(s[idx...])
    }
}
