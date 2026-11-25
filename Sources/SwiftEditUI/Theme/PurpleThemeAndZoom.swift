import Foundation
import SwiftEditCore
import SwiftUI
#if os(macOS)
import AppKit
#endif

#if os(macOS)
/// Immutable `NSColor` container safe to share across threads (`NSColor` sRGB instances are immutable once created).
private final class CachedNSColorBox: @unchecked Sendable {
    let color: NSColor
    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.color = NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}
#endif

/// Immutable sRGB color token with pre-materialized `swiftUIColor`/`nsColor` and WCAG 2.2 relative luminance calculation (`UI-001`, `UI-002`, `UI-009`).
public struct RGBAColorToken: Equatable, Sendable {
    public let hex: String
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double
    /// Pre-materialized SwiftUI `Color` in the `.sRGB` color space preserving `alpha` (`UI-001`).
    public let swiftUIColor: Color
    #if os(macOS)
    private let cachedNSColor: CachedNSColorBox
    /// Pre-materialized AppKit `NSColor` in the `.sRGB` color space preserving `alpha` (zero allocation per read, `AR-003`, `UI-001`).
    public var nsColor: NSColor { cachedNSColor.color }
    #endif

    public init(hex: String, alpha: Double = 1.0) {
        let (canonicalHex, rawValue) = Self.parseHex(hex)
        let r = Double((rawValue >> 16) & 0xFF) / 255.0
        let g = Double((rawValue >> 8) & 0xFF) / 255.0
        let b = Double(rawValue & 0xFF) / 255.0
        self.hex = canonicalHex
        self.red = r
        self.green = g
        self.blue = b
        self.alpha = alpha
        self.swiftUIColor = Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
        #if os(macOS)
        self.cachedNSColor = CachedNSColorBox(red: r, green: g, blue: b, alpha: alpha)
        #endif
    }

    public static func == (lhs: RGBAColorToken, rhs: RGBAColorToken) -> Bool {
        lhs.hex == rhs.hex
            && lhs.red == rhs.red
            && lhs.green == rhs.green
            && lhs.blue == rhs.blue
            && lhs.alpha == rhs.alpha
    }

    private static func parseHex(_ hex: String) -> (canonical: String, rawValue: UInt32) {
        let trimmed = trimHexPayloadBytes(Array(hex.utf8))
        var value: UInt32 = 0
        var valid = !trimmed.isEmpty
        var upperBytes: [UInt8] = [0x23]
        upperBytes.reserveCapacity(7)
        for rawByte in trimmed {
            let upper = (rawByte >= 0x61 && rawByte <= 0x7A) ? (rawByte & ~0x20) : rawByte
            upperBytes.append(upper)
            value = accumulateHexNibble(upper, current: value, valid: &valid)
        }
        return (String(decoding: upperBytes, as: UTF8.self), valid ? value : 0)
    }

    private static func trimHexPayloadBytes(_ bytes: [UInt8]) -> ArraySlice<UInt8> {
        var start = 0
        var end = bytes.count
        while start < end && isHexASCIIWhitespace(bytes[start]) { start += 1 }
        while end > start && isHexASCIIWhitespace(bytes[end - 1]) { end -= 1 }
        if start < end && bytes[start] == 0x23 { start += 1 }
        return bytes[start..<end]
    }

