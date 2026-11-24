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
        outline(index: MarkdownLineIndex(text: text))
    }

    /// Variant reusing a revision-cached `MarkdownLineIndex` (`PERF-017-B3`).
    public static func outline(index: MarkdownLineIndex) -> [MarkdownHeading] {
        let skipFrontLines = index.frontmatterLineCount
        var fenceCursor = 0
        var result: [MarkdownHeading] = []
        let units = index.units
        let unitCount = units.count
        let starts = index.lineStarts
        let lineCount = starts.count
        let fences = index.fences
        var line = skipFrontLines
        while line < lineCount, result.count < maxHeadings {
            // Fences are ordered; skip whole fenced ranges.
            while fenceCursor < fences.count, fences[fenceCursor].close < line { fenceCursor += 1 }
            if fenceCursor < fences.count, fences[fenceCursor].open <= line {
                line = fences[fenceCursor].close + 1
                continue
            }
            let start = starts[line]
            if start < unitCount {
                let first = units[start]
                if first == 0x23 || first == 0x20 {
                    let end = line + 1 < lineCount ? starts[line + 1] - 1 : unitCount
                    if let heading = parse(units[start..<max(start, end)], offset: start) {
                        result.append(heading)
                    }
                }
            }
            line += 1
        }
        return result
    }

    private static func parse(_ slice: ArraySlice<UInt16>, offset: Int) -> MarkdownHeading? {
        guard slice.count <= MarkdownLineIndex.maxLineUTF16,
              let opened = consumeATXOpeningMarker(slice) else { return nil }
        let titleRange = trimATXHeadingBodyBounds(slice, from: opened.bodyStart, to: opened.trimmedEnd)
        let title = decodeATXHeadingTitle(slice, range: titleRange)
        return MarkdownHeading(level: opened.level, title: title, utf16Offset: offset)
    }
}

extension MarkdownHeadingOutlineEngine {
    private static func consumeATXOpeningMarker(_ slice: ArraySlice<UInt16>) -> (level: Int, bodyStart: Int, trimmedEnd: Int)? {
        var i = slice.startIndex
        var end = slice.endIndex
        var spaces = 0
        while i < end, spaces < 4, slice[i] == 0x20 { i += 1; spaces += 1 }
        guard spaces <= 3, i < end, slice[i] == 0x23 else { return nil }

        while end > i, isHeadingTrailingTrimUnit(slice[end - 1]) { end -= 1 }

        var level = 0
        while i < end, slice[i] == 0x23 { level += 1; i += 1 }
        guard (1...6).contains(level), i == end || isHeadingHorizontalSpace(slice[i]) else { return nil }
        return (level, i, end)
    }

    private static func trimATXHeadingBodyBounds(_ slice: ArraySlice<UInt16>, from start: Int, to initialEnd: Int) -> Range<Int> {
        var i = start
        var end = initialEnd
        var bodyEnd = end
        while bodyEnd > i, slice[bodyEnd - 1] == 0x23 { bodyEnd -= 1 }
        if bodyEnd < end, bodyEnd == i || isHeadingHorizontalSpace(slice[bodyEnd - 1]) {
            end = bodyEnd
        }
        while i < end, isHeadingHorizontalSpace(slice[i]) { i += 1 }
        while end > i, isHeadingHorizontalSpace(slice[end - 1]) { end -= 1 }
        return i..<end
    }

    private static func decodeATXHeadingTitle(_ slice: ArraySlice<UInt16>, range: Range<Int>) -> String {
        let rawTitle = String(decoding: slice[range], as: UTF16.self)
        guard !range.isEmpty, slice[range.lowerBound] >= 0x80 || slice[range.upperBound - 1] >= 0x80 else {
            return rawTitle
        }
        return rawTitle.trimmingCharacters(in: .whitespaces)
    }

    @inline(__always)
    private static func isHeadingTrailingTrimUnit(_ u: UInt16) -> Bool {
        u == 0x0D || u == 0x20 || u == 0x09
    }

    @inline(__always)
    private static func isHeadingHorizontalSpace(_ u: UInt16) -> Bool {
        u == 0x20 || u == 0x09
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
    /// Identical queries are ignored so SwiftUI TextField commit/focus callbacks never reset `selectedIndex` before confirm.
    public mutating func setQuery(_ newQuery: String) {
        guard newQuery != query else { return }
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
