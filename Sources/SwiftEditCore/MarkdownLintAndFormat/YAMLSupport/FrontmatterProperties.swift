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
            let step = scanFrontmatterTopLevelLine(in: index, at: line, closing: closing, currentCount: properties.count, seen: &seen)
            if step.isMalformed { malformed = true }
            if step.hitPropertyCap { break }
            if let prop = step.property { properties.append(prop) }
            line = step.nextLine
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
        if let inlineKind = classifyInlineValueTokens(slice, content: content, hasChildren: !children.isEmpty) {
            return inlineKind
        }
        guard !children.isEmpty else { return .scalar("") }
        return classifyBlockSequenceChildren(children)
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
            guard let parsed = parseFlowListItem(inner, at: i) else { return nil }
            items.append(parsed.item)
            i = advancePastFlowComma(inner, from: parsed.itemEnd)
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

    private static let doubleQuotedEscapes: [Character: Character] = [
        "n": "\n",
        "t": "\t",
        "r": "\r",
    ]

    /// Decodes a quoted scalar (`\"`, `\\`, `\n`, `\t`, `\r`, `\xHH` escapes or `''`), mirroring `FrontmatterPropertyWriter.quoted`.
    static func unquote(_ slice: ArraySlice<UInt16>, _ range: TextRange) -> String {
        let raw = text(slice, range)
        guard raw.count >= 2, let q = raw.first, q == "\"" || q == "'", raw.last == q else { return raw }
        let body = raw.dropFirst().dropLast()
        if q == "'" { return body.replacingOccurrences(of: "''", with: "'") }
        return decodeDoubleQuotedScalar(body)
    }

    private static func decodeDoubleQuotedScalar(_ body: Substring) -> String {
        var out = ""
        var chars = Array(body)[...]
        while let ch = chars.popFirst() {
            guard ch == "\\", let next = chars.popFirst() else {
                out.append(ch)
                continue
            }
            appendEscapedCharacter(next, remaining: &chars, into: &out)
        }
        return out
    }

    private static func appendEscapedCharacter(
        _ escaped: Character,
        remaining chars: inout ArraySlice<Character>,
        into out: inout String
    ) {
        if let mapped = doubleQuotedEscapes[escaped] {
            out.append(mapped)
            return
        }
        if escaped == "x", let scalar = consumeHexEscape(from: &chars) {
            out.unicodeScalars.append(scalar)
            return
        }
        out.append(escaped)
    }

    private static func consumeHexEscape(from chars: inout ArraySlice<Character>) -> Unicode.Scalar? {
        let hex = String(chars.prefix(2))
        guard hex.count == 2, let value = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(value) else {
            return nil
        }
        chars = chars.dropFirst(2)
        return scalar
    }
}

extension FrontmatterPropertyParser {
    private struct TopLevelLineStep {
        let property: FrontmatterProperty?
        let nextLine: Int
        let isMalformed: Bool
        let hitPropertyCap: Bool
    }

    private static func scanFrontmatterTopLevelLine(
        in index: MarkdownLineIndex,
        at line: Int,
        closing: Int,
        currentCount: Int,
        seen: inout Set<String>
    ) -> TopLevelLineStep {
        let slice = index.lineSlice(line)
        guard let first = slice.first, isBlankLine(slice) == false else {
            return TopLevelLineStep(property: nil, nextLine: line + 1, isMalformed: false, hitPropertyCap: false)
        }
        if YAMLLineTokenizer.isBlank(first) {
            return TopLevelLineStep(property: nil, nextLine: line + 1, isMalformed: true, hitPropertyCap: false)
        }
        let tokens = YAMLLineTokenizer.tokens(line: slice)
        if tokens.first?.kind == .comment {
            return TopLevelLineStep(property: nil, nextLine: line + 1, isMalformed: false, hitPropertyCap: false)
        }
        guard let keyToken = tokens.first, keyToken.kind == .key, keyToken.range.location == 0 else {
            return TopLevelLineStep(property: nil, nextLine: line + 1, isMalformed: true, hitPropertyCap: false)
        }

        let collected = collectFrontmatterChildLines(in: index, from: line + 1, closing: closing)
        if currentCount >= YAMLSupportLimits.maxProperties {
            return TopLevelLineStep(property: nil, nextLine: collected.endLine, isMalformed: true, hitPropertyCap: true)
        }
        let key = unquote(slice, keyToken.range)
        let isDuplicate = !seen.insert(key).inserted
        let valueTokens = Array(tokens.drop { $0.kind != .colon }.dropFirst())
        let comment = tokens.last(where: { $0.kind == .comment }).map { text(slice, $0.range) }
        let start = index.lineStarts[line]
        let upper = index.lineStarts[collected.endLine]
        let property = FrontmatterProperty(
            key: key,
            kind: classify(slice, valueTokens, children: collected.children),
            lineRange: line..<collected.endLine,
            utf16Range: TextRange(location: start, length: upper - start),
            trailingComment: comment
        )
        return TopLevelLineStep(
            property: property,
            nextLine: collected.endLine,
            isMalformed: collected.hasTabIndent || isDuplicate,
            hitPropertyCap: false
        )
    }

