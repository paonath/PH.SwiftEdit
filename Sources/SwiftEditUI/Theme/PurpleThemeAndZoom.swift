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
        let utf8 = hex.utf8
        var start = utf8.startIndex
        var end = utf8.endIndex
        while start < end && (utf8[start] == 0x20 || utf8[start] == 0x09 || utf8[start] == 0x0A || utf8[start] == 0x0D) {
            start = utf8.index(after: start)
        }
        while end > start {
            let prev = utf8.index(before: end)
            let b = utf8[prev]
            if b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D {
                end = prev
            } else {
                break
            }
        }
        if start < end && utf8[start] == 0x23 { // '#'
            start = utf8.index(after: start)
        }
        var value: UInt32 = 0
        var valid = (start < end)
        var upperBytes: [UInt8] = [0x23]
        upperBytes.reserveCapacity(7)
        var idx = start
        while idx < end {
            var b = utf8[idx]
            if b >= 0x61 && b <= 0x7A { b &= ~0x20 }
            upperBytes.append(b)
            let digit: UInt32?
            if b >= 0x30 && b <= 0x39 {
                digit = UInt32(b - 0x30)
            } else if b >= 0x41 && b <= 0x46 {
                digit = UInt32(b - 0x41 + 10)
            } else {
                digit = nil
            }
            if let d = digit, valid {
                let (shifted, ov1) = value.multipliedReportingOverflow(by: 16)
                let (sum, ov2) = shifted.addingReportingOverflow(d)
                if ov1 || ov2 { valid = false; value = 0 } else { value = sum }
            } else {
                valid = false
                value = 0
            }
            idx = utf8.index(after: idx)
        }
        return (String(decoding: upperBytes, as: UTF8.self), valid ? value : 0)
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

