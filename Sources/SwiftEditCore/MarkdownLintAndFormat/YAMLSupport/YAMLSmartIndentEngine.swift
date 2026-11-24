import Foundation

/// Two-space YAML `Enter`/`Tab` engine for `.yaml` tabs and Markdown frontmatter (`REQ-006`, `BC-003`, `BC-004`).
///
/// Never inserts a tab character (YAML forbids tab indentation). Work is bounded by the caret line plus, for Markdown,
/// the first `YAMLFrontmatterScanner.maxLines + 2` lines used to locate the frontmatter, so cost never scales with the
/// document. Returned edits are applied by the caller as one undoable `BufferRevision`.
public enum YAMLSmartIndentEngine {
    static let indentUnit = 2

    /// Returns the `Enter` edit, or `nil` when the caret is not in a YAML context (plain text, Markdown body, binary).
    public static func evaluateNewline(in snapshot: DocumentSnapshot, caretLocation: Int, language: DocumentLanguage) -> SmartNewlineEdit? {
        guard let context = context(in: snapshot, caret: caretLocation, language: language) else { return nil }
        let line = context.line
        let prefixEnd = line.startIndex + (caretLocation - context.lineStart)
        let prefix = line[line.startIndex..<prefixEnd]
        let suffixIsBlank = line[prefixEnd...].allSatisfy { YAMLLineTokenizer.isBlank($0) || $0 == YAMLLineTokenizer.cr }
        let indent = prefix.prefix { YAMLLineTokenizer.isBlank($0) }.count
        let tokens = YAMLLineTokenizer.tokens(line: prefix).filter { $0.kind != .comment }

        // Empty `- ` marker: exit the list, keeping the indentation.
        if suffixIsBlank, tokens.count == 1, tokens[0].kind == .listDash {
            let removeFrom = context.lineStart + indent
            return SmartNewlineEdit(
                edit: TextEdit(range: TextRange(location: removeFrom, length: caretLocation - removeFrom), replacement: ""),
                newCaretLocation: removeFrom
            )
        }
        var newIndent = indent
        var marker = ""
        if let last = tokens.last, last.kind == .colon, let key = tokens.last(where: { $0.kind == .key }) {
            newIndent = key.range.location + indentUnit
        } else if let dash = tokens.first, dash.kind == .listDash, tokens.count > 1 {
            newIndent = dash.range.location
            marker = "- "
        }
        let insertion = "\n" + String(repeating: " ", count: newIndent) + marker
        return SmartNewlineEdit(
            edit: TextEdit(range: TextRange(location: caretLocation, length: 0), replacement: insertion),
            newCaretLocation: caretLocation + (insertion as NSString).length
        )
    }

    /// `Tab` inserts two spaces (replacing the selection); `Shift+Tab` removes up to two leading spaces of the caret line.
    public static func evaluateTab(in snapshot: DocumentSnapshot, selection: TextRange, outdent: Bool, language: DocumentLanguage) -> SmartListOutcome {
        guard let context = context(in: snapshot, caret: selection.location, language: language) else { return .notApplicable }
        if !outdent {
            let edit = TextEdit(range: selection, replacement: String(repeating: " ", count: indentUnit))
            return .edit(SmartListEdit(edits: [edit], newSelection: TextRange(location: selection.location + indentUnit, length: 0)))
        }
        let removable = min(indentUnit, context.line.prefix { $0 == YAMLLineTokenizer.space }.count)
        guard removable > 0 else { return .consumedNoOp }
        let edit = TextEdit(range: TextRange(location: context.lineStart, length: removable), replacement: "")
        let shifted = max(context.lineStart, selection.location - removable)
        return .edit(SmartListEdit(edits: [edit], newSelection: TextRange(location: shifted, length: selection.length)))
    }

    private struct LineContext {
        let lineStart: Int
        let line: ArraySlice<UInt16>
    }

    /// Resolves the caret line when it lies in a YAML context; `nil` otherwise.
    private static func context(in snapshot: DocumentSnapshot, caret: Int, language: DocumentLanguage) -> LineContext? {
        guard language != .plainText, !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText else { return nil }
        let utf16 = snapshot.text.utf16
        guard caret >= 0, caret <= utf16.count else { return nil }
        let caretIndex = utf16.index(utf16.startIndex, offsetBy: caret)
        var startIndex = caretIndex
        while startIndex > utf16.startIndex {
            let previous = utf16.index(before: startIndex)
            if utf16[previous] == 0x0A { break }
            startIndex = previous
        }
        var endIndex = caretIndex
        while endIndex < utf16.endIndex, utf16[endIndex] != 0x0A { endIndex = utf16.index(after: endIndex) }
        let line = Array(utf16[startIndex..<endIndex])
        guard line.count <= YAMLSupportLimits.maxLineUTF16 else { return nil }
        let lineStart = utf16.distance(from: utf16.startIndex, to: startIndex)
        if language == .markdown, isInsideFrontmatter(snapshot.text, lineStart: lineStart) == false { return nil }
        return LineContext(lineStart: lineStart, line: line[...])
    }

    /// `true` when `lineStart` begins an interior line of the line-1 frontmatter block (delimiters excluded).
    private static func isInsideFrontmatter(_ text: String, lineStart: Int) -> Bool {
        guard let index = FrontmatterLocator.prefixIndex(of: text) else { return false }
        let count = index.frontmatterLineCount
        guard count >= 3 else { return false }
        let line = index.line(containing: lineStart)
        return line >= 1 && line <= count - 2
    }
}
