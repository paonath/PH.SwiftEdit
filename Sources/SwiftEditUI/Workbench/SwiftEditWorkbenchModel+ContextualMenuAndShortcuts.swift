import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit

/// Leaf overlay state, contextual `Cmd+Return` presentation, appearance cycling, and ESC dismissal for `SwiftEditWorkbenchModel` (`REQ-002`, `REQ-009`, `UI-005`).
extension SwiftEditWorkbenchModel {
    public var isCheatSheetPresented: Bool {
        get { overlayState.isCheatSheetPresented }
        set { overlayState.isCheatSheetPresented = newValue }
    }
    public var isAboutSheetPresented: Bool {
        get { overlayState.isAboutSheetPresented }
        set { overlayState.isAboutSheetPresented = newValue }
    }
    public var isHelpSheetPresented: Bool {
        get { overlayState.isHelpSheetPresented }
        set { overlayState.isHelpSheetPresented = newValue }
    }
    public var isShortcutsPanelVisible: Bool {
        get { overlayState.isShortcutsPanelVisible }
        set { overlayState.isShortcutsPanelVisible = newValue }
    }
    public var elementContextualMenu: ElementContextualMenuState? {
        get { overlayState.elementContextualMenu }
        set { overlayState.elementContextualMenu = newValue }
    }

    public func toggleShortcutsPanel() {
        isShortcutsPanelVisible.toggle()
        if !isShortcutsPanelVisible { requestEditorFocus() }
    }

    /// Iteratively locates the first editable `SwiftEditNSTextView` in `view`'s subtree in pre-order DFS order (`UI-007`, `SEC-012`).
    static func editableEditorTextView(in view: NSView?) -> SwiftEditNSTextView? {
        guard let view else { return nil }
        var worklist: [NSView] = [view]
        var visited = Set<ObjectIdentifier>()
        let maxNodes = SwiftEditNSTextView.maxTraversalVisitedNodes
        while let current = worklist.popLast(), visited.count < maxNodes {
            let id = ObjectIdentifier(current)
            guard visited.insert(id).inserted else { continue }
            if let textView = current as? SwiftEditNSTextView, textView.isEditable {
                return textView
            }
            for child in current.subviews.reversed() {
                worklist.append(child)
            }
        }
        return nil
    }

    /// `[folder, file]` for the active tab: the open workspace folder (or the file's parent) and the tab title.
    public var headerBreadcrumb: [String] {
        guard let activeID = tabSession.activeTabID,
              let tab = tabSession.tabs.first(where: { $0.id == activeID }) else { return [] }
        let folder = selectedFolderURL?.lastPathComponent ?? tab.fileURL?.deletingLastPathComponent().lastPathComponent
        return [folder, tab.title].compactMap { $0 }.filter { !$0.isEmpty && $0 != "/" }
    }

    /// Status-bar theme toggle: Light -> Dark -> Auto -> Light.
    public func cycleAppearanceMode() {
        switch appearanceMode {
        case .light: appearanceMode = .black
        case .black: appearanceMode = .auto
        case .auto: appearanceMode = .light
        }
    }

    /// `true` for a writable, non-tailing tab; selection-only groups are filtered when nothing is selected (`REQ-021-05`).
    public var canPresentElementContextualMenu: Bool {
        guard activeLogTail == nil, safetyBanner.canSave,
              let session = activeDocumentSession, !session.isBinaryReadOnly else { return false }
        return currentSelection.upperBound <= session.text.utf16.count
    }

    /// `true` when the active document is writable (not binary read-only, not live log-tail) and eligible for native macOS Dictation (`REQ-031-02`, `SEC-012`).
    public var canStartDictationHere: Bool {
        guard activeLogTail == nil,
              activeBinaryInspection == nil,
              safetyBanner.canSave,
              let activeID = tabSession.activeTabID,
              !logTailOnlyTabIDs.contains(activeID),
              let session = sessionsByID[activeID],
              !session.isBinaryReadOnly else {
            return false
        }
        return true
    }

    /// Focuses the active editable `SwiftEditNSTextView` and dispatches native macOS Dictation (`startDictation:`) via the injected `dictationTrigger` seam (`REQ-031-02`, `SEC-001`, `SEC-004`, `SEC-012`).
    @discardableResult
    public func startDictationHere() -> Bool {
        guard canStartDictationHere,
              let textView = Self.editableEditorTextView(in: hostWindow?.contentView),
              textView.isEditable else {
            return false
        }
        textView.window?.makeFirstResponder(textView)
        requestEditorFocus()
        let started = deps.dictationTrigger(textView)
        if !started {
            statusBannerMessage = "macOS Dictation is unavailable or disabled in System Settings."
        }
        return started
    }

    /// Opens the palette for the current selection or caret; returns `false` (key not consumed) on binary/log tabs.
    @discardableResult
    public func presentElementContextualMenu(anchor: CGPoint? = nil) -> Bool {
        guard canPresentElementContextualMenu else { return false }
        headerSubmenu.escapePressed()
        navigatorState = nil
        let groups = ElementContextualActionCatalog.groups(
            hasSelection: currentSelection.length > 0,
            canRevealInFolderNavigator: canRevealActiveDocumentInFolderNavigator,
            canStartDictation: canStartDictationHere
        )
        elementContextualMenu = ElementContextualMenuState(
            selection: currentSelection,
            anchor: anchor,
            groups: groups
        )
        return true
    }

    /// Closes the palette and gives focus back to the editor with the original selection.
    public func closeElementContextualMenu() {
        guard let menu = elementContextualMenu else { return }
        elementContextualMenu = nil
        currentSelection = menu.selection
        programmaticSelectionToken += 1
        requestEditorFocus()
    }

    /// Descriptive submenu rows reflecting the active tab's quarantine state and the preview/diff toggles.
    public var headerCommandItems: [HeaderCommandItem] {
        HeaderCommandCatalog.items(
            canSave: safetyBanner.canSave,
            canFormat: safetyBanner.canFormat,
            showMarkdownPreview: showMarkdownPreview,
            appearanceMode: appearanceMode
        )
    }

    /// ESC layering: contextual menu, header submenu, navigator, then distraction-free. Returns `true` when consumed.
    @discardableResult
    public func handleEscape() -> Bool {
        if elementContextualMenu != nil { closeElementContextualMenu(); return true }
        if headerSubmenu.isOpen { dismissHeaderSubmenu(); return true }
        if navigatorState != nil { closeDocumentNavigator(); return true }
        if isDistractionFree { toggleDistractionFree(); return true }
        return false
    }
}
#endif
