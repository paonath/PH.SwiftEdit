import Foundation
import CoreGraphics
import ImageIO

/// One renderable block of the native GFM preview; `sourceLine` is 1-based and drives scroll synchronization (`UI-007`).
///
/// Raw HTML is carried as `inertHTML` text and MUST be rendered as monospaced plain text, never interpreted (`SEC-004`).
public enum GFMPreviewBlock: Equatable, Sendable {
    case heading(level: Int, text: String, sourceLine: Int)
    case paragraph(text: String, sourceLine: Int)
    case listItem(text: String, ordered: Bool, indent: Int, taskChecked: Bool?, sourceLine: Int)
    case quote(text: String, sourceLine: Int)
    case table(header: [String], rows: [[String]], sourceLine: Int)
    case code(text: String, sourceLine: Int)
    case thematicBreak(sourceLine: Int)
    case inertHTML(text: String, sourceLine: Int)

    public var sourceLine: Int {
        switch self {
        case .heading(_, _, let l), .paragraph(_, let l), .listItem(_, _, _, _, let l), .quote(_, let l),
             .table(_, _, let l), .code(_, let l), .thematicBreak(let l), .inertHTML(_, let l):
            return l
        }
    }
}

/// Precomputed document-wide image reference entry for one preview block (`BUG-014`, `CWE-400`).
public struct GFMPreviewImageEntry: Equatable, Sendable {
    public let reference: String
    public let documentIndex: Int

    public init(reference: String, documentIndex: Int) {
        self.reference = reference
        self.documentIndex = documentIndex
    }
}

/// Immutable preview projection pinned to the `BufferRevision` it was computed from, carrying precomputed `O(B)` ordered-list ordinals and document-wide image indices.
public struct GFMPreviewDocument: Equatable, Sendable {
    public let revision: BufferRevision
    public let blocks: [GFMPreviewBlock]
    /// Precomputed 1-based ordered-list ordinal per block index (`O(1)` lookup during rendering).
    public let orderedOrdinals: [Int]
    /// Precomputed document-wide image references per block index (capped at `PreviewResourceAndLinkGate.maxImagesPerDocument`).
    public let imageEntriesByBlock: [[GFMPreviewImageEntry]]

    public init(revision: BufferRevision, blocks: [GFMPreviewBlock]) {
        self.revision = revision
        self.blocks = blocks
        self.orderedOrdinals = MarkdownPreviewProjector.computeOrderedOrdinals(for: blocks)
        self.imageEntriesByBlock = MarkdownPreviewProjector.computeImageEntries(for: blocks)
    }
}

/// Projects a snapshot into preview blocks only while the preview is visible (`BC-004`, `SEC-004`, `SEC-012`).
///
/// Returns `nil` (zero work) when `showPreview` is `false`, for binary or degraded snapshots, and for non-Markdown documents. Tables beyond `GFMTableEditEngine` caps degrade to paragraph text; lines are truncated at `4096` UTF-16 units.
public enum MarkdownPreviewProjector {

    public static func project(
        snapshot: DocumentSnapshot,
        showPreview: Bool,
        isMarkdownDocument: Bool = true,
        lineIndex: MarkdownLineIndex? = nil
    ) -> GFMPreviewDocument? {
        guard showPreview, isMarkdownDocument, !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText else { return nil }
        let index = lineIndex ?? MarkdownLineIndex(text: snapshot.text)
        var state = PreviewProjectionState(index: index, includeEnrichment: false)
        var line = 0
        while line < index.lineCount {
            line = advancePreviewProjectionLine(at: line, state: &state)
        }
        flushPreviewParagraph(&state)
        return GFMPreviewDocument(revision: snapshot.revision, blocks: state.blocks)
    }

    /// Projects an enriched preview document including structured line-1 YAML frontmatter entries, fenced block language tags, and pre-laid-out native diagrams (`REQ-003`, `REQ-004`).
    public static func projectEnriched(
        snapshot: DocumentSnapshot,
        showPreview: Bool,
        isMarkdownDocument: Bool = true,
        lineIndex: MarkdownLineIndex? = nil
    ) -> GFMPreviewEnrichedDocument? {
        guard showPreview, isMarkdownDocument, !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText else { return nil }
        let index = lineIndex ?? MarkdownLineIndex(text: snapshot.text)
        let frontmatter = extractFrontmatterEntries(snapshot: snapshot, index: index)
        var state = PreviewProjectionState(index: index, includeEnrichment: true)
        var line = frontmatter.hasValidHeader ? index.frontmatterLineCount : 0
        while line < index.lineCount {
            line = advancePreviewProjectionLine(at: line, state: &state)
        }
        flushPreviewParagraph(&state)
        return GFMPreviewEnrichedDocument(
            revision: snapshot.revision,
            frontmatterEntries: frontmatter.entries,
            blocks: state.blocks,
            fenceLanguagesByBlock: state.fenceLanguages,
            diagramsByBlock: state.diagrams
        )
    }