/// Semantic Concept E2 Feather-in-Triangle Purple (`Viola`) workspace chrome palette and `#FFFFFF`/`#000000` inverted editor canvas (`UI-001..003`, `UI-009`).
///
/// Intentionally omits `brandGround` so `SwiftEditUI` views cannot hardcode near-black `#0B0614` surfaces in Light mode (`CWE-451`).
public struct PurpleThemePalette: Equatable, Sendable {
    /// Active resolved Light or Black theme mode.
    public let mode: ResolvedThemeMode
    /// Concept E2 feather bottom anchor (`#7C3AED`).
    public let primaryAccent: RGBAColorToken
    /// Concept E2 inverted-triangle stroke anchor (`#A78BFA`).
    public let strokeLavender: RGBAColorToken
    /// Concept E2 feather top highlight anchor (`#C4B5FD`).
    public let featherHighlight: RGBAColorToken
    /// Default workspace chrome container surface (`#F5F3FF` Light, `#0B0614` Black).
    public let chromeSurface: RGBAColorToken
    /// Primary text and icon foreground across chrome and modal sheets (`#1E1035` Light, `#EDE9FE` Black, `>= 12.1:1`).
    public let chromeForeground: RGBAColorToken
    /// Pure editor canvas background (`#FFFFFF` Light, `#000000` Black, `21:1` contrast) (`UI-002`).
    public let editorCanvasBackground: RGBAColorToken
    /// Pure editor canvas primary text (`#000000` Light, `#FFFFFF` Black, `21:1` contrast) (`UI-002`).
    public let editorCanvasText: RGBAColorToken
    /// Subtle full-width current-line highlight (`#F3F0FA` Light, `#161224` Black) (`UI-002`).
    public let currentLineHighlight: RGBAColorToken
    /// Depth-indexed nested bracket pair colors verified at `>= 4.5:1` against `editorCanvasBackground` (`AR-012`, `UI-002`).
    public let nestedBracketPalette: [RGBAColorToken]
    /// Background highlight pill behind the active matched bracket pair (`UI-002`).
    public let activeBracketHighlight: RGBAColorToken
    /// Error foreground color applied to unbalanced bracket delimiters (`#991B1B` Light, `#FCA5A5` Black, `>= 6.78:1` against `unbalancedBracketBackground`, `CWE-451`, `UI-002`).
    public let unbalancedBracketHighlight: RGBAColorToken
    /// Opaque pill background paired with `unbalancedBracketHighlight` (`#FEE2E2` Light, `#450A0A` Black, `>= 6.78:1` WCAG 2.2 AA contrast) (`UI-002`, `UI-009`).
    public let unbalancedBracketBackground: RGBAColorToken
    /// Trojan Source Unicode BiDi warning text foreground (`#78350F` Light, `#FDE68A` Black, `>= 8.15:1` contrast, `CVE-2021-42574`, `CWE-451`, `UI-008`).
    public let bidiWarningForeground: RGBAColorToken
    /// Trojan Source Unicode BiDi warning banner background (`#FEF3C7` Light, `#451A03` Black, `CVE-2021-42574`, `UI-008`).
    public let bidiWarningBackground: RGBAColorToken
    /// Trojan Source Unicode BiDi warning border (`#B45309` Light, `#F59E0B` Black, `>= 4.56:1` against `chromeSurface`, `CVE-2021-42574`, `UI-008`).
    public let bidiWarningBorder: RGBAColorToken
    /// Binary read-only quarantine banner text foreground (`#7C2D12` Light, `#FED7AA` Black, `>= 8.18:1` contrast, `CWE-451`, `DATA-003`, `UI-008`).
    public let binaryQuarantineForeground: RGBAColorToken
    /// Binary read-only quarantine banner background (`#FFEDD5` Light, `#431407` Black, `DATA-003`, `UI-008`).
    public let binaryQuarantineBackground: RGBAColorToken
    /// Binary read-only quarantine banner border (`#C2410C` Light, `#FB923C` Black, `>= 4.69:1` against `chromeSurface`, `DATA-003`, `UI-008`).
    public let binaryQuarantineBorder: RGBAColorToken
    /// Inert raw-HTML preview block text foreground (`#7F1D1D` Light, `#FECACA` Black, `>= 8.17:1` contrast, `CWE-451`, `UI-006`).
    public let inertHTMLWarningForeground: RGBAColorToken
    /// Inert raw-HTML preview block background (`#FEE2E2` Light, `#450A0A` Black, `UI-006`).
    public let inertHTMLWarningBackground: RGBAColorToken
    /// Inert raw-HTML preview block border (`#DC2626` Light, `#EF4444` Black, `>= 3.0:1` against `chromeSurface`, `UI-006`).
    public let inertHTMLWarningBorder: RGBAColorToken
    /// Background tint for inline backtick code spans (`` `...` ``) (`UI-002`).
    public let backtickInlineBackground: RGBAColorToken
    /// Background tint for multiline fenced code blocks (`` ```...``` ``) (`UI-002`).
    public let backtickMultilineBackground: RGBAColorToken
    /// Accent foreground applied to inline and fenced backtick code spans (`UI-002`).
    public let backtickForeground: RGBAColorToken
    /// Muted disabled foreground for quarantined binary files in the left sidebar (`#52525B` Light, `#9CA3AF` Black) (`DATA-003`, `UI-008`).
    public let sidebarBinaryDisabledText: RGBAColorToken
    /// Top header bar surface (`#F3E8FF` Light, `#0B0614` Black).
    public let topBarSurface: RGBAColorToken
    /// Modal dialog surface for `AboutSheetView` and `KeyboardShortcutsCheatSheetView` (`#F3E8FF` Light, `#0B0614` Black).
    public let sheetSurface: RGBAColorToken
    /// Collapsible left Folder Navigator surface (`#EDE0FF` Light, `#140A24` Black).
    public let sidebarSurface: RGBAColorToken
    /// Right-column Notepad++-style tab strip surface (`#E9D5FF` Light, `#180C2C` Black).
    public let tabBarSurface: RGBAColorToken
    /// Selected editor tab background seamlessly matching `editorCanvasBackground` (`#FFFFFF` Light, `#000000` Black).
    public let tabActiveSurface: RGBAColorToken
    /// Pin badge and dirty-indicator accent on editor tabs (`#7C3AED` Light, `#C4B5FD` Black).
    public let pinnedTabBadge: RGBAColorToken
    /// Find/Replace/Go-to-Line bar surface (`0.96` alpha, clamped to `1.0` under `reduceTransparency` or `increasedContrast`).
    public let findBarSurface: RGBAColorToken
    /// Translucent header brand submenu surface (`0.90` alpha, clamped to `1.0` under `reduceTransparency` or `increasedContrast`).
    public let submenuTranslucentSurface: RGBAColorToken
    /// Left 1-based line-number gutter surface (`#F5F3FF` Light, `#0B0614` Black).
    public let gutterSurface: RGBAColorToken
    /// Inactive line-number foreground (`#5B21B6` Light, `#A78BFA` Black, `>= 6.8:1`).
    public let gutterForeground: RGBAColorToken
    /// Active caret-line number foreground (`#1E1035` Light, `#EDE9FE` Black, `>= 15.0:1`).
    public let gutterActiveForeground: RGBAColorToken
    /// Bottom status-bar surface (`#7C3AED` Light, `#2E1065` Black).
    public let statusBarSurface: RGBAColorToken
    /// Bottom status-bar text and control foreground (`#FFFFFF`, `>= 5.70:1`).
    public let statusBarForeground: RGBAColorToken
    /// Secondary chrome text and muted label foreground (`#5B21B6` Light, `#C4B5FD` Black, `>= 6.6:1`).
    public let secondaryForeground: RGBAColorToken
    /// Interactive chrome icon, focus-ring, and active-tab border accent (`#7C3AED` Light, `#A78BFA` Black, `>= 3.0:1`).
    public let chromeAccent: RGBAColorToken
    /// Prominent selected-pill and primary-button fill (`#7C3AED`).
    public let activeControlFill: RGBAColorToken
    /// Foreground paired with `activeControlFill` (`#FFFFFF`, `5.70:1`).
    public let activeControlForeground: RGBAColorToken
    /// Shortcut-badge and selector-track container surface (`#E9D5FF` Light, `#2E1065` Black).
    public let badgeSurface: RGBAColorToken
    /// `1pt` chrome separator token (`#C4B5FD` / `#3B1D6E`, stepped up to `#7C3AED` / `#A78BFA` `>= 3.0:1` under `reduceTransparency` or `increasedContrast`).
    public let hairlineBorder: RGBAColorToken
    /// Active text-selection background inside `TextKit2EditorView` (`#DDD6FE` Light, `#3B0764` Black).
    public let selectionBackground: RGBAColorToken
    /// Inserted-line background in Side-by-Side Myers Diff (`#DCFCE7` Light, `#052E16` Black).
    public let diffInsertedBackground: RGBAColorToken
    /// Removed-line background in Side-by-Side Myers Diff (`#FEE2E2` Light, `#450A0A` Black).
    public let diffRemovedBackground: RGBAColorToken
    /// YAML key foreground (`#6B7280` Light 4.83:1, `#9CA3AF` Black 8.6:1); values keep `editorCanvasText` (`REQ-010`, `UI-009`).
    public let yamlKeyForeground: RGBAColorToken
    /// Editor link/image text (`#7C3AED` Light 5.7:1, `#A78BFA` Black 7.0:1); `primaryAccent` on black was 3.69:1 (`F-017-02`).
    public let linkForeground: RGBAColorToken

