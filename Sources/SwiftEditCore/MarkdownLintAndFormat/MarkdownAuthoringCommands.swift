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
        guard let ctx = validatedAuthoringContext(in: snapshot, selection: selection, isMarkdownDocument: isMarkdownDocument) else {
            return nil
        }
        if let inlineEdit = evaluateInlineAuthoringCommand(command, text: ctx.text, selection: selection) {
            return inlineEdit
        }
        return evaluateBlockAuthoringCommand(command, context: ctx, selection: selection)
    }

    private static func wrap(_ marker: String, _ text: NSString, _ sel: TextRange) -> MarkdownAuthoringEdit {
        let m = (marker as NSString).length
        let selected = text.substring(with: NSRange(location: sel.location, length: sel.length))
        if sel.length >= 2 * m, selected.hasPrefix(marker), selected.hasSuffix(marker) {
            let inner = (selected as NSString).substring(with: NSRange(location: m, length: sel.length - 2 * m))
            return MarkdownAuthoringEdit(edits: [TextEdit(range: sel, replacement: inner)], newSelection: TextRange(location: sel.location, length: sel.length - 2 * m))
        }
        if hasSurroundingMarker(marker, markerLength: m, in: text, around: sel) {
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

extension MarkdownAuthoringCommands {
    private struct ValidatedAuthoringContext {
        let text: NSString
        let index: MarkdownLineIndex
        let firstLine: Int
        let lastLine: Int
    }

    private static func validatedAuthoringContext(
        in snapshot: DocumentSnapshot,
        selection: TextRange,
        isMarkdownDocument: Bool
    ) -> ValidatedAuthoringContext? {
        guard isMarkdownDocument, !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText else { return nil }
        let text = snapshot.text as NSString
        guard selection.location >= 0, selection.length >= 0, selection.upperBound <= text.length else { return nil }
        let index = MarkdownLineIndex(text: snapshot.text)
        let firstLine = index.line(containing: selection.location)
        let lastLine = index.line(containing: selection.upperBound)
        guard isAuthoringLineSpanAdmissible(in: index, firstLine: firstLine, lastLine: lastLine) else { return nil }
        return ValidatedAuthoringContext(text: text, index: index, firstLine: firstLine, lastLine: lastLine)
    }

    private static func isAuthoringLineSpanAdmissible(in index: MarkdownLineIndex, firstLine: Int, lastLine: Int) -> Bool {
        for line in firstLine...lastLine {
            if index.isFenced(line: line) { return false }
            if index.lineRange(line).length > MarkdownLineIndex.maxLineUTF16 { return false }
        }
        return true
    }

    private static func evaluateInlineAuthoringCommand(
        _ command: MarkdownAuthoringCommand,
        text: NSString,
        selection: TextRange
    ) -> MarkdownAuthoringEdit? {
        switch command {
        case .bold: return wrap("**", text, selection)
        case .italic: return wrap("*", text, selection)
        case .strikethrough: return wrap("~~", text, selection)
        case .inlineCode: return wrap("`", text, selection)
        case .link: return bracketed(prefix: "[", suffix: "](url)", placeholder: "text", text, selection, selectsDestination: true)
        case .image: return bracketed(prefix: "![", suffix: "](src)", placeholder: "alt", text, selection, selectsDestination: true)
        default: return nil
        }
    }

    private static func evaluateBlockAuthoringCommand(
        _ command: MarkdownAuthoringCommand,
        context: ValidatedAuthoringContext,
        selection: TextRange
    ) -> MarkdownAuthoringEdit? {
        switch command {
        case .heading(let level):
            return (1...6).contains(level) ? heading(level, context.index, context.text, selection) : nil
        case .blockquote:
            return linePrefixToggle("> ", context.index, selection)
        case .taskToggle:
            return taskToggle(context.index, selection)
        case .codeFence:
            return fence(context.index, context.text, selection, context.firstLine, context.lastLine)
        case .insertTable:
            let table = "| Column 1 | Column 2 |\n| --- | --- |\n|  |  |"
            return MarkdownAuthoringEdit(
                edits: [TextEdit(range: selection, replacement: table)],
                newSelection: TextRange(location: selection.location + 2, length: 8)
            )
        default:
            return nil
        }
    }

    private static func hasSurroundingMarker(_ marker: String, markerLength m: Int, in text: NSString, around sel: TextRange) -> Bool {
        guard sel.location >= m, sel.upperBound + m <= text.length else { return false }
        let leading = text.substring(with: NSRange(location: sel.location - m, length: m))
        let trailing = text.substring(with: NSRange(location: sel.upperBound, length: m))
        return leading == marker && trailing == marker
    }
}
