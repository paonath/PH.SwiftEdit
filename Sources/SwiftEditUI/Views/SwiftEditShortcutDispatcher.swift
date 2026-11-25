import Foundation
import SwiftEditCore

#if os(macOS)
import AppKit

/// Normalized key-down input extracted from `NSEvent` (and directly constructible in unit tests) for `SwiftEditShortcutDispatcher` (`UI-009`, `UI-010`).
public struct ShortcutKeyEvent: Sendable, Equatable {
    public static let relevantModifierMask: NSEvent.ModifierFlags = [.command, .option, .shift, .control]

    public let characters: String
    public let charactersIgnoringModifiers: String
    public let keyCode: UInt16
    public let modifiers: NSEvent.ModifierFlags

    public init(
        characters: String,
        charactersIgnoringModifiers: String? = nil,
        keyCode: UInt16 = 0,
        modifiers: NSEvent.ModifierFlags
    ) {
        self.characters = characters
        self.charactersIgnoringModifiers = charactersIgnoringModifiers ?? characters
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.relevantModifierMask)
    }

    public init(event: NSEvent) {
        self.characters = event.characters ?? ""
        self.charactersIgnoringModifiers = event.charactersIgnoringModifiers ?? ""
        self.keyCode = event.keyCode
        self.modifiers = event.modifierFlags.intersection(Self.relevantModifierMask)
    }
}

/// Deterministic shortcut router bypassing `NSTextView` Option-composition traps and AppKit system menu collisions (`UseSelectionForFind`, `FindNext`, `ToggleToolbar`, `ShowColors`) (`UI-009`, `UI-010`).
///
/// Leaves standard editing and macOS app shortcuts (`Cmd+,`, `Cmd+Q`, `Cmd+H`, `Cmd+A/C/V/X/Z/Shift+Z`) untouched for AppKit responder handling.
@MainActor
public enum SwiftEditShortcutDispatcher {
    private static let numpadPlusKeyCode: UInt16 = 69
    private static let numpadMinusKeyCode: UInt16 = 78
    private static let numpadZeroKeyCode: UInt16 = 82
    private static let ansiBackslashKeyCode: UInt16 = 42
    private static let ansiPeriodKeyCode: UInt16 = 47
    private static let ansiOneKeyCode: UInt16 = 18

    private static let headingLevelByKeyCode: [UInt16: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6,
    ]

    /// Evaluates `event` against the active `SwiftEditWorkbenchModel`; returns `true` when consumed.
    public static func dispatch(
        event: NSEvent,
        model: SwiftEditWorkbenchModel,
        isEditingOverlayTextField: Bool = false
    ) -> Bool {
        dispatch(ShortcutKeyEvent(event: event), model: model, isEditingOverlayTextField: isEditingOverlayTextField)
    }

    /// Evaluates `key` against the active `SwiftEditWorkbenchModel`, failing closed on malformed, NUL-embedded, or BiDi-tainted chord payloads (`REQ-008`, `SEC-012`).
    public static func dispatch(
        _ key: ShortcutKeyEvent,
        model: SwiftEditWorkbenchModel,
        isEditingOverlayTextField: Bool = false
    ) -> Bool {
        guard isWellFormedChordString(key.characters),
              isWellFormedChordString(key.charactersIgnoringModifiers) else {
            return false
        }
        let chars = key.characters.lowercased()
        let charsIgnored = key.charactersIgnoringModifiers.lowercased()

        if key.modifiers.contains(.command) {
            return dispatchCommandChord(
                key,
                chars: chars,
                charsIgnored: charsIgnored,
                model: model,
                isEditingOverlayTextField: isEditingOverlayTextField
            )
        }
        return dispatchNonCommandChord(
            key,
            chars: chars,
            charsIgnored: charsIgnored,
            model: model,
            isEditingOverlayTextField: isEditingOverlayTextField
        )
    }

