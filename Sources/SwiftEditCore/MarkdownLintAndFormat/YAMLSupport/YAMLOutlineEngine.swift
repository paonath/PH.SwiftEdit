import Foundation

/// Top-level YAML key outline for the document navigator (`REQ-005`, `BC-004`, `SEC-012`).
///
/// Only mapping keys at column `0` are listed: nested keys, comments, list items and block-scalar bodies (always indented)
/// are excluded by construction, so one linear pass with no structural stack suffices. Capped at
/// `YAMLSupportLimits.maxOutlineEntries` and computed only while the navigator is open.
public enum YAMLOutlineEngine {
    public static func outline(index: MarkdownLineIndex) -> [MarkdownHeading] {
        var result: [MarkdownHeading] = []
        let starts = index.lineStarts
        for line in 0..<starts.count {
            guard result.count < YAMLSupportLimits.maxOutlineEntries else { break }
            if let heading = outlineHeading(forLine: line, in: index) {
                result.append(heading)
            }
        }
        return result
    }

    private static func outlineHeading(forLine line: Int, in index: MarkdownLineIndex) -> MarkdownHeading? {
        let units = index.units
        guard let range = contentLineRange(forLine: line, units: units, starts: index.lineStarts),
              !isIgnoredTopLevelLine(units, start: range.lowerBound, end: range.upperBound) else {
            return nil
        }
        let slice = units[range]
        guard let keyEnd = YAMLLineTokenizer.keyEnd(slice, from: range.lowerBound, end: range.upperBound) else {
            return nil
        }
        let title = String(decoding: units[range.lowerBound..<keyEnd.keyUpper], as: UTF16.self)
        return MarkdownHeading(level: 1, title: title, utf16Offset: range.lowerBound, kind: .yamlKey)
    }

    private static func contentLineRange(forLine line: Int, units: [UInt16], starts: [Int]) -> Range<Int>? {
        let unitCount = units.count
        let lineCount = starts.count
        let start = starts[line]
        guard start < unitCount else { return nil }
        let rawEnd = line + 1 < lineCount ? starts[line + 1] - 1 : unitCount
        var end = max(start, rawEnd)
        if end > start, units[end - 1] == YAMLLineTokenizer.cr { end -= 1 }
        // Skip blank lines across LF, CRLF, and CR endings before slicing (`MODIFIED REQ-005`, `SEC-012`).
        guard end > start, end - start <= YAMLSupportLimits.maxLineUTF16 else { return nil }
        return start..<end
    }

    private static func isIgnoredTopLevelLine(_ units: [UInt16], start: Int, end: Int) -> Bool {
        let first = units[start]
        if first == YAMLLineTokenizer.space || first == YAMLLineTokenizer.tab || first == YAMLLineTokenizer.hash {
            return true
        }
        if isDocumentBoundaryMarker(units, start: start, end: end, first: first) {
            return true
        }
        return first == YAMLLineTokenizer.dash && (start + 1 == end || YAMLLineTokenizer.isBlank(units[start + 1]))
    }

    private static func isDocumentBoundaryMarker(_ units: [UInt16], start: Int, end: Int, first: UInt16) -> Bool {
        guard end - start >= 3, first == YAMLLineTokenizer.dash || first == YAMLLineTokenizer.dot else {
            return false
        }
        guard units[start + 1] == first, units[start + 2] == first else { return false }
        return end - start == 3 || YAMLLineTokenizer.isBlank(units[start + 3])
    }
}
