import Foundation

/// Display classification of one top-level frontmatter value (`REQ-007`).
///
/// Only `scalar` and `list` are editable. Every construct whose faithful rewrite would require a full YAML serializer
/// (nested maps, block scalars, anchors/aliases, tags) is read-only, so the Properties panel never rewrites what it
/// cannot represent and never materializes aliased content (`CWE-776`, `SEC-012`).
public enum FrontmatterValueKind: Equatable, Sendable {
    case scalar(String)
    case list([String])
    case nestedMap, blockScalar, aliased, tagged

    public var isEditable: Bool {
        switch self {
        case .scalar, .list: return true
        case .nestedMap, .blockScalar, .aliased, .tagged: return false
        }
    }
}

/// One top-level frontmatter entry with the exact document lines it owns.
public struct FrontmatterProperty: Equatable, Sendable, Identifiable {
    public let key: String
    public let kind: FrontmatterValueKind
    /// 0-based, half-open document line range owned by the entry (key line plus indented continuation lines).
    public let lineRange: Range<Int>
    /// UTF-16 range of the owned lines including the final newline.
    public let utf16Range: TextRange
    /// Inline comment on the key line (`# ...`), re-emitted verbatim by the writer.
    public let trailingComment: String?
    public var id: String { key }
    public var isEditable: Bool { kind.isEditable }

    public init(key: String, kind: FrontmatterValueKind, lineRange: Range<Int>, utf16Range: TextRange, trailingComment: String? = nil) {
        self.key = key
        self.kind = kind
        self.lineRange = lineRange
        self.utf16Range = utf16Range
        self.trailingComment = trailingComment
    }
}

/// Immutable, revision-tagged frontmatter model consumed by the Properties panel (`AR-008`).
public struct FrontmatterPropertyModel: Equatable, Sendable {
    public let documentID: DocumentID
    public let revision: BufferRevision
    public let properties: [FrontmatterProperty]
    /// `true` when the block is unterminated, malformed, or exceeds `YAMLSupportLimits.maxProperties`: nothing is editable.
    public let isReadOnly: Bool
    /// 0-based line of the closing delimiter (`-1` when unterminated).
    public let closingDelimiterLine: Int
    /// UTF-16 offset of the closing delimiter line start (`-1` when unterminated); additions are inserted here.
    public let closingDelimiterOffset: Int
}

/// Bounded frontmatter location helpers shared by the parser and the YAML smart-indent engine.
enum FrontmatterLocator {
    /// Line index over at most the first `YAMLFrontmatterScanner.maxLines + 2` lines, so frontmatter lookups never scale
    /// with the document body.
    static func prefixIndex(of text: String) -> MarkdownLineIndex? {
        guard text.hasPrefix("---") else { return nil }
        var newlines = 0
        var cutoff = text.utf16.endIndex
        for i in text.utf16.indices where text.utf16[i] == 0x0A {
            newlines += 1
            if newlines > YAMLFrontmatterScanner.maxLines + 1 { cutoff = i; break }
        }
        return MarkdownLineIndex(text: String(text[text.startIndex..<cutoff]))
    }

    /// `true` when line 0 is exactly a `---` delimiter (trailing spaces/CR allowed).
    static func opensWithDelimiter(_ index: MarkdownLineIndex) -> Bool {
        let units = index.lineSlice(0).reversed().drop { $0 == 0x20 || $0 == 0x0D }
        return Array(units) == [0x2D, 0x2D, 0x2D]
    }
}

/// Fail-closed parser of line-1 Markdown frontmatter into editable properties (`REQ-007`, `BC-004`, `SEC-012`).
public enum FrontmatterPropertyParser {

