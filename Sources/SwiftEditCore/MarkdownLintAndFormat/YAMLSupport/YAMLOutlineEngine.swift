import Foundation

/// Top-level YAML key outline for the document navigator (`REQ-005`, `BC-004`, `SEC-012`).
///
/// Only mapping keys at column `0` are listed: nested keys, comments, list items and block-scalar bodies (always indented)
/// are excluded by construction, so one linear pass with no structural stack suffices. Capped at
/// `YAMLSupportLimits.maxOutlineEntries` and computed only while the navigator is open.
public enum YAMLOutlineEngine {
    public static func outline(index: MarkdownLineIndex) -> [MarkdownHeading] {
        var result: [MarkdownHeading] = []
        let units = index.units
        let unitCount = units.count
        let starts = index.lineStarts
        let lineCount = starts.count
        for line in 0..<lineCount {
            guard result.count < YAMLSupportLimits.maxOutlineEntries else { break }
            let start = starts[line]
            guard start < unitCount else { continue }
            let first = units[start]
            guard first != YAMLLineTokenizer.space,
                  first != YAMLLineTokenizer.tab,
                  first != YAMLLineTokenizer.hash else { continue }
            let rawEnd = line + 1 < lineCount ? starts[line + 1] - 1 : unitCount
            var end = max(start, rawEnd)
            if end > start, units[end - 1] == YAMLLineTokenizer.cr { end -= 1 }
            guard end - start <= YAMLSupportLimits.maxLineUTF16 else { continue }
            if end - start >= 3, (first == YAMLLineTokenizer.dash || first == YAMLLineTokenizer.dot),
               units[start + 1] == first, units[start + 2] == first,
               end - start == 3 || YAMLLineTokenizer.isBlank(units[start + 3]) {
                continue
            }
            if first == YAMLLineTokenizer.dash, start + 1 == end || YAMLLineTokenizer.isBlank(units[start + 1]) {
                continue
            }
            let slice = units[start..<end]
            guard let keyEnd = YAMLLineTokenizer.keyEnd(slice, from: start, end: end) else { continue }
            let title = String(decoding: units[start..<keyEnd.keyUpper], as: UTF16.self)
            result.append(MarkdownHeading(level: 1, title: title, utf16Offset: start, kind: .yamlKey))
        }
        return result
    }
}