    private static func extractFrontmatterEntries(
        snapshot: DocumentSnapshot,
        index: MarkdownLineIndex
    ) -> (hasValidHeader: Bool, entries: [GFMPreviewFrontmatterEntry]) {
        guard index.frontmatterLineCount >= 2,
              let parsed = FrontmatterPropertyParser.parse(snapshot: snapshot) else {
            return (false, [])
        }
        let entries = parsed.properties.map { prop in
            let display: String
            switch prop.kind {
            case .scalar(let val): display = val
            case .list(let items): display = "[\(items.joined(separator: ", "))]"
            case .nestedMap: display = "{…}"
            case .blockScalar: display = "|"
            case .aliased: display = "*"
            case .tagged: display = "!"
            }
            return GFMPreviewFrontmatterEntry(key: prop.key, displayValue: display)
        }
        return (true, entries)
    }

    /// Computes 1-based ordinals for all blocks in a single `O(B)` forward stack pass (`BUG-014`).
    public static func computeOrderedOrdinals(for blocks: [GFMPreviewBlock]) -> [Int] {
        var ordinals = Array(repeating: 1, count: blocks.count)
        // Stack tracks active nested list runs sorted strictly ascending by indent.
        var stack: [(indent: Int, ordered: Bool, count: Int)] = []
        for idx in blocks.indices {
            guard case .listItem(_, let ordered, let indent, _, _) = blocks[idx] else {
                if !stack.isEmpty { stack.removeAll(keepingCapacity: true) }
                continue
            }
            while let top = stack.last, top.indent > indent {
                stack.removeLast()
            }
            if let top = stack.last, top.indent == indent {
                if ordered && top.ordered {
                    let next = top.count + 1
                    stack[stack.count - 1].count = next
                    ordinals[idx] = next
                } else {
                    stack[stack.count - 1] = (indent: indent, ordered: ordered, count: 1)
                    ordinals[idx] = 1
                }
            } else {
                stack.append((indent: indent, ordered: ordered, count: 1))
                ordinals[idx] = 1
            }
        }
        return ordinals
    }

    static func computeImageEntries(for blocks: [GFMPreviewBlock]) -> [[GFMPreviewImageEntry]] {
        var globalIndex = 0
        var result: [[GFMPreviewImageEntry]] = []
        result.reserveCapacity(blocks.count)
        for block in blocks {
            let text: String
            switch block {
            case .paragraph(let body, _), .listItem(let body, _, _, _, _):
                text = body
            default:
                result.append([])
                continue
            }
            let refs = PreviewResourceAndLinkGate.imageReferences(in: text)
            if refs.isEmpty {
                result.append([])
            } else {
                var entries: [GFMPreviewImageEntry] = []
                entries.reserveCapacity(refs.count)
                for ref in refs {
                    entries.append(GFMPreviewImageEntry(reference: ref, documentIndex: globalIndex))
                    globalIndex += 1
                }
                result.append(entries)
            }
        }
        return result
    }

    private static func isATXHeading(_ slice: ArraySlice<UInt16>) -> Bool {
        let trimmed = slice.drop(while: { $0 == 0x20 })
        guard trimmed.first == 0x23 else { return false }
        var level = 0
        var idx = trimmed.startIndex
        while idx < trimmed.endIndex, trimmed[idx] == 0x23 {
            level += 1
            idx = trimmed.index(after: idx)
        }
        return (1...6).contains(level) && (idx == trimmed.endIndex || trimmed[idx] == 0x20)
    }

    private static func isSingleLineClosedHTML(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("</") || trimmed.hasSuffix("/>") || trimmed.hasSuffix("-->")
    }

