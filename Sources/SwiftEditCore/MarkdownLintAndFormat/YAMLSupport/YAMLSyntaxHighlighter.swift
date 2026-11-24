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
