import Foundation
import SwiftEditCore
import SwiftUI

/// Action a CheatSheet row performs when clicked (`REQ-021-04`); `nil` rows (Tab completion, sidebar gestures) are
/// documentation only.
public enum CheatSheetCommand: String, CaseIterable, Sendable {
    case newDocument, openFile, openFolder, openAllFiles, save, saveAs, closeDocument, quit
    case undo, redo, cut, copy, paste, selectAll, duplicate, contextualActions
    case formatDocument, formatSection, bold, italic, inlineCode, insertLink, toggleTask
    case find, findAndReplace, goToLine, lineStart, lineEnd
    case toggleSidebar, zoomIn, zoomOut, resetZoom, toggleWordWrap, togglePreview, toggleCompare
    case toggleDiagnostics, documentNavigator, distractionFree, logTailDirect, logTailInverse, toggleTerminal
    case showCheatSheet, toggleShortcutsPanel

    /// Commands that act on the editor text view (first responder actions) rather than on the workbench model.
    public var isTextViewAction: Bool {
        switch self {
        case .undo, .redo, .cut, .copy, .paste, .selectAll, .lineStart, .lineEnd: return true
        default: return false
        }
    }
}

/// Single keyboard shortcut or interactive workspace action documented in the graphical CheatSheet (`UI-009`, `UI-010`).
public struct KeyboardShortcutDescriptor: Equatable, Sendable {
    public let title: String
    public let shortcut: String
    public let summary: String

    public init(title: String, shortcut: String, summary: String) {
        self.title = title
        self.shortcut = shortcut
        self.summary = summary
    }

    /// Executable action for this row (`nil` = documentation only).
    public var command: CheatSheetCommand? { KeyboardShortcutsCheatSheetCatalog.commandsByTitle[title] }

    /// Case-insensitive match on title, summary or shortcut; `⌘⇧⌥⌃` symbols and `Cmd/Shift/Option/Ctrl` words are
    /// interchangeable so "⇧⌘D", "cmd+shift+d" and "shift cmd d" all match (`REQ-021-04`).
    public func matches(_ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return true }
        if title.localizedCaseInsensitiveContains(needle) || summary.localizedCaseInsensitiveContains(needle) {
            return true
        }
        let keys = Self.normalizedKeys(shortcut)
        let wanted = Self.normalizedKeys(needle)
        return !wanted.isEmpty && wanted.isSubset(of: keys)
    }

    static func normalizedKeys(_ text: String) -> Set<String> {
        var expanded = text.lowercased()
        for (symbol, word) in [("⌘", " cmd "), ("⇧", " shift "), ("⌥", " option "), ("⌃", " ctrl "), ("↩", " return ")] {
            expanded = expanded.replacingOccurrences(of: symbol, with: word)
        }
        let aliases = ["command": "cmd", "opt": "option", "alt": "option", "control": "ctrl", "enter": "return"]
        let tokens = expanded.split(whereSeparator: { $0 == "+" || $0 == " " }).map(String.init).filter { !$0.isEmpty }
        return Set(tokens.map { aliases[$0] ?? $0 })
    }
}

/// Categorized group of shortcuts rendered inside `KeyboardShortcutsCheatSheetView` (`UI-010`).
public struct KeyboardShortcutSection: Equatable, Sendable {
    public let category: String
    public let items: [KeyboardShortcutDescriptor]

    public init(category: String, items: [KeyboardShortcutDescriptor]) {
        self.category = category
        self.items = items
    }
}

/// Authoritative catalog of all `PH.SwiftEdit` keyboard shortcuts and sidebar actions (`File`, `Edit`, `Navigation`, `View`, `Sidebar`) (`UI-009`, `UI-010`).
public enum KeyboardShortcutsCheatSheetCatalog {
    /// Row title -> executable command (`REQ-021-04`).
    public static let commandsByTitle: [String: CheatSheetCommand] = [
        "New Document": .newDocument, "Open File": .openFile, "Open Folder": .openFolder,
        "Open All Files in Folder": .openAllFiles, "Save": .save, "Save As": .saveAs,
        "Close Document": .closeDocument, "Quit SwiftEdit": .quit,
        "Undo": .undo, "Redo": .redo, "Cut": .cut, "Copy": .copy, "Paste": .paste, "Select All": .selectAll,
        "Duplicate Line or Selection": .duplicate, "Contextual Actions": .contextualActions,
        "Format Markdown Document": .formatDocument, "Format Markdown Section": .formatSection,
        "Bold": .bold, "Italic": .italic, "Inline Code": .inlineCode, "Insert Link": .insertLink,
        "Toggle Task Checkbox": .toggleTask,
        "Find in Document": .find, "Find and Replace": .findAndReplace, "Go to Line": .goToLine,
        "Line Start": .lineStart, "Line End": .lineEnd,
        "Toggle Left Sidebar": .toggleSidebar, "Zoom In": .zoomIn, "Zoom Out": .zoomOut, "Reset Zoom": .resetZoom,
        "Toggle Word Wrap": .toggleWordWrap, "Toggle Markdown Preview": .togglePreview,
        "Toggle File Compare Diff": .toggleCompare, "Toggle Markdown Diagnostics": .toggleDiagnostics,
        "Document Navigator": .documentNavigator, "Distraction-Free": .distractionFree,
        "Log Tail (Direct)": .logTailDirect, "Log Tail (Inverse)": .logTailInverse, "Terminal Panel": .toggleTerminal,
        "Keyboard Shortcuts CheatSheet": .showCheatSheet, "Keyboard Shortcuts Side Panel": .toggleShortcutsPanel,
    ]

