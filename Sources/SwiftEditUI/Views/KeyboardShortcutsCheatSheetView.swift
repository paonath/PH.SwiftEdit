import Foundation
import SwiftEditCore
import SwiftUI

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
    public static let allSections: [KeyboardShortcutSection] = [
        KeyboardShortcutSection(category: "File", items: [
            KeyboardShortcutDescriptor(title: "New Document", shortcut: "Cmd+N", summary: "Create a new untitled UTF-8 tab"),
            KeyboardShortcutDescriptor(title: "Open File", shortcut: "Cmd+O", summary: "Open an existing file into a tab"),
            KeyboardShortcutDescriptor(title: "Open Folder", shortcut: "Cmd+Shift+O", summary: "Mount a workspace folder and expand the left sidebar"),
            KeyboardShortcutDescriptor(title: "Open All Files in Folder", shortcut: "Cmd+Shift+Option+O", summary: "Open shallow non-binary text files in a folder (confirms > 50)"),
            KeyboardShortcutDescriptor(title: "Save", shortcut: "Cmd+S", summary: "Atomically save preserving UTF-8 and LF/CRLF/CR"),
            KeyboardShortcutDescriptor(title: "Save As", shortcut: "Cmd+Shift+S", summary: "Save the active document to a new path"),
            KeyboardShortcutDescriptor(title: "Close Document", shortcut: "Cmd+W", summary: "Close the active tab (prompts if unsaved)"),
            KeyboardShortcutDescriptor(title: "Quit PH.SwiftEdit", shortcut: "Cmd+Q", summary: "Quit application (prompts if any tab has unsaved edits)"),
        ]),
        KeyboardShortcutSection(category: "Edit", items: [
            KeyboardShortcutDescriptor(title: "Undo", shortcut: "Cmd+Z", summary: "Undo the previous text edit"),
            KeyboardShortcutDescriptor(title: "Redo", shortcut: "Cmd+Y", summary: "Redo the previously undone text edit"),
            KeyboardShortcutDescriptor(title: "Cut", shortcut: "Cmd+X", summary: "Cut selected text to pasteboard"),
            KeyboardShortcutDescriptor(title: "Copy", shortcut: "Cmd+C", summary: "Copy selected text to pasteboard"),
            KeyboardShortcutDescriptor(title: "Paste", shortcut: "Cmd+V", summary: "Paste plain text from pasteboard"),
            KeyboardShortcutDescriptor(title: "Select All", shortcut: "Cmd+A", summary: "Select all text in the active buffer"),
            KeyboardShortcutDescriptor(title: "Duplicate Line or Selection", shortcut: "Cmd+D", summary: "Duplicate current line or selected range"),
            KeyboardShortcutDescriptor(title: "Format Markdown", shortcut: "Cmd+Shift+F", summary: "Format Markdown document via swift-markdown AST"),
        ]),
        KeyboardShortcutSection(category: "Navigation", items: [
            KeyboardShortcutDescriptor(title: "Find in Document", shortcut: "Cmd+F", summary: "Open literal Find bar"),
            KeyboardShortcutDescriptor(title: "Find and Replace", shortcut: "Cmd+H", summary: "Open literal Find & Replace bar"),
            KeyboardShortcutDescriptor(title: "Go to Line", shortcut: "Cmd+G", summary: "Jump to a 1-based line number"),
            KeyboardShortcutDescriptor(title: "Line Start", shortcut: "Home", summary: "Move caret to start of current line"),
            KeyboardShortcutDescriptor(title: "Line End", shortcut: "End", summary: "Move caret to end of current line"),
        ]),
        KeyboardShortcutSection(category: "View", items: [
            KeyboardShortcutDescriptor(title: "Toggle Left Sidebar", shortcut: "Cmd+B", summary: "Show or collapse the Folder Navigator sidebar"),
            KeyboardShortcutDescriptor(title: "Zoom In", shortcut: "Cmd++", summary: "Increase editor font zoom (+10% up to 300%)"),
            KeyboardShortcutDescriptor(title: "Zoom Out", shortcut: "Cmd+-", summary: "Decrease editor font zoom (-10% down to 50%)"),
            KeyboardShortcutDescriptor(title: "Reset Zoom", shortcut: "Cmd+0", summary: "Reset editor font zoom to 100%"),
            KeyboardShortcutDescriptor(title: "Keyboard Shortcuts CheatSheet", shortcut: "Cmd+/", summary: "Open graphical keyboard shortcuts reference"),
        ]),
        KeyboardShortcutSection(category: "Sidebar", items: [
            KeyboardShortcutDescriptor(title: "Parent Folder", shortcut: "...", summary: "Ascend to parent directory when user permissions allow"),
            KeyboardShortcutDescriptor(title: "Pin / Collapse Sidebar", shortcut: "Pin / Cmd+B", summary: "Collapse or pin the percentage-resized left navigation panel"),
            KeyboardShortcutDescriptor(title: "Sidebar Context Actions", shortcut: "Right-Click", summary: "New File/Folder prompt (rows & empty space), Reveal/Open in Finder, Open Terminal/iTerm2, Cut/Copy/Paste/Rename/Trash"),
            KeyboardShortcutDescriptor(title: "Reorder Tabs", shortcut: "Drag / Context", summary: "Drag tabs left or right or use tab Move Left / Move Right actions"),
        ]),
    ]
}

#if os(macOS)
/// Graphical modal CheatSheet presenting all categorized keyboard shortcuts (`UI-001`, `UI-010`).
public struct KeyboardShortcutsCheatSheetView: View {
    public let palette: PurpleThemePalette
    public let onClose: () -> Void

    public init(palette: PurpleThemePalette, onClose: @escaping () -> Void) {
        self.palette = palette
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Keyboard Shortcuts CheatSheet")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Close") { onClose() }
                    .keyboardShortcut(.cancelAction)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(KeyboardShortcutsCheatSheetCatalog.allSections, id: \.category) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.category)
                                .font(.headline)
                                .foregroundStyle(Color(.sRGB, red: palette.featherHighlight.red, green: palette.featherHighlight.green, blue: palette.featherHighlight.blue, opacity: 1.0))
                            ForEach(section.items, id: \.title) { item in
                                HStack(spacing: 12) {
                                    Text(item.shortcut)
                                        .font(.callout.monospaced().weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color(.sRGB, red: palette.primaryAccent.red, green: palette.primaryAccent.green, blue: palette.primaryAccent.blue, opacity: 0.25))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .frame(width: 175, alignment: .leading)
                                    Text(item.title)
                                        .font(.callout.weight(.medium))
                                        .frame(width: 210, alignment: .leading)
                                    Text(item.summary)
                                        .font(.caption)
                                        .opacity(0.85)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 460)
        .background(Color(.sRGB, red: palette.brandGround.red, green: palette.brandGround.green, blue: palette.brandGround.blue, opacity: 1.0))
        .foregroundStyle(Color(.sRGB, red: palette.chromeForeground.red, green: palette.chromeForeground.green, blue: palette.chromeForeground.blue, opacity: 1.0))
    }
}
#endif