    /// Computes 1-based ordinal for an ordered list item at `blockIndex` within contiguous `.listItem` runs at matching indentation (`BUG-014`).
    public static func orderedOrdinal(at blockIndex: Int, in blocks: [GFMPreviewBlock]) -> Int {
        guard blocks.indices.contains(blockIndex),
              case .listItem(_, let ordered, let targetIndent, _, _) = blocks[blockIndex],
              ordered else {
            return 1
        }
        var ordinal = 1
        var cursor = blockIndex - 1
        while cursor >= 0 {
            guard case .listItem(_, let prevOrdered, let prevIndent, _, _) = blocks[cursor] else {
                break
            }
            if prevIndent < targetIndent {
                break
            }
            if prevIndent == targetIndent {
                if !prevOrdered {
                    break
                }
                ordinal += 1
            }
            cursor -= 1
        }
        return ordinal
    }

    /// Formats the rendered marker label (`☑`, `☐`, `1.`, or `•`) for one preview list row (`BUG-014`).
    public static func listMarkerText(ordered: Bool, taskChecked: Bool?, ordinal: Int) -> String {
        if let taskChecked {
            return taskChecked ? "☑" : "☐"
        }
        return ordered ? "\(max(1, ordinal))." : "•"
    }

    /// Assigns document-wide sequential image indices across all blocks so `PreviewResourceAndLinkGate.maxImagesPerDocument` (`64`) cannot be bypassed across paragraphs (`BUG-014`, `CWE-400`).
    public static func documentImageIndices(for blocks: [GFMPreviewBlock]) -> [[(reference: String, documentIndex: Int)]] {
        var globalIndex = 0
        return blocks.map { block in
            let text: String
            switch block {
            case .paragraph(let body, _), .listItem(let body, _, _, _, _):
                text = body
            default:
                return []
            }
            let refs = PreviewResourceAndLinkGate.imageReferences(in: text)
            return refs.map { ref in
                defer { globalIndex += 1 }
                return (ref, globalIndex)
            }
        }
    }

    private static func isClosingFence(_ index: MarkdownLineIndex, openLine: Int, closeLine: Int) -> Bool {
        guard let opener = MarkdownLineIndex.fenceOpening(index.lineSlice(openLine)) else { return false }
        let slice = index.lineSlice(closeLine)
        var idx = slice.startIndex
        var spaces = 0
        while idx < slice.endIndex, slice[idx] == 0x20, spaces < 4 { idx += 1; spaces += 1 }
        guard spaces < 4 else { return false }
        var count = 0
        while idx < slice.endIndex, slice[idx] == opener.char { idx += 1; count += 1 }
        guard count >= opener.count else { return false }
        while idx < slice.endIndex {
            let u = slice[idx]
            if u != 0x20 && u != 0x09 && u != 0x0D { return false }
            idx += 1
        }
        return true
    }

    private static func isThematic(_ line: ArraySlice<UInt16>) -> Bool {
        var marker: UInt16 = 0
        var count = 0
        for u in line {
            if u == 0x20 { continue }
            if marker == 0 { guard u == 0x2D || u == 0x2A || u == 0x5F else { return false }; marker = u }
            guard u == marker else { return false }
            count += 1
        }
        return count >= 3
    }
}

extension MarkdownPreviewProjector {
    private struct PreviewProjectionState {
        let index: MarkdownLineIndex
        let includeEnrichment: Bool
        var blocks: [GFMPreviewBlock] = []
        var fenceLanguages: [String?] = []
        var diagrams: [MarkdownDiagramModel?] = []
        var paragraph: [String] = []
        var paragraphStart: Int = 0
        var fenceCursor: Int = 0

        mutating func appendNonCodeBlock(_ block: GFMPreviewBlock) {
            blocks.append(block)
            if includeEnrichment {
                fenceLanguages.append(nil)
                diagrams.append(nil)
            }
        }

        mutating func appendCodeBlock(text: String, language: String?, sourceLine: Int) {
            blocks.append(.code(text: text, sourceLine: sourceLine))
            guard includeEnrichment else { return }
            fenceLanguages.append(language)
            if case .diagram(let model) = MarkdownDiagramParser.parse(language: language, source: text) {
                diagrams.append(model)
            } else {
                diagrams.append(nil)
            }
        }
    }

