import Foundation
import SwiftEditCore
import SwiftUI

/// Pointer region relevant to the header submenu lifecycle (`UI-010`, `UI-011`).
public enum HeaderSubmenuRegion: Equatable, Sendable {
    /// Logo, `PH.SwiftEdit` title, and center bar trigger area.
    case trigger
    /// The translucent submenu panel itself.
    case panel
    /// Isolated trailing Zoom and `Light | Dark | Auto` controls (never open the submenu).
    case trailingControls
    /// Anywhere else in the window.
    case outside
}

/// Click-and-keyboard-only lifecycle of the translucent header submenu (`BUG-006`, `PERF-004`, WCAG 2.2 SC 1.4.13).
///
/// - Hovering the brand trigger or leaving the trigger/panel NEVER auto-opens or auto-closes the submenu.
/// - `clickToggle()` opens or closes instantaneously in `0 ms` and remains sticky until an explicit outside click, logo re-click, item click, `Escape`, or `windowResignedKey()`.
/// - Exposes deterministic keyboard navigation (`moveSelection`, `selectFirst`, `selectLast`) skipping disabled items on quarantined binary tabs (`TEST-004`).
public struct HeaderSubmenuStateMachine: Equatable, Sendable {
    /// Fixed header height guaranteeing `0.0 pt` editor displacement and exact overlay alignment (`UI-012`).
    public static let topBarHeight: Double = 36.0

    public private(set) var isOpen: Bool = false
    public private(set) var pointerRegion: HeaderSubmenuRegion = .outside
    public private(set) var selectedIndex: Int?
    private var isDragging: Bool = false

    public init() {}

    /// Records the latest pointer region for diagnostics without triggering hover open or auto-close (`BUG-006`).
    public mutating func pointerEntered(_ region: HeaderSubmenuRegion) {
        pointerRegion = region
    }

    /// Deliberate no-op: hover dwell and grace auto-dismiss timers are disabled so human users can reach and click every item without time pressure (`BUG-006`, `PERF-004`).
    public mutating func advance(by duration: Duration) {
        _ = duration
    }

    /// Instantaneous `0 ms` toggle for pointer click, tap, or VoiceOver/keyboard activation (`BUG-006`).
    public mutating func clickToggle() {
        isOpen.toggle()
        selectedIndex = isOpen ? 0 : nil
    }

    /// Closes immediately on `Escape` press (`WCAG 2.2`).
    public mutating func escapePressed() {
        isOpen = false
        selectedIndex = nil
    }

    /// Tracks tab or sidebar drag state.
    public mutating func setDragging(_ dragging: Bool) {
        isDragging = dragging
    }

    /// Closes immediately after executing a submenu command.
    public mutating func dismissAfterCommand() {
        escapePressed()
    }

    /// Closes immediately when the host window resigns key focus.
    public mutating func windowResignedKey() {
        escapePressed()
    }

    /// Moves keyboard focus highlight across enabled command rows by `delta` steps, wrapping cleanly.
    public mutating func moveSelection(delta: Int, items: [HeaderCommandItem]) {
        guard isOpen else { return }
        let enabledIndices = items.indices.filter { items[$0].isEnabled }
        guard !enabledIndices.isEmpty else {
            selectedIndex = nil
            return
        }
        guard let current = selectedIndex, let pos = enabledIndices.firstIndex(of: current) else {
            selectedIndex = enabledIndices.first
            return
        }
        let nextPos = (pos + delta % enabledIndices.count + enabledIndices.count) % enabledIndices.count
        selectedIndex = enabledIndices[nextPos]
    }

    /// Moves keyboard selection to the first enabled command (`Home`).
    public mutating func selectFirst(items: [HeaderCommandItem]) {
        guard isOpen else { return }
        selectedIndex = items.firstIndex(where: \.isEnabled)
    }

    /// Moves keyboard selection to the last enabled command (`End`).
    public mutating func selectLast(items: [HeaderCommandItem]) {
        guard isOpen else { return }
        selectedIndex = items.lastIndex(where: \.isEnabled)
    }

