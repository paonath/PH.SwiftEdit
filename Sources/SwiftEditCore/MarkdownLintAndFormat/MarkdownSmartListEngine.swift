import Foundation

/// Atomic list-indentation edit batch computed for one `Tab` / `Shift+Tab` keystroke (`BC-004`, `BC-006`).
public struct SmartListEdit: Equatable, Sendable {
    /// Non-overlapping UTF-16 `TextEdit` values (one per touched list line) to apply in a single `BufferRevision`.
    public let edits: [TextEdit]
    /// Selection (UTF-16) translated by the inserted or removed prefix lengths.
    public let newSelection: TextRange

    public init(edits: [TextEdit], newSelection: TextRange) {
        self.edits = edits
        self.newSelection = newSelection
    }

    /// Merges the per-line edits into one replacement spanning the touched region of `text`.
    ///
    /// Applying a single replacement lets AppKit register exactly one undo step and the workbench record exactly one `BufferRevision` (`UI-007`).
    public func coalescedEdit(in text: String) -> TextEdit {
        let source = text as NSString
        let ordered = edits.sorted { $0.range.location < $1.range.location }
        guard let first = ordered.first, let last = ordered.last else {
            return TextEdit(range: TextRange(location: 0, length: 0), replacement: "")
        }
        var replacement = ""
        var cursor = first.range.location
        for edit in ordered {
            if edit.range.location > cursor {
                replacement += source.substring(with: NSRange(location: cursor, length: edit.range.location - cursor))
            }
            replacement += edit.replacement
            cursor = edit.range.upperBound
        }
        return TextEdit(
            range: TextRange(location: first.range.location, length: last.range.upperBound - first.range.location),
            replacement: replacement
        )
    }
}

/// Typed result of a list-indentation request.
///
/// `consumedNoOp` lets the UI swallow the key (e.g. `Tab` on a root item that must never become an indented code block) while
/// `notApplicable` lets AppKit run its default behavior.
public enum SmartListOutcome: Equatable, Sendable {
    case edit(SmartListEdit)
    case consumedNoOp
    case notApplicable
}

/// A parsed Markdown list line (UTF-16 offsets relative to the line start).
struct MarkdownListLine: Equatable {
    enum Kind: Equatable {
        case bullet(marker: UInt16, taskState: UInt16?)
        case ordered(number: Int, delimiter: UInt16)
    }

    let indent: Int
    let kind: Kind
    /// Length of the marker including its trailing space (excluding indent).
    let markerLength: Int
    var prefixLength: Int { indent + markerLength }
}

/// Shared zero-regex list-line grammar used by the list engine, the smart newline engine, and the outline lint rule (`BC-004`, `BC-011`).
enum MarkdownListGrammar {
    static let space: UInt16 = 0x20
    static let maxOrderedNumber = 999_999_999
    static let maxLineUTF16 = 4096

    /// Parses `line` as a CommonMark list item (`- `, `* `, `+ `, task checkbox, or `N. ` / `N) `); leading tabs make a line non-list.
    static func parseListLine(_ line: ArraySlice<UInt16>) -> MarkdownListLine? {
        var idx = line.startIndex
        while idx < line.endIndex, line[idx] == space { idx += 1 }
        let indent = idx - line.startIndex
        guard idx < line.endIndex else { return nil }
        let first = line[idx]

        if first == 0x2D || first == 0x2A || first == 0x2B {
            guard idx + 1 < line.endIndex, line[idx + 1] == space else { return nil }
            if idx + 5 < line.endIndex,
               line[idx + 2] == 0x5B, line[idx + 4] == 0x5D, line[idx + 5] == space,
               line[idx + 3] == space || line[idx + 3] == 0x78 || line[idx + 3] == 0x58 {
                return MarkdownListLine(indent: indent, kind: .bullet(marker: first, taskState: line[idx + 3]), markerLength: 6)
            }
            return MarkdownListLine(indent: indent, kind: .bullet(marker: first, taskState: nil), markerLength: 2)
        }

        var number = 0
        var digits = 0
        var cursor = idx
        while cursor < line.endIndex, line[cursor] >= 0x30, line[cursor] <= 0x39 {
            digits += 1
            guard digits <= 9 else { return nil }
            number = number * 10 + Int(line[cursor] - 0x30)
            cursor += 1
        }
        guard digits > 0, cursor + 1 < line.endIndex,
              line[cursor] == 0x2E || line[cursor] == 0x29,
              line[cursor + 1] == space else { return nil }
        return MarkdownListLine(indent: indent, kind: .ordered(number: number, delimiter: line[cursor]), markerLength: digits + 2)
    }

