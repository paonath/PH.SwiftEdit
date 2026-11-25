import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

private struct TabReorderDropDelegate: DropDelegate {
    let targetTab: TabDescriptor
    let model: SwiftEditWorkbenchModel
    @Binding var draggingTabID: DocumentID?

    func dropEntered(info: DropInfo) {
        guard let draggedID = draggingTabID,
              draggedID != targetTab.id,
              let targetIndex = model.tabSession.tabs.firstIndex(where: { $0.id == targetTab.id }) else {
            return
        }
        model.moveTab(id: draggedID, toIndex: targetIndex)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingTabID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

/// Root Zed-minimal Purple (`Viola`) + inverted `#FFFFFF`/`#000000` SwiftUI workspace view for `PH.SwiftEdit` (`UI-001..012`).
public struct SwiftEditRootView: View {
    @Environment(\.colorScheme) var systemColorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.colorSchemeContrast) var colorSchemeContrast
    @State var model = SwiftEditWorkbenchModel()
    @State var draggingTabID: DocumentID?
    @State var hoveredTabID: DocumentID?
    @State var isExternalDropTargeted = false
    @State var dragStartSidebarRatio: Double?
    @State var presentedDirtyAlertTabID: DocumentID?
    @State var gutterViewportMetrics: GutterViewportMetrics?
    @State var keyDownMonitor: Any?

    public init() {}

    init(initialModel: SwiftEditWorkbenchModel) {
        self._model = State(initialValue: initialModel)
    }

    private var layoutContent: some View {
        VStack(spacing: 0) {
            if !model.isDistractionFree { toolbarBar }
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    if model.isDistractionFree {
                        EmptyView()
                    } else if !model.isLeftSidebarCollapsed {
                        let sidebarWidth = SidebarLayoutGeometry.resolvedWidth(
                            forContainerWidth: Double(geometry.size.width),
                            ratio: model.sidebarWidthRatio
                        )
                        sidebarView
                            .frame(width: CGFloat(sidebarWidth))
                        sidebarPercentageDivider(containerWidth: Double(geometry.size.width))
                    }
                    VStack(spacing: 0) {
                        if !model.isDistractionFree { tabBar; safetyAndErrorBanners }
                        if !model.isDistractionFree { FindReplaceGoToLineBar(
                            state: $model.findReplaceState,
                            palette: model.palette,
                            onFind: { model.executeFind() },
                            onFindNext: { model.findNextMatch() },
                            onFindPrevious: { model.findPreviousMatch() },
                            onReplace: { model.executeReplaceSingle() },
                            onReplaceAll: { model.executeReplaceAll() },
                            onGoToLine: { model.executeGoToLine() },
                            onClose: { model.presentFindBar(mode: .hidden) }
                        ) }
                        if let tail = model.activeLogTail, !model.isDistractionFree {
                            LogTailPanelView(model: model, tail: tail)
                        }
                        if model.isPropertiesPanelVisible {
                            PropertiesPanelView(model: model, state: model.propertiesPanel)
                        }
                        editorAndOptionalPanels
                        if model.isTerminalPanelVisible, !model.isDistractionFree {
                            TerminalPanelView(model: model)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            if !model.isDistractionFree { statusBar }
        }
        .overlay(alignment: .top) {
            DocumentNavigatorOverlayView(model: model)
        }
        .overlay(alignment: .top) {
            QuickOpenAndFolderSearchView(model: model)
        }
        .overlay(alignment: .topLeading) {
            ElementContextualMenuView(model: model)
        }
        .overlay(alignment: .topLeading) {
            headerSubmenuOverlay
        }
        .onExitCommand {
            if model.handleEscape() { return }
            model.headerSubmenu.escapePressed()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            model.headerSubmenu.windowResignedKey()
        }
        .onChange(of: draggingTabID) { _, newValue in
            model.headerSubmenu.setDragging(newValue != nil || dragStartSidebarRatio != nil)
        }
        .onChange(of: dragStartSidebarRatio) { _, newValue in
            model.headerSubmenu.setDragging(newValue != nil || draggingTabID != nil)
        }
    }

    public var body: some View {
        applyAlerts(to: applySheets(to: applyLifecycleAndObservers(to: baseRootView)))
            .environment(\.appTypography, AppTypographyContext(typography: model.typography, generation: model.typographyGeneration))
    }

    private var baseRootView: some View {
        layoutContent
            .background(HostingWindowFinder { window in
                model.hostWindow = window
                if let window {
                    model.applyInitialFullScreenIfNeeded(for: window)
                }
            })
            .background(model.palette.chromeSurface.swiftUIColor)
            .foregroundStyle(model.palette.chromeForeground.swiftUIColor)
            .preferredColorScheme(model.preferredSwiftUIColorScheme)
            .frame(minWidth: 960, minHeight: 620)
            .onDrop(of: [UTType.fileURL], isTargeted: $isExternalDropTargeted) { providers in
                handleExternalFileDrop(providers: providers)
            }
            .overlay {
                if isExternalDropTargeted {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(model.palette.chromeAccent.swiftUIColor, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .focusedSceneValue(\.workbenchModel, model)
    }


    /// Root-level overlay: `.zIndex(99)` outside-click shield positioned strictly below `topBarHeight` so the header logo trigger stays clickable to toggle, beneath the `.zIndex(100)` sticky submenu (`BUG-006`, `UI-012`).
    @ViewBuilder
    private var headerSubmenuOverlay: some View {
        if model.headerSubmenu.isOpen {
            let items = model.headerCommandItems
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .padding(.top, model.chromeMetrics.headerHeight)
                    .onTapGesture { model.dismissHeaderSubmenu() }
                    .zIndex(99)
                HeaderBrandSubmenuView(
                    items: items,
                    palette: model.palette,
                    selectedID: model.headerSubmenu.selectedCommandID(in: items),
                    onSelect: { model.performHeaderCommand($0) },
                    onMoveSelection: { delta in model.headerSubmenu.moveSelection(delta: delta, items: items) },
                    onSelectFirst: { model.headerSubmenu.selectFirst(items: items) },
                    onSelectLast: { model.headerSubmenu.selectLast(items: items) },
                    onDismiss: { model.dismissHeaderSubmenu() },
                    scale: model.chromeMetrics.factor
                )
                .padding(.leading, 12)
                .offset(y: model.chromeMetrics.headerHeight)
                .zIndex(100)
            }
        }
    }

    /// Zed-style header: unchanged Concept E2 logo menu followed by the command icon cluster on the left, the
    /// `folder / file` breadcrumb on the right; every size follows the editor zoom (`REQ-021-02`, `REQ-021-03`).
    private var toolbarBar: some View {
        let metrics = model.chromeMetrics
        return HStack(spacing: 8 * metrics.factor) {
            Button(action: { model.headerSubmenu.clickToggle() }) {
                HStack(spacing: 6 * metrics.factor) {
                    SwiftEditBrandLogoView(size: metrics.headerLogoSize)
                    Text("SwiftEdit")
                        .appFont(size: metrics.headerFontSize, weight: .semibold)
                        .foregroundStyle(model.palette.chromeForeground.swiftUIColor)
                    AppIconView(model.headerSubmenu.isOpen ? .chevronUp : .chevronDown, size: 10 * metrics.factor)
                        .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                }
                .padding(.horizontal, 6 * metrics.factor)
                .padding(.vertical, 3 * metrics.factor)
                .background(model.headerSubmenu.isOpen ? model.palette.accentSoftSurface.swiftUIColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6 * metrics.factor))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help("SwiftEdit commands menu")
            .accessibilityLabel("SwiftEdit commands menu")
            .accessibilityValue(model.headerSubmenu.isOpen ? "Expanded" : "Collapsed")
            .accessibilityHint("Toggles the SwiftEdit command menu")

            HStack(spacing: 2 * metrics.factor) {
                headerIconButton(.sidebar, help: "Toggle Folder Navigator (⌘B)", isActive: !model.isLeftSidebarCollapsed) { model.toggleLeftSidebar() }
                headerIconButton(.search, help: "Find in Document (⌘F)", isActive: model.findReplaceState.mode != .hidden) { model.presentFindBar(mode: .find) }
                headerIconButton(.eye, help: "Toggle Markdown Preview (⌘P)", isActive: model.showMarkdownPreview) { model.toggleMarkdownPreview() }
                headerIconButton(.diff, help: "Toggle File Compare (⇧⌘D)", isActive: model.showDiffPane) { model.toggleDiffPane() }
                headerIconButton(.terminal, help: "Toggle Terminal Panel (⌘J)", isActive: model.isTerminalPanelVisible) { model.toggleTerminalPanel() }
                headerIconButton(.keyboard, help: "Toggle Keyboard Shortcuts Panel (⌥⌘/)", isActive: model.isShortcutsPanelVisible) { model.toggleShortcutsPanel() }
            }

            Spacer(minLength: 8)

            headerBreadcrumb
        }
        .padding(.horizontal, 12)
        .frame(height: metrics.headerHeight)
        .foregroundStyle(model.palette.chromeForeground.swiftUIColor)
        .tint(model.palette.chromeAccent.swiftUIColor)
        .background(model.palette.topBarSurface.swiftUIColor)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(model.palette.hairlineBorder.swiftUIColor)
                .frame(height: 1)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            model.isToolbarHovered = hovering
        }
    }

    /// `folder / file` breadcrumb of the active tab (muted folder, primary file name).
    @ViewBuilder
    private var headerBreadcrumb: some View {
        let parts = model.headerBreadcrumb
        if !parts.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                    Text(verbatim: "/")
                        .foregroundStyle(model.palette.hairlineBorder.swiftUIColor)
                    Text(verbatim: part)
                        .foregroundStyle((index == parts.count - 1 ? model.palette.chromeForeground : model.palette.secondaryForeground).swiftUIColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: (index == parts.count - 1 ? 320 : 180) * model.chromeMetrics.factor, alignment: .trailing)
                        .fixedSize(horizontal: index == parts.count - 1, vertical: false)
                }
            }
            .appFont(size: model.chromeMetrics.headerFontSize, weight: .medium)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Current file: \(parts.joined(separator: ", "))")
        }
    }

    /// Icon-only toggle in the header cluster; active state uses the soft accent surface and accent glyph.
    private func headerIconButton(_ icon: AppIcon, help: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        let metrics = model.chromeMetrics
        return Button(action: action) {
            AppIconView(icon, size: metrics.headerIconSize)
                .foregroundStyle((isActive ? model.palette.chromeAccent : model.palette.secondaryForeground).swiftUIColor)
                .frame(width: metrics.headerIconButtonWidth, height: metrics.headerIconButtonHeight)
                .background(isActive ? model.palette.accentSoftSurface.swiftUIColor : Color.clear, in: RoundedRectangle(cornerRadius: 5 * metrics.factor))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func sidebarPercentageDivider(containerWidth: Double) -> some View {
        Rectangle()
            .fill(model.palette.hairlineBorder.swiftUIColor)
            .frame(width: 1)
            .padding(.horizontal, 2.5)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if dragStartSidebarRatio == nil {
                            dragStartSidebarRatio = model.sidebarWidthRatio
                        }
                        let startRatio = dragStartSidebarRatio ?? model.sidebarWidthRatio
                        let nextRatio = SidebarLayoutGeometry.updatedRatio(
                            currentRatio: startRatio,
                            dragDeltaWidth: Double(value.translation.width),
                            containerWidth: containerWidth
                        )
                        model.updateSidebarWidthRatio(nextRatio)
                    }
                    .onEnded { _ in
                        dragStartSidebarRatio = nil
                    }
            )
            .accessibilityLabel("Resize Sidebar Divider")
    }
}

extension SwiftEditRootView {
    /// Flat Zed-style tabs: the active tab merges with the canvas under a 2 pt accent line; close shows on the active or
    /// hovered tab, a dot marks unsaved tabs, a small pin marks pinned ones; reorder/pin live in drag and context menu (R-03).
    private var tabBar: some View {
        let metrics = model.chromeMetrics
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(model.tabSession.tabs, id: \.id) { tab in
                    let isActive = tab.id == model.tabSession.activeTabID
                    let isHovered = hoveredTabID == tab.id
                    HStack(spacing: 6) {
                        if tab.isPinned {
                            AppIconView(.pin, size: metrics.tabBadgeSize)
                                .foregroundStyle(model.palette.pinnedTabBadge.swiftUIColor)
                        }
                        Button(action: { model.activateTab(id: tab.id) }) {
                            Text(tab.title)
                                .appFont(size: metrics.tabFontSize, weight: isActive ? .medium : .regular)
                                .foregroundStyle((isActive ? model.palette.chromeForeground : model.palette.secondaryForeground).swiftUIColor)
                                .lineLimit(1)
                                .frame(minWidth: metrics.tabMinWidth, maxWidth: metrics.tabMaxWidth, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(tab.title)\(tab.isDirty ? ", unsaved" : "")\(tab.isPinned ? ", pinned" : "")")

                        Button(action: { model.requestCloseTab(id: tab.id) }) {
                            Group {
                                if tab.isDirty && !isActive && !isHovered {
                                    AppIconView(.dot, size: metrics.tabBadgeSize)
                                } else {
                                    AppIconView(.close, size: metrics.tabBadgeSize)
                                }
                            }
                            .minimumHitTarget(metrics.tabIconTarget)
                        }
                        .buttonStyle(.plain)
                        .opacity(isActive || isHovered || tab.isDirty ? 1 : 0)
                        .help("Close Tab (⇧⌘W)")
                        .accessibilityLabel("Close tab \(tab.title)")
                    }
                    .foregroundStyle(model.palette.secondaryForeground.swiftUIColor)
                    .padding(.horizontal, metrics.tabHorizontalPadding + 4)
                    .frame(minHeight: metrics.tabHeight)
                    .background(isActive ? model.palette.tabActiveSurface.swiftUIColor : Color.clear)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(isActive ? model.palette.chromeAccent.swiftUIColor : Color.clear)
                            .frame(height: 2)
                    }
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(model.palette.hairlineBorder.swiftUIColor)
                            .frame(width: 1)
                    }
                    .contentShape(Rectangle())
                    .onHover { inside in hoveredTabID = inside ? tab.id : (hoveredTabID == tab.id ? nil : hoveredTabID) }
                    .onDrag {
                        draggingTabID = tab.id
                        return NSItemProvider(object: tab.id.rawValue.uuidString as NSString)
                    }
                    .onDrop(
                        of: [UTType.text],
                        delegate: TabReorderDropDelegate(targetTab: tab, model: model, draggingTabID: $draggingTabID)
                    )
                    .contextMenu {
                        Button("Move Tab Left") { model.moveTabLeft(id: tab.id) }
                        Button("Move Tab Right") { model.moveTabRight(id: tab.id) }
                        Divider()
                        Button(tab.isPinned ? "Unpin Tab" : "Pin Tab") { model.togglePin(id: tab.id) }
                        Divider()
                        Button("Close Tab") { model.requestCloseTab(id: tab.id) }
                            .disabled(tab.isPinned)
                        Button("Close Tabs to the Right") { model.requestCloseTabsToTheRight(of: tab.id) }
                            .disabled(model.tabSession.unpinnedTabIDsToTheRight(of: tab.id).isEmpty)
                        Button("Close Other Tabs") { model.requestCloseOtherTabs(keeping: tab.id) }
                            .disabled(model.tabSession.unpinnedOtherTabIDs(keeping: tab.id).isEmpty)
                        Button("Close All Unpinned Tabs") { model.requestCloseAllUnpinnedTabs() }
                            .disabled(model.tabSession.unpinnedTabIDs().isEmpty)
                        Button("Close All Tabs") { model.requestCloseAllTabs() }
                    }
                    .overlay {
                        TabMiddleClickCatcher { model.handleMiddleClickTab(id: tab.id) }
                    }
                }
            }
        }
        .background(model.palette.tabBarSurface.swiftUIColor)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(model.palette.hairlineBorder.swiftUIColor)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    var safetyAndErrorBanners: some View {
        if model.safetyBanner.isBinaryReadOnlyBannerVisible {
            HStack(spacing: 10) {
                Text("READ-ONLY BINARY INSPECTION: Save, Format, Pin Tab, and SessionRecovery are disabled.")
                Spacer()
                if model.activeBinaryInspection != nil {
                    Button("Dismiss Inspection") { model.dismissBinaryInspection() }
                        .buttonStyle(.bordered)
                }
            }
            .purpleSecurityWarningBanner(
                foreground: model.palette.binaryQuarantineForeground,
                background: model.palette.binaryQuarantineBackground,
                border: model.palette.binaryQuarantineBorder,
                verticalPadding: 6
            )
        }
        if !model.safetyBanner.bidiWarnings.isEmpty {
            Text("BiDi Warning: \(model.safetyBanner.bidiWarnings.count) Unicode bidirectional control character(s) detected.")
                .purpleSecurityWarningBanner(
                    foreground: model.palette.bidiWarningForeground,
                    background: model.palette.bidiWarningBackground,
                    border: model.palette.bidiWarningBorder,
                    verticalPadding: 5
                )
        }
        if let activeID = model.tabSession.activeTabID, model.activeTabHasExternalConflict {
            HStack(spacing: 10) {
                Text("File modified externally on disk while this tab has unsaved edits.")
                Spacer()
                Button("Reload from Disk") { model.reloadConflictedTabFromDisk(id: activeID) }
                    .buttonStyle(.bordered)
                Button("Keep Mine") { model.keepLocalEditsForConflictedTab(id: activeID) }
                    .buttonStyle(.bordered)
                Button("Compare") { model.compareConflictedTabWithDisk(id: activeID) }
                    .buttonStyle(.bordered)
            }
            .purpleSecurityWarningBanner(
                foreground: model.palette.bidiWarningForeground,
                background: model.palette.bidiWarningBackground,
                border: model.palette.bidiWarningBorder,
                verticalPadding: 6
            )
        }
        if let message = model.statusBannerMessage {
            Text(message)
                .appFont(.caption)
                .foregroundStyle(model.palette.chromeForeground.swiftUIColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(model.palette.badgeSurface.swiftUIColor)
        }
    }


}

private struct HostingWindowFinder: NSViewRepresentable {
    let onResolveWindow: (NSWindow?) -> Void

