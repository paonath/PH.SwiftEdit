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
        guard selection.location >= 0,
              selection.length >= 0,
              selection.upperBound <= units.count,
              let lines = splitLines(units) else {
            return .notApplicable
        }
        let targets = targetLineIndices(lines, selection: selection)
        guard !targets.isEmpty else { return .notApplicable }

        let batch = collectIndentEdits(for: targets, in: lines, units: units, outdent: outdent)
        guard batch.sawList else { return .notApplicable }
        guard !batch.edits.isEmpty else { return .consumedNoOp }

        let newStart = translate(selection.location, through: batch.deltas)
        let newEnd = translate(selection.upperBound, through: batch.deltas)
        return .edit(SmartListEdit(edits: batch.edits, newSelection: TextRange(location: newStart, length: max(0, newEnd - newStart))))
    }

    private static func collectIndentEdits(
        for targets: [Int],
        in lines: [Line],
        units: [UInt16],
        outdent: Bool
    ) -> (edits: [TextEdit], deltas: [(lineStart: Int, oldPrefixEnd: Int, newPrefixLength: Int, delta: Int)], sawList: Bool) {
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
        return (edits, deltas, sawList)
    }

    // MARK: - Line model

    private static func splitLines(_ units: [UInt16]) -> [Line]? {
        var lines: [Line] = []
        var fence: (char: UInt16, count: Int)?
        var start = 0
        while true {
            let end = findLineBreakOffset(in: units, from: start)
            let slice = units[start..<end]
            guard slice.count <= MarkdownListGrammar.maxLineUTF16 else { return nil }
            let kind = classifySmartListLine(slice, fence: &fence)
            lines.append(Line(start: start, end: end, kind: kind))
            guard let nextStart = advancePastLineBreak(in: units, from: end) else { break }
            start = nextStart
        }
        return lines
    }

    private static func findLineBreakOffset(in units: [UInt16], from start: Int) -> Int {
        var end = start
        while end < units.count, units[end] != 0x0A, units[end] != 0x0D {
            end += 1
        }
        return end
    }

    private static func advancePastLineBreak(in units: [UInt16], from lineEnd: Int) -> Int? {
        guard lineEnd < units.count else { return nil }
        if units[lineEnd] == 0x0D, lineEnd + 1 < units.count, units[lineEnd + 1] == 0x0A {
            return lineEnd + 2
        }
        return lineEnd + 1
    }

    private static func classifySmartListLine(
        _ slice: ArraySlice<UInt16>,
        fence: inout (char: UInt16, count: Int)?
    ) -> LineKind {
        if let open = fence {
            if isClosingFence(slice, char: open.char, minCount: open.count) { fence = nil }
            return .fenced
        }
        if let opened = openingFence(slice) {
            fence = opened
            return .fenced
        }
        if slice.allSatisfy({ $0 == MarkdownListGrammar.space || $0 == 0x09 }) {
            return .blank
        }
        if let item = MarkdownListGrammar.parseListLine(slice) {
            return .list(item)
        }
        return .other(indent: slice.prefix(while: { $0 == MarkdownListGrammar.space }).count)
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
