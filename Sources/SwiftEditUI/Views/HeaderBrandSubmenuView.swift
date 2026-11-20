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

/// Deterministic value-type lifecycle of the translucent header submenu (WCAG 2.2 SC 1.4.13: dismissible, hoverable, persistent).
///
/// - Hover on `.trigger` opens after a continuous `120 ms` dwell; `clickToggle()` opens or closes in `0 ms`.
/// - Leaving both `.trigger` and `.panel` while open closes after a `180 ms` grace period, so pointer travel between them never flickers.
/// - An active tab or sidebar drag blocks hover opening.
/// - `escapePressed()` closes immediately and latches `isSuppressedUntilPointerExit` until the pointer leaves the trigger or the user clicks.
///
/// Time is injected through `advance(by:)` so unit tests need no wall-clock waits (`TEST-004`).
public struct HeaderSubmenuStateMachine: Equatable, Sendable {
    /// Fixed header height guaranteeing `0.0 pt` editor displacement when the overlay opens (`UI-012`).
    public static let topBarHeight: Double = 36.0
    public static let dwellDuration: Duration = .milliseconds(120)
    public static let exitGraceDuration: Duration = .milliseconds(180)

    public private(set) var isOpen: Bool = false
    public private(set) var isSuppressedUntilPointerExit: Bool = false
    public private(set) var pointerRegion: HeaderSubmenuRegion = .outside
    private var isDragging: Bool = false
    private var dwellElapsed: Duration = .zero
    private var graceElapsed: Duration = .zero

    public init() {}

    /// Records that the pointer moved into `region`, resetting the relevant timers.
    public mutating func pointerEntered(_ region: HeaderSubmenuRegion) {
        pointerRegion = region
        dwellElapsed = .zero
        graceElapsed = .zero
        if region != .trigger {
            isSuppressedUntilPointerExit = false
        }
    }

    /// Advances the dwell or grace timer by `duration` and applies any resulting open/close transition.
    public mutating func advance(by duration: Duration) {
        if isOpen {
            guard pointerRegion != .trigger, pointerRegion != .panel else { return }
            graceElapsed += duration
            if graceElapsed >= Self.exitGraceDuration {
                isOpen = false
                graceElapsed = .zero
            }
            return
        }
        guard pointerRegion == .trigger, !isDragging, !isSuppressedUntilPointerExit else { return }
        dwellElapsed += duration
        if dwellElapsed >= Self.dwellDuration {
            isOpen = true
            dwellElapsed = .zero
        }
    }

    /// Instant toggle for click, tap, or keyboard activation; clears any `Escape` latch.
    public mutating func clickToggle() {
        isSuppressedUntilPointerExit = false
        isOpen.toggle()
        dwellElapsed = .zero
        graceElapsed = .zero
    }

    /// Closes immediately and suppresses hover reopening until the pointer exits the trigger.
    public mutating func escapePressed() {
        isOpen = false
        isSuppressedUntilPointerExit = true
        dwellElapsed = .zero
        graceElapsed = .zero
    }

    /// Blocks hover opening while a tab or sidebar drag is in progress.
    public mutating func setDragging(_ dragging: Bool) {
        isDragging = dragging
        if dragging { dwellElapsed = .zero }
    }

    /// Closes after a command is chosen or the window resigns key, latching until pointer exit.
    public mutating func dismissAfterCommand() {
        escapePressed()
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
    public let onSelect: (HeaderCommandID) -> Void

    public init(items: [HeaderCommandItem], palette: PurpleThemePalette, onSelect: @escaping (HeaderCommandID) -> Void) {
        self.items = items
        self.palette = palette
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(items, id: \.id) { item in
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
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!item.isEnabled)
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("PH.SwiftEdit command menu")
    }
}
#endif
