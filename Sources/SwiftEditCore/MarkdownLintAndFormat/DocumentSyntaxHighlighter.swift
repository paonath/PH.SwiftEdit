import Foundation

/// Language dispatcher used by the TextKit 2 rendering validator: Markdown (with frontmatter delegation), YAML, log, or nothing (`BC-004`, `AR-006`).
public enum DocumentSyntaxHighlighter {

    /// Snapshot entry point; binary, degraded, and plain-text snapshots never produce spans (`DATA-003`).
    public static func spans(snapshot: DocumentSnapshot, visibleRange: TextRange, language: DocumentLanguage) -> [MarkdownSyntaxSpan] {
        guard !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText, visibleRange.length > 0, language != .plainText else { return [] }
        return spans(index: MarkdownLineIndex(text: snapshot.text), visibleRange: visibleRange, language: language)
    }

    /// Hot-path entry point reusing a revision-cached `MarkdownLineIndex`.
    public static func spans(index: MarkdownLineIndex, visibleRange: TextRange, language: DocumentLanguage) -> [MarkdownSyntaxSpan] {
        switch language {
        case .markdown: return MarkdownSyntaxHighlighter.spans(index: index, visibleRange: visibleRange)
        case .yaml: return YAMLSyntaxHighlighter.spans(index: index, visibleRange: visibleRange)
        case .log: return LogSyntaxHighlighter.spans(index: index, visibleRange: visibleRange)
        case .plainText: return []
        }
    }
}