    /// Returns the currently highlighted enabled `HeaderCommandID`, if any.
    public func selectedCommandID(in items: [HeaderCommandItem]) -> HeaderCommandID? {
        guard isOpen, let selectedIndex, items.indices.contains(selectedIndex), items[selectedIndex].isEnabled else {
            return nil
        }
        return items[selectedIndex].id
    }
}

/// Stable identifiers for header submenu commands; routed by `SwiftEditWorkbenchModel.performHeaderCommand(_:)` so the menu bar and submenu share one execution path.
public enum HeaderCommandID: String, Equatable, Sendable, CaseIterable {
    case newDocument, openFile, openFolder, saveDocument, saveDocumentAs
    case duplicateLineOrSelection, formatDocument, formatSection
    case toggleMarkdownPreview, toggleDiffPane, showCheatSheet
}

/// Descriptor of one submenu row: descriptive verb-noun title, monospaced shortcut badge, and quarantine-aware enablement (`UI-008`, `UI-009`).
public struct HeaderCommandItem: Equatable, Sendable {
    public let id: HeaderCommandID
    public let title: String
    public let shortcutBadge: String?
    public let isEnabled: Bool
    public let symbolName: String
}

/// Stateless factory projecting submenu rows from workbench state.
///
/// Mutating commands (`Save`, `Save As…`, `Duplicate`, both `Format` commands) follow `canSave` / `canFormat`, so binary read-only tabs disable them (`DATA-003`, `SEC-012`).
/// Shortcut badges are display-only; the actual key bindings live exclusively in `SwiftEditCommands` (`UI-009`).
public enum HeaderCommandCatalog {
    public static func items(canSave: Bool, canFormat: Bool, showMarkdownPreview: Bool, showDiffPane: Bool) -> [HeaderCommandItem] {
        [
            HeaderCommandItem(id: .newDocument, title: "New Document", shortcutBadge: "⌘N", isEnabled: true, symbolName: "doc.badge.plus"),
            HeaderCommandItem(id: .openFile, title: "Open File…", shortcutBadge: "⌘O", isEnabled: true, symbolName: "doc"),
            HeaderCommandItem(id: .openFolder, title: "Open Folder…", shortcutBadge: "⇧⌘O", isEnabled: true, symbolName: "folder"),
            HeaderCommandItem(id: .saveDocument, title: "Save Document", shortcutBadge: "⌘S", isEnabled: canSave, symbolName: "square.and.arrow.down"),
            HeaderCommandItem(id: .saveDocumentAs, title: "Save Document As…", shortcutBadge: "⇧⌘S", isEnabled: canSave, symbolName: "square.and.arrow.down.on.square"),
            HeaderCommandItem(id: .duplicateLineOrSelection, title: "Duplicate Line or Selection", shortcutBadge: "⌘D", isEnabled: canSave, symbolName: "plus.square.on.square"),
            HeaderCommandItem(id: .formatDocument, title: "Format Markdown Document", shortcutBadge: "⇧⌘F", isEnabled: canFormat, symbolName: "text.alignleft"),
            HeaderCommandItem(id: .formatSection, title: "Format Markdown Section", shortcutBadge: "⌥⇧⌘F", isEnabled: canFormat, symbolName: "text.line.first.and.arrowtriangle.forward"),
            HeaderCommandItem(id: .toggleMarkdownPreview, title: showMarkdownPreview ? "Hide Markdown Preview" : "Show Markdown Preview", shortcutBadge: "⌘P", isEnabled: true, symbolName: "doc.richtext"),
            HeaderCommandItem(id: .toggleDiffPane, title: showDiffPane ? "Hide File Compare Diff" : "Show File Compare Diff", shortcutBadge: nil, isEnabled: true, symbolName: "rectangle.split.2x1"),
            HeaderCommandItem(id: .showCheatSheet, title: "Keyboard Shortcuts CheatSheet", shortcutBadge: "⌘/", isEnabled: true, symbolName: "keyboard"),
        ]
    }
}

