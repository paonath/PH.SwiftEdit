import Foundation

/// One ATX heading of a Markdown document.
public struct MarkdownHeading: Equatable, Sendable, Identifiable {
    /// Heading level `1...6` (number of leading `#`).
    public let level: Int
    /// Display title with the marker and the optional closing `#` run removed.
    public let title: String
    /// UTF-16 offset of the heading line start (caret target).
    public let utf16Offset: Int
    /// Entry kind, so Markdown headings and YAML top-level keys share one navigator row type and jump path.
    public var kind: OutlineEntryKind = .heading
    public var id: Int { utf16Offset }
    /// Grey row badge: `H<level>` for headings, `KEY` for YAML keys.
    public var badge: String { kind == .yamlKey ? "KEY" : "H\(level)" }
}

/// Navigator entry source (`REQ-005`).
public enum OutlineEntryKind: Equatable, Sendable { case heading, yamlKey }

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
        let start = slice.startIndex
        var end = slice.endIndex
        var i = start
        var spaces = 0
        while i < end, spaces < 4, slice[i] == 0x20 { i += 1; spaces += 1 }
        guard spaces <= 3, i < end, slice[i] == 0x23 else { return nil }

        // Trim trailing CR/space/tab only on lines that actually begin with `#`.
        while end > i {
            let u = slice[end - 1]
            if u == 0x0D || u == 0x20 || u == 0x09 { end -= 1 } else { break }
        }

        var level = 0
        while i < end, slice[i] == 0x23 { level += 1; i += 1 }
        guard (1...6).contains(level) else { return nil }
        guard i == end || slice[i] == 0x20 || slice[i] == 0x09 else { return nil }

        // Trim optional closing `#` run preceded by space/tab (or covering the whole body).
        var bodyEnd = end
        while bodyEnd > i, slice[bodyEnd - 1] == 0x23 { bodyEnd -= 1 }
        if bodyEnd < end, bodyEnd == i || slice[bodyEnd - 1] == 0x20 || slice[bodyEnd - 1] == 0x09 {
            end = bodyEnd
        }

        // Trim leading/trailing ASCII space/tab before decoding to String.
        while i < end, slice[i] == 0x20 || slice[i] == 0x09 { i += 1 }
        while end > i, slice[end - 1] == 0x20 || slice[end - 1] == 0x09 { end -= 1 }
        let title = String(decoding: slice[i..<end], as: UTF16.self).trimmingCharacters(in: .whitespaces)
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
        let previousNeedle = query.trimmingCharacters(in: .whitespaces)
        query = newQuery
        let needle = newQuery.trimmingCharacters(in: .whitespaces)
        if needle.isEmpty {
            filtered = headings
        } else {
            let source = (!previousNeedle.isEmpty && needle.localizedCaseInsensitiveContains(previousNeedle))
                ? filtered
                : headings
            filtered = source.filter { $0.title.localizedCaseInsensitiveContains(needle) }
        }
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
