import Foundation
import SwiftEditCore
import SwiftUI
#if os(macOS)
import AppKit
#endif

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
