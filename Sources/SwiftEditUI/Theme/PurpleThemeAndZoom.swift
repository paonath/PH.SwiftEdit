import Foundation
import SwiftEditCore

/// Immutable sRGB color token with WCAG 2.2 relative luminance and contrast ratio calculation (`UI-001`, `UI-002`, `UI-009`).
public struct RGBAColorToken: Equatable, Sendable {
    public let hex: String
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(hex: String, alpha: Double = 1.0) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let digits = sanitized.hasPrefix("#") ? String(sanitized.dropFirst()) : sanitized
        let rawValue = UInt32(digits, radix: 16) ?? 0
        self.hex = "#\(digits)"
        self.red = Double((rawValue >> 16) & 0xFF) / 255.0
        self.green = Double((rawValue >> 8) & 0xFF) / 255.0
        self.blue = Double(rawValue & 0xFF) / 255.0
        self.alpha = alpha
    }

    /// WCAG 2.2 relative luminance (`0.0` pure black to `1.0` pure white).
    public var relativeLuminance: Double {
        0.2126 * Self.linearize(red) + 0.7152 * Self.linearize(green) + 0.0722 * Self.linearize(blue)
    }

    /// WCAG 2.2 contrast ratio (`1.0` to `21.0`) between `self` and `other` (`UI-009`).
    public func contrastRatio(against other: RGBAColorToken) -> Double {
        let l1 = relativeLuminance
        let l2 = other.relativeLuminance
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    private static func linearize(_ channel: Double) -> Double {
        channel <= 0.04045 ? (channel / 12.92) : pow((channel + 0.055) / 1.055, 2.4)
    }
}

/// Concrete Light or Black presentation mode resolved from `AppearanceMode` (`UI-001`, `UI-003`).
public enum ResolvedThemeMode: String, Equatable, Sendable {
    case light
    case black
}

/// Semantic Concept E2 Feather-in-Triangle Purple (`Viola`) workspace chrome palette and `#FFFFFF`/`#000000` inverted editor canvas (`UI-001..003`, `UI-009`).
public struct PurpleThemePalette: Equatable, Sendable {
    public let mode: ResolvedThemeMode
    public let brandGround: RGBAColorToken
    public let primaryAccent: RGBAColorToken
    public let strokeLavender: RGBAColorToken
    public let featherHighlight: RGBAColorToken
    public let chromeSurface: RGBAColorToken
    public let chromeForeground: RGBAColorToken
    public let editorCanvasBackground: RGBAColorToken
    public let editorCanvasText: RGBAColorToken

    /// Resolves Concept E2 Purple chrome tokens and pure `#FFFFFF`/`#000000` inverted editor canvas tokens for `appearance`.
    public static func resolve(
        appearance: AppearanceMode,
        systemPrefersDark: Bool = true
    ) -> PurpleThemePalette {
        let resolvedMode: ResolvedThemeMode
        switch appearance {
        case .light: resolvedMode = .light
        case .black: resolvedMode = .black
        case .auto: resolvedMode = systemPrefersDark ? .black : .light
        }

        let brandGround = RGBAColorToken(hex: "#0B0614")
        let primaryAccent = RGBAColorToken(hex: "#7C3AED")
        let strokeLavender = RGBAColorToken(hex: "#A78BFA")
        let featherHighlight = RGBAColorToken(hex: "#C4B5FD")

        switch resolvedMode {
        case .light:
            return PurpleThemePalette(
                mode: .light,
                brandGround: brandGround,
                primaryAccent: primaryAccent,
                strokeLavender: strokeLavender,
                featherHighlight: featherHighlight,
                chromeSurface: RGBAColorToken(hex: "#F5F3FF"),
                chromeForeground: RGBAColorToken(hex: "#1E1035"),
                editorCanvasBackground: RGBAColorToken(hex: "#FFFFFF"),
                editorCanvasText: RGBAColorToken(hex: "#000000")
            )
        case .black:
            return PurpleThemePalette(
                mode: .black,
                brandGround: brandGround,
                primaryAccent: primaryAccent,
                strokeLavender: strokeLavender,
                featherHighlight: featherHighlight,
                chromeSurface: brandGround,
                chromeForeground: RGBAColorToken(hex: "#EDE9FE"),
                editorCanvasBackground: RGBAColorToken(hex: "#000000"),
                editorCanvasText: RGBAColorToken(hex: "#FFFFFF")
            )
        }
    }
}

