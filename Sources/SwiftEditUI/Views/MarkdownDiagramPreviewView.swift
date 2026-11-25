import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit

/// Shared top-right action bar for fenced code and native diagram blocks in Markdown Preview (`REQ-003`, `REQ-004`, `UI-009`).
///
/// Enforces WCAG 2.5.8 `>= 24×24 pt` interactive hit targets via `metrics.previewActionTarget` at every zoom level (`50%..300%`).
@MainActor
struct PreviewFenceHeaderToolbarView: View {
    let languageBadge: String?
    let hasDiagramToggle: Bool
    @Binding var showRawCode: Bool
    let rawCode: String
    let palette: PurpleThemePalette
    let metrics: ZoomedChromeMetrics
    let onCopyCode: (String) -> Void
    @State private var didCopy = false

    var body: some View {
        HStack(spacing: 6) {
            if let badge = languageBadge, !badge.isEmpty {
                Text(badge.uppercased())
                    .appFont(size: metrics.previewCaptionFontSize, weight: .semibold, monospaced: true)
                    .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(palette.badgeSurface.swiftUIColor, in: RoundedRectangle(cornerRadius: 4))
            }
            Spacer(minLength: 4)
            if hasDiagramToggle {
                Button {
                    showRawCode.toggle()
                } label: {
                    HStack(spacing: 4) {
                        AppIconView(showRawCode ? .eye : .code, size: max(12, 12 * metrics.factor))
                        Text(showRawCode ? "Diagram" : "Code")
                            .appFont(size: metrics.previewCaptionFontSize, weight: .medium)
                    }
                    .padding(.horizontal, 8)
                    .frame(minWidth: metrics.previewActionTarget, minHeight: metrics.previewActionTarget)
                    .background(palette.badgeSurface.swiftUIColor, in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.chromeForeground.swiftUIColor)
                .accessibilityLabel(showRawCode ? "Show Diagram" : "Show Source Code")
            }
            Button {
                onCopyCode(rawCode)
                didCopy = true
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    didCopy = false
                }
            } label: {
                HStack(spacing: 4) {
                    AppIconView(didCopy ? .check : .duplicate, size: max(12, 12 * metrics.factor))
                    Text(didCopy ? "Copied" : "Copy")
                        .appFont(size: metrics.previewCaptionFontSize, weight: .medium)
                }
                .padding(.horizontal, 8)
                .frame(minWidth: metrics.previewActionTarget, minHeight: metrics.previewActionTarget)
                .background(palette.badgeSurface.swiftUIColor, in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.chromeForeground.swiftUIColor)
            .accessibilityLabel("Copy code to clipboard")
        }
    }
}

/// Native Zero-WebKit SwiftUI `Canvas` renderer for `markmap`/`mindmap` and core `mermaid` diagrams (`REQ-004`, `SEC-004`).
///
/// Scales geometry and labels linearly by `metrics.factor` (`50%..300%`) and exposes a `Diagram | Code` toggle plus Copy to Clipboard button.
@MainActor
struct MarkdownDiagramPreviewView: View {
    let diagram: MarkdownDiagramModel
    let rawCode: String
    let languageLabel: String?
    let palette: PurpleThemePalette
    let metrics: ZoomedChromeMetrics
    let onCopyCode: (String) -> Void
    @Environment(\.appTypography) private var typographyContext
    @State private var showRawCode = false

    private var scale: CGFloat { metrics.factor }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PreviewFenceHeaderToolbarView(
                languageBadge: languageLabel ?? diagram.kind.rawValue,
                hasDiagramToggle: true,
                showRawCode: $showRawCode,
                rawCode: rawCode,
                palette: palette,
                metrics: metrics,
                onCopyCode: onCopyCode
            )
            if showRawCode {
                Text(rawCode)
                    .appFont(size: metrics.previewCodeFontSize, monospaced: true, role: .editor)
                    .padding(8 * scale)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(palette.backtickForeground.swiftUIColor)
            } else {
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    diagramCanvas
                }
                .frame(maxHeight: max(220, 420 * scale))
            }
        }
        .padding(8)
        .background(palette.backtickMultilineBackground.swiftUIColor, in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(palette.hairlineBorder.swiftUIColor, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Native \(diagram.kind.rawValue) diagram")
    }

    @ViewBuilder
    private var diagramCanvas: some View {
        let font = (typographyContext.typography ?? .fallback).font(.interface, size: max(9, 11.5 * scale), weight: .medium)
        switch diagram {
        case .mindmap(let nodes, let w, let h):
            Canvas { ctx, _ in
                drawMindmap(nodes: nodes, in: &ctx, font: font)
            }
            .frame(width: CGFloat(w) * scale, height: CGFloat(h) * scale)
        case .graph(_, _, let nodes, let edges, let w, let h):
            Canvas { ctx, _ in
                drawGraph(nodes: nodes, edges: edges, in: &ctx, font: font)
            }
            .frame(width: CGFloat(w) * scale, height: CGFloat(h) * scale)
        case .sequence(let participants, let centers, let messages, let w, let h):
            Canvas { ctx, _ in
                drawSequence(participants: participants, centers: centers, messages: messages, canvasHeight: h, in: &ctx, font: font)
            }
            .frame(width: CGFloat(w) * scale, height: CGFloat(h) * scale)
        }
    }
}