    final class ProbeNSView: NSView {
        var onResolveWindow: ((NSWindow?) -> Void)?

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            let callback = onResolveWindow
            super.viewWillMove(toWindow: newWindow)
            callback?(newWindow)
        }
    }

    func makeNSView(context: Context) -> ProbeNSView {
        let view = ProbeNSView()
        view.onResolveWindow = onResolveWindow
        return view
    }

    func updateNSView(_ nsView: ProbeNSView, context: Context) {
        nsView.onResolveWindow = onResolveWindow
        if let win = nsView.window {
            onResolveWindow(win)
        }
    }
}

/// Transparent AppKit responder overlay forwarding middle-mouse button clicks (`otherMouseUp`, button `2`) to close tabs without stealing primary clicks, hover, or drag (`REQ-002`).
private struct TabMiddleClickCatcher: NSViewRepresentable {
    let onMiddleClick: () -> Void

    final class CatcherNSView: NSView {
        var onMiddleClick: (() -> Void)?

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let current = NSApp.currentEvent,
                  current.type == .otherMouseDown || current.type == .otherMouseUp else {
                return nil
            }
            return bounds.contains(point) ? self : nil
        }

        override func otherMouseUp(with event: NSEvent) {
            if event.buttonNumber == 2, bounds.contains(convert(event.locationInWindow, from: nil)) {
                onMiddleClick?()
                return
            }
            super.otherMouseUp(with: event)
        }
    }

    func makeNSView(context: Context) -> CatcherNSView {
        let v = CatcherNSView()
        v.onMiddleClick = onMiddleClick
        return v
    }

    func updateNSView(_ nsView: CatcherNSView, context: Context) {
        nsView.onMiddleClick = onMiddleClick
    }
}
#endif
