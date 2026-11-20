import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
/// Alfred-style centered heading palette for the active Markdown tab (`UI-009`).
///
/// Rows show a grey, disabled `H<level>` badge instead of `#`; indentation and font size shrink with the level.
/// Heading titles are rendered through `Text(verbatim:)` and never interpreted (`SEC-012`).
@MainActor
struct DocumentNavigatorOverlayView: View {
    let model: SwiftEditWorkbenchModel
    @FocusState private var queryFocused: Bool

    private static let indentPerLevel: CGFloat = 16

    /// Font size by level: H1 largest, H6 smallest.
    static func fontSize(forLevel level: Int) -> CGFloat { CGFloat(max(11, 19 - (level - 1) * 2)) }

    var body: some View {
        if let state = model.navigatorState {
            VStack(spacing: 0) {
                TextField("Go to heading…", text: Binding(
                    get: { model.navigatorState?.query ?? "" },
                    set: { model.navigatorState?.setQuery($0) }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .padding(14)
                .focused($queryFocused)
                .onSubmit { model.confirmDocumentNavigator() }
                .onKeyPress(.downArrow) { model.navigatorState?.moveDown(); return .handled }
                .onKeyPress(.upArrow) { model.navigatorState?.moveUp(); return .handled }
                .onKeyPress(.escape) { model.closeDocumentNavigator(); return .handled }
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(state.filtered.enumerated()), id: \.element.id) { row, heading in
                                rowView(heading, selected: row == state.selectedIndex)
                                    .id(heading.id)
                                    .onTapGesture {
                                        model.navigatorState?.select(index: row)
                                        model.confirmDocumentNavigator()
                                    }
                            }
                        }
                    }
                    .onChange(of: state.selectedIndex) { _, newValue in
                        if state.filtered.indices.contains(newValue) { proxy.scrollTo(state.filtered[newValue].id) }
                    }
                }
                .frame(maxHeight: 360)
            }
            .frame(width: 560)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(model.palette.strokeLavender.swiftUIColor))
            .shadow(radius: 24)
            .padding(.top, 90)
            .onAppear { queryFocused = true }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Document navigator")
        }
    }

    private func rowView(_ heading: MarkdownHeading, selected: Bool) -> some View {
        HStack(spacing: 10) {
            Text(verbatim: "H\(heading.level)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .opacity(0.6)
                .frame(width: 26, alignment: .leading)
            Text(verbatim: heading.title.isEmpty ? "(empty)" : String(heading.title.prefix(200)))
                .font(.system(size: Self.fontSize(forLevel: heading.level), weight: heading.level <= 2 ? .semibold : .regular))
                .lineLimit(1)
                .padding(.leading, CGFloat(heading.level - 1) * Self.indentPerLevel)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(selected ? model.palette.primaryAccent.swiftUIColor.opacity(0.25) : Color.clear)
        .contentShape(Rectangle())
    }
}
#endif