    /// Returns the deterministic depth-indexed color for a matched nested bracket pair (`AR-012`).
    public func nestedBracketColor(forDepth depth: Int) -> RGBAColorToken {
        guard !nestedBracketPalette.isEmpty else { return primaryAccent }
        return nestedBracketPalette[max(0, depth) % nestedBracketPalette.count]
    }

    /// Resolves Concept E2 Purple chrome tokens, pure `#FFFFFF`/`#000000` inverted editor canvas tokens, and accessibility overrides.
    /// - Parameters:
    ///   - appearance: Requested `Light`, `Black`, or `Auto` preference mode.
    ///   - systemPrefersDark: Unmasked host OS dark-mode state consulted when `appearance == .auto`.
    ///   - reduceTransparency: Clamps `submenuTranslucentSurface` and `findBarSurface` to `1.0` alpha and steps up `hairlineBorder` contrast when `true`.
    ///   - increasedContrast: Clamps translucent chrome surfaces to `1.0` alpha and steps up `hairlineBorder` to `>= 3.0:1` when `true`.
    /// - Returns: Contrast-verified `PurpleThemePalette` value snapshot.
    private static let lightStandard: PurpleThemePalette = buildPalette(mode: .light, clampOpaque: false)
    private static let lightHighContrast: PurpleThemePalette = buildPalette(mode: .light, clampOpaque: true)
    private static let blackStandard: PurpleThemePalette = buildPalette(mode: .black, clampOpaque: false)
    private static let blackHighContrast: PurpleThemePalette = buildPalette(mode: .black, clampOpaque: true)