    private static func dispatchCommandChord(
        _ key: ShortcutKeyEvent,
        chars: String,
        charsIgnored: String,
        model: SwiftEditWorkbenchModel,
        isEditingOverlayTextField: Bool
    ) -> Bool {
        switch key.modifiers {
        case [.command]:
            return dispatchCommandOnly(key, chars: chars, charsIgnored: charsIgnored, model: model, isEditingOverlayTextField: isEditingOverlayTextField)
        case [.command, .shift]:
            return dispatchCommandShift(key, chars: chars, charsIgnored: charsIgnored, model: model, isEditingOverlayTextField: isEditingOverlayTextField)
        case [.command, .option]:
            return dispatchCommandOption(charsIgnored: charsIgnored, model: model, isEditingOverlayTextField: isEditingOverlayTextField)
        case [.command, .shift, .option]:
            return dispatchCommandShiftOption(charsIgnored: charsIgnored, model: model)
        case [.command, .control]:
            return dispatchCommandControl(key, charsIgnored: charsIgnored, model: model, isEditingOverlayTextField: isEditingOverlayTextField)
        default:
            return false
        }
    }

    private struct CommandTableEntry {
        let blocksOnOverlayField: Bool
        let run: @MainActor (SwiftEditWorkbenchModel) -> Bool
    }

    private static let commandOnlyTable: [String: CommandTableEntry] = [
        "l": CommandTableEntry(blocksOnOverlayField: true) { $0.startLogTail(mode: .direct); return true },
        "j": CommandTableEntry(blocksOnOverlayField: false) { $0.toggleTerminalPanel(); return true },
        "n": CommandTableEntry(blocksOnOverlayField: false) { $0.newUntitledTab(); return true },
        "o": CommandTableEntry(blocksOnOverlayField: false) { $0.openFileViaPanel(); return true },
        "s": CommandTableEntry(blocksOnOverlayField: false) { if $0.safetyBanner.canSave { $0.saveActiveDocument() }; return true },
        "w": CommandTableEntry(blocksOnOverlayField: false) { $0.toggleWordWrap(); return true },
        "f": CommandTableEntry(blocksOnOverlayField: false) { $0.presentFindBar(mode: .find); return true },
        "g": CommandTableEntry(blocksOnOverlayField: false) { $0.presentFindBar(mode: .goToLine); return true },
        "b": CommandTableEntry(blocksOnOverlayField: false) { $0.toggleLeftSidebar(); return true },
        "+": CommandTableEntry(blocksOnOverlayField: false) { $0.zoomController.zoomIn(); return true },
        "=": CommandTableEntry(blocksOnOverlayField: false) { $0.zoomController.zoomIn(); return true },
        "-": CommandTableEntry(blocksOnOverlayField: false) { $0.zoomController.zoomOut(); return true },
        "0": CommandTableEntry(blocksOnOverlayField: false) { $0.zoomController.resetZoom(); return true },
        "p": CommandTableEntry(blocksOnOverlayField: false) { $0.toggleMarkdownPreview(); return true },
        "t": CommandTableEntry(blocksOnOverlayField: false) { $0.toggleQuickOpen(); return true },
        "/": CommandTableEntry(blocksOnOverlayField: false) { $0.isCheatSheetPresented = true; return true },
        "d": CommandTableEntry(blocksOnOverlayField: true) { if $0.safetyBanner.canSave { $0.performCommandD() }; return true },
        "i": CommandTableEntry(blocksOnOverlayField: true) { if $0.isMarkdownMenuEnabled { $0.applyMarkdownCommand(.italic) }; return true },
        "e": CommandTableEntry(blocksOnOverlayField: true) { if $0.isMarkdownMenuEnabled { $0.applyMarkdownCommand(.inlineCode) }; return true },
        "k": CommandTableEntry(blocksOnOverlayField: true) { if $0.isMarkdownMenuEnabled { $0.applyMarkdownCommand(.link) }; return true },
        "1": CommandTableEntry(blocksOnOverlayField: false) { $0.selectTabAtShortcutIndex(1); return true },
        "2": CommandTableEntry(blocksOnOverlayField: false) { $0.selectTabAtShortcutIndex(2); return true },
        "3": CommandTableEntry(blocksOnOverlayField: false) { $0.selectTabAtShortcutIndex(3); return true },
        "4": CommandTableEntry(blocksOnOverlayField: false) { $0.selectTabAtShortcutIndex(4); return true },
        "5": CommandTableEntry(blocksOnOverlayField: false) { $0.selectTabAtShortcutIndex(5); return true },
        "6": CommandTableEntry(blocksOnOverlayField: false) { $0.selectTabAtShortcutIndex(6); return true },
        "7": CommandTableEntry(blocksOnOverlayField: false) { $0.selectTabAtShortcutIndex(7); return true },
        "8": CommandTableEntry(blocksOnOverlayField: false) { $0.selectTabAtShortcutIndex(8); return true },
        "9": CommandTableEntry(blocksOnOverlayField: false) { $0.selectTabAtShortcutIndex(9); return true },
        "\r": CommandTableEntry(blocksOnOverlayField: true) { $0.presentElementContextualMenu() },
        "\u{3}": CommandTableEntry(blocksOnOverlayField: true) { $0.presentElementContextualMenu() },
    ]

