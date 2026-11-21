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

    /// Evaluates `key` against the active `SwiftEditWorkbenchModel`; returns `true` when consumed.
    public static func dispatch(
        _ key: ShortcutKeyEvent,
        model: SwiftEditWorkbenchModel,
        isEditingOverlayTextField: Bool = false
    ) -> Bool {
        let chars = key.characters.lowercased()
        let charsIgnored = key.charactersIgnoringModifiers.lowercased()

        switch key.modifiers {
        case [.option]:
            return dispatchOptionOnly(key, chars: chars, charsIgnored: charsIgnored, model: model)
        case [.option, .shift]:
            if chars == "\\" || charsIgnored == "\\" {
                return toggleNavigatorIfEligible(model: model)
            }
            return false
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

    private static func toggleNavigatorIfEligible(model: SwiftEditWorkbenchModel) -> Bool {
        guard model.isNavigatorEnabled || model.navigatorState != nil else { return true }
        model.toggleDocumentNavigator()
        return true
    }

    private static func dispatchOptionOnly(
        _ key: ShortcutKeyEvent,
        chars: String,
        charsIgnored: String,
        model: SwiftEditWorkbenchModel
    ) -> Bool {
        if charsIgnored == "\\" || chars == "\\" || key.keyCode == ansiBackslashKeyCode {
            return toggleNavigatorIfEligible(model: model)
        }
        if charsIgnored == "1" || key.keyCode == ansiOneKeyCode {
            model.toggleDistractionFree()
            return true
        }
        return false
    }

    private static func dispatchCommandOnly(
        _ key: ShortcutKeyEvent,
        chars: String,
        charsIgnored: String,
        model: SwiftEditWorkbenchModel,
        isEditingOverlayTextField: Bool
    ) -> Bool {
        switch charsIgnored {
        case "n":
            model.newUntitledTab()
            return true
        case "o":
            model.openFileViaPanel()
            return true
        case "s":
            if model.safetyBanner.canSave { model.saveActiveDocument() }
            return true
        case "w":
            model.requestCloseActiveTab()
            return true
        case "f":
            model.presentFindBar(mode: .find)
            return true
        case "g":
            model.presentFindBar(mode: .goToLine)
            return true
        case "b":
            model.toggleLeftSidebar()
            return true
        case "+", "=":
            model.zoomController.zoomIn()
            return true
        case "-":
            model.zoomController.zoomOut()
            return true
        case "0":
            model.zoomController.resetZoom()
            return true
        case "p":
            model.toggleMarkdownPreview()
            return true
        case "/":
            model.isCheatSheetPresented = true
            return true
        case "d":
            guard !isEditingOverlayTextField else { return false }
            if model.safetyBanner.canSave { model.performCommandD() }
            return true
        case "i":
            guard !isEditingOverlayTextField else { return false }
            if model.isMarkdownMenuEnabled { model.applyMarkdownCommand(.italic) }
            return true
        case "e":
            guard !isEditingOverlayTextField else { return false }
            if model.isMarkdownMenuEnabled { model.applyMarkdownCommand(.inlineCode) }
            return true
        case "k":
            guard !isEditingOverlayTextField else { return false }
            if model.isMarkdownMenuEnabled { model.applyMarkdownCommand(.link) }
            return true
        default:
            if key.keyCode == numpadPlusKeyCode {
                model.zoomController.zoomIn()
                return true
            }
            if key.keyCode == numpadMinusKeyCode {
                model.zoomController.zoomOut()
                return true
            }
            if key.keyCode == numpadZeroKeyCode {
                model.zoomController.resetZoom()
                return true
            }
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
        switch charsIgnored {
        case "o":
            model.openFolderViaPanel()
            return true
        case "s":
            if model.safetyBanner.canSave { model.saveActiveDocumentAsViaPanel() }
            return true
        case "f":
            if model.safetyBanner.canFormat { model.formatActiveDocument() }
            return true
        case "b":
            guard !isEditingOverlayTextField else { return false }
            if model.isMarkdownMenuEnabled { model.applyMarkdownCommand(.bold) }
            return true
        case "x":
            guard !isEditingOverlayTextField else { return false }
            if model.isMarkdownMenuEnabled { model.applyMarkdownCommand(.strikethrough) }
            return true
        case "c":
            guard !isEditingOverlayTextField else { return false }
            if model.isMarkdownMenuEnabled { model.applyMarkdownCommand(.codeFence) }
            return true
        case "i":
            guard !isEditingOverlayTextField else { return false }
            if model.isMarkdownMenuEnabled { model.applyMarkdownCommand(.image) }
            return true
        case "l":
            guard !isEditingOverlayTextField else { return false }
            if model.isMarkdownMenuEnabled { model.applyMarkdownCommand(.taskToggle) }
            return true
        case ".", ">":
            guard !isEditingOverlayTextField else { return false }
            if model.isMarkdownMenuEnabled { model.applyMarkdownCommand(.blockquote) }
            return true
        case "m":
            guard !isEditingOverlayTextField else { return false }
            if model.isMarkdownMenuEnabled { model.toggleDiagnosticsPopover() }
            return true
        default:
            if key.keyCode == ansiPeriodKeyCode || chars == ":" || chars == ">" {
                guard !isEditingOverlayTextField else { return false }
                if model.isMarkdownMenuEnabled { model.applyMarkdownCommand(.blockquote) }
                return true
            }
            return false
        }
    }

    private static func dispatchCommandOption(
        charsIgnored: String,
        model: SwiftEditWorkbenchModel,
        isEditingOverlayTextField: Bool
    ) -> Bool {
        switch charsIgnored {
        case "f":
            model.presentFindBar(mode: .findAndReplace)
            return true
        case "t":
            guard !isEditingOverlayTextField else { return false }
            if model.isMarkdownMenuEnabled { model.applyMarkdownCommand(.insertTable) }
            return true
        default:
            return false
        }
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
#endif