    /// Returns `true` when `line` begins (after `>= 2` spaces) with a pseudo-outline marker: one letter `a...y` / `A...Y` followed by `. `, or `D.D `.
    static func isPseudoOutlineMarker(_ line: ArraySlice<UInt16>) -> Bool {
        pseudoOutlineContinuation(line) != nil
    }

    /// Parses a pseudo-outline marker and returns `(markerLength, nextMarker)` for the next sibling (`a.` -> `b.`, `1.1` -> `1.2`), or `nil` when absent or not continuable.
    static func pseudoOutlineContinuation(_ line: ArraySlice<UInt16>) -> (indent: Int, markerLength: Int, nextMarker: String)? {
        var idx = line.startIndex
        while idx < line.endIndex, line[idx] == space { idx += 1 }
        let indent = idx - line.startIndex
        guard indent >= 2, idx < line.endIndex else { return nil }
        let first = line[idx]

        let isLower = first >= 0x61 && first <= 0x79
        let isUpper = first >= 0x41 && first <= 0x59
        if isLower || isUpper {
            guard idx + 2 < line.endIndex, line[idx + 1] == 0x2E, line[idx + 2] == space else { return nil }
            let next = String(UnicodeScalar(UInt8(first + 1)))
            return (indent, 3, next + ". ")
        }

        guard first >= 0x30, first <= 0x39 else { return nil }
        var cursor = idx
        var majorDigits = 0
        while cursor < line.endIndex, line[cursor] >= 0x30, line[cursor] <= 0x39 {
            majorDigits += 1
            guard majorDigits <= 9 else { return nil }
            cursor += 1
        }
        guard cursor < line.endIndex, line[cursor] == 0x2E else { return nil }
        let majorEnd = cursor
        cursor += 1
        var minor = 0
        var minorDigits = 0
        while cursor < line.endIndex, line[cursor] >= 0x30, line[cursor] <= 0x39 {
            minorDigits += 1
            guard minorDigits <= 9 else { return nil }
            minor = minor * 10 + Int(line[cursor] - 0x30)
            cursor += 1
        }
        guard minorDigits > 0, cursor < line.endIndex, line[cursor] == space else { return nil }
        let major = String(decoding: line[idx..<majorEnd], as: UTF16.self)
        let (nextMinor, overflow) = minor.addingReportingOverflow(1)
        guard !overflow, nextMinor <= maxOrderedNumber else { return nil }
        return (indent, cursor + 1 - idx, "\(major).\(nextMinor) ")
    }
}

/// Pure zero-regex `Tab` / `Shift+Tab` list indentation engine (`BC-004`, `BC-006`, `BC-011`, `SEC-012`).
///
/// Contract (Three-Tier, CommonMark 0.31.2 valid):
/// - `Tab` nests a list line by four spaces, inheriting the next number of a same-level preceding sibling or restarting at `1`; bullet and task markers are preserved.
/// - `Shift+Tab` outdents by four spaces and resumes the parent level's numbering.
/// - **Parent-Ceiling**: nesting requires a preceding list line whose indent is at least the current indent, so a root item never becomes a 4-space indented code block; otherwise the key is consumed as a no-op.
///
/// Bounds (`CWE-400`, `DATA-003`): binary and degraded snapshots, fenced code, lines over `4096` UTF-16 units, nesting past `32` levels, and ordered numbers past `999_999_999` never produce an edit. Sibling lookback is capped at `128` lines.
public enum MarkdownSmartListEngine {
    public static let maxNestingLevels = 32
    public static let maxSiblingLookbackLines = 128
    private static let indentStep = 4

    private enum LineKind {
        case blank
        case list(MarkdownListLine)
        case other(indent: Int)
        case fenced
    }

    private struct Line {
        let start: Int
        let end: Int
        let kind: LineKind
    }