    private static let commandShiftTable: [String: CommandTableEntry] = [
        "w": CommandTableEntry(blocksOnOverlayField: false) { $0.requestCloseActiveTab(); return true },
        "d": CommandTableEntry(blocksOnOverlayField: false) { $0.toggleDiffPane(); return true },
        "o": CommandTableEntry(blocksOnOverlayField: false) { $0.openFolderViaPanel(); return true },
        "s": CommandTableEntry(blocksOnOverlayField: false) { if $0.safetyBanner.canSave { $0.saveActiveDocumentAsViaPanel() }; return true },
        "f": CommandTableEntry(blocksOnOverlayField: false) { if $0.safetyBanner.canFormat { $0.formatActiveDocument() }; return true },
        "b": CommandTableEntry(blocksOnOverlayField: true) { if $0.isMarkdownMenuEnabled { $0.applyMarkdownCommand(.bold) }; return true },
        "x": CommandTableEntry(blocksOnOverlayField: true) { if $0.isMarkdownMenuEnabled { $0.applyMarkdownCommand(.strikethrough) }; return true },
        "c": CommandTableEntry(blocksOnOverlayField: true) { if $0.isMarkdownMenuEnabled { $0.applyMarkdownCommand(.codeFence) }; return true },
        "i": CommandTableEntry(blocksOnOverlayField: true) { if $0.isMarkdownMenuEnabled { $0.applyMarkdownCommand(.image) }; return true },
        "l": CommandTableEntry(blocksOnOverlayField: true) { $0.startLogTail(mode: .inverse); return true },
        ".": CommandTableEntry(blocksOnOverlayField: true) { if $0.isMarkdownMenuEnabled { $0.applyMarkdownCommand(.blockquote) }; return true },
        ">": CommandTableEntry(blocksOnOverlayField: true) { if $0.isMarkdownMenuEnabled { $0.applyMarkdownCommand(.blockquote) }; return true },
        "m": CommandTableEntry(blocksOnOverlayField: true) { if $0.isMarkdownMenuEnabled { $0.toggleDiagnosticsPopover() }; return true },
        "t": CommandTableEntry(blocksOnOverlayField: false) { _ = $0.reopenLastClosedTab(); return true },
        "]": CommandTableEntry(blocksOnOverlayField: false) { $0.selectNextTab(); return true },
        "}": CommandTableEntry(blocksOnOverlayField: false) { $0.selectNextTab(); return true },
        "[": CommandTableEntry(blocksOnOverlayField: false) { $0.selectPreviousTab(); return true },
        "{": CommandTableEntry(blocksOnOverlayField: false) { $0.selectPreviousTab(); return true },
    ]

    private static let commandOptionTable: [String: CommandTableEntry] = [
        "/": CommandTableEntry(blocksOnOverlayField: false) { $0.toggleShortcutsPanel(); return true },
        "÷": CommandTableEntry(blocksOnOverlayField: false) { $0.toggleShortcutsPanel(); return true },
        "f": CommandTableEntry(blocksOnOverlayField: false) { $0.presentFindBar(mode: .findAndReplace); return true },
        "e": CommandTableEntry(blocksOnOverlayField: true) { $0.useSelectionForFind(); return true },
        "t": CommandTableEntry(blocksOnOverlayField: true) { if $0.isMarkdownMenuEnabled { $0.applyMarkdownCommand(.insertTable) }; return true },
        "l": CommandTableEntry(blocksOnOverlayField: true) { if $0.isMarkdownMenuEnabled { $0.applyMarkdownCommand(.taskToggle) }; return true },
    ]

    private static func dispatchTableEntry(
        _ table: [String: CommandTableEntry],
        key: String,
        model: SwiftEditWorkbenchModel,
        isEditingOverlayTextField: Bool
    ) -> Bool? {
        guard let entry = table[key] else { return nil }
        guard !(entry.blocksOnOverlayField && isEditingOverlayTextField) else { return false }
        return entry.run(model)
    }

