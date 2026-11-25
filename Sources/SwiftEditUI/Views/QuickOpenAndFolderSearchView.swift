import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
/// Centered Alfred/Zed-style overlays for Quick Open (`Cmd+T`) and Multi-File Find in Folder (`Ctrl+Shift+F`) (`REQ-007`, `UI-001`, `UI-009`).
@MainActor
struct QuickOpenAndFolderSearchView: View {
    let model: SwiftEditWorkbenchModel
    @FocusState private var fieldFocused: Bool

    var body: some View {
        if model.quickOpenController.isQuickOpenPresented {
            quickOpenOverlay
        } else if model.quickOpenController.isFolderSearchPresented {
            folderSearchOverlay
        }
    }

    private var quickOpenOverlay: some View {
        let controller = model.quickOpenController
        let queryBinding = Binding<String>(
            get: { controller.quickOpenQuery },
            set: { model.updateQuickOpenQuery($0) }
        )
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                AppIconView(.search, size: 14)
                    .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                TextField("Quick Open file by name…", text: queryBinding)
                    .textFieldStyle(.plain)
                    .appFont(size: 15)
                    .focused($fieldFocused)
                    .onSubmit { model.confirmQuickOpenSelection() }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(controller.candidates.enumerated()), id: \.element.id) { idx, candidate in
                        HStack(spacing: 10) {
                            AppIconView(.fileText, size: 13)
                                .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                            Text(verbatim: candidate.filename)
                                .appFont(size: 13, weight: .medium)
                            Spacer(minLength: 8)
                            Text(verbatim: candidate.relativePath)
                                .appFont(size: 11, monospaced: true)
                                .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(minHeight: ChromeHitTarget.minimumPoints)
                        .background(
                            idx == controller.quickOpenSelectedIndex ? model.palette.accentSoftSurface.swiftUIColor : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                        .onTapGesture { model.confirmQuickOpenSelection(at: idx) }
                    }
                }
            }
            .frame(maxHeight: 340)
        }
        .modifier(QuickOverlayCardChrome(palette: model.palette, label: "Quick Open"))
        .onAppear { fieldFocused = true }
        .onKeyPress(.downArrow) { model.moveQuickOpenSelection(delta: 1); return .handled }
        .onKeyPress(.upArrow) { model.moveQuickOpenSelection(delta: -1); return .handled }
        .onKeyPress(.escape) { model.closeQuickOpen(); return .handled }
    }

    private var folderSearchOverlay: some View {
        @Bindable var controller = model.quickOpenController
        let result = controller.folderSearchResult
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                AppIconView(.search, size: 14)
                    .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                TextField("Find in Folder (literal)…", text: $controller.folderSearchQuery)
                    .textFieldStyle(.plain)
                    .appFont(size: 14)
                    .focused($fieldFocused)
                    .onSubmit { model.executeFindInFolder() }
                Toggle("Aa", isOn: $controller.folderSearchCaseSensitive).toggleStyle(.button)
                Toggle("Ww", isOn: $controller.folderSearchWholeWord).toggleStyle(.button)
                Button("Search") { model.executeFindInFolder() }
                Button { model.closeFindInFolder() } label: {
                    AppIconView(.close, size: 12).minimumHitTarget()
                }
                .buttonStyle(.plain)
                .help("Close Find in Folder")
                .accessibilityLabel("Close Find in Folder")
            }
            .controlSize(.small)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            Divider()
            HStack {
                Text(result.isTruncatedAtMatchCap ? "Showing first \(result.matches.count) matches (capped at 5,000)" : "\(result.matches.count) match(es)")
                    .appFont(.caption, monospaced: true)
                    .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(result.matches) { match in
                        Button { model.openFolderSearchMatch(match) } label: {
                            HStack(spacing: 8) {
                                Text(verbatim: "\(match.relativePath):\(match.lineNumber)")
                                    .appFont(size: 11.5, weight: .semibold, monospaced: true)
                                    .foregroundStyle(model.palette.linkForeground.swiftUIColor)
                                Text(verbatim: match.linePreview)
                                    .appFont(size: 12, monospaced: true)
                                    .foregroundStyle(model.palette.chromeForeground.swiftUIColor)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .frame(minHeight: ChromeHitTarget.minimumPoints)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 360)
        }
        .modifier(QuickOverlayCardChrome(palette: model.palette, label: "Find in Folder"))
        .onAppear { fieldFocused = true }
        .onKeyPress(.escape) { model.closeFindInFolder(); return .handled }
    }
}

private struct QuickOverlayCardChrome: ViewModifier {
    let palette: PurpleThemePalette
    let label: String

    func body(content: Content) -> some View {
        content
            .frame(width: 600)
            .background(palette.submenuTranslucentSurface.swiftUIColor, in: RoundedRectangle(cornerRadius: 10))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.hairlineBorder.swiftUIColor))
            .shadow(color: .black.opacity(palette.mode == .black ? 0.45 : 0.14), radius: 18, y: 8)
            .padding(.top, 84)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(label)
    }
}
#endif