    /// Evaluates `Tab` (`outdent == false`) or `Shift+Tab` (`outdent == true`) for `selection` in `snapshot`.
    public static func evaluateIndent(
        in snapshot: DocumentSnapshot,
        selection: TextRange,
        outdent: Bool,
        isMarkdownDocument: Bool
    ) -> SmartListOutcome {
        guard isMarkdownDocument, !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText else {
            return .notApplicable
        }
        let units = Array(snapshot.text.utf16)
        guard selection.location >= 0, selection.length >= 0, selection.upperBound <= units.count else {
            return .notApplicable
        }

        guard let lines = splitLines(units) else { return .notApplicable }
        let targets = targetLineIndices(lines, selection: selection)
        guard !targets.isEmpty else { return .notApplicable }

        var edits: [TextEdit] = []
        var deltas: [(lineStart: Int, oldPrefixEnd: Int, newPrefixLength: Int, delta: Int)] = []
        var sawList = false
        for index in targets {
            guard case .list(let item) = lines[index].kind else { continue }
            sawList = true
            guard let newPrefix = replacementPrefix(for: item, at: index, in: lines, units: units, outdent: outdent) else {
                continue
            }
            let line = lines[index]
            edits.append(TextEdit(range: TextRange(location: line.start, length: item.prefixLength), replacement: newPrefix))
            deltas.append((line.start, line.start + item.prefixLength, newPrefix.utf16.count, newPrefix.utf16.count - item.prefixLength))
        }
        guard sawList else { return .notApplicable }
        guard !edits.isEmpty else { return .consumedNoOp }

        let newStart = translate(selection.location, through: deltas)
        let newEnd = translate(selection.upperBound, through: deltas)
        return .edit(SmartListEdit(edits: edits, newSelection: TextRange(location: newStart, length: max(0, newEnd - newStart))))
    }

    // MARK: - Line model

    private static func splitLines(_ units: [UInt16]) -> [Line]? {
        var lines: [Line] = []
        var start = 0
        var fence: (char: UInt16, count: Int)?
        var cursor = 0
        while true {
            var end = cursor
            while end < units.count, units[end] != 0x0A, units[end] != 0x0D { end += 1 }
            let slice = units[start..<end]
            if slice.count > MarkdownListGrammar.maxLineUTF16 { return nil }

            let kind: LineKind
            if let open = fence {
                kind = .fenced
                if isClosingFence(slice, char: open.char, minCount: open.count) { fence = nil }
            } else if let opened = openingFence(slice) {
                fence = opened
                kind = .fenced
            } else if slice.allSatisfy({ $0 == MarkdownListGrammar.space || $0 == 0x09 }) {
                kind = .blank
            } else if let item = MarkdownListGrammar.parseListLine(slice) {
                kind = .list(item)
            } else {
                kind = .other(indent: slice.prefix(while: { $0 == MarkdownListGrammar.space }).count)
            }
            lines.append(Line(start: start, end: end, kind: kind))

            guard end < units.count else { break }
            if units[end] == 0x0D, end + 1 < units.count, units[end + 1] == 0x0A { cursor = end + 2 } else { cursor = end + 1 }
            start = cursor
        }
        return lines
    }

    private static func openingFence(_ line: ArraySlice<UInt16>) -> (char: UInt16, count: Int)? {
        var idx = line.startIndex
        var spaces = 0
        while idx < line.endIndex, line[idx] == MarkdownListGrammar.space, spaces < 3 { idx += 1; spaces += 1 }
        guard idx < line.endIndex, line[idx] == 0x60 || line[idx] == 0x7E else { return nil }
        let char = line[idx]
        let begin = idx
        while idx < line.endIndex, line[idx] == char { idx += 1 }
        guard idx - begin >= 3 else { return nil }
        if char == 0x60, line[idx...].contains(0x60) { return nil }
        return (char, idx - begin)
    }

    private static func isClosingFence(_ line: ArraySlice<UInt16>, char: UInt16, minCount: Int) -> Bool {
        var idx = line.startIndex
        var spaces = 0
        while idx < line.endIndex, line[idx] == MarkdownListGrammar.space, spaces < 3 { idx += 1; spaces += 1 }
        let begin = idx
        while idx < line.endIndex, line[idx] == char { idx += 1 }
        guard idx - begin >= minCount else { return false }
        return line[idx...].allSatisfy { $0 == MarkdownListGrammar.space || $0 == 0x09 }
    }