    /// Sections whose rows match `query` (empty sections are dropped; empty query returns everything).
    public static func sections(matching query: String) -> [KeyboardShortcutSection] {
        allSections.compactMap { section in
            let items = section.items.filter { $0.matches(query) }
            return items.isEmpty ? nil : KeyboardShortcutSection(category: section.category, items: items)
        }
    }

    public static let allSections: [KeyboardShortcutSection] = [
        KeyboardShortcutSection(category: "File", items: [
            KeyboardShortcutDescriptor(title: "New Document", shortcut: "Cmd+N", summary: "Create a new untitled UTF-8 tab"),
            KeyboardShortcutDescriptor(title: "Open File", shortcut: "Cmd+O", summary: "Open an existing file into a tab"),
            KeyboardShortcutDescriptor(title: "Open Folder", shortcut: "Cmd+Shift+O", summary: "Mount a workspace folder and expand the left sidebar"),
            KeyboardShortcutDescriptor(title: "Open All Files in Folder", shortcut: "Cmd+Shift+Option+O", summary: "Open shallow non-binary text files in a folder (confirms > 50)"),
            KeyboardShortcutDescriptor(title: "Save", shortcut: "Cmd+S", summary: "Atomically save preserving UTF-8 and LF/CRLF/CR"),
            KeyboardShortcutDescriptor(title: "Save As", shortcut: "Cmd+Shift+S", summary: "Save the active document to a new path"),
            KeyboardShortcutDescriptor(title: "Close Document", shortcut: "Shift+Cmd+W", summary: "Close the active tab (prompts if unsaved)"),
            KeyboardShortcutDescriptor(title: "Quit SwiftEdit", shortcut: "Cmd+Q", summary: "Quit application (prompts if any tab has unsaved edits)"),
        ]),
        KeyboardShortcutSection(category: "Edit", items: [
            KeyboardShortcutDescriptor(title: "Undo", shortcut: "Cmd+Z", summary: "Undo the previous text edit"),
            KeyboardShortcutDescriptor(title: "Redo", shortcut: "Shift+Cmd+Z", summary: "Redo the previously undone text edit"),
            KeyboardShortcutDescriptor(title: "Cut", shortcut: "Cmd+X", summary: "Cut selected text to pasteboard"),
            KeyboardShortcutDescriptor(title: "Copy", shortcut: "Cmd+C", summary: "Copy selected text to pasteboard"),
            KeyboardShortcutDescriptor(title: "Paste", shortcut: "Cmd+V", summary: "Paste plain text from pasteboard"),
            KeyboardShortcutDescriptor(title: "Select All", shortcut: "Cmd+A", summary: "Select all text in the active buffer"),
            KeyboardShortcutDescriptor(title: "Duplicate Line or Selection", shortcut: "Cmd+D", summary: "Duplicate current line or selected range"),
            KeyboardShortcutDescriptor(title: "Accept Word Completion", shortcut: "Tab", summary: "Accept the grey inline suggestion built from words already in the document (Esc dismisses)"),
            KeyboardShortcutDescriptor(title: "Contextual Actions", shortcut: "Cmd+Return", summary: "Open the action palette: Surround With (selection) and Duplicate Document (always)"),
            KeyboardShortcutDescriptor(title: "Format Markdown Document", shortcut: "Cmd+Shift+F", summary: "Format Markdown document via swift-markdown AST"),
            KeyboardShortcutDescriptor(title: "Format Markdown Section", shortcut: "Cmd+Option+Shift+F", summary: "Format only the selected Markdown lines"),
            KeyboardShortcutDescriptor(title: "Bold", shortcut: "Shift+Cmd+B", summary: "Toggle bold Markdown emphasis"),
            KeyboardShortcutDescriptor(title: "Italic", shortcut: "Cmd+I", summary: "Toggle italic Markdown emphasis"),
            KeyboardShortcutDescriptor(title: "Inline Code", shortcut: "Cmd+E", summary: "Toggle inline code span"),
            KeyboardShortcutDescriptor(title: "Insert Link", shortcut: "Cmd+K", summary: "Wrap selection as a Markdown link"),
            KeyboardShortcutDescriptor(title: "Toggle Task Checkbox", shortcut: "Option+Cmd+L", summary: "Toggle a Markdown task item between [ ] and [x]"),
            KeyboardShortcutDescriptor(title: "Markdown Heading (1-6)", shortcut: "Ctrl+Cmd+1..6", summary: "Apply ATX heading level 1 through 6"),
        ]),
        KeyboardShortcutSection(category: "Navigation", items: [
            KeyboardShortcutDescriptor(title: "Find in Document", shortcut: "Cmd+F", summary: "Open literal Find bar"),
            KeyboardShortcutDescriptor(title: "Find and Replace", shortcut: "Opt+Cmd+F", summary: "Open literal Find & Replace bar (keeps Cmd+H as macOS Hide)"),
            KeyboardShortcutDescriptor(title: "Go to Line", shortcut: "Cmd+G", summary: "Jump to a 1-based line number"),
            KeyboardShortcutDescriptor(title: "Line Start", shortcut: "Home", summary: "Move caret to start of current line"),
            KeyboardShortcutDescriptor(title: "Line End", shortcut: "End", summary: "Move caret to end of current line"),
        ]),
        KeyboardShortcutSection(category: "View", items: [
            KeyboardShortcutDescriptor(title: "Toggle Left Sidebar", shortcut: "Cmd+B", summary: "Show or collapse the Folder Navigator sidebar"),
            KeyboardShortcutDescriptor(title: "Zoom In", shortcut: "Cmd++", summary: "Increase editor font zoom (+10% up to 300%)"),
            KeyboardShortcutDescriptor(title: "Zoom Out", shortcut: "Cmd+-", summary: "Decrease editor font zoom (-10% down to 50%)"),
            KeyboardShortcutDescriptor(title: "Reset Zoom", shortcut: "Cmd+0", summary: "Reset editor font zoom to 100%"),
            KeyboardShortcutDescriptor(title: "Toggle Word Wrap", shortcut: "Cmd+W", summary: "Wrap long lines to the window width or scroll horizontally"),
            KeyboardShortcutDescriptor(title: "Toggle Markdown Preview", shortcut: "Cmd+P", summary: "Show or hide the native Markdown preview (off by default)"),
            KeyboardShortcutDescriptor(title: "Toggle File Compare Diff", shortcut: "Shift+Cmd+D", summary: "Toggle side-by-side Myers diff against saved baseline"),
            KeyboardShortcutDescriptor(title: "Toggle Markdown Diagnostics", shortcut: "Shift+Cmd+M", summary: "Open the Markdown lint diagnostics popover with Jump-to-Range and Fix All"),
            KeyboardShortcutDescriptor(title: "Document Navigator", shortcut: "Option+\\", summary: "Heading/key palette for the current Markdown or YAML tab (Esc or Option+\\ closes)"),
            KeyboardShortcutDescriptor(title: "Distraction-Free", shortcut: "Option+1", summary: "Full-screen editor only; Esc or Option+1 restores the layout"),
            KeyboardShortcutDescriptor(title: "Log Tail (Direct)", shortcut: "Cmd+L", summary: "Live tail of the last lines of the active file, newest at the bottom"),
            KeyboardShortcutDescriptor(title: "Log Tail (Inverse)", shortcut: "Shift+Cmd+L", summary: "Live tail with the newest line at the top"),
            KeyboardShortcutDescriptor(title: "Terminal Panel", shortcut: "Cmd+J", summary: "Show or hide the bottom panel; each session opens your default terminal in the current folder"),
            KeyboardShortcutDescriptor(title: "Keyboard Shortcuts CheatSheet", shortcut: "Cmd+/", summary: "Open graphical keyboard shortcuts reference"),
            KeyboardShortcutDescriptor(title: "Keyboard Shortcuts Side Panel", shortcut: "Option+Cmd+/", summary: "Dock the searchable, clickable shortcuts list on the right"),
        ]),
        KeyboardShortcutSection(category: "Sidebar", items: [
            KeyboardShortcutDescriptor(title: "Parent Folder", shortcut: "...", summary: "Ascend to parent directory when user permissions allow"),
            KeyboardShortcutDescriptor(title: "Open Sidebar Folder", shortcut: "Double-Click", summary: "Single-click selects a folder; double-click opens it (Finder-style)"),
            KeyboardShortcutDescriptor(title: "Pin / Collapse Sidebar", shortcut: "Pin / Cmd+B", summary: "Collapse or pin the percentage-resized left navigation panel"),
            KeyboardShortcutDescriptor(title: "Sidebar Context Actions", shortcut: "Right-Click", summary: "New File/Folder prompt (rows & empty space), Reveal/Open in Finder, Open Terminal/iTerm2, Copy Path to Clipboard, Cut/Copy/Paste/Rename/Trash"),
            KeyboardShortcutDescriptor(title: "Reorder Tabs", shortcut: "Drag / Context", summary: "Drag tabs left or right or use tab Move Left / Move Right actions"),
        ]),
    ]
}

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