    private static func dispatchCommandOnly(
        _ key: ShortcutKeyEvent,
        chars: String,
        charsIgnored: String,
        model: SwiftEditWorkbenchModel,
        isEditingOverlayTextField: Bool
    ) -> Bool {
        if let handled = dispatchTableEntry(
            commandOnlyTable,
            key: charsIgnored,
            model: model,
            isEditingOverlayTextField: isEditingOverlayTextField
        ) {
            return handled
        }
        return dispatchCommandOnlyHardwareKeyFallback(key, chars: chars, model: model)
    }

    private static func dispatchCommandOnlyHardwareKeyFallback(
        _ key: ShortcutKeyEvent,
        chars: String,
        model: SwiftEditWorkbenchModel
    ) -> Bool {
        switch key.keyCode {
        case numpadPlusKeyCode:
            model.zoomController.zoomIn()
            return true
        case numpadMinusKeyCode:
            model.zoomController.zoomOut()
            return true
        case numpadZeroKeyCode:
            model.zoomController.resetZoom()
            return true
        default:
            if chars == "/" {
                model.isCheatSheetPresented = true
                return true
            }
            return false
        }
    }

    private static func dispatchCommandShift(
        _ key: ShortcutKeyEvent,
        chars: String,
        charsIgnored: String,
        model: SwiftEditWorkbenchModel,
        isEditingOverlayTextField: Bool
    ) -> Bool {
        if chars == "/" || charsIgnored == "/" || chars == "?" {
            model.isCheatSheetPresented = true
            return true
        }
        if chars == "+" || charsIgnored == "+" || key.keyCode == numpadPlusKeyCode {
            model.zoomController.zoomIn()
            return true
        }
        if let handled = dispatchTableEntry(
            commandShiftTable,
            key: charsIgnored,
            model: model,
            isEditingOverlayTextField: isEditingOverlayTextField
        ) {
            return handled
        }
        if key.keyCode == ansiPeriodKeyCode || chars == ":" || chars == ">" {
            guard !isEditingOverlayTextField else { return false }
            if model.isMarkdownMenuEnabled { model.applyMarkdownCommand(.blockquote) }
            return true
        }
        return false
    }

    private static func dispatchCommandOption(
        charsIgnored: String,
        model: SwiftEditWorkbenchModel,
        isEditingOverlayTextField: Bool
    ) -> Bool {
        dispatchTableEntry(
            commandOptionTable,
            key: charsIgnored,
            model: model,
            isEditingOverlayTextField: isEditingOverlayTextField
        ) ?? false
    }

    private static func dispatchCommandShiftOption(
        charsIgnored: String,
        model: SwiftEditWorkbenchModel
    ) -> Bool {
        switch charsIgnored {
        case "o":
            model.openAllFilesInFolderViaPanel()
            return true
        case "f":
            if model.safetyBanner.canFormat { model.formatActiveSection() }
            return true
        default:
            return false
        }
    }

    private static func dispatchCommandControl(
        _ key: ShortcutKeyEvent,
        charsIgnored: String,
        model: SwiftEditWorkbenchModel,
        isEditingOverlayTextField: Bool
    ) -> Bool {
        guard !isEditingOverlayTextField else { return false }
        let level: Int?
        if let digit = Int(charsIgnored), (1...6).contains(digit) {
            level = digit
        } else {
            level = headingLevelByKeyCode[key.keyCode]
        }
        guard let level else { return false }
        if model.isMarkdownMenuEnabled {
            model.applyMarkdownCommand(.heading(level: level))
        }
        return true
    }
}

extension SwiftEditShortcutDispatcher {
    private static let f7KeyCode: UInt16 = 98
    private static let upArrowKeyCode: UInt16 = 126
    private static let downArrowKeyCode: UInt16 = 125

    fileprivate static func dispatchNonCommandChord(
        _ key: ShortcutKeyEvent,
        chars: String,
        charsIgnored: String,
        model: SwiftEditWorkbenchModel,
        isEditingOverlayTextField: Bool
    ) -> Bool {
        switch key.modifiers {
        case [.option]:
            return dispatchOptionOnly(key, chars: chars, charsIgnored: charsIgnored, model: model, isEditingOverlayTextField: isEditingOverlayTextField)
        case [.option, .shift]:
            return dispatchOptionShift(chars: chars, charsIgnored: charsIgnored, model: model)
        case [.control]:
            return dispatchControlOnly(key, charsIgnored: charsIgnored, model: model, isEditingOverlayTextField: isEditingOverlayTextField)
        case [.control, .shift]:
            return dispatchControlShift(key, charsIgnored: charsIgnored, model: model, isEditingOverlayTextField: isEditingOverlayTextField)
        case []:
            return dispatchDiffHunkNavigation(key, reverse: false, model: model)
        case [.shift]:
            return dispatchDiffHunkNavigation(key, reverse: true, model: model)
        default:
            return false
        }
    }