    private static func collectFrontmatterChildLines(
        in index: MarkdownLineIndex,
        from startLine: Int,
        closing: Int
    ) -> (children: [ArraySlice<UInt16>], endLine: Int, hasTabIndent: Bool) {
        var end = startLine
        var children: [ArraySlice<UInt16>] = []
        var hasTabIndent = false
        while end < closing {
            let child = index.lineSlice(end)
            if let c = child.first, !YAMLLineTokenizer.isBlank(c) { break }
            if hasLeadingTabIndent(child) { hasTabIndent = true }
            if isBlankLine(child) == false { children.append(child) }
            end += 1
        }
        return (children, end, hasTabIndent)
    }

    private static func hasLeadingTabIndent(_ line: ArraySlice<UInt16>) -> Bool {
        guard line.contains(YAMLLineTokenizer.tab) else { return false }
        return line.prefix(while: { YAMLLineTokenizer.isBlank($0) }).contains(YAMLLineTokenizer.tab)
    }

    private static let inlineNonEditableKinds: [(kind: YAMLTokenKind, value: FrontmatterValueKind)] = [
        (.anchor, .aliased),
        (.alias, .aliased),
        (.tag, .tagged),
        (.blockScalarIndicator, .blockScalar),
    ]

    private static func nonEditableInlineKind(in content: [YAMLToken]) -> FrontmatterValueKind? {
        for entry in inlineNonEditableKinds where content.contains(where: { $0.kind == entry.kind }) {
            return entry.value
        }
        return nil
    }

    private static func classifyInlineValueTokens(
        _ slice: ArraySlice<UInt16>,
        content: [YAMLToken],
        hasChildren: Bool
    ) -> FrontmatterValueKind? {
        if let special = nonEditableInlineKind(in: content) { return special }
        guard let token = content.first else { return nil }
        guard !hasChildren else { return .blockScalar }
        return classifyInlineScalarOrFlow(slice, token: token)
    }

    private static func classifyInlineScalarOrFlow(
        _ slice: ArraySlice<UInt16>,
        token: YAMLToken
    ) -> FrontmatterValueKind {
        let raw = text(slice, token.range)
        if raw.hasPrefix("{") { return .nestedMap }
        if raw.hasPrefix("[") { return flowList(raw) ?? .nestedMap }
        return .scalar(token.kind == .quotedString ? unquote(slice, token.range) : raw)
    }

    private static func classifyBlockSequenceChildren(_ children: [ArraySlice<UInt16>]) -> FrontmatterValueKind {
        var items: [String] = []
        items.reserveCapacity(children.count)
        for child in children {
            switch classifySingleChildSequenceLine(child) {
            case .item(let value): items.append(value)
            case .nonEditable(let kind): return kind
            }
        }
        return .list(items)
    }

    private enum ChildSequenceClassification {
        case item(String)
        case nonEditable(FrontmatterValueKind)
    }

    private static func classifySingleChildSequenceLine(_ child: ArraySlice<UInt16>) -> ChildSequenceClassification {
        let tokens = YAMLLineTokenizer.tokens(line: child).filter { $0.kind != .comment }
        guard tokens.count == 2, tokens[0].kind == .listDash else {
            let hasAliasOrAnchor = tokens.contains { $0.kind == .anchor || $0.kind == .alias }
            return .nonEditable(hasAliasOrAnchor ? .aliased : .nestedMap)
        }
        return classifySequenceItemToken(tokens[1], in: child)
    }

    private static func classifySequenceItemToken(
        _ item: YAMLToken,
        in child: ArraySlice<UInt16>
    ) -> ChildSequenceClassification {
        switch item.kind {
        case .quotedString:
            return .item(unquote(child, item.range))
        case .value:
            let raw = text(child, item.range)
            return (raw.hasPrefix("[") || raw.hasPrefix("{")) ? .nonEditable(.nestedMap) : .item(raw)
        case .alias, .anchor:
            return .nonEditable(.aliased)
        case .tag:
            return .nonEditable(.tagged)
        default:
            return .nonEditable(.nestedMap)
        }
    }

