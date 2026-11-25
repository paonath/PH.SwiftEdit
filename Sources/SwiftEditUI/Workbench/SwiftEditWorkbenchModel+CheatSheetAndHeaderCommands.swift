import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit

/// Table-driven cheat-sheet, contextual action execution, and header submenu commands decoupled from leaf overlay state (`REQ-008`, `REQ-009`, `AR-007`).
extension SwiftEditWorkbenchModel {

    public func performCheatSheetCommandFromSheet(_ command: CheatSheetCommand) {
        isCheatSheetPresented = false
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            self?.performCheatSheetCommand(command)
        }
    }

    private static let overlaysRetainingFocus: Set<CheatSheetCommand> = [
        .showCheatSheet, .toggleShortcutsPanel, .find, .findAndReplace,
        .goToLine, .documentNavigator, .contextualActions,
    ]

    private static let cheatSheetWorkbenchActions: [CheatSheetCommand: @MainActor (SwiftEditWorkbenchModel) -> Void] = [
        .newDocument: { $0.newUntitledTab() },
        .openFile: { $0.openFileViaPanel() },
        .openFolder: { $0.openFolderViaPanel() },
        .openAllFiles: { $0.openAllFilesInFolderViaPanel() },
        .save: { if $0.safetyBanner.canSave { $0.saveActiveDocument() } },
        .saveAs: { if $0.safetyBanner.canSave { $0.saveActiveDocumentAsViaPanel() } },
        .closeDocument: { $0.requestCloseActiveTab() },
        .quit: { _ in NSApp.terminate(nil) },
        .duplicate: { if $0.safetyBanner.canSave { $0.performCommandD() } },
        .contextualActions: { _ = $0.presentElementContextualMenu() },
        .formatDocument: { if $0.safetyBanner.canFormat { $0.formatActiveDocument() } },
        .formatSection: { if $0.safetyBanner.canFormat { $0.formatActiveSection() } },
        .bold: { $0.applyMarkdownCommand(.bold) },
        .italic: { $0.applyMarkdownCommand(.italic) },
        .inlineCode: { $0.applyMarkdownCommand(.inlineCode) },
        .insertLink: { $0.applyMarkdownCommand(.link) },
        .toggleTask: { $0.applyMarkdownCommand(.taskToggle) },
        .find: { $0.presentFindBar(mode: .find) },
        .findAndReplace: { $0.presentFindBar(mode: .findAndReplace) },
        .goToLine: { $0.presentFindBar(mode: .goToLine) },
        .toggleSidebar: { $0.toggleLeftSidebar() },
        .zoomIn: { $0.zoomController.zoomIn() },
        .zoomOut: { $0.zoomController.zoomOut() },
        .resetZoom: { $0.zoomController.resetZoom() },
        .toggleWordWrap: { $0.toggleWordWrap() },
        .togglePreview: { $0.toggleMarkdownPreview() },
        .toggleCompare: { $0.toggleDiffPane() },
        .toggleDiagnostics: { $0.toggleDiagnosticsPopover() },
        .documentNavigator: { $0.toggleDocumentNavigator() },
        .distractionFree: { $0.toggleDistractionFree() },
        .logTailDirect: { $0.startLogTail(mode: .direct) },
        .logTailInverse: { $0.startLogTail(mode: .inverse) },
        .toggleTerminal: { $0.toggleTerminalPanel() },
        .showCheatSheet: { $0.isCheatSheetPresented = true },
        .toggleShortcutsPanel: { $0.toggleShortcutsPanel() },
    ]

    /// Runs a CheatSheet row at the editor caret/selection (text actions) or on the workbench via a table-driven command map (`REQ-008`).
    public func performCheatSheetCommand(_ command: CheatSheetCommand) {
        if command.isTextViewAction {
            performEditorTextAction(command)
            return
        }
        Self.cheatSheetWorkbenchActions[command]?(self)
        if Self.overlaysRetainingFocus.contains(command) == false {
            requestEditorFocus()
        }
    }

    func performEditorTextAction(_ command: CheatSheetCommand) {
        guard let textView = Self.editableEditorTextView(in: hostWindow?.contentView) else { return }
        textView.window?.makeFirstResponder(textView)
        switch command {
        case .undo: textView.undoManager?.undo()
        case .redo: textView.undoManager?.redo()
        case .cut: textView.cut(nil)
        case .copy: textView.copy(nil)
        case .paste: textView.paste(nil)
        case .selectAll: textView.selectAll(nil)
        case .lineStart: textView.moveToBeginningOfLine(nil)
        case .lineEnd: textView.moveToEndOfLine(nil)
        default: break
        }
    }

    /// Return / click: toggles a group header or performs an action row (highlighted row when `rowID` is `nil`).
    public func activateElementContextualMenuRow(rowID: String? = nil) {
        if let rowID { elementContextualMenu?.highlight(rowID: rowID) }
        guard let row = elementContextualMenu?.highlightedRow else { return }
        switch row {
        case .group(let group, _):
            elementContextualMenu?.toggleGroup(group.id)
        case .action(let action, _):
            performElementContextualAction(action)
        }
    }

    /// Applies `action` to the captured selection as one `BufferRevision` (or runs a document/terminal action) and closes the palette.
    @discardableResult
    public func performElementContextualAction(_ action: ElementContextualAction) -> Bool {
        guard let menu = elementContextualMenu else { return false }
        elementContextualMenu = nil
        if case .sendToTerminal = action.kind {
            return requestSendSelectionToTerminal(selection: menu.selection)
        }
        defer { requestEditorFocus() }
        if case .duplicateDocument = action.kind {
            return duplicateActiveDocument()
        }
        guard activeLogTail == nil, safetyBanner.canSave,
              let activeID = tabSession.activeTabID, logTailOnlyTabIDs.contains(activeID) == false,
              var session = sessionsByID[activeID],
              let edit = ElementContextualActionCatalog.evaluate(action.kind, in: session.snapshot, selection: menu.selection) else {
            return false
        }
        do {
            _ = try session.applyTextEdits(edit.edits, expectedRevision: session.revision)
            session.reconcileDirtyState(against: savedBaselineByID[activeID])
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            syncUntitledTabTitleIfNeeded(for: activeID, session: session)
            currentSelection = edit.newSelection
            programmaticSelectionToken += 1
            scheduleRecoveryPersist()
            refreshDiagnosticsForActiveDocument()
            return true
        } catch {
            statusBannerMessage = "Contextual action failed: \(error)"
            return false
        }
    }

    public func performHeaderCommand(_ id: HeaderCommandID) {
        guard headerCommandItems.first(where: { $0.id == id })?.isEnabled == true else { return }
        headerSubmenu.dismissAfterCommand()
        switch id {
        case .newDocument: newUntitledTab()
        case .openFile: openFileViaPanel()
        case .openFolder: openFolderViaPanel()
        case .saveDocument: saveActiveDocument()
        case .saveDocumentAs: saveActiveDocumentAsViaPanel()
        case .duplicateLineOrSelection: performCommandD()
        case .formatDocument: formatActiveDocument()
        case .formatSection: formatActiveSection()
        case .toggleMarkdownPreview: toggleMarkdownPreview()
        case .showCheatSheet: isCheatSheetPresented = true
        case .appearanceLight: appearanceMode = .light
        case .appearanceDark: appearanceMode = .black
        case .appearanceAuto: appearanceMode = .auto
        }
    }

    /// Duplicates the active writable document either next to its file on disk (`name copy.ext`) or as an adjacent untitled tab (`REQ-021-05`).
    @discardableResult
    public func duplicateActiveDocument() -> Bool {
        guard activeLogTail == nil, activeBinaryInspection == nil, safetyBanner.canSave,
              let activeID = tabSession.activeTabID, logTailOnlyTabIDs.contains(activeID) == false,
              let session = sessionsByID[activeID], session.isBinaryReadOnly == false else {
            statusBannerMessage = "Duplicate Document is not available for binary or live-tail tabs."
            return false
        }
        let sourceIndex = tabSession.tabs.firstIndex { $0.id == activeID } ?? max(0, tabSession.tabs.count - 1)
        if let sourceURL = session.fileURL {
            guard duplicateBackedFileOnDisk(sourceURL: sourceURL, session: session) else { return false }
        } else {
            newUntitledTab()
            handleEditorTextChanged(session.text)
        }
        guard let newID = tabSession.activeTabID, newID != activeID else { return false }
        moveTab(id: newID, toIndex: min(sourceIndex + 1, tabSession.tabs.count - 1))
        statusBannerMessage = "Duplicated as \(tabSession.tabs.first { $0.id == newID }?.title ?? "new tab")."
        return true
    }

    private func duplicateBackedFileOnDisk(sourceURL: URL, session: DocumentSession) -> Bool {
        guard let target = DuplicateDocumentNaming.copyURL(for: sourceURL, exists: { FileManager.default.fileExists(atPath: $0.path) }) else {
            statusBannerMessage = "Duplicate failed: no free “copy” name next to \(sourceURL.lastPathComponent)."
            return false
        }
        let scope = resolveSaveScope(for: target)
        let copy = DocumentSession(text: session.text, encoding: session.encoding, lineEnding: session.lineEnding)
        do {
            guard FileManager.default.fileExists(atPath: target.path) == false else { throw CocoaError(.fileWriteFileExists) }
            _ = try deps.loader.save(copy, to: target, withinScope: scope)
        } catch {
            statusBannerMessage = "Duplicate failed: \(error)"
            return false
        }
        openFile(at: target, withinScope: scope)
        refreshFolderEntries()
        return true
    }
}
#endif