    private static func advancePreviewProjectionLine(at line: Int, state: inout PreviewProjectionState) -> Int {
        if let span = activePreviewFence(at: line, state: &state) {
            return consumePreviewFenceBlock(at: line, span: span, state: &state)
        }
        if isPreviewBlankLine(state.index, line: line) {
            flushPreviewParagraph(&state)
            return line + 1
        }
        let slice = state.index.lineSlice(line)
        if let singleBlock = matchPreviewSingleLineBlock(at: line, slice: slice) {
            flushPreviewParagraph(&state)
            state.appendNonCodeBlock(singleBlock)
            return line + 1
        }
        if isPreviewTableStart(state.index, line: line) {
            return consumePreviewTableBlock(at: line, slice: slice, state: &state)
        }
        if isPreviewHTMLStart(slice) {
            return consumePreviewHTMLBlock(at: line, state: &state)
        }
        if state.paragraph.isEmpty { state.paragraphStart = line }
        state.paragraph.append(previewLineText(state.index, line: line))
        return line + 1
    }

    private static func activePreviewFence(at line: Int, state: inout PreviewProjectionState) -> (open: Int, close: Int)? {
        let fences = state.index.fences
        while state.fenceCursor < fences.count && fences[state.fenceCursor].close < line {
            state.fenceCursor += 1
        }
        if state.fenceCursor < fences.count && fences[state.fenceCursor].open <= line {
            return fences[state.fenceCursor]
        }
        return nil
    }

    private static func previewLineText(_ index: MarkdownLineIndex, line: Int) -> String {
        let s = index.lineSlice(line)
        return String(decoding: s.prefix(MarkdownLineIndex.maxLineUTF16), as: UTF16.self)
    }

    private static func isPreviewBlankLine(_ index: MarkdownLineIndex, line: Int) -> Bool {
        index.lineSlice(line).allSatisfy { $0 == 0x20 || $0 == 0x09 }
    }

    private static func flushPreviewParagraph(_ state: inout PreviewProjectionState) {
        guard !state.paragraph.isEmpty else { return }
        state.appendNonCodeBlock(.paragraph(text: state.paragraph.joined(separator: "\n"), sourceLine: state.paragraphStart + 1))
        state.paragraph.removeAll(keepingCapacity: true)
    }

    private static func consumePreviewFenceBlock(
        at open: Int,
        span: (open: Int, close: Int),
        state: inout PreviewProjectionState
    ) -> Int {
        flushPreviewParagraph(&state)
        let closed = span.close > span.open && isClosingFence(state.index, openLine: span.open, closeLine: span.close)
        let bodyEnd = closed ? span.close : span.close + 1
        let body = ((open + 1)..<max(open + 1, bodyEnd)).map { previewLineText(state.index, line: $0) }
        let lang = state.includeEnrichment ? extractFenceLanguage(state.index.lineSlice(open)) : nil
        state.appendCodeBlock(text: body.joined(separator: "\n"), language: lang, sourceLine: open + 1)
        return span.close + 1
    }

    private static func extractFenceLanguage(_ slice: ArraySlice<UInt16>) -> String? {
        guard let opener = MarkdownLineIndex.fenceOpening(slice) else { return nil }
        var idx = slice.startIndex
        while idx < slice.endIndex, slice[idx] == 0x20 { idx += 1 }
        while idx < slice.endIndex, slice[idx] == opener.char { idx += 1 }
        let info = String(decoding: slice[idx...].prefix(256), as: UTF16.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let token = info.split(whereSeparator: \.isWhitespace).first, !token.isEmpty else { return nil }
        return String(token)
    }

    private static func matchPreviewSingleLineBlock(at line: Int, slice: ArraySlice<UInt16>) -> GFMPreviewBlock? {
        let trimmed = slice.drop(while: { $0 == 0x20 })
        if let heading = parsePreviewHeadingBlock(trimmed, sourceLine: line + 1) {
            return heading
        }
        if isThematic(trimmed) {
            return .thematicBreak(sourceLine: line + 1)
        }
        if trimmed.first == 0x3E {
            var body = String(decoding: trimmed.dropFirst(), as: UTF16.self)
            if body.hasPrefix(" ") { body.removeFirst() }
            return .quote(text: body, sourceLine: line + 1)
        }
        return parsePreviewListItemBlock(slice, sourceLine: line + 1)
    }

    private static func parsePreviewHeadingBlock(_ trimmed: ArraySlice<UInt16>, sourceLine: Int) -> GFMPreviewBlock? {
        guard trimmed.first == 0x23 else { return nil }
        var level = 0
        var j = trimmed.startIndex
        while j < trimmed.endIndex, trimmed[j] == 0x23 { level += 1; j += 1 }
        guard level <= 6, j == trimmed.endIndex || trimmed[j] == 0x20 else { return nil }
        let title = String(decoding: trimmed[j...], as: UTF16.self).trimmingCharacters(in: .whitespaces)
        return .heading(level: level, text: title, sourceLine: sourceLine)
    }

    private static func parsePreviewListItemBlock(_ slice: ArraySlice<UInt16>, sourceLine: Int) -> GFMPreviewBlock? {
        guard let item = MarkdownListGrammar.parseListLine(slice) else { return nil }
        let body = String(decoding: slice.dropFirst(item.prefixLength), as: UTF16.self)
        switch item.kind {
        case .ordered:
            return .listItem(text: body, ordered: true, indent: item.indent, taskChecked: nil, sourceLine: sourceLine)
        case .bullet(_, let state):
            return .listItem(text: body, ordered: false, indent: item.indent, taskChecked: state.map { $0 != 0x20 }, sourceLine: sourceLine)
        }
    }
}

extension MarkdownPreviewProjector {
    private static func isPreviewHTMLStart(_ s: ArraySlice<UInt16>) -> Bool {
        var i = s.startIndex
        while i < s.endIndex, s[i] == 0x20 { i += 1 }
        guard i + 1 < s.endIndex, s[i] == 0x3C else { return false }
        let n = s[i + 1]
        return (n >= 0x41 && n <= 0x5A) || (n >= 0x61 && n <= 0x7A) || n == 0x2F || n == 0x21
    }