extension MarkdownDiagramPreviewView {
    fileprivate func drawMindmap(nodes: [MindmapPositionedNode], in ctx: inout GraphicsContext, font: Font) {
        let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let strokeColor = palette.linkForeground.swiftUIColor
        let fillSurface = palette.badgeSurface.swiftUIColor
        let textColor = palette.chromeForeground.swiftUIColor

        for node in nodes {
            if let pid = node.parentID, let parent = byID[pid] {
                let p0 = CGPoint(x: CGFloat(parent.x + parent.width) * scale, y: CGFloat(parent.y + parent.height * 0.5) * scale)
                let p1 = CGPoint(x: CGFloat(node.x) * scale, y: CGFloat(node.y + node.height * 0.5) * scale)
                let midX = (p0.x + p1.x) * 0.5
                var curve = Path()
                curve.move(to: p0)
                curve.addCurve(to: p1, control1: CGPoint(x: midX, y: p0.y), control2: CGPoint(x: midX, y: p1.y))
                ctx.stroke(curve, with: .color(strokeColor.opacity(0.75)), lineWidth: max(1.2, 1.5 * scale))
            }
        }
        for node in nodes {
            let rect = CGRect(
                x: CGFloat(node.x) * scale,
                y: CGFloat(node.y) * scale,
                width: CGFloat(node.width) * scale,
                height: CGFloat(node.height) * scale
            )
            let pill = Path(roundedRect: rect, cornerRadius: 7 * scale)
            ctx.fill(pill, with: .color(fillSurface))
            ctx.stroke(pill, with: .color(strokeColor), lineWidth: max(1.0, 1.25 * scale))
            let resolved = ctx.resolve(Text(verbatim: node.label).font(font).foregroundColor(textColor))
            ctx.draw(resolved, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
        }
    }

    fileprivate func drawGraph(nodes: [GraphPositionedNode], edges: [GraphPositionedEdge], in ctx: inout GraphicsContext, font: Font) {
        let strokeColor = palette.linkForeground.swiftUIColor
        let fillSurface = palette.badgeSurface.swiftUIColor
        let textColor = palette.chromeForeground.swiftUIColor
        let secondaryColor = palette.secondaryForeground.swiftUIColor

        drawSubgraphFrames(nodes: nodes, in: &ctx, font: font, borderColor: palette.hairlineBorder.swiftUIColor, labelColor: secondaryColor)

        for edge in edges {
            let start = CGPoint(x: CGFloat(edge.fromPoint.x) * scale, y: CGFloat(edge.fromPoint.y) * scale)
            let end = CGPoint(x: CGFloat(edge.toPoint.x) * scale, y: CGFloat(edge.toPoint.y) * scale)
            var line = Path()
            line.move(to: start)
            line.addLine(to: end)
            let style = strokeStyle(for: edge.style)
            ctx.stroke(line, with: .color(secondaryColor), style: style)
            drawArrowHead(from: start, to: end, color: secondaryColor, in: &ctx)
            if let label = edge.label, !label.isEmpty {
                let mid = CGPoint(x: (start.x + end.x) * 0.5, y: (start.y + end.y) * 0.5 - 8 * scale)
                let resolved = ctx.resolve(Text(verbatim: label).font(font).foregroundColor(secondaryColor))
                ctx.draw(resolved, at: mid, anchor: .center)
            }
        }

        for node in nodes {
            let rect = CGRect(x: CGFloat(node.x) * scale, y: CGFloat(node.y) * scale, width: CGFloat(node.width) * scale, height: CGFloat(node.height) * scale)
            let shapePath = pathForNodeShape(node.shape, in: rect)
            ctx.fill(shapePath, with: .color(fillSurface))
            ctx.stroke(shapePath, with: .color(strokeColor), lineWidth: max(1.0, 1.3 * scale))
            let resolved = ctx.resolve(Text(verbatim: node.label).font(font).foregroundColor(textColor))
            ctx.draw(resolved, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
        }
    }

    private func drawSubgraphFrames(
        nodes: [GraphPositionedNode],
        in ctx: inout GraphicsContext,
        font: Font,
        borderColor: Color,
        labelColor: Color
    ) {
        var boundsByGroup: [String: CGRect] = [:]
        for node in nodes {
            guard let group = node.subgraphTitle else { continue }
            let r = CGRect(x: CGFloat(node.x) * scale, y: CGFloat(node.y) * scale, width: CGFloat(node.width) * scale, height: CGFloat(node.height) * scale)
            boundsByGroup[group] = boundsByGroup[group]?.union(r) ?? r
        }
        for (title, inner) in boundsByGroup {
            let frame = inner.insetBy(dx: -10 * scale, dy: -16 * scale)
            let box = Path(roundedRect: frame, cornerRadius: 6 * scale)
            ctx.stroke(box, with: .color(borderColor), style: StrokeStyle(lineWidth: 1, dash: [4 * scale, 3 * scale]))
            let resolved = ctx.resolve(Text(verbatim: title).font(font).foregroundColor(labelColor))
            ctx.draw(resolved, at: CGPoint(x: frame.minX + 6 * scale, y: frame.minY + 2 * scale), anchor: .topLeading)
        }
    }

    private func strokeStyle(for edgeStyle: DiagramEdgeStyle) -> StrokeStyle {
        switch edgeStyle {
        case .solid: return StrokeStyle(lineWidth: max(1.1, 1.4 * scale))
        case .dotted: return StrokeStyle(lineWidth: max(1.1, 1.4 * scale), dash: [4 * scale, 3 * scale])
        case .thick: return StrokeStyle(lineWidth: max(2.0, 2.6 * scale))
        }
    }

    private func pathForNodeShape(_ shape: FlowchartNodeShape, in rect: CGRect) -> Path {
        switch shape {
        case .rect:
            return Path(roundedRect: rect, cornerRadius: 3 * scale)
        case .rounded:
            return Path(roundedRect: rect, cornerRadius: 8 * scale)
        case .stadium:
            return Path(roundedRect: rect, cornerRadius: rect.height * 0.5)
        case .circle:
            let side = min(rect.width, rect.height)
            let sq = CGRect(x: rect.midX - side * 0.5, y: rect.midY - side * 0.5, width: side, height: side)
            return Path(ellipseIn: sq)
        case .diamond:
            var p = Path()
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            p.closeSubpath()
            return p
        }
    }

    fileprivate func drawSequence(
        participants: [String],
        centers: [Double],
        messages: [SequenceMessageLayout],
        canvasHeight: Double,
        in ctx: inout GraphicsContext,
        font: Font
    ) {
        let strokeColor = palette.linkForeground.swiftUIColor
        let fillSurface = palette.badgeSurface.swiftUIColor
        let textColor = palette.chromeForeground.swiftUIColor
        let secondary = palette.secondaryForeground.swiftUIColor

        for (idx, name) in participants.enumerated() where idx < centers.count {
            let cx = CGFloat(centers[idx]) * scale
            let box = CGRect(x: cx - 56 * scale, y: 12 * scale, width: 112 * scale, height: 28 * scale)
            let p = Path(roundedRect: box, cornerRadius: 5 * scale)
            ctx.fill(p, with: .color(fillSurface))
            ctx.stroke(p, with: .color(strokeColor), lineWidth: max(1.0, 1.3 * scale))
            let resolved = ctx.resolve(Text(verbatim: name).font(font).foregroundColor(textColor))
            ctx.draw(resolved, at: CGPoint(x: box.midX, y: box.midY), anchor: .center)

            var lifeline = Path()
            lifeline.move(to: CGPoint(x: cx, y: box.maxY))
            lifeline.addLine(to: CGPoint(x: cx, y: CGFloat(canvasHeight - 12) * scale))
            ctx.stroke(lifeline, with: .color(palette.hairlineBorder.swiftUIColor), style: StrokeStyle(lineWidth: 1, dash: [4 * scale, 4 * scale]))
        }

        for msg in messages where msg.fromLane < centers.count && msg.toLane < centers.count {
            let x0 = CGFloat(centers[msg.fromLane]) * scale
            let x1 = CGFloat(centers[msg.toLane]) * scale
            let y = CGFloat(msg.rowY) * scale
            let start = CGPoint(x: x0, y: y)
            let end = CGPoint(x: x0 == x1 ? x0 + 28 * scale : x1, y: y)
            var arrow = Path()
            arrow.move(to: start)
            arrow.addLine(to: end)
            let style = msg.isDashed
                ? StrokeStyle(lineWidth: max(1.1, 1.4 * scale), dash: [4 * scale, 3 * scale])
                : StrokeStyle(lineWidth: max(1.1, 1.4 * scale))
            ctx.stroke(arrow, with: .color(secondary), style: style)
            drawArrowHead(from: start, to: end, color: secondary, in: &ctx)
            if !msg.label.isEmpty {
                let resolved = ctx.resolve(Text(verbatim: msg.label).font(font).foregroundColor(textColor))
                ctx.draw(resolved, at: CGPoint(x: (start.x + end.x) * 0.5, y: y - 9 * scale), anchor: .center)
            }
        }
    }

    private func drawArrowHead(from start: CGPoint, to end: CGPoint, color: Color, in ctx: inout GraphicsContext) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let len = hypot(dx, dy)
        guard len > 0.001 else { return }
        let angle = atan2(dy, dx)
        let tipLength = 7.0 * scale
        let wingAngle: CGFloat = 0.48
        var head = Path()
        head.move(to: end)
        head.addLine(to: CGPoint(x: end.x - tipLength * cos(angle - wingAngle), y: end.y - tipLength * sin(angle - wingAngle)))
        head.move(to: end)
        head.addLine(to: CGPoint(x: end.x - tipLength * cos(angle + wingAngle), y: end.y - tipLength * sin(angle + wingAngle)))
        ctx.stroke(head, with: .color(color), lineWidth: max(1.1, 1.4 * scale))
    }
}
#endif