/// Stateless value-type controller scaling editor monospaced font size across `50%..300%` (`Cmd++`, `Cmd+-`, `Cmd+0`, pinch, pane focus) without mutating document text (`UI-004`).
public struct EditorZoomController: Equatable, Sendable {
    public static let minZoomPercent: Int = EditorPreferences.minZoomPercent
    public static let maxZoomPercent: Int = EditorPreferences.maxZoomPercent
    public static let defaultZoomPercent: Int = EditorPreferences.defaultZoomPercent
    public static let stepPercent: Int = 10

    public private(set) var zoomPercent: Int
    public let baseFontSizePoints: Double
    public private(set) var isPaneFocusZoomed: Bool

    public init(
        zoomPercent: Int = EditorZoomController.defaultZoomPercent,
        baseFontSizePoints: Double = 14.0,
        isPaneFocusZoomed: Bool = false
    ) {
        self.zoomPercent = EditorPreferences.clampZoom(zoomPercent)
        self.baseFontSizePoints = max(1.0, baseFontSizePoints)
        self.isPaneFocusZoomed = isPaneFocusZoomed
    }

    /// Effective monospaced font point size computed from `baseFontSizePoints * (zoomPercent / 100)`.
    public var scaledFontSizePoints: Double {
        baseFontSizePoints * (Double(zoomPercent) / 100.0)
    }

    /// Executes `Cmd++` (`+10%`), clamped at `300%`.
    public mutating func zoomIn() {
        zoomPercent = EditorPreferences.clampZoom(zoomPercent + Self.stepPercent)
    }

    /// Executes `Cmd+-` (`-10%`), clamped at `50%`.
    public mutating func zoomOut() {
        zoomPercent = EditorPreferences.clampZoom(zoomPercent - Self.stepPercent)
    }

    /// Executes `Cmd+0` (`100%`).
    public mutating func resetZoom() {
        zoomPercent = Self.defaultZoomPercent
    }

    /// Applies a trackpad pinch magnification multiplier (`> 0`), rounded and clamped into `50%..300%`.
    public mutating func applyPinchMagnification(_ factor: Double) {
        guard factor > 0 else { return }
        let scaled = Int((Double(zoomPercent) * factor).rounded())
        zoomPercent = EditorPreferences.clampZoom(scaled)
    }

    /// Toggles distraction-free pane focus zoom without mutating buffer text.
    public mutating func togglePaneFocus() {
        isPaneFocusZoomed.toggle()
    }
}

/// Inline warning descriptor emitted when Unicode bidirectional control characters are present (`UI-008`).
public struct BiDiControlCharacterWarning: Equatable, Sendable {
    public let utf16Offset: Int
    public let line: Int
    public let scalarHex: String
    public let name: String

    public init(utf16Offset: Int, line: Int, scalarHex: String, name: String) {
        self.utf16Offset = utf16Offset
        self.line = line
        self.scalarHex = scalarHex
        self.name = name
    }
}

/// Canonicalized external URI handoff descriptor requiring user confirmation before opening (`UI-008`, `SEC-004`).
public struct ExternalURIConfirmationPrompt: Equatable, Sendable {
    public let scheme: String
    public let canonicalURI: String
    public let requiresUserConfirmation: Bool

    public init(scheme: String, canonicalURI: String, requiresUserConfirmation: Bool) {
        self.scheme = scheme
        self.canonicalURI = canonicalURI
        self.requiresUserConfirmation = requiresUserConfirmation
    }
}