    private static func dispatchOptionShift(
        chars: String,
        charsIgnored: String,
        model: SwiftEditWorkbenchModel
    ) -> Bool {
        guard chars == "\\" || charsIgnored == "\\" else { return false }
        return toggleNavigatorIfEligible(model: model)
    }

    private static func dispatchControlOnly(
        _ key: ShortcutKeyEvent,
        charsIgnored: String,
        model: SwiftEditWorkbenchModel,
        isEditingOverlayTextField: Bool
    ) -> Bool {
        if charsIgnored == "j", !isEditingOverlayTextField {
            model.joinActiveLines()
            return true
        }
        return dispatchControlTabOrKey(key, charsIgnored: charsIgnored, reverse: false, model: model)
    }

    private static func dispatchControlShift(
        _ key: ShortcutKeyEvent,
        charsIgnored: String,
        model: SwiftEditWorkbenchModel,
        isEditingOverlayTextField: Bool
    ) -> Bool {
        if charsIgnored == "f" {
            model.toggleFindInFolder()
            return true
        }
        if charsIgnored == "k", !isEditingOverlayTextField {
            model.deleteActiveLines()
            return true
        }
        return dispatchControlTabOrKey(key, charsIgnored: charsIgnored, reverse: true, model: model)
    }

    private static func dispatchDiffHunkNavigation(
        _ key: ShortcutKeyEvent,
        reverse: Bool,
        model: SwiftEditWorkbenchModel
    ) -> Bool {
        guard isF7FunctionKey(key), model.showDiffPane else { return false }
        if reverse {
            model.selectPreviousDiffHunk()
        } else {
            model.selectNextDiffHunk()
        }
        return true
    }

    private static func dispatchControlTabOrKey(
        _ key: ShortcutKeyEvent,
        charsIgnored: String,
        reverse: Bool,
        model: SwiftEditWorkbenchModel
    ) -> Bool {
        guard charsIgnored == "\t" || key.keyCode == 48 else { return false }
        if reverse { model.selectPreviousTab() } else { model.selectNextTab() }
        return true
    }

    private static func isF7FunctionKey(_ key: ShortcutKeyEvent) -> Bool {
        key.keyCode == f7KeyCode || key.charactersIgnoringModifiers.unicodeScalars.first?.value == UInt32(NSF7FunctionKey)
    }

    private static func toggleNavigatorIfEligible(model: SwiftEditWorkbenchModel) -> Bool {
        guard model.isNavigatorEnabled || model.navigatorState != nil else { return true }
        model.toggleDocumentNavigator()
        return true
    }

    private static func dispatchOptionOnly(
        _ key: ShortcutKeyEvent,
        chars: String,
        charsIgnored: String,
        model: SwiftEditWorkbenchModel,
        isEditingOverlayTextField: Bool
    ) -> Bool {
        if charsIgnored == "\\" || chars == "\\" || key.keyCode == ansiBackslashKeyCode {
            return toggleNavigatorIfEligible(model: model)
        }
        if charsIgnored == "1" || key.keyCode == ansiOneKeyCode {
            model.toggleDistractionFree()
            return true
        }
        if !isEditingOverlayTextField, key.keyCode == upArrowKeyCode {
            model.moveActiveLinesUp()
            return true
        }
        if !isEditingOverlayTextField, key.keyCode == downArrowKeyCode {
            model.moveActiveLinesDown()
            return true
        }
        return false
    }

    /// Rejects oversized, NUL-embedded, or BiDi/control-tainted chord strings (allowing only Return `\r` and Enter `\u{3}` control keys).
    fileprivate static func isWellFormedChordString(_ value: String) -> Bool {
        let scalars = value.unicodeScalars
        guard scalars.count <= 2 else { return false }
        for scalar in scalars {
            let v = scalar.value
            if v == 0x0D || v == 0x03 || v == 0x09 { continue }
            if v < 0x20 || v == 0x7F || (v >= 0x202A && v <= 0x202E) || (v >= 0x2066 && v <= 0x2069) {
                return false
            }
        }
        return true
    }
}
#endif