    public static func resolve(
        appearance: AppearanceMode,
        systemPrefersDark: Bool = true,
        reduceTransparency: Bool = false,
        increasedContrast: Bool = false
    ) -> PurpleThemePalette {
        let isBlack: Bool
        switch appearance {
        case .light: isBlack = false
        case .black: isBlack = true
        case .auto: isBlack = systemPrefersDark
        }
        let clampOpaque = reduceTransparency || increasedContrast
        switch (isBlack, clampOpaque) {
        case (false, false): return lightStandard
        case (false, true): return lightHighContrast
        case (true, false): return blackStandard
        case (true, true): return blackHighContrast
        }
    }

    private static func buildPalette(mode resolvedMode: ResolvedThemeMode, clampOpaque: Bool) -> PurpleThemePalette {
        let darkGround = RGBAColorToken(hex: SwiftEditBrandLogoGeometry.groundHex)
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
                chromeSurface: RGBAColorToken(hex: "#F5F3FF"),
                chromeForeground: RGBAColorToken(hex: "#1E1035"),
                editorCanvasBackground: RGBAColorToken(hex: "#FFFFFF"),
                editorCanvasText: RGBAColorToken(hex: "#000000"),
                currentLineHighlight: RGBAColorToken(hex: "#F3F0FA"),
                nestedBracketPalette: [
                    RGBAColorToken(hex: "#6D28D9"),
                    RGBAColorToken(hex: "#0369A1"),
                    RGBAColorToken(hex: "#047857"),
                    RGBAColorToken(hex: "#B45309"),
                ],
                activeBracketHighlight: RGBAColorToken(hex: "#EDE9FE"),
                unbalancedBracketHighlight: RGBAColorToken(hex: "#991B1B"),
                unbalancedBracketBackground: RGBAColorToken(hex: "#FEE2E2"),
                bidiWarningForeground: RGBAColorToken(hex: "#78350F"),
                bidiWarningBackground: RGBAColorToken(hex: "#FEF3C7"),
                bidiWarningBorder: RGBAColorToken(hex: "#B45309"),
                binaryQuarantineForeground: RGBAColorToken(hex: "#7C2D12"),
                binaryQuarantineBackground: RGBAColorToken(hex: "#FFEDD5"),
                binaryQuarantineBorder: RGBAColorToken(hex: "#C2410C"),
                inertHTMLWarningForeground: RGBAColorToken(hex: "#7F1D1D"),
                inertHTMLWarningBackground: RGBAColorToken(hex: "#FEE2E2"),
                inertHTMLWarningBorder: RGBAColorToken(hex: "#DC2626"),
                backtickInlineBackground: RGBAColorToken(hex: "#EDE9FE"),
                backtickMultilineBackground: RGBAColorToken(hex: "#F5F3FF"),
                backtickForeground: RGBAColorToken(hex: "#6D28D9"),
                sidebarBinaryDisabledText: RGBAColorToken(hex: "#52525B"),
                topBarSurface: RGBAColorToken(hex: "#F3E8FF"),
                sheetSurface: RGBAColorToken(hex: "#F3E8FF"),
                sidebarSurface: RGBAColorToken(hex: "#EDE0FF"),
                tabBarSurface: RGBAColorToken(hex: "#E9D5FF"),
                tabActiveSurface: RGBAColorToken(hex: "#FFFFFF"),
                pinnedTabBadge: RGBAColorToken(hex: "#7C3AED"),
                findBarSurface: RGBAColorToken(hex: "#F3E8FF", alpha: clampOpaque ? 1.0 : 0.96),
                submenuTranslucentSurface: RGBAColorToken(hex: "#F3E8FF", alpha: clampOpaque ? 1.0 : 0.90),
                gutterSurface: RGBAColorToken(hex: "#F5F3FF"),
                gutterForeground: RGBAColorToken(hex: "#5B21B6"),
                gutterActiveForeground: RGBAColorToken(hex: "#1E1035"),
                statusBarSurface: RGBAColorToken(hex: "#7C3AED"),
                statusBarForeground: RGBAColorToken(hex: "#FFFFFF"),
                secondaryForeground: RGBAColorToken(hex: "#5B21B6"),
                chromeAccent: RGBAColorToken(hex: "#7C3AED"),
                activeControlFill: RGBAColorToken(hex: "#7C3AED"),
                activeControlForeground: RGBAColorToken(hex: "#FFFFFF"),
                badgeSurface: RGBAColorToken(hex: "#E9D5FF"),
                hairlineBorder: RGBAColorToken(hex: clampOpaque ? "#7C3AED" : "#C4B5FD"),
                selectionBackground: RGBAColorToken(hex: "#DDD6FE"),
                diffInsertedBackground: RGBAColorToken(hex: "#DCFCE7"),
                diffRemovedBackground: RGBAColorToken(hex: "#FEE2E2"),
                yamlKeyForeground: RGBAColorToken(hex: "#6B7280"),
                linkForeground: RGBAColorToken(hex: "#7C3AED")
            )
        case .black:
            return PurpleThemePalette(
                mode: .black,
                primaryAccent: primaryAccent,
                strokeLavender: strokeLavender,
                featherHighlight: featherHighlight,
                chromeSurface: darkGround,
                chromeForeground: RGBAColorToken(hex: "#EDE9FE"),
                editorCanvasBackground: RGBAColorToken(hex: "#000000"),
                editorCanvasText: RGBAColorToken(hex: "#FFFFFF"),
                currentLineHighlight: RGBAColorToken(hex: "#161224"),
                nestedBracketPalette: [
                    RGBAColorToken(hex: "#C4B5FD"),
                    RGBAColorToken(hex: "#38BDF8"),
                    RGBAColorToken(hex: "#34D399"),
                    RGBAColorToken(hex: "#FBBF24"),
                ],
                activeBracketHighlight: RGBAColorToken(hex: "#2E1065"),
                unbalancedBracketHighlight: RGBAColorToken(hex: "#FCA5A5"),
                unbalancedBracketBackground: RGBAColorToken(hex: "#450A0A"),
                bidiWarningForeground: RGBAColorToken(hex: "#FDE68A"),
                bidiWarningBackground: RGBAColorToken(hex: "#451A03"),
                bidiWarningBorder: RGBAColorToken(hex: "#F59E0B"),
                binaryQuarantineForeground: RGBAColorToken(hex: "#FED7AA"),
                binaryQuarantineBackground: RGBAColorToken(hex: "#431407"),
                binaryQuarantineBorder: RGBAColorToken(hex: "#FB923C"),
                inertHTMLWarningForeground: RGBAColorToken(hex: "#FECACA"),
                inertHTMLWarningBackground: RGBAColorToken(hex: "#450A0A"),
                inertHTMLWarningBorder: RGBAColorToken(hex: "#EF4444"),
                backtickInlineBackground: RGBAColorToken(hex: "#1F1733"),
                backtickMultilineBackground: RGBAColorToken(hex: "#140F24"),
                backtickForeground: RGBAColorToken(hex: "#DDD6FE"),
                sidebarBinaryDisabledText: RGBAColorToken(hex: "#9CA3AF"),
                topBarSurface: darkGround,
                sheetSurface: darkGround,
                sidebarSurface: RGBAColorToken(hex: "#140A24"),
                tabBarSurface: RGBAColorToken(hex: "#180C2C"),
                tabActiveSurface: RGBAColorToken(hex: "#000000"),
                pinnedTabBadge: RGBAColorToken(hex: "#C4B5FD"),
                findBarSurface: RGBAColorToken(hex: "#140A24", alpha: clampOpaque ? 1.0 : 0.96),
                submenuTranslucentSurface: RGBAColorToken(hex: "#140A24", alpha: clampOpaque ? 1.0 : 0.90),
                gutterSurface: darkGround,
                gutterForeground: RGBAColorToken(hex: "#A78BFA"),
                gutterActiveForeground: RGBAColorToken(hex: "#EDE9FE"),
                statusBarSurface: RGBAColorToken(hex: "#2E1065"),
                statusBarForeground: RGBAColorToken(hex: "#FFFFFF"),
                secondaryForeground: RGBAColorToken(hex: "#C4B5FD"),
                chromeAccent: RGBAColorToken(hex: "#A78BFA"),
                activeControlFill: RGBAColorToken(hex: "#7C3AED"),
                activeControlForeground: RGBAColorToken(hex: "#FFFFFF"),
                badgeSurface: RGBAColorToken(hex: "#2E1065"),
                hairlineBorder: RGBAColorToken(hex: clampOpaque ? "#A78BFA" : "#3B1D6E"),
                selectionBackground: RGBAColorToken(hex: "#3B0764"),
                diffInsertedBackground: RGBAColorToken(hex: "#052E16"),
                diffRemovedBackground: RGBAColorToken(hex: "#450A0A"),
                yamlKeyForeground: RGBAColorToken(hex: "#9CA3AF"),
                linkForeground: RGBAColorToken(hex: "#A78BFA")
            )
        }
    }
}

