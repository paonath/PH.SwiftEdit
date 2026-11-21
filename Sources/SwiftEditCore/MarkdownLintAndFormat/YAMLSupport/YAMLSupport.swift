import Foundation

/// Shared bounds for the zero-dependency YAML subset engines owned by `MarkdownLintAndFormat` (`BC-001`, `SEC-012`).
///
/// Every YAML engine (tokenizer, highlighter, linter, outline, smart indent, frontmatter properties) is pure `Foundation`
/// and consumes the per-revision `MarkdownLineIndex`, so no engine copies the buffer again or recurses on untrusted input.
public enum YAMLSupportLimits {
    /// Lines longer than this (UTF-16 units) are skipped by every YAML engine (`CWE-400`).
    public static let maxLineUTF16 = MarkdownLineIndex.maxLineUTF16
    /// Maximum mapping nesting depth inspected by the structural linter.
    public static let maxDepth = 32
    /// Maximum diagnostics emitted per document.
    public static let maxDiagnostics = 1_000
    /// Maximum top-level keys listed by the outline.
    public static let maxOutlineEntries = 5_000
    /// Maximum frontmatter properties exposed to the Properties panel.
    public static let maxProperties = 500
}
