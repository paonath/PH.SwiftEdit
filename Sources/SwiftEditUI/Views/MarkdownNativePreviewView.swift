import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit

/// Bounded thumbnail cache backing offline Markdown preview images with automatic eviction (`countLimit = 64`, `totalCostLimit = 32 MiB`) (`PERF-005`, `MEM-001`, `SEC-004`).
@MainActor
public final class PreviewThumbnailCache {
    public static let shared = PreviewThumbnailCache()
    private let storage: NSCache<NSString, NSImage>

    public init(countLimit: Int = 64, totalCostLimit: Int = 32 * 1024 * 1024) {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
        self.storage = cache
    }

    /// Stores a decoded thumbnail `image` under `key` bounded by estimated byte cost.
    public func store(_ image: NSImage, forKey key: String, costBytes: Int = 0) {
        storage.setObject(image, forKey: key as NSString, cost: max(0, costBytes))
    }

    /// Returns a cached thumbnail for `key`, or `nil` when evicted or uncached.
    public func image(forKey key: String) -> NSImage? {
        storage.object(forKey: key as NSString)
    }

    /// Immediately evicts all cached thumbnails (called when preview hides or all tabs close) (`MEM-001`).
    public func clear() {
        storage.removeAllObjects()
    }
}

/// Offline preview view without any network transport or external web renderer, rendering `GFMPreviewDocument` via native SwiftUI (`SEC-004`, `UI-007`).
///
/// - Raw HTML is shown as inert monospaced text; remote and `data:` images never load (zero sockets) and render an offline placeholder.
/// - Local images load only after `PreviewResourceAndLinkGate.admitImage` and decode asynchronously off `@MainActor` into bounded `PreviewThumbnailCache`.
/// - Links never open directly: `OpenURLAction` routes them through `PreviewResourceAndLinkGate.decideLink` and a user confirmation alert (`https`/`http`/`mailto` only).
/// - Scrolling follows `activeSourceLine` as the single scroll driver and skips animation under Reduce Motion.
@MainActor
struct MarkdownNativePreviewView: View {
    let document: GFMPreviewDocument?
    var enrichedDocument: GFMPreviewEnrichedDocument? = nil
    let palette: PurpleThemePalette
    let gate: PreviewResourceAndLinkGate?
    let activeSourceLine: Int
    var zoomPercent: Int = 100
    var onCopyCode: (String) -> Void = { _ in }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pendingLinkURI: String?

    private var metrics: ZoomedChromeMetrics {
        ZoomedChromeMetrics(zoomPercent: zoomPercent)
    }

    private var activeBlocks: [GFMPreviewBlock] {
        enrichedDocument?.blocks ?? document?.blocks ?? []
    }

