import Foundation

/// One ATX heading of a Markdown document.
public struct MarkdownHeading: Equatable, Sendable, Identifiable {
    /// Heading level `1...6` (number of leading `#`).
    public let level: Int
    /// Display title with the marker and the optional closing `#` run removed.
    public let title: String
    /// UTF-16 offset of the heading line start (caret target).
    public let utf16Offset: Int
    public var id: Int { utf16Offset }
}

/// Pure on-the-fly ATX heading scanner (`#`..`######`) used by the document navigator.
///
/// Why single pass over `MarkdownLineIndex`: it reuses the shared fence index and UTF-16 offsets
/// (`BC-004`), allocates nothing while the navigator is closed and is O(n) with hard caps (`SEC-012`).
/// Setext headings are intentionally unsupported.
public enum MarkdownHeadingOutlineEngine {
    /// Maximum number of headings returned (CWE-400 guard).
    public static let maxHeadings = 5000

    public static func outline(for text: String) -> [MarkdownHeading] {
        let index = MarkdownLineIndex(text: text)
        let skipFrontLines = YAMLFrontmatterScanner.maskedLineCount(in: index)
        var fenceCursor = 0
        var result: [MarkdownHeading] = []
        var line = skipFrontLines
        while line < index.lineCount, result.count < maxHeadings {
            // Fences are ordered; skip whole fenced ranges.
            while fenceCursor < index.fences.count, index.fences[fenceCursor].close < line { fenceCursor += 1 }
            if fenceCursor < index.fences.count, index.fences[fenceCursor].open <= line {
                line = index.fences[fenceCursor].close + 1
                continue
            }
            if let heading = parse(index.lineSlice(line), offset: index.lineStarts[line]) { result.append(heading) }
            line += 1
        }
        return result
    }

    private static func parse(_ slice: ArraySlice<UInt16>, offset: Int) -> MarkdownHeading? {
        guard slice.count <= MarkdownLineIndex.maxLineUTF16 else { return nil }
        var units = Array(slice)
        while let last = units.last, last == 0x0D || last == 0x20 || last == 0x09 { units.removeLast() }
        var i = 0
        while i < units.count, i < 4, units[i] == 0x20 { i += 1 }
        guard i <= 3 else { return nil }
        var level = 0
        while i < units.count, units[i] == 0x23 { level += 1; i += 1 }
        guard (1...6).contains(level) else { return nil }
        guard i == units.count || units[i] == 0x20 || units[i] == 0x09 else { return nil }
        var body = Array(units[i...])
        // Closing sequence: trailing `#` run preceded by a space (or the whole body).
        var end = body.count
        while end > 0, body[end - 1] == 0x23 { end -= 1 }
        if end < body.count, end == 0 || body[end - 1] == 0x20 || body[end - 1] == 0x09 { body = Array(body[..<end]) }
        let title = String(decoding: body, as: UTF16.self).trimmingCharacters(in: .whitespaces)
        return MarkdownHeading(level: level, title: title, utf16Offset: offset)
    }
}

/// Value-type state of the document navigator palette (query, filtered rows, wrapping selection).
public struct DocumentNavigatorState: Equatable, Sendable {
    public let headings: [MarkdownHeading]
    public private(set) var query: String = ""
    public private(set) var filtered: [MarkdownHeading]
    public private(set) var selectedIndex: Int = 0

    public init(headings: [MarkdownHeading]) {
        self.headings = headings
        self.filtered = headings
    }

    /// Case-insensitive substring filter; an empty query shows ALL headings.
    public mutating func setQuery(_ newQuery: String) {
        query = newQuery
        let needle = newQuery.trimmingCharacters(in: .whitespaces)
        filtered = needle.isEmpty ? headings : headings.filter { $0.title.localizedCaseInsensitiveContains(needle) }
        selectedIndex = 0
    }

    public mutating func moveDown() {
        guard !filtered.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % filtered.count
    }

    public mutating func moveUp() {
        guard !filtered.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + filtered.count) % filtered.count
    }

    public mutating func select(index: Int) {
        if filtered.indices.contains(index) { selectedIndex = index }
    }

    /// UTF-16 caret target for the selected row, clamped to `documentLength`; `nil` when nothing is selectable.
    public func confirm(documentLength: Int) -> Int? {
        guard filtered.indices.contains(selectedIndex) else { return nil }
        return min(max(0, filtered[selectedIndex].utf16Offset), max(0, documentLength))
    }
}
