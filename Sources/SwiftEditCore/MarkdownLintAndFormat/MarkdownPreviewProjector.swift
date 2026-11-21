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

    public static func project(snapshot: DocumentSnapshot, showPreview: Bool, isMarkdownDocument: Bool = true) -> GFMPreviewDocument? {
        guard showPreview, isMarkdownDocument, !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText else { return nil }
        let index = MarkdownLineIndex(text: snapshot.text)
        var blocks: [GFMPreviewBlock] = []
        var paragraph: [String] = []
        var paragraphStart = 0
        let fences = index.fences
        var fenceCursor = 0

        func currentFence(at line: Int) -> (open: Int, close: Int)? {
            while fenceCursor < fences.count && fences[fenceCursor].close < line {
                fenceCursor += 1
            }
            if fenceCursor < fences.count && fences[fenceCursor].open <= line {
                return fences[fenceCursor]
            }
            return nil
        }

        func text(_ line: Int) -> String {
            let s = index.lineSlice(line)
            return String(decoding: s.prefix(MarkdownLineIndex.maxLineUTF16), as: UTF16.self)
        }
        func isBlank(_ line: Int) -> Bool { index.lineSlice(line).allSatisfy { $0 == 0x20 || $0 == 0x09 } }
        func flush() {
            if !paragraph.isEmpty {
                blocks.append(.paragraph(text: paragraph.joined(separator: "\n"), sourceLine: paragraphStart + 1))
                paragraph.removeAll(keepingCapacity: true)
            }
        }
        func isHTMLStart(_ s: ArraySlice<UInt16>) -> Bool {
            var i = s.startIndex
            while i < s.endIndex, s[i] == 0x20 { i += 1 }
            guard i + 1 < s.endIndex, s[i] == 0x3C else { return false }
            let n = s[i + 1]
            return (n >= 0x41 && n <= 0x5A) || (n >= 0x61 && n <= 0x7A) || n == 0x2F || n == 0x21
        }
        func isTableStart(_ line: Int) -> Bool {
            guard line + 1 < index.lineCount else { return false }
            let slice = index.lineSlice(line)
            var i = slice.startIndex
            while i < slice.endIndex, slice[i] == 0x20 { i += 1 }
            return i < slice.endIndex && slice[i] == 0x7C && GFMTableEditEngine.isDelimiterRowSlice(index.lineSlice(line + 1))
        }

        var line = 0
        while line < index.lineCount {
            if let span = currentFence(at: line) {
                flush()
                let open = line
                let closed = span.close > span.open && isClosingFence(index, span.close)
                let bodyEnd = closed ? span.close : span.close + 1
                let body = ((open + 1)..<max(open + 1, bodyEnd)).map(text)
                blocks.append(.code(text: body.joined(separator: "\n"), sourceLine: open + 1))
                line = span.close + 1
                continue
            }
            let slice = index.lineSlice(line)
            if isBlank(line) { flush(); line += 1; continue }
            let trimmed = slice.drop(while: { $0 == 0x20 })
            if trimmed.first == 0x23 {
                var level = 0
                var j = trimmed.startIndex
                while j < trimmed.endIndex, trimmed[j] == 0x23 { level += 1; j += 1 }
                if level <= 6, j == trimmed.endIndex || trimmed[j] == 0x20 {
                    flush()
                    blocks.append(.heading(level: level, text: String(decoding: trimmed[j...], as: UTF16.self).trimmingCharacters(in: .whitespaces), sourceLine: line + 1))
                    line += 1; continue
                }
            }
            if isThematic(trimmed) { flush(); blocks.append(.thematicBreak(sourceLine: line + 1)); line += 1; continue }
            if trimmed.first == 0x3E {
                flush()
                var body = String(decoding: trimmed.dropFirst(), as: UTF16.self)
                if body.hasPrefix(" ") { body.removeFirst() }
                blocks.append(.quote(text: body, sourceLine: line + 1)); line += 1; continue
            }
            if let item = MarkdownListGrammar.parseListLine(slice) {
                flush()
                let body = String(decoding: slice.dropFirst(item.prefixLength), as: UTF16.self)
                var ordered = false
                var task: Bool?
                switch item.kind {
                case .ordered: ordered = true
                case .bullet(_, let state): task = state.map { $0 != 0x20 }
                }
                blocks.append(.listItem(text: body, ordered: ordered, indent: item.indent, taskChecked: task, sourceLine: line + 1))
                line += 1; continue
            }
            if isTableStart(line) {
                flush()
                let header = GFMTableEditEngine.cells(slice)
                var rows: [[String]] = []
                var end = line + 2
                while end < index.lineCount, !isBlank(end), index.lineSlice(end).drop(while: { $0 == 0x20 }).first == 0x7C, rows.count < GFMTableEditEngine.maxRows {
                    rows.append(GFMTableEditEngine.cells(index.lineSlice(end))); end += 1
                }
                if header.count <= GFMTableEditEngine.maxColumns, rows.allSatisfy({ $0.count <= GFMTableEditEngine.maxColumns }) {
                    blocks.append(.table(header: header, rows: rows, sourceLine: line + 1))
                } else {
                    blocks.append(.paragraph(text: (line..<end).map(text).joined(separator: "\n"), sourceLine: line + 1))
                }
                line = end; continue
            }
            if isHTMLStart(slice) {
                flush()
                let start = line
                let firstLine = text(line)
                var raw: [String] = [firstLine]
                line += 1
                if !isSingleLineClosedHTML(firstLine) {
                    while line < index.lineCount, !isBlank(line) {
                        let nextSlice = index.lineSlice(line)
                        if currentFence(at: line) != nil
                            || isTableStart(line)
                            || isATXHeading(nextSlice)
                            || isThematic(nextSlice.drop(while: { $0 == 0x20 }))
                            || MarkdownListGrammar.parseListLine(nextSlice) != nil {
                            break
                        }
                        raw.append(text(line))
                        line += 1
                    }
                }
                blocks.append(.inertHTML(text: raw.joined(separator: "\n"), sourceLine: start + 1))
                continue
            }
            if paragraph.isEmpty { paragraphStart = line }
            paragraph.append(text(line))
            line += 1
        }
        flush()
        return GFMPreviewDocument(revision: snapshot.revision, blocks: blocks)
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

    private static func isClosingFence(_ index: MarkdownLineIndex, _ line: Int) -> Bool {
        let s = index.lineSlice(line).drop(while: { $0 == 0x20 })
        return s.count >= 3 && (s.allSatisfy { $0 == 0x60 } || s.allSatisfy { $0 == 0x7E })
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
        let ref = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = ref.lowercased()
        if ref.isEmpty || lower.contains("://") || lower.hasPrefix("data:") || ref.hasPrefix("//") { return .blocked(.remoteOrData) }
        let decoded = ref.removingPercentEncoding ?? ref
        let url = (decoded.hasPrefix("/") ? URL(fileURLWithPath: decoded) : documentDirectory.appendingPathComponent(decoded)).standardizedFileURL
        let rootPath = scopeRoot.path.hasSuffix("/") ? scopeRoot.path : scopeRoot.path + "/"
        guard url.path.hasPrefix(rootPath) else { return .blocked(.outOfScope) }
        guard Self.allowedExtensions.contains(url.pathExtension.lowercased()) else { return .blocked(.forbiddenExtension) }
        guard admittedCount < Self.maxImagesPerDocument else { return .blocked(.tooManyImages) }
        do {
            let attrs = try fileSystem.fileAttributes(at: url, withinScope: scopeRoot)
            if attrs.isSymbolicLink { return .blocked(.symlink) }
            guard attrs.byteSize <= Self.maxBytes else { return .blocked(.tooLarge) }
            let data = try fileSystem.readData(at: url, maxBytes: Int(Self.maxBytes), withinScope: scopeRoot)
            guard let size = Self.pixelSize(of: data) else { return .blocked(.unreadable) }
            guard size.width <= Self.maxPixelEdge, size.height <= Self.maxPixelEdge, size.width * size.height <= Self.maxPixels else { return .blocked(.tooManyPixels) }
            return .admitted(url: url, targetMaxPixel: min(Self.thumbnailMaxPixel, max(size.width, size.height)))
        } catch DomainError.securityScopeViolation {
            return .blocked(.outOfScope)
        } catch {
            return .blocked(.unreadable)
        }
    }

    /// Decodes a downsampled thumbnail (`<= targetMaxPixel`) without ever materializing the full-size bitmap.
    public func loadThumbnail(for admitted: ImageAdmission) -> CGImage? {
        guard case .admitted(let url, let target) = admitted,
              let data = try? fileSystem.readData(at: url, maxBytes: Int(Self.maxBytes), withinScope: scopeRoot),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: target
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Single-read admission + thumbnail decode avoiding duplicate `<= 16 MiB` disk reads for local raster preview images (`SEC-002`, `SEC-003`).
    public func admitAndLoadThumbnail(reference: String, admittedCount: Int = 0) -> (admission: ImageAdmission, thumbnail: CGImage?) {
        let ref = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = ref.lowercased()
        if ref.isEmpty || lower.contains("://") || lower.hasPrefix("data:") || ref.hasPrefix("//") { return (.blocked(.remoteOrData), nil) }
        let decoded = ref.removingPercentEncoding ?? ref
        let url = (decoded.hasPrefix("/") ? URL(fileURLWithPath: decoded) : documentDirectory.appendingPathComponent(decoded)).standardizedFileURL
        let rootPath = scopeRoot.path.hasSuffix("/") ? scopeRoot.path : scopeRoot.path + "/"
        guard url.path.hasPrefix(rootPath) else { return (.blocked(.outOfScope), nil) }
        guard Self.allowedExtensions.contains(url.pathExtension.lowercased()) else { return (.blocked(.forbiddenExtension), nil) }
        guard admittedCount < Self.maxImagesPerDocument else { return (.blocked(.tooManyImages), nil) }
        do {
            let attrs = try fileSystem.fileAttributes(at: url, withinScope: scopeRoot)
            if attrs.isSymbolicLink { return (.blocked(.symlink), nil) }
            guard attrs.byteSize <= Self.maxBytes else { return (.blocked(.tooLarge), nil) }
            let data = try fileSystem.readData(at: url, maxBytes: Int(Self.maxBytes), withinScope: scopeRoot)
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let w = props[kCGImagePropertyPixelWidth] as? Int,
                  let h = props[kCGImagePropertyPixelHeight] as? Int else {
                return (.blocked(.unreadable), nil)
            }
            guard w <= Self.maxPixelEdge, h <= Self.maxPixelEdge, w * h <= Self.maxPixels else {
                return (.blocked(.tooManyPixels), nil)
            }
            let target = min(Self.thumbnailMaxPixel, max(w, h))
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: target
            ]
            let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
            return (.admitted(url: url, targetMaxPixel: target), image)
        } catch DomainError.securityScopeViolation {
            return (.blocked(.outOfScope), nil)
        } catch {
            return (.blocked(.unreadable), nil)
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
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (w, h)
    }
}
