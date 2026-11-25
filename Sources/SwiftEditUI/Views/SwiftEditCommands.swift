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
            Self.appInfoContent(model: model)
        }
    }

    @CommandsBuilder
    private var newItemCommands: some Commands {
        CommandGroup(replacing: .newItem) {
            Self.newItemContent(model: model)
        }
    }

    @CommandsBuilder
    private var saveItemCommands: some Commands {
        CommandGroup(replacing: .saveItem) {
            Self.saveItemContent(model: model)
        }
    }

    @CommandsBuilder
    private var pasteboardAfterCommands: some Commands {
        CommandGroup(after: .pasteboard) {
            Self.pasteboardAfterContent(model: model)
        }
    }

    @CommandsBuilder
    private var sidebarAfterCommands: some Commands {
        CommandGroup(after: .sidebar) {
            Self.sidebarAfterContent(model: model)
        }
    }

    @CommandsBuilder
    private var printItemCommands: some Commands {
        // Replaces the system Print item so Cmd+P toggles the in-memory Markdown preview and never reaches the print spooler (SEC-004).
        CommandGroup(replacing: .printItem) {
            Self.printItemContent(model: model)
        }
    }

    @CommandsBuilder
    private var navigateMenu: some Commands {
        CommandMenu("Navigate") {
            Self.navigateMenuContent(model: model)
        }
    }

    @CommandsBuilder
    private var markdownMenu: some Commands {
        CommandMenu("Markdown") {
            Self.markdownMenuContent(model: model)
        }
    }

    @CommandsBuilder
    private var helpCommands: some Commands {
        CommandGroup(replacing: .help) {
            Self.helpCommandsContent(model: model)
        }
    }
}

extension SwiftEditCommands {
    @ViewBuilder
    static func appInfoContent(model: SwiftEditWorkbenchModel?) -> some View {
        Button("About SwiftEdit") {
            model?.isAboutSheetPresented = true
        }
        .disabled(model == nil)
        Button("Check for Updates…") {
            model?.checkForUpdates()
        }
        .disabled(model == nil)
    }