    /// Returns `nil` when the snapshot has no line-1 `---` block (or is binary/degraded), a read-only model when the block
    /// is unterminated or malformed, and an editable model otherwise.
    public static func parse(snapshot: DocumentSnapshot) -> FrontmatterPropertyModel? {
        guard !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText,
              let index = FrontmatterLocator.prefixIndex(of: snapshot.text),
              index.lineCount > 1, FrontmatterLocator.opensWithDelimiter(index) else { return nil }
        let count = index.frontmatterLineCount
        guard count >= 2 else {
            return FrontmatterPropertyModel(documentID: snapshot.id, revision: snapshot.revision, properties: [], isReadOnly: true, closingDelimiterLine: -1, closingDelimiterOffset: -1)
        }
        let closing = count - 1
        var properties: [FrontmatterProperty] = []
        var malformed = false
        var seen: Set<String> = []
        var line = 1
        while line < closing {
            let slice = index.lineSlice(line)
            guard let first = slice.first, !isBlankLine(slice) else { line += 1; continue }
            if first == YAMLLineTokenizer.space || first == YAMLLineTokenizer.tab { malformed = true; line += 1; continue }
            let tokens = YAMLLineTokenizer.tokens(line: slice)
            if tokens.first?.kind == .comment { line += 1; continue }
            guard let keyToken = tokens.first, keyToken.kind == .key, keyToken.range.location == 0 else { malformed = true; line += 1; continue }
            var end = line + 1
            var children: [ArraySlice<UInt16>] = []
            while end < closing {
                let child = index.lineSlice(end)
                if let c = child.first, c != YAMLLineTokenizer.space, c != YAMLLineTokenizer.tab { break }
                if child.contains(YAMLLineTokenizer.tab), child.prefix(while: { YAMLLineTokenizer.isBlank($0) }).contains(YAMLLineTokenizer.tab) { malformed = true }
                if !isBlankLine(child) { children.append(child) }
                end += 1
            }
            if properties.count >= YAMLSupportLimits.maxProperties { malformed = true; break }
            let key = unquote(slice, keyToken.range)
            if !seen.insert(key).inserted { malformed = true }
            let valueTokens = tokens.drop { $0.kind != .colon }.dropFirst()
            let comment = tokens.last(where: { $0.kind == .comment }).map { text(slice, $0.range) }
            let start = index.lineStarts[line]
            let upper = index.lineStarts[end]
            properties.append(FrontmatterProperty(
                key: key,
                kind: classify(slice, Array(valueTokens), children: children),
                lineRange: line..<end,
                utf16Range: TextRange(location: start, length: upper - start),
                trailingComment: comment
            ))
            line = end
        }
        return FrontmatterPropertyModel(
            documentID: snapshot.id,
            revision: snapshot.revision,
            properties: properties,
            isReadOnly: malformed,
            closingDelimiterLine: closing,
            closingDelimiterOffset: index.lineStarts[closing]
        )
    }

    /// Classifies the value tokens after the key colon plus any indented child lines.
    static func classify(_ slice: ArraySlice<UInt16>, _ value: [YAMLToken], children: [ArraySlice<UInt16>]) -> FrontmatterValueKind {
        let content = value.filter { $0.kind != .comment }
        if content.contains(where: { $0.kind == .anchor || $0.kind == .alias }) { return .aliased }
        if content.contains(where: { $0.kind == .tag }) { return .tagged }
        if content.contains(where: { $0.kind == .blockScalarIndicator }) { return .blockScalar }
        if let token = content.first {
            guard children.isEmpty else { return .blockScalar } // multi-line plain scalar
            let raw = text(slice, token.range)
            if raw.hasPrefix("{") { return .nestedMap }
            if raw.hasPrefix("[") { return flowList(raw) ?? .nestedMap }
            return .scalar(token.kind == .quotedString ? unquote(slice, token.range) : raw)
        }
        guard !children.isEmpty else { return .scalar("") }
        var items: [String] = []
        for child in children {
            let tokens = YAMLLineTokenizer.tokens(line: child).filter { $0.kind != .comment }
            guard tokens.count == 2, tokens[0].kind == .listDash else {
                if tokens.contains(where: { $0.kind == .key }) { return .nestedMap }
                if tokens.contains(where: { $0.kind == .anchor || $0.kind == .alias }) { return .aliased }
                return .nestedMap
            }
            let item = tokens[1]
            switch item.kind {
            case .quotedString: items.append(unquote(child, item.range))
            case .value:
                let raw = text(child, item.range)
                guard !raw.hasPrefix("["), !raw.hasPrefix("{") else { return .nestedMap }
                items.append(raw)
            case .alias, .anchor: return .aliased
            case .tag: return .tagged
            default: return .nestedMap
            }
        }
        return .list(items)
    }