    private static func targetLineIndices(_ lines: [Line], selection: TextRange) -> [Int] {
        var result: [Int] = []
        for (index, line) in lines.enumerated() {
            if selection.length == 0 {
                if selection.location >= line.start, selection.location <= line.end { result.append(index); break }
            } else if line.start < selection.upperBound, line.end >= selection.location,
                      !(line.end == selection.location && line.start != line.end && selection.location != line.start) {
                result.append(index)
            }
        }
        return result
    }

    // MARK: - Replacement prefix

    private static func replacementPrefix(
        for item: MarkdownListLine,
        at index: Int,
        in lines: [Line],
        units: [UInt16],
        outdent: Bool
    ) -> String? {
        if outdent {
            guard item.indent >= indentStep else { return nil }
            let target = item.indent - indentStep
            return buildPrefix(item: item, targetIndent: target, siblingNumber: precedingSiblingNumber(before: index, at: target, in: lines, preferOrderedFor: item))
        }
        guard item.indent / indentStep < maxNestingLevels - 1 else { return nil }
        guard let previousIndent = nearestPrecedingListIndent(before: index, in: lines), previousIndent >= item.indent else {
            return nil
        }
        let target = item.indent + indentStep
        return buildPrefix(item: item, targetIndent: target, siblingNumber: precedingSiblingNumber(before: index, at: target, in: lines, preferOrderedFor: item))
    }

    /// Returns the replacement prefix, or `nil` when numbering would pass the `999_999_999` cap.
    private static func buildPrefix(item: MarkdownListLine, targetIndent: Int, siblingNumber: (number: Int, delimiter: UInt16)?) -> String? {
        let pad = String(repeating: " ", count: targetIndent)
        switch item.kind {
        case .bullet(let marker, let taskState):
            let m = String(UnicodeScalar(UInt8(marker)))
            if let state = taskState {
                return pad + m + " [" + String(UnicodeScalar(UInt8(state))) + "] "
            }
            return pad + m + " "
        case .ordered(let number, let delimiter):
            var nextNumber = 1
            var nextDelimiter = delimiter
            if let sibling = siblingNumber {
                let (incremented, overflow) = sibling.number.addingReportingOverflow(1)
                guard !overflow, incremented <= MarkdownListGrammar.maxOrderedNumber else { return nil }
                nextNumber = incremented
                nextDelimiter = sibling.delimiter
            } else if targetIndent == 0 {
                nextNumber = number
            }
            return pad + "\(nextNumber)" + String(UnicodeScalar(UInt8(nextDelimiter))) + " "
        }
    }

    private static func nearestPrecedingListIndent(before index: Int, in lines: [Line]) -> Int? {
        var scanned = 0
        var cursor = index - 1
        while cursor >= 0, scanned < maxSiblingLookbackLines {
            switch lines[cursor].kind {
            case .list(let item): return item.indent
            case .other(let indent) where indent == 0: return nil
            default: break
            }
            cursor -= 1
            scanned += 1
        }
        return nil
    }

    /// Finds the closest preceding ordered list line at exactly `indent`, stopping at shallower list lines or unindented prose.
    private static func precedingSiblingNumber(
        before index: Int,
        at indent: Int,
        in lines: [Line],
        preferOrderedFor item: MarkdownListLine
    ) -> (number: Int, delimiter: UInt16)? {
        var scanned = 0
        var cursor = index - 1
        while cursor >= 0, scanned < maxSiblingLookbackLines {
            switch lines[cursor].kind {
            case .list(let candidate):
                if candidate.indent < indent { return nil }
                if candidate.indent == indent, case .ordered(let n, let d) = candidate.kind { return (n, d) }
            case .other(let otherIndent) where otherIndent == 0:
                return nil
            default:
                break
            }
            cursor -= 1
            scanned += 1
        }
        return nil
    }

    private static func translate(
        _ offset: Int,
        through deltas: [(lineStart: Int, oldPrefixEnd: Int, newPrefixLength: Int, delta: Int)]
    ) -> Int {
        var shift = 0
        for entry in deltas {
            if offset >= entry.oldPrefixEnd {
                shift += entry.delta
            } else if offset > entry.lineStart {
                let within = min(offset - entry.lineStart, entry.newPrefixLength)
                return entry.lineStart + shift + within
            } else {
                break
            }
        }
        return offset + shift
    }
}