    private static func parseFlowListItem(_ inner: ArraySlice<UInt16>, at i: Int) -> (item: String, itemEnd: Int)? {
        let u = inner[i]
        guard isDisallowedFlowItemOpeningUnit(u) == false else { return nil }
        if u == YAMLLineTokenizer.dquote || u == YAMLLineTokenizer.squote {
            let itemEnd = YAMLLineTokenizer.quotedEnd(inner, from: i, end: inner.endIndex)
            let item = unquote(inner, TextRange(location: i - inner.startIndex, length: itemEnd - i))
            return (item, itemEnd)
        }
        var itemEnd = i
        while itemEnd < inner.endIndex, inner[itemEnd] != YAMLLineTokenizer.comma { itemEnd += 1 }
        var upper = itemEnd
        while upper > i, YAMLLineTokenizer.isBlank(inner[upper - 1]) { upper -= 1 }
        return (String(decoding: inner[i..<upper], as: UTF16.self), itemEnd)
    }

    @inline(__always)
    private static func isDisallowedFlowItemOpeningUnit(_ u: UInt16) -> Bool {
        u == YAMLLineTokenizer.lbracket || u == YAMLLineTokenizer.lbrace || u == YAMLLineTokenizer.star || u == YAMLLineTokenizer.amp
    }

    private static func advancePastFlowComma(_ inner: ArraySlice<UInt16>, from start: Int) -> Int {
        var i = start
        while i < inner.endIndex, inner[i] != YAMLLineTokenizer.comma { i += 1 }
        return i + 1
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
        switch operation {
        case .setValue(let key, let value):
            return applySetValue(key: key, value: value, model: model)
        case .rename(let from, let to):
            return applyRename(from: from, to: to, model: model)
        case .add(let key, let value):
            return applyAdd(key: key, value: value, model: model)
        case .remove(let key):
            return applyRemove(key: key, model: model)
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

extension FrontmatterPropertyWriter {
    private static func findPropertyEntry(_ key: String, in model: FrontmatterPropertyModel) -> FrontmatterProperty? {
        model.properties.first { $0.key == key }
    }

    private static func applySetValue(key: String, value: FrontmatterEditValue, model: FrontmatterPropertyModel) -> FrontmatterWriteResult {
        guard let property = findPropertyEntry(key, in: model) else { return .rejected(.unknownKey) }
        guard property.isEditable else { return .rejected(.readOnly) }
        let replacement = render(key: key, value: value, blockStyle: property.lineRange.count > 1, comment: property.trailingComment)
        return .edit(TextEdit(range: property.utf16Range, replacement: replacement))
    }

    private static func applyRename(from: String, to: String, model: FrontmatterPropertyModel) -> FrontmatterWriteResult {
        guard isValidKey(to) else { return .rejected(.invalidKey) }
        guard let property = findPropertyEntry(from, in: model) else { return .rejected(.unknownKey) }
        guard property.isEditable, let value = editValue(property.kind) else { return .rejected(.readOnly) }
        guard from == to || findPropertyEntry(to, in: model) == nil else { return .rejected(.duplicateKey) }
        let replacement = render(key: to, value: value, blockStyle: property.lineRange.count > 1, comment: property.trailingComment)
        return .edit(TextEdit(range: property.utf16Range, replacement: replacement))
    }

    private static func applyAdd(key: String, value: FrontmatterEditValue, model: FrontmatterPropertyModel) -> FrontmatterWriteResult {
        guard isValidKey(key) else { return .rejected(.invalidKey) }
        guard findPropertyEntry(key, in: model) == nil else { return .rejected(.duplicateKey) }
        guard model.properties.count < YAMLSupportLimits.maxProperties else { return .rejected(.readOnly) }
        let insertRange = TextRange(location: model.closingDelimiterOffset, length: 0)
        return .edit(TextEdit(range: insertRange, replacement: render(key: key, value: value, blockStyle: false, comment: nil)))
    }

    private static func applyRemove(key: String, model: FrontmatterPropertyModel) -> FrontmatterWriteResult {
        guard let property = findPropertyEntry(key, in: model) else { return .rejected(.unknownKey) }
        return .edit(TextEdit(range: property.utf16Range, replacement: ""))
    }
}
