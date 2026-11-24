import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

/// Lifecycle observers, modal sheets, confirmation alerts, external file drops, and AppKit key-down monitoring for `SwiftEditRootView` (`UI-005`, `UI-009`).
extension SwiftEditRootView {
    func handleExternalFileDrop(providers: [NSItemProvider]) -> Bool {
        let matching = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !matching.isEmpty else { return false }
        let activeModel = model
        for provider in matching {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let resolvedURL: URL?
                if let data = item as? Data {
                    resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
                } else if let url = item as? URL {
                    resolvedURL = url
                } else if let str = item as? String {
                    resolvedURL = URL(string: str)
                } else {
                    resolvedURL = nil
                }
                guard let resolvedURL, resolvedURL.isFileURL else { return }
                Task { @MainActor in
                    activeModel.openDroppedURLs([resolvedURL])
                }
            }
        }
        return true
    }

    @ViewBuilder
    func applyLifecycleAndObservers<Content: View>(to content: Content) -> some View {
        content
            .onAppear {
                SwiftEditAppLifecycleBridge.shared.attach(workbench: model)
                model.windowFullScreenQuery = { NSApp.keyWindow?.styleMask.contains(.fullScreen) ?? false }
                model.windowFullScreenToggle = { NSApp.keyWindow?.toggleFullScreen(nil) }
                model.refreshUnmaskedSystemAppearance()
                model.updateAccessibilityPreferences(
                    reduceTransparency: reduceTransparency,
                    increasedContrast: colorSchemeContrast == .increased
                )
                attachKeyDownMonitor()
            }
            .onDisappear {
                detachKeyDownMonitor()
            }
            .onChange(of: systemColorScheme) { _, newScheme in
                if model.appearanceMode == .auto {
                    model.updateSystemColorScheme(prefersDark: newScheme == .dark)
                }
            }
            .onChange(of: reduceTransparency) { _, newValue in
                model.updateAccessibilityPreferences(
                    reduceTransparency: newValue,
                    increasedContrast: colorSchemeContrast == .increased
                )
            }
            .onChange(of: colorSchemeContrast) { _, newContrast in
                model.updateAccessibilityPreferences(
                    reduceTransparency: reduceTransparency,
                    increasedContrast: newContrast == .increased
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
                if model.isDistractionFree { model.windowDidExitFullScreen() }
            }
    }

    @ViewBuilder
    func applySheets<Content: View>(to content: Content) -> some View {
        content
            .sheet(isPresented: $model.isCheatSheetPresented) {
                KeyboardShortcutsCheatSheetView(
                    palette: model.palette,
                    onClose: {
                        model.isCheatSheetPresented = false
                        model.requestEditorFocus()
                    },
                    onPerform: { model.performCheatSheetCommandFromSheet($0) },
                    onDock: {
                        model.isCheatSheetPresented = false
                        model.isShortcutsPanelVisible = true
                    }
                )
            }
            .sheet(isPresented: $model.isHelpSheetPresented) {
                HelpDocumentationView(palette: model.palette) {
                    model.isHelpSheetPresented = false
                    model.requestEditorFocus()
                }
            }
            .sheet(isPresented: $model.isAboutSheetPresented) {
                AboutSheetView(
                    descriptor: AboutSheetDescriptor.resolveFromMainBundle(),
                    palette: model.palette
                ) {
                    model.isAboutSheetPresented = false
                    model.requestEditorFocus()
                }
            }
            .sheet(isPresented: $model.isUpdateDialogPresented) {
                UpdateCheckSheetView(model: model, palette: model.palette) {
                    model.dismissUpdateDialog()
                    model.requestEditorFocus()
                }
            }
    }

    @ViewBuilder
    func applyAlerts<Content: View>(to content: Content) -> some View {
        content
            .alert("Unsaved Changes", isPresented: dirtyCloseAlertPresented) {
                Button("Save") { model.resolvePendingDirtyClose(.save) }
                Button("Don't Save", role: .destructive) { model.resolvePendingDirtyClose(.dontSave) }
                Button("Cancel", role: .cancel) { model.resolvePendingDirtyClose(.cancel) }
            } message: {
                let title = model.tabSession.tabs.first(where: { $0.id == presentedDirtyAlertTabID })?.title ?? model.activeTabTitle
                Text("Do you want to save your changes to \"\(title)\" before closing?")
            }
            .onChange(of: model.pendingDirtyCloseTabID) { _, newValue in
                presentedDirtyAlertTabID = newValue
            }
            .alert("Open All Files in Folder?", isPresented: batchOpenAlertPresented) {
                Button("Open \(model.pendingBatchOpenPlan?.files.count ?? 0) Files") { model.confirmPendingBatchOpen() }
                Button("Cancel", role: .cancel) { model.cancelPendingBatchOpen() }
            } message: {
                Text("This folder contains more than 50 text files (\(model.pendingBatchOpenPlan?.files.count ?? 0) eligible files). Open all?")
            }
            .alert("Move Item to Trash?", isPresented: trashItemAlertPresented) {
                Button("Move to Trash", role: .destructive) { model.confirmPendingTrashItem() }
                Button("Cancel", role: .cancel) { model.cancelPendingTrashItem() }
            } message: {
                Text(model.pendingTrashItemURL?.lastPathComponent ?? "")
            }
            .alert("Send Multiline Text to Terminal?", isPresented: multilineTerminalSendAlertPresented) {
                Button("Send to Terminal") { model.confirmPendingMultilineTerminalSend() }
                Button("Cancel", role: .cancel) { model.cancelPendingMultilineTerminalSend() }
            } message: {
                let count = model.pendingMultilineTerminalSend?.lineCount ?? 0
                Text("The selected text spans \(count) lines. Pasting multiline text into a shell may execute intermediate lines depending on shell settings. No trailing Return is appended.")
            }
    }

    var dirtyCloseAlertPresented: Binding<Bool> {
        Binding(
            get: { presentedDirtyAlertTabID != nil },
            set: { isPresented in
                if !isPresented {
                    presentedDirtyAlertTabID = nil
                    if let nextID = model.pendingDirtyCloseTabID {
                        Task { @MainActor in
                            if model.pendingDirtyCloseTabID == nextID {
                                presentedDirtyAlertTabID = nextID
                            }
                        }
                    }
                }
            }
        )
    }

    var batchOpenAlertPresented: Binding<Bool> {
        Binding(
            get: { model.pendingBatchOpenPlan != nil },
            set: { if !$0 { model.cancelPendingBatchOpen() } }
        )
    }

    var trashItemAlertPresented: Binding<Bool> {
        Binding(
            get: { model.pendingTrashItemURL != nil },
            set: { if !$0 { model.cancelPendingTrashItem() } }
        )
    }

    var multilineTerminalSendAlertPresented: Binding<Bool> {
        Binding(
            get: { model.pendingMultilineTerminalSend != nil },
            set: { if !$0 { model.cancelPendingMultilineTerminalSend() } }
        )
    }

    private static let overlayNavigationKeyCodes: Set<UInt16> = [36, 53, 76, 123, 124, 125, 126]

    func attachKeyDownMonitor() {
        guard keyDownMonitor == nil else { return }
        let activeModel = model
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let cmdOrOpt = event.modifierFlags.intersection([.command, .option])
            if cmdOrOpt.isEmpty && !Self.overlayNavigationKeyCodes.contains(event.keyCode) {
                return event
            }
            let consumed = MainActor.assumeIsolated {
                Self.handleMonitoredKeyDownEvent(event, cmdOrOpt: cmdOrOpt, model: activeModel)
            }
            return consumed ? nil : event
        }
    }

    @MainActor
    private static func handleMonitoredKeyDownEvent(
        _ event: NSEvent,
        cmdOrOpt: NSEvent.ModifierFlags,
        model activeModel: SwiftEditWorkbenchModel
    ) -> Bool {
        guard isEligibleHostWindow(event.window, for: activeModel) else { return false }
        if cmdOrOpt.isEmpty {
            return handleUnmodifiedOverlayKey(keyCode: event.keyCode, model: activeModel)
        }
        guard isModalSheetOrConfirmationActive(on: activeModel) == false,
              let eventWindow = event.window else {
            return false
        }
        return dispatchResponderShortcut(event: event, responder: eventWindow.firstResponder, model: activeModel)
    }

    @MainActor
    private static func isEligibleHostWindow(_ window: NSWindow?, for model: SwiftEditWorkbenchModel) -> Bool {
        guard let eventWindow = window, eventWindow.attachedSheet == nil else { return false }
        if let ownerWindow = model.hostWindow {
            return eventWindow === ownerWindow
        }
        return eventWindow.identifier?.rawValue != "com_apple_SwiftUI_Settings_window" && !eventWindow.isSheet
    }

    @MainActor
    private static func handleUnmodifiedOverlayKey(keyCode: UInt16, model: SwiftEditWorkbenchModel) -> Bool {
        if model.elementContextualMenu != nil {
            return handleContextualMenuNavigationKey(keyCode: keyCode, model: model)
        }
        if model.navigatorState != nil {
            return handleDocumentNavigatorKey(keyCode: keyCode, model: model)
        }
        return false
    }

    @MainActor
    private static func handleContextualMenuNavigationKey(keyCode: UInt16, model: SwiftEditWorkbenchModel) -> Bool {
        switch keyCode {
        case 36, 76: model.activateElementContextualMenuRow(); return true
        case 125: model.elementContextualMenu?.moveHighlight(1); return true
        case 126: model.elementContextualMenu?.moveHighlight(-1); return true
        case 124 where model.elementContextualMenu?.query.isEmpty == true:
            model.elementContextualMenu?.setHighlightedGroupExpanded(true); return true
        case 123 where model.elementContextualMenu?.query.isEmpty == true:
            model.elementContextualMenu?.setHighlightedGroupExpanded(false); return true
        case 53: model.closeElementContextualMenu(); return true
        default: return false
        }
    }

    @MainActor
    private static func handleDocumentNavigatorKey(keyCode: UInt16, model: SwiftEditWorkbenchModel) -> Bool {
        switch keyCode {
        case 36, 76: model.confirmDocumentNavigator(); return true
        case 125: model.navigatorState?.moveDown(); return true
        case 126: model.navigatorState?.moveUp(); return true
        case 53: model.closeDocumentNavigator(); return true
        default: return false
        }
    }

    @MainActor
    private static func isModalSheetOrConfirmationActive(on model: SwiftEditWorkbenchModel) -> Bool {
        model.isCheatSheetPresented || model.isAboutSheetPresented || model.isHelpSheetPresented
            || model.isUpdateDialogPresented || model.pendingDirtyCloseTabID != nil
            || model.pendingBatchOpenPlan != nil || model.pendingTrashItemURL != nil
            || model.pendingMultilineTerminalSend != nil
    }

    @MainActor
    private static func dispatchResponderShortcut(
        event: NSEvent,
        responder: NSResponder?,
        model: SwiftEditWorkbenchModel
    ) -> Bool {
        let mods = event.modifierFlags.intersection(ShortcutKeyEvent.relevantModifierMask)
        if responder is SwiftEditTerminalView {
            guard mods == [.command], (event.charactersIgnoringModifiers ?? "").lowercased() == "j" else { return false }
            model.toggleTerminalPanel()
            return true
        }
        if let editor = responder as? SwiftEditNSTextView, mods == [.command], (event.keyCode == 36 || event.keyCode == 76) {
            return model.presentElementContextualMenu(anchor: selectionAnchor(in: editor))
        }
        let isEditingOverlayTextField = (responder is NSTextView) && !(responder is SwiftEditNSTextView)
        return SwiftEditShortcutDispatcher.dispatch(event: event, model: model, isEditingOverlayTextField: isEditingOverlayTextField)
    }

    /// Bottom-left of the selection's first line in window-content coordinates (y down), or `nil`.
    @MainActor
    static func selectionAnchor(in textView: NSTextView) -> CGPoint? {
        guard let window = textView.window, let content = window.contentView else { return nil }
        let selection = textView.selectedRange()
        let screenRect = textView.firstRect(forCharacterRange: NSRange(location: selection.location, length: 0), actualRange: nil)
        guard screenRect != .zero else { return nil }
        let inContent = content.convert(window.convertFromScreen(screenRect), from: nil)
        let y = content.isFlipped ? inContent.maxY : content.bounds.height - inContent.minY
        return CGPoint(x: inContent.minX, y: y)
    }

    func detachKeyDownMonitor() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
    }
}

#endif