    private static func isHexASCIIWhitespace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
    }

    private static func accumulateHexNibble(_ upperByte: UInt8, current: UInt32, valid: inout Bool) -> UInt32 {
        guard valid, let digit = decodeUpperHexDigit(upperByte) else {
            valid = false
            return 0
        }
        let (shifted, ov1) = current.multipliedReportingOverflow(by: 16)
        let (sum, ov2) = shifted.addingReportingOverflow(digit)
        guard !ov1 && !ov2 else {
            valid = false
            return 0
        }
        return sum
    }

    private static func decodeUpperHexDigit(_ upperByte: UInt8) -> UInt32? {
        if upperByte >= 0x30 && upperByte <= 0x39 { return UInt32(upperByte - 0x30) }
        if upperByte >= 0x41 && upperByte <= 0x46 { return UInt32(upperByte - 0x41 + 10) }
        return nil
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

/// Immutable Concept E2 brand logo geometry and palette specification derived from `docs/design/assets/logo-e2-refined.svg` (`UI-001`).
public struct SwiftEditBrandLogoGeometry: Equatable, Sendable {
    public static let groundHex = "#0B0614"
    public static let triangleStrokeHex = "#A78BFA"
    public static let featherTopHex = "#C4B5FD"
    public static let featherBottomHex = "#7C3AED"
    public static let viewBoxSize: Double = 512.0
    public static let cornerRadius: Double = 96.0
    public static let topBarLogoSize: Double = 20.0
    public static let aboutDialogLogoSize: Double = 84.0
}

/// Target macOS window chrome appearance applied to `NSApp.appearance` (`AR-003`, `UI-003`).
public enum MacOSWindowAppearanceTarget: String, Equatable, Sendable {
    /// Forces standard macOS Light (`NSAppearance.Name.aqua`) window titlebars, menus, and sheets.
    case aqua
    /// Forces standard macOS Dark (`NSAppearance.Name.darkAqua`) window titlebars, menus, and sheets.
    case darkAqua
    /// Clears `NSApp.appearance` (`nil`) so macOS host automatic appearance governs chrome surfaces.
    case systemAutomatic
}

#if os(macOS)
/// `@MainActor` bridge synchronizing `NSApp.appearance` and reading unmasked host OS interface style (`AR-003`, `UI-003`, `UI-005`).
///
/// Guards `NSApp.activationPolicy() == .regular` before mutating `NSApp.appearance` so headless parallel `Swift Testing` processes (`NSApp == nil` or `.prohibited`) remain side-effect-free (`TEST-003`).
@MainActor
public enum MacOSAppearanceSynchronizer {
    /// Maps an `AppearanceMode` to its deterministic `MacOSWindowAppearanceTarget`.
    public static func target(for appearance: AppearanceMode) -> MacOSWindowAppearanceTarget {
        switch appearance {
        case .light: return .aqua
        case .black: return .darkAqua
        case .auto: return .systemAutomatic
        }
    }

    /// Maps an `AppearanceMode` to an explicit `NSAppearance.Name` (`nil` when `.auto` delegates to the host OS).
    public static func nsAppearanceName(for appearance: AppearanceMode) -> NSAppearance.Name? {
        switch appearance {
        case .light: return .aqua
        case .black: return .darkAqua
        case .auto: return nil
        }
    }

    /// Synchronizes `NSApp.appearance` when running inside a regular GUI application process and returns the resolved target (`UI-003`).
    @discardableResult
    public static func synchronizeApplicationAppearance(for appearance: AppearanceMode) -> MacOSWindowAppearanceTarget {
        let resolvedTarget = target(for: appearance)
        guard let app = NSApp, app.activationPolicy() == .regular else {
            return resolvedTarget
        }
        app.appearance = nsAppearanceName(for: appearance).flatMap { NSAppearance(named: $0) }
        return resolvedTarget
    }

    /// Reads the unmasked host macOS `AppleInterfaceStyle` global preference (`true` when `"Dark"`, `false` when Light) without being shadowed by `NSApp.appearance` or SwiftUI `.preferredColorScheme` overrides (`UI-003`).
    public static func readUnmaskedSystemPrefersDark(userDefaults: UserDefaults = .standard) -> Bool {
        (userDefaults.string(forKey: "AppleInterfaceStyle") ?? "") == "Dark"
    }
}
#endif

/// Concrete Light or Black presentation mode resolved from `AppearanceMode` (`UI-001`, `UI-003`).
public enum ResolvedThemeMode: String, Equatable, Sendable {
    case light
    case black
}

/// Safety, Trojan Source BiDi, binary quarantine, and raw-HTML warning banner tokens (`UI-006`, `UI-008`, `DATA-003`).
public struct PurpleWarningBannerPalette: Equatable, Sendable {
    public let bidiWarningForeground: RGBAColorToken
    public let bidiWarningBackground: RGBAColorToken
    public let bidiWarningBorder: RGBAColorToken
    public let binaryQuarantineForeground: RGBAColorToken
    public let binaryQuarantineBackground: RGBAColorToken
    public let binaryQuarantineBorder: RGBAColorToken
    public let inertHTMLWarningForeground: RGBAColorToken
    public let inertHTMLWarningBackground: RGBAColorToken
    public let inertHTMLWarningBorder: RGBAColorToken
    public let sidebarBinaryDisabledText: RGBAColorToken
}

/// Editor syntax, bracket-pair, backtick, word-occurrence, and Myers diff canvas tokens (`AR-012`, `UI-002`, `UI-009`).
public struct PurpleEditorSyntaxPalette: Equatable, Sendable {
    public let nestedBracketPalette: [RGBAColorToken]
    public let activeBracketHighlight: RGBAColorToken
    public let unbalancedBracketHighlight: RGBAColorToken
    public let unbalancedBracketBackground: RGBAColorToken
    public let backtickInlineBackground: RGBAColorToken
    public let backtickMultilineBackground: RGBAColorToken
    public let backtickForeground: RGBAColorToken
    public let wordOccurrenceBackground: RGBAColorToken
    public let wordOccurrenceUnderline: RGBAColorToken
    public let diffInsertedBackground: RGBAColorToken
    public let diffRemovedBackground: RGBAColorToken
    public let yamlKeyForeground: RGBAColorToken
    public let linkForeground: RGBAColorToken
}

/// Log viewer severity and structured token foreground/background colors (`>= 4.5:1` contrast on editor canvas).
public struct PurpleLogSyntaxPalette: Equatable, Sendable {
    public let logTraceForeground: RGBAColorToken
    public let logDebugForeground: RGBAColorToken
    public let logInfoForeground: RGBAColorToken
    public let logWarnForeground: RGBAColorToken
    public let logErrorForeground: RGBAColorToken
    public let logCriticalForeground: RGBAColorToken
    public let logCriticalBackground: RGBAColorToken
    public let logTimestampForeground: RGBAColorToken
    public let logGuidForeground: RGBAColorToken
    public let logStringForeground: RGBAColorToken
    public let logExceptionForeground: RGBAColorToken
}

/// Workspace container, header, sheet, sidebar, tab-strip, find-bar, and submenu surface tokens grouped out of `PurpleThemePalette` (`UI-001..003`).
public struct PurpleChromeSurfacesPalette: Equatable, Sendable {
    public let chromeSurface: RGBAColorToken
    public let chromeForeground: RGBAColorToken
    public let topBarSurface: RGBAColorToken
    public let sheetSurface: RGBAColorToken
    public let sidebarSurface: RGBAColorToken
    public let tabBarSurface: RGBAColorToken
    public let tabActiveSurface: RGBAColorToken
    public let pinnedTabBadge: RGBAColorToken
    public let findBarSurface: RGBAColorToken
    public let submenuTranslucentSurface: RGBAColorToken
}

/// Gutter, status bar, badge, border, and selection tokens grouped out of `PurpleThemePalette` (`UI-001..003`).
public struct PurpleChromeControlsPalette: Equatable, Sendable {
    public let gutterSurface: RGBAColorToken
    public let gutterForeground: RGBAColorToken
    public let gutterActiveForeground: RGBAColorToken
    public let statusBarSurface: RGBAColorToken
    public let statusBarForeground: RGBAColorToken
    public let secondaryForeground: RGBAColorToken
    public let badgeSurface: RGBAColorToken
    public let hairlineBorder: RGBAColorToken
    public let selectionBackground: RGBAColorToken
    public let selectionForeground: RGBAColorToken
    public let accentSoftSurface: RGBAColorToken
}

/// Semantic Concept E2 Feather-in-Triangle Purple (`Viola`) workspace chrome palette and `#FFFFFF`/`#000000` inverted editor canvas (`UI-001..003`, `UI-009`).
///
/// Intentionally omits `brandGround` so `SwiftEditUI` views cannot hardcode near-black `#0B0614` surfaces in Light mode (`CWE-451`).
/// Groups chrome-surface, chrome-control, warning, editor-syntax, and log-syntax sub-palettes (`<= 20` members per block) while exposing flat token properties via extensions.
public struct PurpleThemePalette: Equatable, Sendable {
    /// Active resolved Light or Black theme mode.
    public let mode: ResolvedThemeMode
    /// Concept E2 feather bottom anchor (`#7C3AED`).
    public let primaryAccent: RGBAColorToken
    /// Concept E2 inverted-triangle stroke anchor (`#A78BFA`).
    public let strokeLavender: RGBAColorToken
    /// Concept E2 feather top highlight anchor (`#C4B5FD`).
    public let featherHighlight: RGBAColorToken
    /// Pure editor canvas background (`#FFFFFF` Light, `#000000` Black, `21:1` contrast) (`UI-002`).
    public let editorCanvasBackground: RGBAColorToken
    /// Pure editor canvas primary text (`#000000` Light, `#FFFFFF` Black, `21:1` contrast) (`UI-002`).
    public let editorCanvasText: RGBAColorToken
    /// Subtle full-width current-line highlight (`#F3F0FA` Light, `#161224` Black) (`UI-002`).
    public let currentLineHighlight: RGBAColorToken
    /// Interactive chrome icon, focus-ring, and active-tab border accent (`#7C3AED` Light, `#A78BFA` Black, `>= 3.0:1`).
    public let chromeAccent: RGBAColorToken
    /// Prominent selected-pill and primary-button fill (`#7C3AED`).
    public let activeControlFill: RGBAColorToken
    /// Foreground paired with `activeControlFill` (`#FFFFFF`, `5.70:1`).
    public let activeControlForeground: RGBAColorToken
    /// Grouped workspace container, header, sheet, sidebar, tab, find-bar, and submenu surfaces (`UI-001..003`).
    public let surfaces: PurpleChromeSurfacesPalette
    /// Grouped gutter, status bar, badge, border, and selection tokens (`UI-001..003`).
    public let controls: PurpleChromeControlsPalette
    /// Grouped safety and quarantine warning banner tokens (`UI-006`, `UI-008`, `DATA-003`).
    public let warnings: PurpleWarningBannerPalette
    /// Grouped editor syntax, bracket, backtick, occurrence, and diff tokens (`UI-002`, `UI-009`).
    public let syntax: PurpleEditorSyntaxPalette
    /// Grouped log viewer severity and structured highlight tokens.
    public let logs: PurpleLogSyntaxPalette
    /// Selectable Base16/Tinted-Theming-inspired semantic syntax color palette (`UI-002`, `UI-009`).
    public let syntaxColors: SyntaxColorSchemePalette
}

/// Backward-compatible flat accessors for workspace chrome surface tokens (`UI-001..003`).
public extension PurpleThemePalette {
    var chromeSurface: RGBAColorToken { surfaces.chromeSurface }
    var chromeForeground: RGBAColorToken { surfaces.chromeForeground }
    var topBarSurface: RGBAColorToken { surfaces.topBarSurface }
    var sheetSurface: RGBAColorToken { surfaces.sheetSurface }
    var sidebarSurface: RGBAColorToken { surfaces.sidebarSurface }
    var tabBarSurface: RGBAColorToken { surfaces.tabBarSurface }
    var tabActiveSurface: RGBAColorToken { surfaces.tabActiveSurface }
    var pinnedTabBadge: RGBAColorToken { surfaces.pinnedTabBadge }
    var findBarSurface: RGBAColorToken { surfaces.findBarSurface }
    var submenuTranslucentSurface: RGBAColorToken { surfaces.submenuTranslucentSurface }
}

/// Backward-compatible flat accessors for chrome control, gutter, status bar, and selection tokens (`UI-001..003`).
public extension PurpleThemePalette {
    var gutterSurface: RGBAColorToken { controls.gutterSurface }
    var gutterForeground: RGBAColorToken { controls.gutterForeground }
    var gutterActiveForeground: RGBAColorToken { controls.gutterActiveForeground }
    var statusBarSurface: RGBAColorToken { controls.statusBarSurface }
    var statusBarForeground: RGBAColorToken { controls.statusBarForeground }
    var secondaryForeground: RGBAColorToken { controls.secondaryForeground }
    var badgeSurface: RGBAColorToken { controls.badgeSurface }
    var hairlineBorder: RGBAColorToken { controls.hairlineBorder }
    var selectionBackground: RGBAColorToken { controls.selectionBackground }
    var selectionForeground: RGBAColorToken { controls.selectionForeground }
    var accentSoftSurface: RGBAColorToken { controls.accentSoftSurface }
}

/// Backward-compatible flat accessors for warning banner tokens (`UI-006`, `UI-008`, `DATA-003`).
public extension PurpleThemePalette {
    var bidiWarningForeground: RGBAColorToken { warnings.bidiWarningForeground }
    var bidiWarningBackground: RGBAColorToken { warnings.bidiWarningBackground }
    var bidiWarningBorder: RGBAColorToken { warnings.bidiWarningBorder }
    var binaryQuarantineForeground: RGBAColorToken { warnings.binaryQuarantineForeground }
    var binaryQuarantineBackground: RGBAColorToken { warnings.binaryQuarantineBackground }
    var binaryQuarantineBorder: RGBAColorToken { warnings.binaryQuarantineBorder }
    var inertHTMLWarningForeground: RGBAColorToken { warnings.inertHTMLWarningForeground }
    var inertHTMLWarningBackground: RGBAColorToken { warnings.inertHTMLWarningBackground }
    var inertHTMLWarningBorder: RGBAColorToken { warnings.inertHTMLWarningBorder }
    var sidebarBinaryDisabledText: RGBAColorToken { warnings.sidebarBinaryDisabledText }
}

/// Backward-compatible flat accessors for editor syntax, bracket, backtick, occurrence, and diff tokens (`UI-002`, `UI-009`).
public extension PurpleThemePalette {
    var nestedBracketPalette: [RGBAColorToken] { syntax.nestedBracketPalette }
    var activeBracketHighlight: RGBAColorToken { syntax.activeBracketHighlight }
    var unbalancedBracketHighlight: RGBAColorToken { syntax.unbalancedBracketHighlight }
    var unbalancedBracketBackground: RGBAColorToken { syntax.unbalancedBracketBackground }
    var backtickInlineBackground: RGBAColorToken { syntax.backtickInlineBackground }
    var backtickMultilineBackground: RGBAColorToken { syntax.backtickMultilineBackground }
    var backtickForeground: RGBAColorToken { syntax.backtickForeground }
    var wordOccurrenceBackground: RGBAColorToken { syntax.wordOccurrenceBackground }
    var wordOccurrenceUnderline: RGBAColorToken { syntax.wordOccurrenceUnderline }
    var diffInsertedBackground: RGBAColorToken { syntax.diffInsertedBackground }
    var diffRemovedBackground: RGBAColorToken { syntax.diffRemovedBackground }
    var yamlKeyForeground: RGBAColorToken { syntax.yamlKeyForeground }
    var linkForeground: RGBAColorToken { syntax.linkForeground }
}

/// Log syntax token accessors, nested bracket lookup, and cached Light/Black palette resolution (`UI-001..003`, `UI-009`).
public extension PurpleThemePalette {
    var logTraceForeground: RGBAColorToken { logs.logTraceForeground }
    var logDebugForeground: RGBAColorToken { logs.logDebugForeground }
    var logInfoForeground: RGBAColorToken { logs.logInfoForeground }
    var logWarnForeground: RGBAColorToken { logs.logWarnForeground }
    var logErrorForeground: RGBAColorToken { logs.logErrorForeground }
    var logCriticalForeground: RGBAColorToken { logs.logCriticalForeground }
    var logCriticalBackground: RGBAColorToken { logs.logCriticalBackground }
    var logTimestampForeground: RGBAColorToken { logs.logTimestampForeground }
    var logGuidForeground: RGBAColorToken { logs.logGuidForeground }
    var logStringForeground: RGBAColorToken { logs.logStringForeground }
    var logExceptionForeground: RGBAColorToken { logs.logExceptionForeground }

    /// Returns the deterministic depth-indexed color for a matched nested bracket pair (`AR-012`).
    func nestedBracketColor(forDepth depth: Int) -> RGBAColorToken {
        guard !nestedBracketPalette.isEmpty else { return primaryAccent }
        return nestedBracketPalette[max(0, depth) % nestedBracketPalette.count]
    }

    private static let lightStandard: PurpleThemePalette = buildPalette(mode: .light, clampOpaque: false)
    private static let lightHighContrast: PurpleThemePalette = buildPalette(mode: .light, clampOpaque: true)
    private static let blackStandard: PurpleThemePalette = buildPalette(mode: .black, clampOpaque: false)
    private static let blackHighContrast: PurpleThemePalette = buildPalette(mode: .black, clampOpaque: true)

    /// Resolves Concept E2 Purple chrome tokens, pure `#FFFFFF`/`#000000` inverted editor canvas tokens, semantic syntax color scheme, and accessibility overrides.
    static func resolve(
        appearance: AppearanceMode,
        systemPrefersDark: Bool = true,
        reduceTransparency: Bool = false,
        increasedContrast: Bool = false,
        syntaxColorScheme: SyntaxColorScheme = .swiftEditDefault
    ) -> PurpleThemePalette {
        let isBlack: Bool
        switch appearance {
        case .light: isBlack = false
        case .black: isBlack = true
        case .auto: isBlack = systemPrefersDark
        }
        let clampOpaque = reduceTransparency || increasedContrast
        let base: PurpleThemePalette
        switch (isBlack, clampOpaque) {
        case (false, false): base = lightStandard
        case (false, true): base = lightHighContrast
        case (true, false): base = blackStandard
        case (true, true): base = blackHighContrast
        }
        guard syntaxColorScheme != .swiftEditDefault else { return base }
        return base.withSyntaxColorScheme(syntaxColorScheme)
    }

    /// Returns a copy of this palette with `scheme` applied to semantic syntax color tokens (`UI-003`).
    func withSyntaxColorScheme(_ scheme: SyntaxColorScheme) -> PurpleThemePalette {
        PurpleThemePalette(
            mode: mode,
            primaryAccent: primaryAccent,
            strokeLavender: strokeLavender,
            featherHighlight: featherHighlight,
            editorCanvasBackground: editorCanvasBackground,
            editorCanvasText: editorCanvasText,
            currentLineHighlight: currentLineHighlight,
            chromeAccent: chromeAccent,
            activeControlFill: activeControlFill,
            activeControlForeground: activeControlForeground,
            surfaces: surfaces,
            controls: controls,
            warnings: warnings,
            syntax: syntax,
            logs: logs,
            syntaxColors: SyntaxColorSchemePalette.resolve(scheme: scheme, mode: mode)
        )
    }

    private static func buildPalette(mode resolvedMode: ResolvedThemeMode, clampOpaque: Bool) -> PurpleThemePalette {
        let primaryAccent = RGBAColorToken(hex: SwiftEditBrandLogoGeometry.featherBottomHex)
        let strokeLavender = RGBAColorToken(hex: SwiftEditBrandLogoGeometry.triangleStrokeHex)
        let featherHighlight = RGBAColorToken(hex: SwiftEditBrandLogoGeometry.featherTopHex)

        switch resolvedMode {
        case .light:
            return PurpleThemePalette(
                mode: .light,
                primaryAccent: primaryAccent,
                strokeLavender: strokeLavender,
                featherHighlight: featherHighlight,
                editorCanvasBackground: RGBAColorToken(hex: "#FFFFFF"),
                editorCanvasText: RGBAColorToken(hex: "#000000"),
                currentLineHighlight: RGBAColorToken(hex: "#F3F0FA"),
                chromeAccent: RGBAColorToken(hex: "#7C3AED"),
                activeControlFill: RGBAColorToken(hex: "#7C3AED"),
                activeControlForeground: RGBAColorToken(hex: "#FFFFFF"),
                surfaces: PurpleChromeSurfacesPalette(
                    chromeSurface: RGBAColorToken(hex: "#F6F5F9"),
                    chromeForeground: RGBAColorToken(hex: "#1C1A22"),
                    topBarSurface: RGBAColorToken(hex: "#F6F5F9"),
                    sheetSurface: RGBAColorToken(hex: "#F8F7FA"),
                    sidebarSurface: RGBAColorToken(hex: "#F3F2F7"),
                    tabBarSurface: RGBAColorToken(hex: "#EFEDF4"),
                    tabActiveSurface: RGBAColorToken(hex: "#FFFFFF"),
                    pinnedTabBadge: RGBAColorToken(hex: "#7C3AED"),
                    findBarSurface: RGBAColorToken(hex: "#F6F5F9", alpha: clampOpaque ? 1.0 : 0.96),
                    submenuTranslucentSurface: RGBAColorToken(hex: "#FFFFFF", alpha: clampOpaque ? 1.0 : 0.94)
                ),
                controls: PurpleChromeControlsPalette(
                    gutterSurface: RGBAColorToken(hex: "#F1F0F4"),
                    gutterForeground: RGBAColorToken(hex: "#6E6A7A"),
                    gutterActiveForeground: RGBAColorToken(hex: "#1C1A22"),
                    statusBarSurface: RGBAColorToken(hex: "#F6F5F9"),
                    statusBarForeground: RGBAColorToken(hex: "#5E5A6B"),
                    secondaryForeground: RGBAColorToken(hex: "#5E5A6B"),
                    badgeSurface: RGBAColorToken(hex: "#ECEAF1"),
                    hairlineBorder: RGBAColorToken(hex: clampOpaque ? "#858191" : "#E3E0EA"),
                    selectionBackground: RGBAColorToken(hex: "#6D28D9"),
                    selectionForeground: RGBAColorToken(hex: "#FFFFFF"),
                    accentSoftSurface: RGBAColorToken(hex: "#EDE7FD")
                ),
                warnings: PurpleWarningBannerPalette(
                    bidiWarningForeground: RGBAColorToken(hex: "#78350F"),
                    bidiWarningBackground: RGBAColorToken(hex: "#FEF3C7"),
                    bidiWarningBorder: RGBAColorToken(hex: "#B45309"),
                    binaryQuarantineForeground: RGBAColorToken(hex: "#7C2D12"),
                    binaryQuarantineBackground: RGBAColorToken(hex: "#FFEDD5"),
                    binaryQuarantineBorder: RGBAColorToken(hex: "#C2410C"),
                    inertHTMLWarningForeground: RGBAColorToken(hex: "#7F1D1D"),
                    inertHTMLWarningBackground: RGBAColorToken(hex: "#FEE2E2"),
                    inertHTMLWarningBorder: RGBAColorToken(hex: "#DC2626"),
                    sidebarBinaryDisabledText: RGBAColorToken(hex: "#52525B")
                ),
                syntax: PurpleEditorSyntaxPalette(
                    nestedBracketPalette: [
                        RGBAColorToken(hex: "#6D28D9"),
                        RGBAColorToken(hex: "#0369A1"),
                        RGBAColorToken(hex: "#047857"),
                        RGBAColorToken(hex: "#B45309"),
                    ],
                    activeBracketHighlight: RGBAColorToken(hex: "#EDE9FE"),
                    unbalancedBracketHighlight: RGBAColorToken(hex: "#991B1B"),
                    unbalancedBracketBackground: RGBAColorToken(hex: "#FEE2E2"),
                    backtickInlineBackground: RGBAColorToken(hex: "#F7F0D4"),
                    backtickMultilineBackground: RGBAColorToken(hex: "#FBF6E2"),
                    backtickForeground: RGBAColorToken(hex: "#3F2E00"),
                    wordOccurrenceBackground: RGBAColorToken(hex: "#DDD6FE"),
                    wordOccurrenceUnderline: RGBAColorToken(hex: "#7C3AED", alpha: clampOpaque ? 1.0 : 0.75),
                    diffInsertedBackground: RGBAColorToken(hex: "#DCFCE7"),
                    diffRemovedBackground: RGBAColorToken(hex: "#FEE2E2"),
                    yamlKeyForeground: RGBAColorToken(hex: "#6B7280"),
                    linkForeground: RGBAColorToken(hex: "#7C3AED")
                ),
                logs: PurpleLogSyntaxPalette(
                    logTraceForeground: RGBAColorToken(hex: "#6B7280"),
                    logDebugForeground: RGBAColorToken(hex: "#0E7490"),
                    logInfoForeground: RGBAColorToken(hex: "#15803D"),
                    logWarnForeground: RGBAColorToken(hex: "#B45309"),
                    logErrorForeground: RGBAColorToken(hex: "#B91C1C"),
                    logCriticalForeground: RGBAColorToken(hex: "#FFFFFF"),
                    logCriticalBackground: RGBAColorToken(hex: "#B91C1C"),
                    logTimestampForeground: RGBAColorToken(hex: "#1D4ED8"),
                    logGuidForeground: RGBAColorToken(hex: "#6D28D9"),
                    logStringForeground: RGBAColorToken(hex: "#9D174D"),
                    logExceptionForeground: RGBAColorToken(hex: "#C2410C")
                ),
                syntaxColors: SyntaxColorSchemePalette.resolve(scheme: .swiftEditDefault, mode: .light)
            )
        case .black:
            return PurpleThemePalette(
                mode: .black,
                primaryAccent: primaryAccent,
                strokeLavender: strokeLavender,
                featherHighlight: featherHighlight,
                editorCanvasBackground: RGBAColorToken(hex: "#000000"),
                editorCanvasText: RGBAColorToken(hex: "#FFFFFF"),
                currentLineHighlight: RGBAColorToken(hex: "#161224"),
                chromeAccent: RGBAColorToken(hex: "#A78BFA"),
                activeControlFill: RGBAColorToken(hex: "#7C3AED"),
                activeControlForeground: RGBAColorToken(hex: "#FFFFFF"),
                surfaces: PurpleChromeSurfacesPalette(
                    chromeSurface: RGBAColorToken(hex: "#100E14"),
                    chromeForeground: RGBAColorToken(hex: "#ECEAF2"),
                    topBarSurface: RGBAColorToken(hex: "#100E14"),
                    sheetSurface: RGBAColorToken(hex: "#121017"),
                    sidebarSurface: RGBAColorToken(hex: "#0C0B10"),
                    tabBarSurface: RGBAColorToken(hex: "#16131C"),
                    tabActiveSurface: RGBAColorToken(hex: "#000000"),
                    pinnedTabBadge: RGBAColorToken(hex: "#C4B5FD"),
                    findBarSurface: RGBAColorToken(hex: "#121017", alpha: clampOpaque ? 1.0 : 0.96),
                    submenuTranslucentSurface: RGBAColorToken(hex: "#16131C", alpha: clampOpaque ? 1.0 : 0.94)
                ),
                controls: PurpleChromeControlsPalette(
                    gutterSurface: RGBAColorToken(hex: "#121117"),
                    gutterForeground: RGBAColorToken(hex: "#8A8597"),
                    gutterActiveForeground: RGBAColorToken(hex: "#FFFFFF"),
                    statusBarSurface: RGBAColorToken(hex: "#100E14"),
                    statusBarForeground: RGBAColorToken(hex: "#A29EAE"),
                    secondaryForeground: RGBAColorToken(hex: "#A29EAE"),
                    badgeSurface: RGBAColorToken(hex: "#221E2A"),
                    hairlineBorder: RGBAColorToken(hex: clampOpaque ? "#6F6A7E" : "#25212D"),
                    selectionBackground: RGBAColorToken(hex: "#A78BFA"),
                    selectionForeground: RGBAColorToken(hex: "#000000"),
                    accentSoftSurface: RGBAColorToken(hex: "#241B3A")
                ),
                warnings: PurpleWarningBannerPalette(
                    bidiWarningForeground: RGBAColorToken(hex: "#FDE68A"),
                    bidiWarningBackground: RGBAColorToken(hex: "#451A03"),
                    bidiWarningBorder: RGBAColorToken(hex: "#F59E0B"),
                    binaryQuarantineForeground: RGBAColorToken(hex: "#FED7AA"),
                    binaryQuarantineBackground: RGBAColorToken(hex: "#431407"),
                    binaryQuarantineBorder: RGBAColorToken(hex: "#FB923C"),
                    inertHTMLWarningForeground: RGBAColorToken(hex: "#FECACA"),
                    inertHTMLWarningBackground: RGBAColorToken(hex: "#450A0A"),
                    inertHTMLWarningBorder: RGBAColorToken(hex: "#EF4444"),
                    sidebarBinaryDisabledText: RGBAColorToken(hex: "#9CA3AF")
                ),
                syntax: PurpleEditorSyntaxPalette(
                    nestedBracketPalette: [
                        RGBAColorToken(hex: "#C4B5FD"),
                        RGBAColorToken(hex: "#38BDF8"),
                        RGBAColorToken(hex: "#34D399"),
                        RGBAColorToken(hex: "#FBBF24"),
                    ],
                    activeBracketHighlight: RGBAColorToken(hex: "#2E1065"),
                    unbalancedBracketHighlight: RGBAColorToken(hex: "#FCA5A5"),
                    unbalancedBracketBackground: RGBAColorToken(hex: "#450A0A"),
                    backtickInlineBackground: RGBAColorToken(hex: "#24221C"),
                    backtickMultilineBackground: RGBAColorToken(hex: "#17150F"),
                    backtickForeground: RGBAColorToken(hex: "#F6E5A8"),
                    wordOccurrenceBackground: RGBAColorToken(hex: "#3B1D6E"),
                    wordOccurrenceUnderline: RGBAColorToken(hex: "#C4B5FD", alpha: clampOpaque ? 1.0 : 0.75),
                    diffInsertedBackground: RGBAColorToken(hex: "#052E16"),
                    diffRemovedBackground: RGBAColorToken(hex: "#450A0A"),
                    yamlKeyForeground: RGBAColorToken(hex: "#9CA3AF"),
                    linkForeground: RGBAColorToken(hex: "#A78BFA")
                ),
                logs: PurpleLogSyntaxPalette(
                    logTraceForeground: RGBAColorToken(hex: "#9CA3AF"),
                    logDebugForeground: RGBAColorToken(hex: "#22D3EE"),
                    logInfoForeground: RGBAColorToken(hex: "#4ADE80"),
                    logWarnForeground: RGBAColorToken(hex: "#FBBF24"),
                    logErrorForeground: RGBAColorToken(hex: "#F87171"),
                    logCriticalForeground: RGBAColorToken(hex: "#FFFFFF"),
                    logCriticalBackground: RGBAColorToken(hex: "#991B1B"),
                    logTimestampForeground: RGBAColorToken(hex: "#60A5FA"),
                    logGuidForeground: RGBAColorToken(hex: "#A78BFA"),
                    logStringForeground: RGBAColorToken(hex: "#F9A8D4"),
                    logExceptionForeground: RGBAColorToken(hex: "#FB923C")
                ),
                syntaxColors: SyntaxColorSchemePalette.resolve(scheme: .swiftEditDefault, mode: .black)
            )
        }
    }
}