    private static func isPreviewTableStart(_ index: MarkdownLineIndex, line: Int) -> Bool {
        guard line + 1 < index.lineCount else { return false }
        let slice = index.lineSlice(line)
        var i = slice.startIndex
        while i < slice.endIndex, slice[i] == 0x20 { i += 1 }
        return i < slice.endIndex && slice[i] == 0x7C && GFMTableEditEngine.isDelimiterRowSlice(index.lineSlice(line + 1))
    }

    private static func consumePreviewTableBlock(
        at line: Int,
        slice: ArraySlice<UInt16>,
        state: inout PreviewProjectionState
    ) -> Int {
        flushPreviewParagraph(&state)
        let header = GFMTableEditEngine.cells(slice)
        var rows: [[String]] = []
        var end = line + 2
        while end < state.index.lineCount, isPreviewTableBodyRow(state.index, line: end), rows.count < GFMTableEditEngine.maxRows {
            rows.append(GFMTableEditEngine.cells(state.index.lineSlice(end)))
            end += 1
        }
        if header.count <= GFMTableEditEngine.maxColumns, rows.allSatisfy({ $0.count <= GFMTableEditEngine.maxColumns }) {
            state.appendNonCodeBlock(.table(header: header, rows: rows, sourceLine: line + 1))
        } else {
            let fallback = (line..<end).map { previewLineText(state.index, line: $0) }.joined(separator: "\n")
            state.appendNonCodeBlock(.paragraph(text: fallback, sourceLine: line + 1))
        }
        return end
    }

    private static func isPreviewTableBodyRow(_ index: MarkdownLineIndex, line: Int) -> Bool {
        guard !isPreviewBlankLine(index, line: line) else { return false }
        return index.lineSlice(line).drop(while: { $0 == 0x20 }).first == 0x7C
    }

    private static func consumePreviewHTMLBlock(at start: Int, state: inout PreviewProjectionState) -> Int {
        flushPreviewParagraph(&state)
        let firstLine = previewLineText(state.index, line: start)
        var raw: [String] = [firstLine]
        var line = start + 1
        if isSingleLineClosedHTML(firstLine) == false {
            while line < state.index.lineCount, shouldTerminatePreviewHTMLBlock(at: line, state: &state) == false {
                raw.append(previewLineText(state.index, line: line))
                line += 1
            }
        }
        state.appendNonCodeBlock(.inertHTML(text: raw.joined(separator: "\n"), sourceLine: start + 1))
        return line
    }