/// Minimum pointer target size (WCAG 2.2 SC 2.5.8).
public enum ChromeHitTarget {
    /// WCAG 2.2 SC 2.5.8 minimum target size in points (`F-017-03`).
    public static let minimumPoints: CGFloat = 24
}

#if os(macOS)
public extension View {
    /// Expands the hit area of glyph-sized controls to at least `ChromeHitTarget.minimumPoints` without changing the glyph.
    func minimumHitTarget(_ size: CGFloat = ChromeHitTarget.minimumPoints) -> some View {
        let side = max(ChromeHitTarget.minimumPoints, size)
        return frame(minWidth: side, minHeight: side).contentShape(Rectangle())
    }
}
#endif

/// Stateless value-type controller scaling editor and left sidebar font sizes across `50%..300%` (`Cmd++`, `Cmd+-`, `Cmd+0`, pinch, pane focus) without mutating document text (`UI-004`).
public struct EditorZoomController: Equatable, Sendable {
    public static let minZoomPercent: Int = EditorPreferences.minZoomPercent
    public static let maxZoomPercent: Int = EditorPreferences.maxZoomPercent
    public static let defaultZoomPercent: Int = EditorPreferences.defaultZoomPercent
    public static let stepPercent: Int = 10

    public private(set) var zoomPercent: Int
    public let baseFontSizePoints: Double
    public let baseSidebarFontSizePoints: Double
    public private(set) var isPaneFocusZoomed: Bool

