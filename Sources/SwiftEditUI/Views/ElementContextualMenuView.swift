import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
/// Zed-style contextual action palette anchored under the selection (`REQ-020-04`, `UI-010`).
///
/// Filter field on top, expandable group headers with a chevron and action count, then action rows with icon, title and
/// a monospaced result preview. Every label is rendered through `Text(verbatim:)` (`SEC-012`).
@MainActor
struct ElementContextualMenuView: View {
    let model: SwiftEditWorkbenchModel
    @FocusState private var queryFocused: Bool

    static let width: CGFloat = 300

    var body: some View {
        if let state = model.elementContextualMenu {
            GeometryReader { proxy in
                let origin = Self.origin(for: state.anchor, in: proxy.size, globalOrigin: proxy.frame(in: .global).origin)
                ZStack(alignment: .topLeading) {
                    // A click anywhere outside the palette (document included) dismisses it exactly like Esc:
                    // the original selection is restored and nothing is edited (`REQ-022-04`).
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { model.closeElementContextualMenu() }
                        .accessibilityHidden(true)
                    palette(state: state)
                        .offset(x: origin.x, y: origin.y)
                }
            }
        }
    }

    /// Clamps the anchor so the palette stays fully inside the window; `nil` anchors center it under the header.
    static func origin(for anchor: CGPoint?, in size: CGSize, globalOrigin: CGPoint, estimatedHeight: CGFloat = 220) -> CGPoint {
        guard let anchor else {
            return CGPoint(x: max(8, (size.width - width) / 2), y: 96)
        }
        let local = CGPoint(x: anchor.x - globalOrigin.x, y: anchor.y - globalOrigin.y + 4)
        let x = min(max(8, local.x), max(8, size.width - width - 8))
        let y = local.y + estimatedHeight > size.height - 8 ? max(8, size.height - estimatedHeight - 8) : max(8, local.y)
        return CGPoint(x: x, y: y)
    }

    private var queryBinding: Binding<String> {
        Binding(
            get: { model.elementContextualMenu?.query ?? "" },
            set: { model.elementContextualMenu?.setQuery($0) }
        )
    }

    private func palette(state: ElementContextualMenuState) -> some View {
        let palette = model.palette
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                AppIconView(.search, size: 12)
                    .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                TextField(model.elementContextualMenu?.selection.length ?? 0 > 0 ? "Actions for selection…" : "Actions for document…", text: queryBinding)
                    .textFieldStyle(.plain)
                    .appFont(size: 12)
                    .focused($queryFocused)
                    .onSubmit { model.activateElementContextualMenuRow() }
                Text(verbatim: "⌘↩")
                    .appFont(size: 10, weight: .medium, monospaced: true)
                    .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(palette.badgeSurface.swiftUIColor, in: RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            Rectangle().fill(palette.hairlineBorder.swiftUIColor).frame(height: 1)
            VStack(alignment: .leading, spacing: 1) {
                let rows = state.rows
                if rows.isEmpty {
                    Text(verbatim: "No matching actions")
                        .appFont(size: 12)
                        .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                        .padding(10)
                }
                ForEach(rows) { row in
                    rowView(row, highlighted: row.id == state.highlightedRowID)
                        .contentShape(Rectangle())
                        .onTapGesture { model.activateElementContextualMenuRow(rowID: row.id) }
                        .onHover { inside in if inside { model.elementContextualMenu?.highlight(rowID: row.id) } }
                }
            }
            .padding(4)
        }
        .frame(width: Self.width, alignment: .leading)
        .background(palette.submenuTranslucentSurface.swiftUIColor, in: RoundedRectangle(cornerRadius: 8))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.hairlineBorder.swiftUIColor, lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        .onAppear {
            queryFocused = true
            DispatchQueue.main.async { queryFocused = true }
        }
        .onKeyPress(.escape) { model.closeElementContextualMenu(); return .handled }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Contextual actions for selection")
    }

    @ViewBuilder
    private func rowView(_ row: ElementContextualMenuState.Row, highlighted: Bool) -> some View {
        let palette = model.palette
        switch row {
        case .group(let group, let isExpanded):
            HStack(spacing: 6) {
                AppIconView(isExpanded ? .chevronDown : .chevronRight, size: 11)
                    .frame(width: 12)
                    .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                Text(verbatim: group.title)
                    .appFont(size: 11, weight: .semibold)
                    .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                Spacer(minLength: 0)
                Text(verbatim: "\(group.actions.count)")
                    .appFont(size: 10, monospaced: true)
                    .foregroundStyle(palette.secondaryForeground.swiftUIColor.opacity(0.8))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(highlighted ? palette.accentSoftSurface.swiftUIColor : Color.clear, in: RoundedRectangle(cornerRadius: 5))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(group.title), \(isExpanded ? "expanded" : "collapsed"), \(group.actions.count) actions")
            .accessibilityAddTraits(.isButton)
        case .action(let action, _):
            HStack(spacing: 8) {
                AppIconView(AppIcon(rawValue: action.iconName) ?? .code, size: 13)
                    .frame(width: 16)
                    .foregroundStyle(highlighted ? palette.primaryAccent.swiftUIColor : palette.secondaryForeground.swiftUIColor)
                Text(verbatim: action.title)
                    .appFont(size: 12)
                    .foregroundStyle(palette.chromeForeground.swiftUIColor)
                Spacer(minLength: 0)
                Text(verbatim: action.preview)
                    .appFont(size: 11, monospaced: true)
                    .foregroundStyle(palette.secondaryForeground.swiftUIColor)
            }
            .padding(.leading, 22)
            .padding(.trailing, 8)
            .padding(.vertical, 5)
            .background(highlighted ? palette.accentSoftSurface.swiftUIColor : Color.clear, in: RoundedRectangle(cornerRadius: 5))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(action.title), result \(action.preview)")
            .accessibilityAddTraits(.isButton)
        }
    }
}
#endif
