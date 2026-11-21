import Foundation

/// Top-level YAML key outline for the document navigator (`REQ-005`, `BC-004`, `SEC-012`).
///
/// Only mapping keys at column `0` are listed: nested keys, comments, list items and block-scalar bodies (always indented)
/// are excluded by construction, so one linear pass with no structural stack suffices. Capped at
/// `YAMLSupportLimits.maxOutlineEntries` and computed only while the navigator is open.
public enum YAMLOutlineEngine {
    public static func outline(index: MarkdownLineIndex) -> [MarkdownHeading] {
        var result: [MarkdownHeading] = []
        for line in 0..<index.lineCount {
            guard result.count < YAMLSupportLimits.maxOutlineEntries else { break }
            let slice = index.lineSlice(line)
            guard let first = slice.first, first != YAMLLineTokenizer.space, first != YAMLLineTokenizer.tab else { continue }
            guard let key = YAMLLineTokenizer.tokens(line: slice).first, key.kind == .key, key.range.location == 0 else { continue }
            let units = slice[slice.startIndex..<(slice.startIndex + key.range.length)]
            let title = String(decoding: units, as: UTF16.self)
            result.append(MarkdownHeading(level: 1, title: title, utf16Offset: index.lineStarts[line], kind: .yamlKey))
        }
        return result
    }
}