    var body: some View {
        let currentMetrics = metrics
        let blocks = activeBlocks
        let ordinals = enrichedDocument?.orderedOrdinals ?? document?.orderedOrdinals ?? []
        let imageSlots = enrichedDocument?.imageEntriesByBlock ?? document?.imageEntriesByBlock ?? []
        let fenceLanguages = enrichedDocument?.fenceLanguagesByBlock ?? []
        let diagrams = enrichedDocument?.diagramsByBlock ?? []
        let frontmatter = enrichedDocument?.frontmatterEntries ?? []

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: currentMetrics.previewBlockSpacing) {
                    Text("PREVIEW")
                        .appFont(size: currentMetrics.previewHeaderLabelFontSize, weight: .semibold)
                        .tracking(0.8)
                        .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                        .accessibilityLabel("Preview")
                    if !frontmatter.isEmpty {
                        frontmatterMetadataCard(entries: frontmatter, metrics: currentMetrics)
                    }
                    ForEach(blocks.indices, id: \.self) { offset in
                        blockView(
                            blocks[offset],
                            ordinal: offset < ordinals.count ? ordinals[offset] : 1,
                            imageEntries: offset < imageSlots.count ? imageSlots[offset] : [],
                            fenceLanguage: offset < fenceLanguages.count ? fenceLanguages[offset] : nil,
                            diagram: offset < diagrams.count ? diagrams[offset] : nil,
                            metrics: currentMetrics
                        )
                        .id(offset)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .onChange(of: activeSourceLine) { _, line in
                let targetBlocks = activeBlocks
                guard !targetBlocks.isEmpty else { return }
                // Binary search monotonically ordered `sourceLine` values in O(log B).
                var lo = 0
                var hi = targetBlocks.count
                while lo < hi {
                    let mid = lo + (hi - lo) / 2
                    if targetBlocks[mid].sourceLine <= line { lo = mid + 1 } else { hi = mid }
                }
                guard lo > 0 else { return }
                let target = lo - 1
                if reduceMotion { proxy.scrollTo(target, anchor: .top) } else { withAnimation(.easeInOut(duration: 0.15)) { proxy.scrollTo(target, anchor: .top) } }
            }
        }
        .background(palette.editorCanvasBackground.swiftUIColor)
        .overlay(alignment: .leading) { Rectangle().fill(palette.hairlineBorder.swiftUIColor).frame(width: 1) }
        .environment(\.openURL, OpenURLAction { url in
            if case .requiresConfirmation(let canonical) = PreviewResourceAndLinkGate.decideLink(url.absoluteString) {
                pendingLinkURI = canonical
            }
            return .handled
        })
        .alert("Open External Link?", isPresented: Binding(get: { pendingLinkURI != nil }, set: { if !$0 { pendingLinkURI = nil } })) {
            Button("Open in Browser") {
                if let uri = pendingLinkURI, let url = URL(string: uri) { NSWorkspace.shared.open(url) }
                pendingLinkURI = nil
            }
            Button("Cancel", role: .cancel) { pendingLinkURI = nil }
        } message: {
            Text(pendingLinkURI ?? "")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Markdown Preview")
    }

    private func frontmatterMetadataCard(entries: [GFMPreviewFrontmatterEntry], metrics: ZoomedChromeMetrics) -> some View {
        VStack(alignment: .leading, spacing: 4 * metrics.factor) {
            Text("PROPERTIES")
                .appFont(size: metrics.previewCaptionFontSize, weight: .semibold)
                .tracking(0.6)
                .foregroundStyle(palette.secondaryForeground.swiftUIColor)
            Grid(alignment: .leading, horizontalSpacing: 12 * metrics.factor, verticalSpacing: 4 * metrics.factor) {
                ForEach(entries.indices, id: \.self) { idx in
                    GridRow {
                        Text(verbatim: entries[idx].key)
                            .appFont(size: metrics.previewCaptionFontSize, weight: .semibold, monospaced: true)
                            .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                        Text(verbatim: entries[idx].displayValue)
                            .appFont(size: metrics.previewBodyFontSize)
                            .foregroundStyle(palette.chromeForeground.swiftUIColor)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.badgeSurface.swiftUIColor, in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(palette.hairlineBorder.swiftUIColor, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Frontmatter properties")
    }

    @ViewBuilder
    private func blockView(
        _ block: GFMPreviewBlock,
        ordinal: Int,
        imageEntries: [GFMPreviewImageEntry],
        fenceLanguage: String?,
        diagram: MarkdownDiagramModel?,
        metrics: ZoomedChromeMetrics
    ) -> some View {
        switch block {
        case .heading(let level, let text, _):
            let headingSize = level <= 1 ? metrics.previewH1FontSize
                : (level == 2 ? metrics.previewH2FontSize : (level == 3 ? metrics.previewH3FontSize : metrics.previewBodyFontSize))
            Text(inline(text))
                .appFont(size: headingSize, weight: level <= 2 ? .semibold : .medium)
                .foregroundStyle(palette.chromeForeground.swiftUIColor)
                .padding(.top, (level <= 2 ? 6 : 2) * metrics.factor)
        case .paragraph(let text, _):
            VStack(alignment: .leading, spacing: 6 * metrics.factor) {
                Text(inline(text))
                    .appFont(size: metrics.previewBodyFontSize)
                    .foregroundStyle(palette.chromeForeground.swiftUIColor)
                imageViews(entries: imageEntries, metrics: metrics)
            }
        case .listItem(let text, let ordered, let indent, let task, _):
            HStack(alignment: .top, spacing: 6 * metrics.factor) {
                Text(MarkdownPreviewProjector.listMarkerText(ordered: ordered, taskChecked: task, ordinal: ordinal))
                    .appFont(size: metrics.previewBodyFontSize)
                VStack(alignment: .leading, spacing: 4 * metrics.factor) {
                    Text(inline(text))
                        .appFont(size: metrics.previewBodyFontSize)
                    imageViews(entries: imageEntries, metrics: metrics)
                }
            }
            .padding(.leading, CGFloat(indent) * metrics.previewIndentStep)
            .foregroundStyle(palette.chromeForeground.swiftUIColor)
        case .quote(let text, _):
            Text(inline(text))
                .appFont(size: metrics.previewBodyFontSize)
                .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                .padding(.leading, 10 * metrics.factor)
                .overlay(alignment: .leading) {
                    Rectangle().fill(palette.hairlineBorder.swiftUIColor).frame(width: metrics.previewQuoteBarWidth)
                }
        case .table(let header, let rows, _):
            Grid(alignment: .leading, horizontalSpacing: 12 * metrics.factor, verticalSpacing: 4 * metrics.factor) {
                GridRow {
                    ForEach(header.indices, id: \.self) { idx in
                        Text(inline(header[idx])).appFont(size: metrics.previewBodyFontSize, weight: .semibold)
                    }
                }
                Divider()
                ForEach(rows.indices, id: \.self) { rowIdx in
                    let row = rows[rowIdx]
                    GridRow {
                        ForEach(row.indices, id: \.self) { colIdx in
                            Text(inline(row[colIdx])).appFont(size: metrics.previewBodyFontSize)
                        }
                    }
                }
            }
            .foregroundStyle(palette.chromeForeground.swiftUIColor)
        case .code(let text, _):
            if let diagram {
                MarkdownDiagramPreviewView(
                    diagram: diagram,
                    rawCode: text,
                    languageLabel: fenceLanguage,
                    palette: palette,
                    metrics: metrics,
                    onCopyCode: onCopyCode
                )
            } else {
                PreviewCodeFenceBlockView(
                    text: text,
                    languageLabel: fenceLanguage,
                    palette: palette,
                    metrics: metrics,
                    onCopyCode: onCopyCode
                )
            }
        case .thematicBreak:
            Divider()
        case .inertHTML(let text, _):
            Text(text)
                .appFont(size: metrics.previewCodeFontSize, monospaced: true, role: .editor)
                .padding(6 * metrics.factor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(palette.inertHTMLWarningForeground.swiftUIColor)
                .background(palette.inertHTMLWarningBackground.swiftUIColor)
                .overlay { RoundedRectangle(cornerRadius: 4).stroke(palette.inertHTMLWarningBorder.swiftUIColor, lineWidth: 1) }
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    @ViewBuilder
    private func imageViews(entries: [GFMPreviewImageEntry], metrics: ZoomedChromeMetrics) -> some View {
        ForEach(entries.indices, id: \.self) { idx in
            let entry = entries[idx]
            if let gate {
                PreviewThumbnailTileView(
                    gate: gate,
                    reference: entry.reference,
                    documentIndex: entry.documentIndex,
                    palette: palette,
                    maxWidth: metrics.previewThumbnailMaxWidth,
                    captionFontSize: metrics.previewCaptionFontSize
                )
            } else {
                Label { Text("Image blocked or offline") } icon: { AppIconView(.imageOff, size: max(12, 13 * metrics.factor)) }
                    .appFont(size: metrics.previewCaptionFontSize)
                    .foregroundStyle(palette.secondaryForeground.swiftUIColor)
            }
        }
    }

    /// Inline Markdown only (bold, italic, code, links); plain text bypasses the Foundation Markdown parser and parsed runs are cached (`PERF-005`).
    private func inline(_ text: String) -> AttributedString {
        InlineMarkdownRenderCache.shared.attributedString(for: text)
    }
}

/// Fenced code block card with zoom-scaled `.editor` typography and mandatory top-right Copy to Clipboard button (`REQ-003`).
@MainActor
private struct PreviewCodeFenceBlockView: View {
    let text: String
    let languageLabel: String?
    let palette: PurpleThemePalette
    let metrics: ZoomedChromeMetrics
    let onCopyCode: (String) -> Void
    @State private var unusedToggle = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PreviewFenceHeaderToolbarView(
                languageBadge: languageLabel,
                hasDiagramToggle: false,
                showRawCode: $unusedToggle,
                rawCode: text,
                palette: palette,
                metrics: metrics,
                onCopyCode: onCopyCode
            )
            Text(text)
                .appFont(size: metrics.previewCodeFontSize, monospaced: true, role: .editor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(palette.backtickForeground.swiftUIColor)
        }
        .padding(8)
        .background(palette.backtickMultilineBackground.swiftUIColor, in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(palette.hairlineBorder.swiftUIColor, lineWidth: 1)
        }
    }
}

/// Bounded `@MainActor` cache for inline Markdown `AttributedString` parsing with a zero-parser fast path for plain text (`PERF-005`).
@MainActor
private final class InlineMarkdownRenderCache {
    static let shared = InlineMarkdownRenderCache()

    private final class Box: NSObject {
        let value: AttributedString
        init(_ value: AttributedString) { self.value = value }
    }

    private let cache: NSCache<NSString, Box> = {
        let c = NSCache<NSString, Box>()
        c.countLimit = 512
        return c
    }()

    func attributedString(for text: String) -> AttributedString {
        if !Self.containsInlineSyntaxTrigger(text) {
            return AttributedString(text)
        }
        let key = text as NSString
        if let hit = cache.object(forKey: key) {
            return hit.value
        }
        let parsed = (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
        cache.setObject(Box(parsed), forKey: key)
        return parsed
    }

    private static func containsInlineSyntaxTrigger(_ text: String) -> Bool {
        for byte in text.utf8 {
            switch byte {
            case 0x2A, // '*'
                 0x5F, // '_'
                 0x60, // '`'
                 0x5B, // '['
                 0x7E, // '~'
                 0x5C, // '\'
                 0x3C, // '<'
                 0x26: // '&' (HTML entities)
                return true
            default:
                continue
            }
        }
        return false
    }
}

/// Off-`@MainActor` local thumbnail loader keyed by reference + index and backed by `PreviewThumbnailCache` (`PERF-005`).
@MainActor
private struct PreviewThumbnailTileView: View {
    let gate: PreviewResourceAndLinkGate
    let reference: String
    let documentIndex: Int
    let palette: PurpleThemePalette
    var maxWidth: CGFloat = 480
    var captionFontSize: CGFloat = 10
    @State private var loadedImage: NSImage?
    @State private var isBlocked = false

    private var taskKey: String { "\(reference)#\(documentIndex)" }

    var body: some View {
        Group {
            if let loadedImage {
                Image(nsImage: loadedImage)
                    .resizable().scaledToFit().frame(maxWidth: maxWidth)
                    .accessibilityLabel("Image \(reference)")
            } else if isBlocked {
                Label { Text("Image blocked or offline") } icon: { AppIconView(.imageOff, size: 13) }
                    .appFont(size: captionFontSize).foregroundStyle(palette.secondaryForeground.swiftUIColor)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .task(id: taskKey) {
            if let cached = PreviewThumbnailCache.shared.image(forKey: taskKey) {
                loadedImage = cached
                isBlocked = false
                return
            }
            loadedImage = nil
            isBlocked = false
            let localGate = gate
            let ref = reference
            let slot = documentIndex
            let cgImage: CGImage? = await Task.detached(priority: .utility) {
                localGate.admitAndLoadThumbnail(reference: ref, admittedCount: slot).thumbnail
            }.value
            guard !Task.isCancelled else { return }
            if let cgImage {
                let img = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                let cost = cgImage.bytesPerRow * cgImage.height
                PreviewThumbnailCache.shared.store(img, forKey: taskKey, costBytes: cost)
                loadedImage = img
                isBlocked = false
            } else {
                loadedImage = nil
                isBlocked = true
            }
        }
    }
}
#endif