#if os(macOS)
/// Translucent submenu panel (`312 pt` wide) listing `HeaderCommandItem` rows with monospaced keycap badges.
///
/// Uses only semantic `PurpleThemePalette` tokens; `submenuTranslucentSurface` is `0.90` alpha over `.ultraThinMaterial` and becomes fully opaque under Reduce Transparency or Increased Contrast (`UI-001`, `UI-003`).
/// Declares no `.keyboardShortcut` modifiers (single source: `SwiftEditCommands`).
public struct HeaderBrandSubmenuView: View {
    public let items: [HeaderCommandItem]
    public let palette: PurpleThemePalette
    public var selectedID: HeaderCommandID?
    public var onSelect: (HeaderCommandID) -> Void
    public var onMoveSelection: ((Int) -> Void)?
    public var onSelectFirst: (() -> Void)?
    public var onSelectLast: (() -> Void)?
    public var onDismiss: (() -> Void)?
    @State private var hoveredID: HeaderCommandID?
    @FocusState private var isSubmenuFocused: Bool

    public init(
        items: [HeaderCommandItem],
        palette: PurpleThemePalette,
        selectedID: HeaderCommandID? = nil,
        onSelect: @escaping (HeaderCommandID) -> Void,
        onMoveSelection: ((Int) -> Void)? = nil,
        onSelectFirst: (() -> Void)? = nil,
        onSelectLast: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.items = items
        self.palette = palette
        self.selectedID = selectedID
        self.onSelect = onSelect
        self.onMoveSelection = onMoveSelection
        self.onSelectFirst = onSelectFirst
        self.onSelectLast = onSelectLast
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(items, id: \.id) { item in
                let isHighlighted = item.isEnabled && (hoveredID == item.id || selectedID == item.id)
                Button(action: { onSelect(item.id) }) {
                    HStack(spacing: 10) {
                        Image(systemName: item.symbolName)
                            .frame(width: 18)
                            .foregroundStyle(item.isEnabled ? palette.chromeAccent.swiftUIColor : palette.secondaryForeground.swiftUIColor)
                        Text(item.title)
                            .foregroundStyle(item.isEnabled ? palette.chromeForeground.swiftUIColor : palette.secondaryForeground.swiftUIColor)
                        Spacer(minLength: 12)
                        if let badge = item.shortcutBadge {
                            Text(badge)
                                .font(.caption.monospaced().weight(.semibold))
                                .foregroundStyle(palette.chromeForeground.swiftUIColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(palette.badgeSurface.swiftUIColor)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isHighlighted ? palette.selectionBackground.swiftUIColor : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(selectedID == item.id && item.isEnabled ? palette.chromeAccent.swiftUIColor : Color.clear, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!item.isEnabled)
                .onHover { hovering in
                    hoveredID = hovering ? item.id : (hoveredID == item.id ? nil : hoveredID)
                }
                .accessibilityLabel(item.title)
            }
        }
        .padding(6)
        .frame(width: 312)
        .background(.ultraThinMaterial)
        .background(palette.submenuTranslucentSurface.swiftUIColor)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(palette.hairlineBorder.swiftUIColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .focusable()
        .focused($isSubmenuFocused)
        .focusEffectDisabled()
        .onAppear {
            isSubmenuFocused = true
        }
        .onKeyPress(.downArrow) {
            onMoveSelection?(1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            onMoveSelection?(-1)
            return .handled
        }
        .onKeyPress(.home) {
            onSelectFirst?()
            return .handled
        }
        .onKeyPress(.end) {
            onSelectLast?()
            return .handled
        }
        .onKeyPress(.return) {
            if let selectedID { onSelect(selectedID) }
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss?()
            return .handled
        }
        .onExitCommand {
            onDismiss?()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("PH.SwiftEdit command menu")
    }
}
#endif
