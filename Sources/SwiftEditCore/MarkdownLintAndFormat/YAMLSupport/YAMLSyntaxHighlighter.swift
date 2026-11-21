import Foundation

/// Viewport-only YAML tokenizer projection for `.yaml` tabs and Markdown frontmatter (`BC-004`, `UI-012`, `SEC-012`).
///
/// Only lines intersecting `visibleRange` are tokenized, reusing the per-revision `MarkdownLineIndex`, so per-fragment cost
/// is bounded by the viewport. Core returns span kinds only; colors and the lighter key weight are applied by `SwiftEditUI`.
public enum YAMLSyntaxHighlighter {

    /// Returns YAML spans for visible lines, restricted to lines `0..<lineLimit` when given (frontmatter delegation).
    public static func spans(index: MarkdownLineIndex, visibleRange: TextRange, lineLimit: Int? = nil) -> [MarkdownSyntaxSpan] {
        guard visibleRange.length > 0, !index.units.isEmpty else { return [] }
        let first = index.line(containing: visibleRange.location)
        var last = index.line(containing: max(visibleRange.location, visibleRange.upperBound - 1))
        if let lineLimit { last = min(last, lineLimit - 1) }
        guard first <= last else { return [] }
        var out: [MarkdownSyntaxSpan] = []
        out.reserveCapacity((last - first + 1) * 3)
        for line in first...last {
            let range = index.lineRange(line)
            guard range.length > 0, range.length <= YAMLSupportLimits.maxLineUTF16 else { continue }
            for token in YAMLLineTokenizer.tokens(line: index.lineSlice(line)) {
                out.append(MarkdownSyntaxSpan(
                    kind: kind(for: token.kind),
                    range: TextRange(location: range.location + token.range.location, length: token.range.length)
                ))
            }
        }
        return out
    }

    /// Token-to-span mapping: keys and values are visually separated; every structural indicator is punctuation.
    static func kind(for token: YAMLTokenKind) -> MarkdownSyntaxKind {
        switch token {
        case .key: return .yamlKey
        case .value, .quotedString: return .yamlValue
        case .comment: return .yamlComment
        case .colon, .listDash, .anchor, .alias, .tag, .documentMarker, .blockScalarIndicator: return .yamlPunctuation
        }
    }
}

/// Language dispatcher used by the TextKit 2 rendering validator: Markdown (with frontmatter delegation), YAML, or nothing.
public enum DocumentSyntaxHighlighter {

    /// Snapshot entry point; binary, degraded and plain-text snapshots never produce spans (`DATA-003`).
    public static func spans(snapshot: DocumentSnapshot, visibleRange: TextRange, language: DocumentLanguage) -> [MarkdownSyntaxSpan] {
        guard !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText, visibleRange.length > 0, language != .plainText else { return [] }
        return spans(index: MarkdownLineIndex(text: snapshot.text), visibleRange: visibleRange, language: language)
    }

    /// Hot-path entry point reusing a revision-cached `MarkdownLineIndex`.
    public static func spans(index: MarkdownLineIndex, visibleRange: TextRange, language: DocumentLanguage) -> [MarkdownSyntaxSpan] {
        switch language {
        case .markdown: return MarkdownSyntaxHighlighter.spans(index: index, visibleRange: visibleRange)
        case .yaml: return YAMLSyntaxHighlighter.spans(index: index, visibleRange: visibleRange)
        case .plainText: return []
        }
    }
}
