import Foundation

/// Line-to-UTF-16 mapping for lint diagnostics, built on the shared `MarkdownLineIndex` so ranges are Unicode-scalar aligned and never derived from UTF-8 byte columns (`BC-004`).
public struct MarkdownSourceLineTable: Sendable {
    public let index: MarkdownLineIndex

    public init(text: String) { self.index = MarkdownLineIndex(text: text) }
    public init(index: MarkdownLineIndex) { self.index = index }

    public var lineCount: Int { index.lineCount }

    /// UTF-16 range of a 1-based `line` excluding its newline, or `nil` when out of bounds.
    public func range(ofLine line: Int) -> TextRange? {
        guard line >= 1, line <= index.lineCount else { return nil }
        return index.lineRange(line - 1)
    }
}

/// Detects Line-1 `---` ... `---` (or `...`) YAML frontmatter of at most `maxLines` lines so it can be masked with line-preserving blanks (`SEC-012`).
public enum YAMLFrontmatterScanner {
    public static let maxLines = MarkdownLineIndex.maxFrontmatterLines

    /// Number of leading lines belonging to the frontmatter block including both delimiters; `0` when none or when unterminated within `maxLines`.
    public static func maskedLineCount(in index: MarkdownLineIndex) -> Int {
        index.frontmatterLineCount
    }
}
