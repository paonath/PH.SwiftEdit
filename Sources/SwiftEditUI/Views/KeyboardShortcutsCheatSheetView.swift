import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
/// Searchable, clickable shortcut list shared by the floating sheet and the right side panel (`REQ-021-04`).
///
/// Typing filters by title, summary or shortcut and highlights the matching rows; ↑/↓ move the selection and Return or a
/// click runs the row's `CheatSheetCommand` on the editor (documentation-only rows are dimmed and not clickable).
struct ShortcutsCatalogList: View {
    let palette: PurpleThemePalette
    let compact: Bool
    let onPerform: (CheatSheetCommand) -> Void
    @State private var query = ""
    @State private var selectedTitle: String?
    @State private var hoveredTitle: String?
    @FocusState private var searchFocused: Bool

    private var sections: [KeyboardShortcutSection] { KeyboardShortcutsCheatSheetCatalog.sections(matching: query) }
    private var flatItems: [KeyboardShortcutDescriptor] { sections.flatMap(\.items) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            searchField
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: compact ? 10 : 14) {
                        if sections.isEmpty {
                            Text("No shortcut matches “\(query)”.")
                                .appFont(.callout)
                                .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                        }
                        ForEach(sections, id: \.category) { section in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(section.category.uppercased())
                                    .appFont(.caption2, weight: .semibold)
                                    .tracking(0.6)
                                    .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                                    .padding(.bottom, 2)
                                ForEach(section.items, id: \.title) { item in
                                    row(item).id(item.title)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: selectedTitle) { _, title in
                    if let title { proxy.scrollTo(title, anchor: .center) }
                }
            }
        }
        .onAppear { DispatchQueue.main.async { searchFocused = true } }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            AppIconView(.search, size: 13)
                .foregroundStyle(palette.secondaryForeground.swiftUIColor)
            TextField("Search function, description or shortcut…", text: $query)
                .textFieldStyle(.plain)
                .appFont(.callout)
                .focused($searchFocused)
                .onSubmit { performSelected() }
                .onKeyPress(.downArrow) { moveSelection(1); return .handled }
                .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
                .onChange(of: query) { _, _ in selectedTitle = query.isEmpty ? nil : flatItems.first(where: { $0.command != nil })?.title }
                .accessibilityLabel("Search keyboard shortcuts")
            if !query.isEmpty {
                Button { query = "" } label: { AppIconView(.closeCircle, size: 12).minimumHitTarget(20) }
                    .buttonStyle(.plain)
                    .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(palette.editorCanvasBackground.swiftUIColor, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.hairlineBorder.swiftUIColor))
    }

    @ViewBuilder
    private func row(_ item: KeyboardShortcutDescriptor) -> some View {
        let isRunnable = item.command != nil
        let isMatch = !query.isEmpty
        let isSelected = selectedTitle == item.title
        let isHovered = hoveredTitle == item.title && isRunnable
        let background: Color = isSelected
            ? palette.accentSoftSurface.swiftUIColor
            : (isHovered ? palette.badgeSurface.swiftUIColor : (isMatch ? palette.accentSoftSurface.swiftUIColor.opacity(0.45) : Color.clear))
        let keycap = Text(verbatim: item.shortcut)
            .appFont(compact ? .caption : .callout, weight: .medium, monospaced: true)
            .foregroundStyle((isRunnable ? palette.chromeForeground : palette.secondaryForeground).swiftUIColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(palette.badgeSurface.swiftUIColor, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke((isRunnable && (isHovered || isSelected) ? palette.chromeAccent : palette.hairlineBorder).swiftUIColor))
        Group {
            if compact {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(item.title).appFont(.callout, weight: .medium).foregroundStyle(palette.chromeForeground.swiftUIColor)
                        Spacer(minLength: 4)
                        keycap
                    }
                    Text(item.summary).appFont(.caption).foregroundStyle(palette.secondaryForeground.swiftUIColor).lineLimit(2)
                }
            } else {
                HStack(spacing: 12) {
                    keycap.frame(width: 190, alignment: .leading)
                    Text(item.title).appFont(.callout, weight: .medium).foregroundStyle(palette.chromeForeground.swiftUIColor).frame(width: 220, alignment: .leading)
                    Text(item.summary).appFont(.caption).foregroundStyle(palette.secondaryForeground.swiftUIColor)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(background, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { inside in hoveredTitle = inside ? item.title : (hoveredTitle == item.title ? nil : hoveredTitle) }
        .onTapGesture { if let command = item.command { selectedTitle = item.title; onPerform(command) } }
        .help(isRunnable ? "Click to run \(item.title) (\(item.shortcut))" : item.summary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(item.shortcut). \(item.summary)")
        .accessibilityAddTraits(isRunnable ? .isButton : [])
        .accessibilityAction { if let command = item.command { onPerform(command) } }
    }

    private func moveSelection(_ delta: Int) {
        let runnable = flatItems.filter { $0.command != nil }
        guard !runnable.isEmpty else { return }
        let current = runnable.firstIndex { $0.title == selectedTitle } ?? (delta > 0 ? -1 : runnable.count)
        let next = min(max(current + delta, 0), runnable.count - 1)
        selectedTitle = runnable[next].title
    }

    private func performSelected() {
        guard let title = selectedTitle ?? flatItems.first(where: { $0.command != nil })?.title,
              let command = flatItems.first(where: { $0.title == title })?.command else { return }
        onPerform(command)
    }
}

/// Graphical modal CheatSheet presenting all categorized keyboard shortcuts (`UI-001`, `UI-010`, `REQ-021-04`).
public struct KeyboardShortcutsCheatSheetView: View {
    public let palette: PurpleThemePalette
    public let onClose: () -> Void
    public var onPerform: ((CheatSheetCommand) -> Void)?
    public var onDock: (() -> Void)?

    public init(palette: PurpleThemePalette, onClose: @escaping () -> Void, onPerform: ((CheatSheetCommand) -> Void)? = nil, onDock: (() -> Void)? = nil) {
        self.palette = palette
        self.onClose = onClose
        self.onPerform = onPerform
        self.onDock = onDock
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Keyboard Shortcuts")
                    .appFont(.title3, weight: .semibold)
                Spacer()
                if let onDock {
                    Button { onDock() } label: {
                        Label { Text("Dock Right") } icon: { AppIconView(.sidebar, size: 12) }
                    }
                    .help("Show the shortcuts as a side panel (⌥⌘/)")
                    .accessibilityLabel("Dock shortcuts as a right side panel")
                }
                Button("Close") { onClose() }
                    .keyboardShortcut(.cancelAction)
            }
            ShortcutsCatalogList(palette: palette, compact: false) { command in onPerform?(command) }
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 460)
        .purpleModalSheetChrome(palette: palette)
    }
}

/// Right-docked, searchable shortcuts panel; clicking a row runs it on the editor without closing the panel (`REQ-021-04`).
struct ShortcutsSidePanelView: View {
    let model: SwiftEditWorkbenchModel

    var body: some View {
        let palette = model.palette
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                AppIconView(.keyboard, size: 14)
                    .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                Text("SHORTCUTS")
                    .appFont(.caption2, weight: .semibold)
                    .tracking(0.8)
                    .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                Spacer()
                Button { model.toggleShortcutsPanel(); model.isCheatSheetPresented = true } label: {
                    AppIconView(.monitor, size: 12).minimumHitTarget(20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                .help("Open as floating window (⌘/)")
                .accessibilityLabel("Open shortcuts as floating window")
                Button { model.toggleShortcutsPanel() } label: { AppIconView(.close, size: 12).minimumHitTarget(20) }
                    .buttonStyle(.plain)
                    .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                    .help("Close shortcuts panel (⌥⌘/)")
                    .accessibilityLabel("Close shortcuts panel")
            }
            ShortcutsCatalogList(palette: palette, compact: true) { command in model.performCheatSheetCommand(command) }
        }
        .padding(12)
        .background(palette.sidebarSurface.swiftUIColor)
        .overlay(alignment: .leading) { Rectangle().fill(palette.hairlineBorder.swiftUIColor).frame(width: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Keyboard shortcuts panel")
    }
}
#endif