    public init(
        zoomPercent: Int = EditorZoomController.defaultZoomPercent,
        baseFontSizePoints: Double = 14.0,
        baseSidebarFontSizePoints: Double = 13.0,
        isPaneFocusZoomed: Bool = false
    ) {
        self.zoomPercent = EditorPreferences.clampZoom(zoomPercent)
        self.baseFontSizePoints = max(1.0, baseFontSizePoints)
        self.baseSidebarFontSizePoints = max(1.0, baseSidebarFontSizePoints)
        self.isPaneFocusZoomed = isPaneFocusZoomed
    }

    /// Linear scale multiplier (`0.5...3.0`) derived from `zoomPercent`.
    public var zoomScaleFactor: Double {
        Double(zoomPercent) / 100.0
    }

    /// Effective editor monospaced font point size computed from `baseFontSizePoints * (zoomPercent / 100)`.
    public var scaledFontSizePoints: Double {
        baseFontSizePoints * zoomScaleFactor
    }

    /// Effective left sidebar font point size scaled proportionally with `zoomPercent` (`50%..300%`) (`UI-004`).
    public var sidebarScaledFontSizePoints: Double {
        baseSidebarFontSizePoints * zoomScaleFactor
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
        // Fast SIMD UTF-8 pre-check: all 10 Trojan Source BiDi scalars encode with UTF-8 lead byte 0xD8 (U+061C) or 0xE2 (U+202A..202E, U+2066..2069).
        let mayContainBiDi: Bool = text.utf8.withContiguousStorageIfAvailable { buf -> Bool in
            guard let base = buf.baseAddress, !buf.isEmpty else { return false }
            let count = buf.count
            return memchr(base, 0xE2, count) != nil || memchr(base, 0xD8, count) != nil
        } ?? true
        guard mayContainBiDi else { return [] }

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

/// Shared semantic styling modifiers keeping modal sheets and `1pt` hairline borders uniform across `SwiftEditUI` views (`UI-001`, `UI-009`).
public extension View {
    /// Applies mode-resolved `sheetSurface`, `chromeForeground`, and `chromeAccent` tint to modal dialogs.
    func purpleModalSheetChrome(palette: PurpleThemePalette) -> some View {
        self
            .background(palette.sheetSurface.swiftUIColor)
            .foregroundStyle(palette.chromeForeground.swiftUIColor)
            .tint(palette.chromeAccent.swiftUIColor)
    }

    /// Renders a `1pt` horizontal or vertical `hairlineBorder` separator along `edge`.
    func purpleHairlineBorder(palette: PurpleThemePalette, edge: Edge) -> some View {
        let isVertical = (edge == .leading || edge == .trailing)
        let alignment: Alignment
        switch edge {
        case .top: alignment = .top
        case .bottom: alignment = .bottom
        case .leading: alignment = .leading
        case .trailing: alignment = .trailing
        }
        return overlay(alignment: alignment) {
            Rectangle()
                .fill(palette.hairlineBorder.swiftUIColor)
                .frame(width: isVertical ? 1 : nil, height: isVertical ? nil : 1)
        }
    }

    /// Applies an opaque high-salience security warning banner surface, foreground, and `1pt` bottom border (`CVE-2021-42574`, `CWE-451`, `UI-008`).
    func purpleSecurityWarningBanner(
        foreground: RGBAColorToken,
        background: RGBAColorToken,
        border: RGBAColorToken,
        verticalPadding: CGFloat
    ) -> some View {
        self
            .appFont(.caption, weight: .semibold)
            .foregroundStyle(foreground.swiftUIColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, verticalPadding)
            .background(background.swiftUIColor)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(border.swiftUIColor)
                    .frame(height: 1)
            }
    }
}
