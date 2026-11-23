import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit

private struct FocusedWorkbenchModelKey: FocusedValueKey {
    typealias Value = SwiftEditWorkbenchModel
}

public extension FocusedValues {
    var workbenchModel: SwiftEditWorkbenchModel? {
        get { self[FocusedWorkbenchModelKey.self] }
        set { self[FocusedWorkbenchModelKey.self] = newValue }
    }
}

/// Single source of every global keyboard shortcut, routed to the focused `SwiftEditWorkbenchModel` (`File`, `Edit`, `View`, `Help`, `About`) (`UI-009`, `UI-010`, `SEC-004`).
///
/// - `Cmd+P` replaces the system Print item with the in-memory Markdown preview toggle, so no print-spooler IPC is reachable from the sandbox (`SEC-004`).
/// - Mutating items (`Save`, `Save As…`, `Duplicate`, `Format Document`, `Format Section`) are disabled from `safetyBanner.canSave` / `canFormat`, mirroring `HeaderCommandCatalog` for binary read-only quarantine (`DATA-003`, `UI-008`).
/// - Header views declare no `.keyboardShortcut` modifiers, preventing double bindings.
public struct SwiftEditCommands: Commands {
    @FocusedValue(\.workbenchModel) private var model

    public init() {}

    public var body: some Commands {
        appInfoCommands
        newItemCommands
        saveItemCommands
        pasteboardAfterCommands
        sidebarAfterCommands
        printItemCommands
        navigateMenu
        markdownMenu
        helpCommands
    }

