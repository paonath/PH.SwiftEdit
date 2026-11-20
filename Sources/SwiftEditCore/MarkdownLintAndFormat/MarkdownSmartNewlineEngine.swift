import Foundation

/// Atomic Markdown smart-newline edit computed for an Enter keystroke (`BC-004`, `BC-006`).
public struct SmartNewlineEdit: Equatable, Sendable {
    /// UTF-16 `TextEdit` to apply via `DocumentSession.applyTextEdits`.
    public let edit: TextEdit
    /// Target UTF-16 caret offset immediately after applying `edit`.
    public let newCaretLocation: Int

    public init(edit: TextEdit, newCaretLocation: Int) {
        self.edit = edit
        self.newCaretLocation = newCaretLocation
    }
}

/// Pure single-pass Markdown Enter-continuation engine supporting unordered bullets, task checkboxes, incremented ordered lists, and blockquotes (`BC-004`, `BC-006`, `BC-011`, `SEC-012`).
///
/// Security & complexity invariants (`CWE-400`, `DATA-003`, `SEC-012`):
/// - Rejects `isBinaryReadOnly` and `isDegradedPlainText` snapshots immediately returning `nil`.
/// - Aborts lines exceeding `4096` UTF-16 code units and checks `Int.addingReportingOverflow(1)` before incrementing ordered-list numerals.
/// - Executes linearly with zero backtracking regular expressions and suppresses continuation inside fenced code blocks.
public enum MarkdownSmartNewlineEngine {
    private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]
    private static let lfUnit: UInt16 = 0x0A
    private static let crUnit: UInt16 = 0x0D
    private static let spaceUnit: UInt16 = 0x20
    private static let tabUnit: UInt16 = 0x09
    private static let backtickUnit: UInt16 = 0x60
    private static let tildeUnit: UInt16 = 0x7E

    /// Returns `true` when `filename` is `nil` (untitled buffer) or carries a recognized Markdown extension (`.md`, `.markdown`, `.mdown`, `.mkd`).
    public static func isMarkdownFilename(_ filename: String?) -> Bool {
        guard let filename, !filename.isEmpty else {
            return true
        }
        let ext = (filename as NSString).pathExtension.lowercased()
        return markdownExtensions.contains(ext)
    }

    /// Evaluates whether pressing Enter at `caretLocation` in `snapshot` should insert a consistent next Markdown list/blockquote prefix or clear an empty marker to exit the list.
    /// - Parameters:
    ///   - snapshot: Immutable document snapshot at the current `BufferRevision`.
    ///   - caretLocation: 0-based UTF-16 caret offset.
    ///   - isMarkdownDocument: Whether Markdown continuation is active for the buffer.
    /// - Returns: A `SmartNewlineEdit` when a Markdown structural continuation or empty-marker exit applies, or `nil` for standard newline insertion.
    public static func evaluateNewline(
        in snapshot: DocumentSnapshot,
        caretLocation: Int,
        isMarkdownDocument: Bool
    ) -> SmartNewlineEdit? {
        guard isMarkdownDocument,
              !snapshot.isBinaryReadOnly,
              !snapshot.isDegradedPlainText else {
            return nil
        }

        let units = Array(snapshot.text.utf16)
        guard caretLocation >= 0 && caretLocation <= units.count else {
            return nil
        }

        let (lineStart, lineEnd) = currentLineBounds(in: units, around: caretLocation)
        guard (lineEnd - lineStart) <= SearchDiffAndBracketEngine.maxBracketScanLineUTF16Length else {
            return nil
        }

        if isInsideFencedCodeBlock(in: units, beforeOffset: lineStart) {
            return nil
        }

        let lineString = String(decoding: units[lineStart..<lineEnd], as: UTF16.self)
        guard let parsed = parseContinuationMarker(in: lineString) else {
            return nil
        }

        let markerEndOffset = lineStart + parsed.markerUTF16Length
        guard caretLocation >= markerEndOffset else {
            return nil
        }

        if parsed.isEmptyContent, parsed.isNestedOrdered,
           case .edit(let outdented) = MarkdownSmartListEngine.evaluateIndent(
               in: snapshot,
               selection: TextRange(location: caretLocation, length: 0),
               outdent: true,
               isMarkdownDocument: true
           ),
           let outdentEdit = outdented.edits.first {
            return SmartNewlineEdit(edit: outdentEdit, newCaretLocation: outdented.newSelection.location)
        }

        if parsed.isEmptyContent {
            return SmartNewlineEdit(
                edit: TextEdit(range: TextRange(location: lineStart, length: lineEnd - lineStart), replacement: ""),
                newCaretLocation: lineStart
            )
        }

        let insertion = "\n" + parsed.nextLinePrefix
        return SmartNewlineEdit(
            edit: TextEdit(range: TextRange(location: caretLocation, length: 0), replacement: insertion),
            newCaretLocation: caretLocation + insertion.utf16.count
        )
    }

    private struct ParsedMarker {
        let markerUTF16Length: Int
        let nextLinePrefix: String
        let isEmptyContent: Bool
        var isNestedOrdered: Bool = false
    }

    private static func currentLineBounds(in units: [UInt16], around caret: Int) -> (start: Int, end: Int) {
        var start = caret
        while start > 0 && units[start - 1] != lfUnit && units[start - 1] != crUnit {
            start -= 1
        }
        var end = caret
        while end < units.count && units[end] != lfUnit && units[end] != crUnit {
            end += 1
        }
        return (start, end)
    }

    private static func isInsideFencedCodeBlock(in units: [UInt16], beforeOffset limitOffset: Int) -> Bool {
        var activeChar: UInt16?
        var activeLength = 0
        var lineStart = 0

        while lineStart < limitOffset {
            var lineEnd = lineStart
            while lineEnd < limitOffset && units[lineEnd] != lfUnit && units[lineEnd] != crUnit {
                lineEnd += 1
            }

            if let fenceChar = activeChar {
                if isClosingFence(in: units, lineStart: lineStart, lineEnd: lineEnd, fenceChar: fenceChar, minCount: activeLength) {
                    activeChar = nil
                    activeLength = 0
                }
            } else if let opened = openingFence(in: units, lineStart: lineStart, lineEnd: lineEnd) {
                activeChar = opened.char
                activeLength = opened.count
            }

            if lineEnd < limitOffset {
                if units[lineEnd] == crUnit, lineEnd + 1 < limitOffset, units[lineEnd + 1] == lfUnit {
                    lineStart = lineEnd + 2
                } else {
                    lineStart = lineEnd + 1
                }
            } else {
                break
            }
        }
        return activeChar != nil
    }

    private static func openingFence(in units: [UInt16], lineStart: Int, lineEnd: Int) -> (char: UInt16, count: Int)? {
        var idx = lineStart
        var spaces = 0
        while idx < lineEnd && units[idx] == spaceUnit && spaces < 3 {
            idx += 1
            spaces += 1
        }
        guard idx < lineEnd else { return nil }
        let ch = units[idx]
        guard ch == backtickUnit || ch == tildeUnit else { return nil }
        let start = idx
        while idx < lineEnd && units[idx] == ch {
            idx += 1
        }
        let count = idx - start
        guard count >= 3 else { return nil }
        if ch == backtickUnit {
            while idx < lineEnd {
                if units[idx] == backtickUnit { return nil }
                idx += 1
            }
        }
        return (ch, count)
    }

    private static func isClosingFence(in units: [UInt16], lineStart: Int, lineEnd: Int, fenceChar: UInt16, minCount: Int) -> Bool {
        var idx = lineStart
        var spaces = 0
        while idx < lineEnd && units[idx] == spaceUnit && spaces < 3 {
            idx += 1
            spaces += 1
        }
        let start = idx
        while idx < lineEnd && units[idx] == fenceChar {
            idx += 1
        }
        guard idx - start >= minCount else { return false }
        while idx < lineEnd {
            if units[idx] != spaceUnit && units[idx] != tabUnit { return false }
            idx += 1
        }
        return true
    }

    private static func parseContinuationMarker(in line: String) -> ParsedMarker? {
        let chars = Array(line)
        var idx = 0
        while idx < chars.count && (chars[idx] == " " || chars[idx] == "\t") {
            idx += 1
        }
        let indent = String(chars[0..<idx])
        guard idx < chars.count else { return nil }

        if let quote = parseBlockquote(chars: chars, from: idx, indent: indent) {
            return quote
        }
        if let task = parseTaskList(chars: chars, from: idx, indent: indent) {
            return task
        }
        if let unordered = parseUnorderedList(chars: chars, from: idx, indent: indent) {
            return unordered
        }
        if let ordered = parseOrderedList(chars: chars, from: idx, indent: indent) {
            return ordered
        }
        if let pseudo = MarkdownListGrammar.pseudoOutlineContinuation(ArraySlice(line.utf16)) {
            let remainder = String(chars[min(chars.count, pseudo.indent + pseudo.markerLength)...])
            return ParsedMarker(
                markerUTF16Length: pseudo.indent + pseudo.markerLength,
                nextLinePrefix: String(repeating: " ", count: pseudo.indent) + pseudo.nextMarker,
                isEmptyContent: remainder.trimmingCharacters(in: .whitespaces).isEmpty
            )
        }
        return nil
    }

    private static func parseBlockquote(chars: [Character], from start: Int, indent: String) -> ParsedMarker? {
        guard chars[start] == ">" else { return nil }
        var idx = start
        var quotePrefix = ""
        while idx < chars.count && chars[idx] == ">" {
            quotePrefix.append(">")
            idx += 1
            if idx < chars.count && chars[idx] == " " {
                quotePrefix.append(" ")
                idx += 1
            }
        }
        if !quotePrefix.hasSuffix(" ") {
            quotePrefix.append(" ")
        }
        let markerString = String(chars[0..<idx])
        let remainder = String(chars[idx..<chars.count])
        return ParsedMarker(
            markerUTF16Length: markerString.utf16.count,
            nextLinePrefix: indent + quotePrefix,
            isEmptyContent: remainder.trimmingCharacters(in: .whitespaces).isEmpty
        )
    }

    private static func parseTaskList(chars: [Character], from start: Int, indent: String) -> ParsedMarker? {
        let bullet = chars[start]
        guard (bullet == "-" || bullet == "*" || bullet == "+"),
              start + 5 < chars.count,
              chars[start + 1] == " ",
              chars[start + 2] == "[",
              (chars[start + 3] == " " || chars[start + 3] == "x" || chars[start + 3] == "X"),
              chars[start + 4] == "]",
              chars[start + 5] == " " else {
            return nil
        }
        let markerEnd = start + 6
        let markerString = String(chars[0..<markerEnd])
        let remainder = String(chars[markerEnd..<chars.count])
        return ParsedMarker(
            markerUTF16Length: markerString.utf16.count,
            nextLinePrefix: "\(indent)\(bullet) [ ] ",
            isEmptyContent: remainder.trimmingCharacters(in: .whitespaces).isEmpty
        )
    }

    private static func parseUnorderedList(chars: [Character], from start: Int, indent: String) -> ParsedMarker? {
        let bullet = chars[start]
        guard (bullet == "-" || bullet == "*" || bullet == "+"),
              start + 1 < chars.count,
              chars[start + 1] == " " else {
            return nil
        }
        let markerEnd = start + 2
        let markerString = String(chars[0..<markerEnd])
        let remainder = String(chars[markerEnd..<chars.count])
        return ParsedMarker(
            markerUTF16Length: markerString.utf16.count,
            nextLinePrefix: "\(indent)\(bullet) ",
            isEmptyContent: remainder.trimmingCharacters(in: .whitespaces).isEmpty
        )
    }

    private static func parseOrderedList(chars: [Character], from start: Int, indent: String) -> ParsedMarker? {
        var idx = start
        while idx < chars.count && chars[idx].isASCII && chars[idx].isNumber {
            idx += 1
        }
        guard idx > start,
              idx + 1 < chars.count,
              (chars[idx] == "." || chars[idx] == ")"),
              chars[idx + 1] == " " else {
            return nil
        }
        let numberString = String(chars[start..<idx])
        guard let currentNumber = Int(numberString) else { return nil }
        let (nextNumber, overflow) = currentNumber.addingReportingOverflow(1)
        guard !overflow else { return nil }

        let punctuation = chars[idx]
        let markerEnd = idx + 2
        let markerString = String(chars[0..<markerEnd])
        let remainder = String(chars[markerEnd..<chars.count])
        return ParsedMarker(
            markerUTF16Length: markerString.utf16.count,
            nextLinePrefix: "\(indent)\(nextNumber)\(punctuation) ",
            isEmptyContent: remainder.trimmingCharacters(in: .whitespaces).isEmpty,
            isNestedOrdered: indent.utf16.count >= 4
        )
    }
}
