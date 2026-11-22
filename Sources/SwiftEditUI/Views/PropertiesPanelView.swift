import Foundation
import SwiftEditCore
import SwiftUI

/// Presentation descriptor of one Properties panel row (pure, headless-testable) (`REQ-009`, `UI-010`).
struct PropertiesPanelRow: Equatable, Identifiable {
    let key: String
    /// Value shown in the row: the scalar text, comma-joined list items, or a placeholder for read-only constructs.
    let displayValue: String
    let isEditable: Bool
    /// VoiceOver label naming the key and either its value or why it is read-only.
    let accessibilityLabel: String
    let isList: Bool
    var id: String { key }

    init(property: FrontmatterProperty, modelIsReadOnly: Bool) {
        key = property.key
        isEditable = property.isEditable && !modelIsReadOnly
        switch property.kind {
        case .scalar(let value):
            displayValue = value
            isList = false
            accessibilityLabel = "\(property.key), value \(value)"
        case .list(let items):
            displayValue = items.joined(separator: ", ")
            isList = true
            accessibilityLabel = "\(property.key), list of \(items.count): \(items.joined(separator: ", "))"
        case .nestedMap:
            displayValue = "{…}"
            isList = false
            accessibilityLabel = "\(property.key), read-only nested mapping"
        case .blockScalar:
            displayValue = "|…"
            isList = false
            accessibilityLabel = "\(property.key), read-only multi-line text"
        case .aliased:
            displayValue = "*…"
            isList = false
            accessibilityLabel = "\(property.key), read-only anchor or alias"
        case .tagged:
            displayValue = "!…"
            isList = false
            accessibilityLabel = "\(property.key), read-only tagged value"
        }
    }

    /// Converts edited field text back into a writer value (lists are comma-separated, items trimmed).
    func editValue(from text: String) -> FrontmatterEditValue {
        guard isList else { return .scalar(text) }
        let items = text.split(separator: ",", omittingEmptySubsequences: true).map { $0.trimmingCharacters(in: .whitespaces) }
        return .list(items.filter { !$0.isEmpty })
    }
}

/// UI-only Properties panel state kept in its own `@Observable` object so panel typing never invalidates the editor (`UI-012`).
@MainActor
@Observable
public final class PropertiesPanelState {
    public var isCollapsed = false
    public init() {}
}

#if os(macOS)
/// Collapsible Obsidian-style frontmatter editor shown above the editor for writable Markdown tabs (`REQ-009`).
///
/// Keys render grey with a lighter weight and values in the full canvas color, matching the inline YAML styling. Every
/// commit goes through `SwiftEditWorkbenchModel.applyPropertyOperation`, i.e. one `TextEdit`, one `BufferRevision` and
/// one undo step. Read-only entries are shown but cannot be edited; a malformed block disables the whole panel.
struct PropertiesPanelView: View {
    let model: SwiftEditWorkbenchModel
    @Bindable var state: PropertiesPanelState
    @State private var drafts: [String: String] = [:]
    @State private var newKey = ""
    @State private var newValue = ""

    var body: some View {
        let palette = model.palette
        let propertiesModel = model.propertiesModel
        let rows = (propertiesModel?.properties ?? []).map { PropertiesPanelRow(property: $0, modelIsReadOnly: propertiesModel?.isReadOnly ?? true) }
        applyPanelChrome(to: panelContent(rows: rows, isReadOnly: propertiesModel?.isReadOnly, palette: palette), palette: palette)
    }

    private func panelContent(rows: [PropertiesPanelRow], isReadOnly: Bool?, palette: PurpleThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            headerButton(rowCount: rows.count, palette: palette)
            if !state.isCollapsed {
                if isReadOnly == true {
                    Text("Frontmatter is read-only: unterminated, malformed or unsupported YAML.")
                        .appFont(.caption)
                        .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                }
                ForEach(rows) { row in rowView(row, palette: palette) }
                if isReadOnly == false { addRow(palette: palette) }
            }
        }
    }

    private func headerButton(rowCount: Int, palette: PurpleThemePalette) -> some View {
        Button {
            state.isCollapsed.toggle()
        } label: {
            Label("Properties (\(rowCount))", systemImage: state.isCollapsed ? "chevron.right" : "chevron.down")
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(palette.secondaryForeground.swiftUIColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Properties, \(rowCount) entries")
        .accessibilityValue(state.isCollapsed ? "Collapsed" : "Expanded")
    }

    @ViewBuilder
    private func applyPanelChrome<Content: View>(to content: Content, palette: PurpleThemePalette) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(palette.editorCanvasBackground.swiftUIColor)
            .overlay(alignment: .bottom) { Rectangle().fill(palette.hairlineBorder.swiftUIColor).frame(height: 1) }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Frontmatter properties")
            .onChange(of: model.activeDocumentSession?.revision) { drafts = [:] }
    }

    private func keyText(_ key: String, palette: PurpleThemePalette) -> some View {
        Text(verbatim: key)
            .appFont(size: 12, weight: .light, monospaced: true)
            .foregroundStyle(palette.yamlKeyForeground.swiftUIColor)
            .frame(width: 140, alignment: .leading)
            .lineLimit(1)
    }

    @ViewBuilder
    private func rowView(_ row: PropertiesPanelRow, palette: PurpleThemePalette) -> some View {
        HStack(spacing: 8) {
            keyText(row.key, palette: palette)
            if row.isEditable {
                TextField(row.key, text: Binding(
                    get: { drafts[row.key] ?? row.displayValue },
                    set: { drafts[row.key] = $0 }
                ))
                .textFieldStyle(.plain)
                .appFont(size: 12, monospaced: true)
                .foregroundStyle(palette.editorCanvasText.swiftUIColor)
                .onSubmit { commit(row) }
                .onExitCommand { drafts[row.key] = nil }
                .accessibilityLabel(row.accessibilityLabel)
                Button {
                    model.applyPropertyOperation(.remove(key: row.key))
                } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.plain)
                .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                .accessibilityLabel("Remove \(row.key)")
            } else {
                Text(verbatim: row.displayValue)
                    .appFont(size: 12, monospaced: true)
                    .foregroundStyle(palette.editorCanvasText.swiftUIColor)
                Image(systemName: "lock")
                    .foregroundStyle(palette.secondaryForeground.swiftUIColor)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: row.isEditable ? .contain : .ignore)
        .accessibilityLabel(row.accessibilityLabel)
    }

    private func addRow(palette: PurpleThemePalette) -> some View {
        HStack(spacing: 8) {
            TextField("new key", text: $newKey)
                .textFieldStyle(.plain)
                .appFont(size: 12, weight: .light, monospaced: true)
                .foregroundStyle(palette.yamlKeyForeground.swiftUIColor)
                .frame(width: 140)
                .accessibilityLabel("New property key")
            TextField("value", text: $newValue)
                .textFieldStyle(.plain)
                .appFont(size: 12, monospaced: true)
                .onSubmit(addProperty)
                .accessibilityLabel("New property value")
            Button("Add", action: addProperty)
                .buttonStyle(.borderless)
                .disabled(newKey.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func commit(_ row: PropertiesPanelRow) {
        guard let text = drafts[row.key], text != row.displayValue else { return }
        model.applyPropertyOperation(.setValue(key: row.key, value: row.editValue(from: text)))
        drafts[row.key] = nil
    }

    private func addProperty() {
        let key = newKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        if case .edit = model.applyPropertyOperation(.add(key: key, value: .scalar(newValue))) {
            newKey = ""
            newValue = ""
        }
    }
}
#endif