    private static func shouldTerminatePreviewHTMLBlock(at line: Int, state: inout PreviewProjectionState) -> Bool {
        if isPreviewBlankLine(state.index, line: line) { return true }
        if activePreviewFence(at: line, state: &state) != nil { return true }
        if isPreviewTableStart(state.index, line: line) { return true }
        let nextSlice = state.index.lineSlice(line)
        if isATXHeading(nextSlice) || isThematic(nextSlice.drop(while: { $0 == 0x20 })) { return true }
        return MarkdownListGrammar.parseListLine(nextSlice) != nil
    }
}

public enum ImageBlockReason: Equatable, Sendable {
    case remoteOrData, outOfScope, forbiddenExtension, tooLarge, tooManyPixels, tooManyImages, symlink, unreadable
}

public enum ImageAdmission: Equatable, Sendable {
    case admitted(url: URL, targetMaxPixel: Int)
    case blocked(ImageBlockReason)
}

public enum LinkDecision: Equatable, Sendable {
    case requiresConfirmation(canonicalURI: String)
    case blocked
}

/// Admission control for preview images and links (`SEC-002`, `SEC-003`, `SEC-004`).
///
/// Image gates run in order before any decode: (1) no remote or `data:` reference, (2) resolved path inside `scopeRoot`, (3) raster extension allowlist (no SVG or PDF), (4) per-document count `<= 64`, (5) not a symlink, `<= 16 MiB`, and header pixels `<= 8192` per edge and `<= 16 MP`, all read through `FileSystemProviding`. The gate never opens a socket. Links are allowed only for `https`, `http`, and `mailto` and always require user confirmation.
public struct PreviewResourceAndLinkGate: Sendable {
    public static let maxBytes: UInt64 = 16 * 1024 * 1024
    public static let maxPixelEdge = 8192
    public static let maxPixels = 16_000_000
    public static let thumbnailMaxPixel = 2048
    public static let maxImagesPerDocument = 64
    static let allowedExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "heic"]

    private let fileSystem: any FileSystemProviding
    private let scopeRoot: URL
    private let documentDirectory: URL

    public init(fileSystem: any FileSystemProviding, scopeRoot: URL, documentDirectory: URL) {
        self.fileSystem = fileSystem
        self.scopeRoot = scopeRoot.standardizedFileURL
        self.documentDirectory = documentDirectory.standardizedFileURL
    }

    public func admitImage(reference: String, admittedCount: Int = 0) -> ImageAdmission {
        switch resolveAdmittedImageData(reference: reference, admittedCount: admittedCount) {
        case .failure(let reason):
            return .blocked(reason)
        case .success(let resolved):
            guard let size = Self.pixelSize(of: resolved.data) else { return .blocked(.unreadable) }
            guard Self.isWithinPixelBounds(width: size.width, height: size.height) else { return .blocked(.tooManyPixels) }
            return .admitted(url: resolved.url, targetMaxPixel: min(Self.thumbnailMaxPixel, max(size.width, size.height)))
        }
    }

    /// Decodes a downsampled thumbnail (`<= targetMaxPixel`) without ever materializing the full-size bitmap.
    public func loadThumbnail(for admitted: ImageAdmission) -> CGImage? {
        guard case .admitted(let url, let target) = admitted,
              let data = try? fileSystem.readData(at: url, maxBytes: Int(Self.maxBytes), withinScope: scopeRoot),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return Self.createDownsampledThumbnail(from: source, targetMaxPixel: target)
    }

    /// Single-read admission + thumbnail decode avoiding duplicate `<= 16 MiB` disk reads for local raster preview images (`SEC-002`, `SEC-003`).
    public func admitAndLoadThumbnail(reference: String, admittedCount: Int = 0) -> (admission: ImageAdmission, thumbnail: CGImage?) {
        switch resolveAdmittedImageData(reference: reference, admittedCount: admittedCount) {
        case .failure(let reason):
            return (.blocked(reason), nil)
        case .success(let resolved):
            guard let source = CGImageSourceCreateWithData(resolved.data as CFData, nil),
                  let size = Self.sourcePixelSize(of: source) else {
                return (.blocked(.unreadable), nil)
            }
            guard Self.isWithinPixelBounds(width: size.width, height: size.height) else {
                return (.blocked(.tooManyPixels), nil)
            }
            let target = min(Self.thumbnailMaxPixel, max(size.width, size.height))
            let image = Self.createDownsampledThumbnail(from: source, targetMaxPixel: target)
            return (.admitted(url: resolved.url, targetMaxPixel: target), image)
        }
    }