/// Evaluates UI safety banner state and external URI confirmation prompts for an inspected `DocumentSnapshot` (`UI-008`, `DATA-003`, `SEC-004`, `SEC-012`).
///
/// Security invariants:
/// - Binary read-only buffers (`isBinaryReadOnly == true`) display a prominent read-only warning banner and disable `canSave`, `canFormat`, and `canPinTab`.
/// - Scans text buffers for Trojan Source Unicode bidirectional control scalars (`U+202A..U+202E`, `U+2066..U+2069`, `U+061C`, `CWE-1007`) and emits exact UTF-16 offset badges.
/// - Restricts external URI handoff exclusively to canonicalized `https`, `http`, and `mailto` targets with mandatory user confirmation (`SEC-004`).
public struct InspectionSafetyBannerState: Equatable, Sendable {
    public static let allowedExternalSchemes: Set<String> = MarkdownLintAndFormatEngine.allowedLinkSchemes

    public let isBinaryReadOnlyBannerVisible: Bool
    public let canSave: Bool
    public let canFormat: Bool
    public let canPinTab: Bool
    public let bidiWarnings: [BiDiControlCharacterWarning]

    public static func evaluate(snapshot: DocumentSnapshot) -> InspectionSafetyBannerState {
        if snapshot.isBinaryReadOnly {
            return InspectionSafetyBannerState(
                isBinaryReadOnlyBannerVisible: true,
                canSave: false,
                canFormat: false,
                canPinTab: false,
                bidiWarnings: []
            )
        }
        let warnings = scanBiDiControlScalars(in: snapshot.text)
        return InspectionSafetyBannerState(
            isBinaryReadOnlyBannerVisible: false,
            canSave: true,
            canFormat: !snapshot.isDegradedPlainText,
            canPinTab: true,
            bidiWarnings: warnings
        )
    }

    public static func prepareExternalURIConfirmation(rawURI: String) -> ExternalURIConfirmationPrompt? {
        let trimmed = rawURI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              allowedExternalSchemes.contains(scheme),
              let canonical = components.url?.absoluteString else {
            return nil
        }
        if (scheme == "https" || scheme == "http"), (components.host ?? "").isEmpty {
            return nil
        }
        if scheme == "mailto", components.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        return ExternalURIConfirmationPrompt(
            scheme: scheme,
            canonicalURI: canonical,
            requiresUserConfirmation: true
        )
    }

    private static func scanBiDiControlScalars(in text: String) -> [BiDiControlCharacterWarning] {
        var warnings: [BiDiControlCharacterWarning] = []
        let scalars = text.unicodeScalars
        var index = scalars.startIndex
        var utf16Offset = 0
        var line = 1

        while index < scalars.endIndex {
            let scalar = scalars[index]
            if let descriptor = bidiDescriptor(for: scalar.value) {
                warnings.append(BiDiControlCharacterWarning(
                    utf16Offset: utf16Offset,
                    line: line,
                    scalarHex: descriptor.hex,
                    name: descriptor.name
                ))
            }
            if scalar.value == 0x0A {
                line += 1
            } else if scalar.value == 0x0D {
                let nextIndex = scalars.index(after: index)
                if nextIndex == scalars.endIndex || scalars[nextIndex].value != 0x0A {
                    line += 1
                }
            }
            utf16Offset += scalar.utf16.count
            index = scalars.index(after: index)
        }
        return warnings
    }

    private static func bidiDescriptor(for value: UInt32) -> (hex: String, name: String)? {
        switch value {
        case 0x202A: return ("U+202A", "LEFT-TO-RIGHT EMBEDDING")
        case 0x202B: return ("U+202B", "RIGHT-TO-LEFT EMBEDDING")
        case 0x202C: return ("U+202C", "POP DIRECTIONAL FORMATTING")
        case 0x202D: return ("U+202D", "LEFT-TO-RIGHT OVERRIDE")
        case 0x202E: return ("U+202E", "RIGHT-TO-LEFT OVERRIDE")
        case 0x2066: return ("U+2066", "LEFT-TO-RIGHT ISOLATE")
        case 0x2067: return ("U+2067", "RIGHT-TO-LEFT ISOLATE")
        case 0x2068: return ("U+2068", "FIRST STRONG ISOLATE")
        case 0x2069: return ("U+2069", "POP DIRECTIONAL ISOLATE")
        case 0x061C: return ("U+061C", "ARABIC LETTER MARK")
        default: return nil
        }
    }
}