    /// Splits a single-level flow sequence `[a, "b, c"]`; `nil` when nested collections appear.
    static func flowList(_ raw: String) -> FrontmatterValueKind? {
        let units = Array(raw.utf16)
        guard units.last == YAMLLineTokenizer.rbracket else { return nil }
        let inner = units[1..<(units.count - 1)]
        var items: [String] = []
        var i = inner.startIndex
        while i < inner.endIndex {
            while i < inner.endIndex, YAMLLineTokenizer.isBlank(inner[i]) { i += 1 }
            guard i < inner.endIndex else { break }
            let u = inner[i]
            if u == YAMLLineTokenizer.lbracket || u == YAMLLineTokenizer.lbrace || u == YAMLLineTokenizer.star || u == YAMLLineTokenizer.amp { return nil }
            var itemEnd: Int
            var item: String
            if u == YAMLLineTokenizer.dquote || u == YAMLLineTokenizer.squote {
                itemEnd = YAMLLineTokenizer.quotedEnd(inner, from: i, end: inner.endIndex)
                item = unquote(inner, TextRange(location: i - inner.startIndex, length: itemEnd - i))
            } else {
                itemEnd = i
                while itemEnd < inner.endIndex, inner[itemEnd] != YAMLLineTokenizer.comma { itemEnd += 1 }
                var upper = itemEnd
                while upper > i, YAMLLineTokenizer.isBlank(inner[upper - 1]) { upper -= 1 }
                item = String(decoding: inner[i..<upper], as: UTF16.self)
            }
            items.append(item)
            i = itemEnd
            while i < inner.endIndex, inner[i] != YAMLLineTokenizer.comma { i += 1 }
            i += 1
        }
        return .list(items)
    }

    private static func isBlankLine(_ slice: ArraySlice<UInt16>) -> Bool {
        slice.allSatisfy { YAMLLineTokenizer.isBlank($0) || $0 == YAMLLineTokenizer.cr }
    }

    static func text(_ slice: ArraySlice<UInt16>, _ range: TextRange) -> String {
        let start = slice.startIndex + range.location
        return String(decoding: slice[start..<(start + range.length)], as: UTF16.self)
    }

    /// Decodes a quoted scalar (`\"`, `\\`, `\n`, `\t`, `\r`, `\xHH` escapes or `''`), mirroring `FrontmatterPropertyWriter.quoted`.
    static func unquote(_ slice: ArraySlice<UInt16>, _ range: TextRange) -> String {
        let raw = text(slice, range)
        guard raw.count >= 2, let q = raw.first, q == "\"" || q == "'", raw.last == q else { return raw }
        let body = raw.dropFirst().dropLast()
        if q == "'" { return body.replacingOccurrences(of: "''", with: "'") }
        var out = ""
        var chars = Array(body)[...]
        while let ch = chars.popFirst() {
            guard ch == "\\", let next = chars.popFirst() else { out.append(ch); continue }
            switch next {
            case "n": out.append("\n")
            case "t": out.append("\t")
            case "r": out.append("\r")
            case "x":
                let hex = String(chars.prefix(2))
                if hex.count == 2, let value = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(value) {
                    out.unicodeScalars.append(scalar)
                    chars = chars.dropFirst(2)
                } else {
                    out.append("x")
                }
            default: out.append(next)
            }
        }
        return out
    }
}

/// New value for an editable property.
public enum FrontmatterEditValue: Equatable, Sendable { case scalar(String), list([String]) }

/// Properties-panel operation on one top-level key.
public enum FrontmatterPropertyOperation: Equatable, Sendable {
    case setValue(key: String, value: FrontmatterEditValue)
    case rename(from: String, to: String)
    case add(key: String, value: FrontmatterEditValue)
    case remove(key: String)
}

/// Why an operation produced no edit.
public enum FrontmatterWriteRejection: Equatable, Sendable { case invalidKey, duplicateKey, unknownKey, readOnly }

/// Writer outcome: exactly one `TextEdit`, a rejection, or a refusal because the model predates the snapshot.
public enum FrontmatterWriteResult: Equatable, Sendable {
    case edit(TextEdit)
    case rejected(FrontmatterWriteRejection)
    case staleRevision
}

/// Minimal, injection-safe frontmatter rewriter (`REQ-008`, `BC-003`, `BC-004`, `CWE-74`).
///
/// Each operation replaces only the lines owned by one entry (or inserts one line before the closing delimiter), so
/// comments, ordering and the Markdown body stay byte-identical. Values that could change YAML structure (`: `, ` #`,
/// quotes, newlines, indicators, edge spaces) are emitted as escaped double-quoted scalars; keys that could forge
/// structure are rejected; a model whose `BufferRevision` differs from the snapshot is refused outright.
public enum FrontmatterPropertyWriter {