    public static func decideLink(_ raw: String) -> LinkDecision {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let comps = URLComponents(string: trimmed), let scheme = comps.scheme?.lowercased(),
              MarkdownLintAndFormatEngine.allowedLinkSchemes.contains(scheme), let canonical = comps.url?.absoluteString else { return .blocked }
        if scheme != "mailto", (comps.host ?? "").isEmpty { return .blocked }
        if scheme == "mailto", comps.path.isEmpty { return .blocked }
        return .requiresConfirmation(canonicalURI: canonical)
    }

    /// Extracts `![alt](src)` sources from one Markdown text fragment (at most `maxImagesPerDocument`), skipping allocation when no `![` sequence exists.
    public static func imageReferences(in text: String) -> [String] {
        // Zero-allocation UTF-8 pre-check: skip 99%+ of blocks with no `![` image marker.
        var hasImageMarker = false
        let utf8 = text.utf8
        var prevWasBang = false
        for b in utf8 {
            if prevWasBang && b == 0x5B {
                hasImageMarker = true
                break
            }
            prevWasBang = (b == 0x21)
        }
        guard hasImageMarker else { return [] }

        let units = Array(text.utf16)
        var out: [String] = []
        var i = 0
        while i + 1 < units.count, out.count < maxImagesPerDocument {
            if units[i] == 0x21, units[i + 1] == 0x5B, let end = MarkdownSyntaxHighlighter.linkEnd(units[...], openBracket: i + 1) {
                var close = i + 2
                while units[close] != 0x5D { close += 1 }
                out.append(String(decoding: units[(close + 2)..<end], as: UTF16.self))
                i = end + 1
            } else { i += 1 }
        }
        return out
    }

    private static func pixelSize(of data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return sourcePixelSize(of: source)
    }
}

extension PreviewResourceAndLinkGate {
    private enum ResolvedImageOutcome {
        case success((url: URL, data: Data))
        case failure(ImageBlockReason)
    }

    private func resolveAdmittedImageData(reference: String, admittedCount: Int) -> ResolvedImageOutcome {
        switch resolveScopedImageURL(reference: reference, admittedCount: admittedCount) {
        case .failure(let reason):
            return .failure(reason)
        case .success(let url):
            return readScopedImageBytes(at: url)
        }
    }

    private enum ScopedImageURLOutcome {
        case success(URL)
        case failure(ImageBlockReason)
    }

    private func resolveScopedImageURL(reference: String, admittedCount: Int) -> ScopedImageURLOutcome {
        let ref = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !Self.isRemoteOrDataImageReference(ref) else { return .failure(.remoteOrData) }
        let decoded = ref.removingPercentEncoding ?? ref
        let candidate = decoded.hasPrefix("/") ? URL(fileURLWithPath: decoded) : documentDirectory.appendingPathComponent(decoded)
        let url = candidate.standardizedFileURL
        let rootPath = scopeRoot.path.hasSuffix("/") ? scopeRoot.path : scopeRoot.path + "/"
        guard url.path.hasPrefix(rootPath) else { return .failure(.outOfScope) }
        guard Self.allowedExtensions.contains(url.pathExtension.lowercased()) else { return .failure(.forbiddenExtension) }
        guard admittedCount < Self.maxImagesPerDocument else { return .failure(.tooManyImages) }
        return .success(url)
    }

    private static func isRemoteOrDataImageReference(_ ref: String) -> Bool {
        if ref.isEmpty || ref.hasPrefix("//") { return true }
        let lower = ref.lowercased()
        return lower.contains("://") || lower.hasPrefix("data:")
    }

    private func readScopedImageBytes(at url: URL) -> ResolvedImageOutcome {
        do {
            let attrs = try fileSystem.fileAttributes(at: url, withinScope: scopeRoot)
            if attrs.isSymbolicLink { return .failure(.symlink) }
            guard attrs.byteSize <= Self.maxBytes else { return .failure(.tooLarge) }
            let data = try fileSystem.readData(at: url, maxBytes: Int(Self.maxBytes), withinScope: scopeRoot)
            return .success((url, data))
        } catch DomainError.securityScopeViolation {
            return .failure(.outOfScope)
        } catch {
            return .failure(.unreadable)
        }
    }

    private static func sourcePixelSize(of source: CGImageSource) -> (width: Int, height: Int)? {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (w, h)
    }

    private static func isWithinPixelBounds(width: Int, height: Int) -> Bool {
        width <= maxPixelEdge && height <= maxPixelEdge && width * height <= maxPixels
    }

    private static func createDownsampledThumbnail(from source: CGImageSource, targetMaxPixel: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetMaxPixel
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
