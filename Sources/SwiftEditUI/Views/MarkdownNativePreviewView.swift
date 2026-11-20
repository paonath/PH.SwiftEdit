import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit

/// Zero-WebKit native GFM preview (`Cmd+P`, default OFF) rendering a `GFMPreviewDocument` with SwiftUI primitives only (`SEC-004`, `UI-007`).
///
/// - Raw HTML is shown as inert monospaced text; remote and `data:` images never load (no `AsyncImage`, zero sockets) and render an offline placeholder.
/// - Local images load only after `PreviewResourceAndLinkGate.admitImage` and are decoded as downsampled thumbnails.
/// - Links never open directly: `OpenURLAction` routes them through `PreviewResourceAndLinkGate.decideLink` and a user confirmation alert (`https`/`http`/`mailto` only).
/// - Scrolling follows `activeSourceLine` as the single scroll driver and skips animation under Reduce Motion.
@MainActor
struct MarkdownNativePreviewView: View {
    let document: GFMPreviewDocument?
    let palette: PurpleThemePalette
    let gate: PreviewResourceAndLinkGate?
    let activeSourceLine: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pendingLinkURI: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    Text("Native Preview (Zero-WebKit)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                    ForEach(Array((document?.blocks ?? []).enumerated()), id: \.offset) { offset, block in
                        blockView(block).id(offset)
                    }
                }
                .padding(12)
            }
            .onChange(of: activeSourceLine) { _, line in
                guard let blocks = document?.blocks,
                      let target = blocks.lastIndex(where: { $0.sourceLine <= line }) else { return }
                if reduceMotion { proxy.scrollTo(target, anchor: .top) } else { withAnimation(.easeInOut(duration: 0.15)) { proxy.scrollTo(target, anchor: .top) } }
            }
        }
        .background(palette.chromeSurface.swiftUIColor)
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

    @ViewBuilder
    private func blockView(_ block: GFMPreviewBlock) -> some View {
        switch block {
        case .heading(let level, let text, _):
            Text(inline(text)).font(level <= 1 ? .title.bold() : (level == 2 ? .title2.bold() : .title3.bold())).foregroundStyle(palette.chromeForeground.swiftUIColor)
        case .paragraph(let text, _):
            VStack(alignment: .leading, spacing: 6) {
                Text(inline(text)).foregroundStyle(palette.chromeForeground.swiftUIColor)
                imageViews(in: text)
            }
        case .listItem(let text, let ordered, let indent, let task, _):
            HStack(alignment: .top, spacing: 6) {
                Text(task.map { $0 ? "☑" : "☐" } ?? (ordered ? "•" : "•"))
                VStack(alignment: .leading, spacing: 4) {
                    Text(inline(text))
                    imageViews(in: text)
                }
            }
            .padding(.leading, CGFloat(indent) * 4)
            .foregroundStyle(palette.chromeForeground.swiftUIColor)
        case .quote(let text, _):
            Text(inline(text)).foregroundStyle(palette.secondaryForeground.swiftUIColor)
                .padding(.leading, 10)
                .overlay(alignment: .leading) { Rectangle().fill(palette.hairlineBorder.swiftUIColor).frame(width: 3) }
        case .table(let header, let rows, _):
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow { ForEach(Array(header.enumerated()), id: \.offset) { _, cell in Text(inline(cell)).bold() } }
                Divider()
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow { ForEach(Array(row.enumerated()), id: \.offset) { _, cell in Text(inline(cell)) } }
                }
            }
            .foregroundStyle(palette.chromeForeground.swiftUIColor)
        case .code(let text, _):
            Text(text).font(.body.monospaced()).padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.backtickMultilineBackground.swiftUIColor)
                .foregroundStyle(palette.backtickForeground.swiftUIColor)
        case .thematicBreak:
            Divider()
        case .inertHTML(let text, _):
            Text(text).font(.body.monospaced()).padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(palette.inertHTMLWarningForeground.swiftUIColor)
                .background(palette.inertHTMLWarningBackground.swiftUIColor)
                .overlay { RoundedRectangle(cornerRadius: 4).stroke(palette.inertHTMLWarningBorder.swiftUIColor, lineWidth: 1) }
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    @ViewBuilder
    private func imageViews(in text: String) -> some View {
        let refs = PreviewResourceAndLinkGate.imageReferences(in: text)
        ForEach(Array(refs.enumerated()), id: \.offset) { index, ref in
            if let gate, case let admission = gate.admitImage(reference: ref, admittedCount: index),
               case .admitted = admission, let cg = gate.loadThumbnail(for: admission) {
                Image(nsImage: NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height)))
                    .resizable().scaledToFit().frame(maxWidth: 480)
                    .accessibilityLabel("Image \(ref)")
            } else {
                Label("Image blocked or offline", systemImage: "photo.badge.exclamationmark")
                    .font(.caption).foregroundStyle(palette.secondaryForeground.swiftUIColor)
            }
        }
    }

    /// Inline Markdown only (bold, italic, code, links); parse failures fall back to the raw text.
    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}
#endif