    @CommandsBuilder
    private var appInfoCommands: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About SwiftEdit") {
                model?.isAboutSheetPresented = true
            }
            .disabled(model == nil)
            Button("Check for Updates…") {
                model?.checkForUpdates()
            }
            .disabled(model == nil)
        }
    }

    @CommandsBuilder
    private var newItemCommands: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Document") { model?.newUntitledTab() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(model == nil)
            Button("Open File…") { model?.openFileViaPanel() }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(model == nil)
            Button("Open Folder…") { model?.openFolderViaPanel() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(model == nil)
            Button("Open All Files in Folder…") { model?.openAllFilesInFolderViaPanel() }
                .keyboardShortcut("o", modifiers: [.command, .shift, .option])
                .disabled(model == nil)
            Menu("Open Recent") {
                if let entries = model?.recentFiles, !entries.isEmpty {
                    ForEach(entries, id: \.standardizedPath) { entry in
                        Button(entry.displayName) {
                            model?.openRecentFile(entry)
                        }
                    }
                    Divider()
                    Button("Clear Recent") {
                        model?.clearRecentFiles()
                    }
                } else {
                    Text("No Recent Files")
                }
            }
        }
    }

    @CommandsBuilder
    private var saveItemCommands: some Commands {
        CommandGroup(replacing: .saveItem) {
            Button("Save") { model?.saveActiveDocument() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(model?.safetyBanner.canSave != true)
            Button("Save As…") { model?.saveActiveDocumentAsViaPanel() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(model?.safetyBanner.canSave != true)
            Divider()
            Button("Close Document") { model?.requestCloseActiveTab() }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(model == nil)
        }
    }

    @CommandsBuilder
    private var pasteboardAfterCommands: some Commands {
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Duplicate Line or Selection") { model?.performCommandD() }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(model?.safetyBanner.canSave != true)
            Button("Format Markdown Document") { model?.formatActiveDocument() }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(model?.safetyBanner.canFormat != true)
            Button("Format Markdown Section") { model?.formatActiveSection() }
                .keyboardShortcut("f", modifiers: [.command, .shift, .option])
                .disabled(model?.safetyBanner.canFormat != true)
            Divider()
            Button("Find…") { model?.presentFindBar(mode: .find) }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(model == nil)
            Button("Find and Replace…") { model?.presentFindBar(mode: .findAndReplace) }
                .keyboardShortcut("f", modifiers: [.command, .option])
                .disabled(model == nil)
            Button("Go to Line…") { model?.presentFindBar(mode: .goToLine) }
                .keyboardShortcut("g", modifiers: .command)
                .disabled(model == nil)
            Divider()
            Button("Contextual Actions…") { model?.presentElementContextualMenu() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model?.canPresentElementContextualMenu != true)
        }
    }

    @CommandsBuilder
    private var sidebarAfterCommands: some Commands {
        CommandGroup(after: .sidebar) {
            Button("Toggle Folder Navigator") { model?.toggleLeftSidebar() }
                .keyboardShortcut("b", modifiers: .command)
                .disabled(model == nil)
            Divider()
            Button("Zoom In") { model?.zoomController.zoomIn() }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(model == nil)
            Button("Zoom Out") { model?.zoomController.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(model == nil)
            Button("Actual Size (100%)") { model?.zoomController.resetZoom() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(model == nil)
            Divider()
            // Live log tail of the active file (`REQ-LOG`): runs in the background, the file stays writable.
            Button("Log Tail (Direct)") { model?.startLogTail(mode: .direct) }
                .keyboardShortcut("l", modifiers: .command)
                .disabled(model == nil)
            Button("Log Tail (Inverse, Newest First)") { model?.startLogTail(mode: .inverse) }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(model == nil)
            Button("Stop Log Tail") { model?.stopLogTail() }
                .disabled(model?.activeLogTail?.isRunning != true)
            Divider()
            Button(model?.isWordWrapEnabled == false ? "Enable Word Wrap" : "Disable Word Wrap") {
                model?.toggleWordWrap()
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(model == nil)
            Button(model?.showDiffPane == true ? "Hide File Compare" : "Show File Compare") { model?.toggleDiffPane() }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(model == nil)
            Divider()
            Button("Toggle Terminal Panel") { model?.toggleTerminalPanel() }
                .keyboardShortcut("j", modifiers: .command)
                .disabled(model == nil)
        }
    }

    @CommandsBuilder
    private var printItemCommands: some Commands {
        // Replaces the system Print item so Cmd+P toggles the in-memory Markdown preview and never reaches the print spooler (SEC-004).
        CommandGroup(replacing: .printItem) {
            Button(model?.showMarkdownPreview == true ? "Hide Markdown Preview" : "Show Markdown Preview") {
                model?.toggleMarkdownPreview()
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(model == nil)
        }
    }

    @CommandsBuilder
    private var navigateMenu: some Commands {
        CommandMenu("Navigate") {
            Button("Document Navigator") { model?.toggleDocumentNavigator() }
                .keyboardShortcut("\\", modifiers: .option)
                .disabled(model?.isNavigatorEnabled != true && model?.navigatorState == nil)
            Button(model?.isDistractionFree == true ? "Exit Distraction-Free" : "Distraction-Free") { model?.toggleDistractionFree() }
                .keyboardShortcut("1", modifiers: .option)
                .disabled(model == nil)
        }
    }

    @CommandsBuilder
    private var markdownMenu: some Commands {
        CommandMenu("Markdown") {
          Group {
            Group {
                Button("Bold") { model?.applyMarkdownCommand(.bold) }.keyboardShortcut("b", modifiers: [.command, .shift])
                Button("Italic") { model?.applyMarkdownCommand(.italic) }.keyboardShortcut("i", modifiers: .command)
                Button("Strikethrough") { model?.applyMarkdownCommand(.strikethrough) }.keyboardShortcut("x", modifiers: [.command, .shift])
                Button("Inline Code") { model?.applyMarkdownCommand(.inlineCode) }.keyboardShortcut("e", modifiers: .command)
                Button("Code Fence") { model?.applyMarkdownCommand(.codeFence) }.keyboardShortcut("c", modifiers: [.command, .shift])
                Divider()
                Button("Insert Link") { model?.applyMarkdownCommand(.link) }.keyboardShortcut("k", modifiers: .command)
                Button("Insert Image") { model?.applyMarkdownCommand(.image) }.keyboardShortcut("i", modifiers: [.command, .shift])
                Button("Toggle Task Checkbox") { model?.applyMarkdownCommand(.taskToggle) }.keyboardShortcut("l", modifiers: [.command, .option])
                Button("Blockquote") { model?.applyMarkdownCommand(.blockquote) }.keyboardShortcut(".", modifiers: [.command, .shift])
                Button("Insert Table") { model?.applyMarkdownCommand(.insertTable) }.keyboardShortcut("t", modifiers: [.command, .option])
                Divider()
                Button("Toggle Markdown Diagnostics") { model?.toggleDiagnosticsPopover() }.keyboardShortcut("m", modifiers: [.command, .shift])
                Button("Fix All Markdown Issues") { model?.applyFixAll() }
            }
            Divider()
            Menu("Heading") {
                ForEach(1...6, id: \.self) { level in
                    Button("Heading \(level)") { model?.applyMarkdownCommand(.heading(level: level)) }
                        .keyboardShortcut(KeyEquivalent(Character(String(level))), modifiers: [.command, .control])
                }
            }
          }
          .disabled(model?.isMarkdownMenuEnabled != true)
        }
    }

    @CommandsBuilder
    private var helpCommands: some Commands {
        CommandGroup(replacing: .help) {
            Button("SwiftEdit Help") {
                model?.isHelpSheetPresented = true
            }
            .keyboardShortcut("?", modifiers: [.command, .shift])
            .disabled(model == nil)
            Button("Keyboard Shortcuts CheatSheet") {
                model?.isCheatSheetPresented = true
            }
            .keyboardShortcut("/", modifiers: .command)
            .disabled(model == nil)
            Button(model?.isShortcutsPanelVisible == true ? "Hide Keyboard Shortcuts Panel" : "Show Keyboard Shortcuts Panel") {
                model?.toggleShortcutsPanel()
            }
            .keyboardShortcut("/", modifiers: [.command, .option])
            .disabled(model == nil)
            Divider()
            Button("About SwiftEdit") {
                model?.isAboutSheetPresented = true
            }
            .disabled(model == nil)
        }
    }
}
#endif