    public static func apply(_ operation: FrontmatterPropertyOperation, model: FrontmatterPropertyModel, snapshot: DocumentSnapshot) -> FrontmatterWriteResult {
        guard model.documentID == snapshot.id, model.revision == snapshot.revision else { return .staleRevision }
        guard !model.isReadOnly, model.closingDelimiterOffset >= 0 else { return .rejected(.readOnly) }
        func entry(_ key: String) -> FrontmatterProperty? { model.properties.first { $0.key == key } }
        switch operation {
        case .setValue(let key, let value):
            guard let property = entry(key) else { return .rejected(.unknownKey) }
            guard property.isEditable else { return .rejected(.readOnly) }
            let blockStyle = property.lineRange.count > 1
            return .edit(TextEdit(range: property.utf16Range, replacement: render(key: key, value: value, blockStyle: blockStyle, comment: property.trailingComment)))
        case .rename(let from, let to):
            guard isValidKey(to) else { return .rejected(.invalidKey) }
            guard let property = entry(from) else { return .rejected(.unknownKey) }
            guard property.isEditable else { return .rejected(.readOnly) }
            guard from == to || entry(to) == nil else { return .rejected(.duplicateKey) }
            guard let value = editValue(property.kind) else { return .rejected(.readOnly) }
            return .edit(TextEdit(range: property.utf16Range, replacement: render(key: to, value: value, blockStyle: property.lineRange.count > 1, comment: property.trailingComment)))
        case .add(let key, let value):
            guard isValidKey(key) else { return .rejected(.invalidKey) }
            guard entry(key) == nil else { return .rejected(.duplicateKey) }
            guard model.properties.count < YAMLSupportLimits.maxProperties else { return .rejected(.readOnly) }
            return .edit(TextEdit(range: TextRange(location: model.closingDelimiterOffset, length: 0), replacement: render(key: key, value: value, blockStyle: false, comment: nil)))
        case .remove(let key):
            guard let property = entry(key) else { return .rejected(.unknownKey) }
            return .edit(TextEdit(range: property.utf16Range, replacement: ""))
        }
    }

    /// Accepts printable, trimmed keys that cannot open a sequence, complex key, comment or nested mapping.
    static func isValidKey(_ key: String) -> Bool {
        guard !key.isEmpty, key == key.trimmingCharacters(in: .whitespaces) else { return false }
        guard !key.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F || CharacterSet.newlines.contains($0) }) else { return false }
        guard let first = key.first, !"-?#&*!|>%@`'\"[]{},".contains(first) else { return false }
        return !key.hasSuffix(":") && !key.contains(": ") && !key.contains(" #")
    }

    private static func editValue(_ kind: FrontmatterValueKind) -> FrontmatterEditValue? {
        switch kind {
        case .scalar(let v): return .scalar(v)
        case .list(let items): return .list(items)
        default: return nil
        }
    }

    /// Renders an entry (always newline-terminated) in flow or block list style.
    static func render(key: String, value: FrontmatterEditValue, blockStyle: Bool, comment: String?) -> String {
        let suffix = comment.map { " \($0)" } ?? ""
        switch value {
        case .scalar(let text):
            return "\(key): \(scalar(text, inFlow: false))\(suffix)\n"
        case .list(let items) where blockStyle:
            return "\(key):\(suffix)\n" + items.map { "  - \(scalar($0, inFlow: false))\n" }.joined()
        case .list(let items):
            return "\(key): [\(items.map { scalar($0, inFlow: true) }.joined(separator: ", "))]\(suffix)\n"
        }
    }

    /// Plain when unambiguous, else an escaped double-quoted scalar.
    static func scalar(_ text: String, inFlow: Bool) -> String {
        isPlainSafe(text, inFlow: inFlow) ? text : quoted(text)
    }

    static func isPlainSafe(_ text: String, inFlow: Bool) -> Bool {
        guard !text.isEmpty, text == text.trimmingCharacters(in: .whitespaces) else { return false }
        guard !text.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F }) else { return false }
        guard let first = text.first, !"-?:,[]{}#&*!|>'\"%@`".contains(first) else { return false }
        if text.contains(": ") || text.contains(" #") || text.hasSuffix(":") { return false }
        if inFlow, text.contains(where: { ",[]{}".contains($0) }) { return false }
        return true
    }

    static func quoted(_ text: String) -> String {
        var out = "\""
        for ch in text {
            switch ch {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            case "\r": out += "\\r"
            default:
                if let scalar = ch.unicodeScalars.first, ch.unicodeScalars.count == 1, scalar.value < 0x20 || scalar.value == 0x7F {
                    out += String(format: "\\x%02X", scalar.value)
                } else {
                    out.append(ch)
                }
            }
        }
        return out + "\""
    }
}