    @ViewBuilder
    static func newItemContent(model: SwiftEditWorkbenchModel?) -> some View {
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
        Button("Quick Open…") { model?.toggleQuickOpen() }
            .keyboardShortcut("t", modifiers: .command)
            .disabled(model?.grantedScopeRootURL == nil && model?.selectedFolderURL == nil)
        Menu("Open Recent") {
            if let entries = model?.recentFiles, entries.isEmpty == false {
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

    @ViewBuilder
    static func saveItemContent(model: SwiftEditWorkbenchModel?) -> some View {
        Button("Save") { model?.saveActiveDocument() }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(model?.safetyBanner.canSave != true)
        Button("Save As…") { model?.saveActiveDocumentAsViaPanel() }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(model?.safetyBanner.canSave != true)
        Button("Revert to Saved") { model?.revertActiveDocumentToSaved() }
            .disabled(model?.activeDocumentSession?.fileURL == nil || model?.activeDocumentSession?.isDirty != true)
        Divider()
        Button("Close Document") { model?.requestCloseActiveTab() }
            .keyboardShortcut("w", modifiers: [.command, .shift])
            .disabled(model == nil)
        Button("Reopen Closed Tab") { _ = model?.reopenLastClosedTab() }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .disabled(model?.bulkCloseAndHistoryController.closedFileURLs.isEmpty != false)
    }

    @ViewBuilder
    static func pasteboardAfterContent(model: SwiftEditWorkbenchModel?) -> some View {
        Divider()
        Button("Duplicate Line or Selection") { model?.performCommandD() }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(model?.safetyBanner.canSave != true)
        Menu("Lines") {
            Button("Move Line Up") { model?.moveActiveLinesUp() }
                .keyboardShortcut(.upArrow, modifiers: .option)
            Button("Move Line Down") { model?.moveActiveLinesDown() }
                .keyboardShortcut(.downArrow, modifiers: .option)
            Button("Delete Line") { model?.deleteActiveLines() }
                .keyboardShortcut("k", modifiers: [.control, .shift])
            Button("Join Lines") { model?.joinActiveLines() }
                .keyboardShortcut("j", modifiers: .control)
            Divider()
            Button("Sort Lines Ascending") { model?.sortActiveLines(ascending: true) }
            Button("Sort Lines Descending") { model?.sortActiveLines(ascending: false) }
            Button("Trim Trailing Whitespace") { model?.trimActiveDocumentTrailingWhitespace() }
        }
        .disabled(model?.safetyBanner.canSave != true)
        Button(model?.activeDocumentLanguage == .json ? "Format JSON Document" : "Format Markdown Document") { model?.formatActiveDocument() }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(model?.safetyBanner.canFormat != true)
        if model?.activeDocumentLanguage == .json {
            Button("Minify JSON Document") { model?.minifyActiveJSONDocument() }
                .disabled(model?.safetyBanner.canFormat != true)
        }
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
        Button("Use Selection for Find") { model?.useSelectionForFind() }
            .keyboardShortcut("e", modifiers: [.command, .option])
            .disabled(model?.currentSelection.length == 0)
        Button("Find in Folder…") { model?.toggleFindInFolder() }
            .keyboardShortcut("f", modifiers: [.control, .shift])
            .disabled(model?.grantedScopeRootURL == nil && model?.selectedFolderURL == nil)
        Button("Go to Line…") { model?.presentFindBar(mode: .goToLine) }
            .keyboardShortcut("g", modifiers: .command)
            .disabled(model == nil)
        Divider()
        Button("Contextual Actions…") { model?.presentElementContextualMenu() }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(model?.canPresentElementContextualMenu != true)
    }

    @ViewBuilder
    static func sidebarAfterContent(model: SwiftEditWorkbenchModel?) -> some View {
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

    @ViewBuilder
    static func printItemContent(model: SwiftEditWorkbenchModel?) -> some View {
        Button(model?.showMarkdownPreview == true ? "Hide Markdown Preview" : "Show Markdown Preview") {
            model?.toggleMarkdownPreview()
        }
        .keyboardShortcut("p", modifiers: .command)
        .disabled(model == nil)
    }

    @ViewBuilder
    static func navigateMenuContent(model: SwiftEditWorkbenchModel?) -> some View {
        Button("Document Navigator") { model?.toggleDocumentNavigator() }
            .keyboardShortcut("\\", modifiers: .option)
            .disabled(model?.isNavigatorEnabled != true && model?.navigatorState == nil)
        Button(model?.isDistractionFree == true ? "Exit Distraction-Free" : "Distraction-Free") { model?.toggleDistractionFree() }
            .keyboardShortcut("1", modifiers: .option)
            .disabled(model == nil)
        Divider()
        Button("Next Tab") { model?.selectNextTab() }
            .keyboardShortcut("]", modifiers: [.command, .shift])
            .disabled(model?.tabSession.tabs.isEmpty != false)
        Button("Previous Tab") { model?.selectPreviousTab() }
            .keyboardShortcut("[", modifiers: [.command, .shift])
            .disabled(model?.tabSession.tabs.isEmpty != false)
        Divider()
        Button("Next Difference") { model?.selectNextDiffHunk() }
            .keyboardShortcut(KeyEquivalent(Character(UnicodeScalar(NSF7FunctionKey)!)), modifiers: [])
            .disabled(model?.showDiffPane != true || model?.diffCoordinator.hunkRowIndices.isEmpty != false)
        Button("Previous Difference") { model?.selectPreviousDiffHunk() }
            .keyboardShortcut(KeyEquivalent(Character(UnicodeScalar(NSF7FunctionKey)!)), modifiers: [.shift])
            .disabled(model?.showDiffPane != true || model?.diffCoordinator.hunkRowIndices.isEmpty != false)
    }

    @ViewBuilder
    static func markdownMenuContent(model: SwiftEditWorkbenchModel?) -> some View {
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

    @ViewBuilder
    static func helpCommandsContent(model: SwiftEditWorkbenchModel?) -> some View {
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

    @ViewBuilder
    static func combinedMenuPreview(model: SwiftEditWorkbenchModel?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            appInfoContent(model: model)
            newItemContent(model: model)
            saveItemContent(model: model)
            pasteboardAfterContent(model: model)
            sidebarAfterContent(model: model)
            printItemContent(model: model)
            navigateMenuContent(model: model)
            markdownMenuContent(model: model)
            helpCommandsContent(model: model)
        }
    }
}
#endif
