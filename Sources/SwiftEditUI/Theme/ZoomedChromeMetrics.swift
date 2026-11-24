import CoreGraphics
import SwiftEditCore

/// Zoom-driven sizes for the tab strip, the left navigator and the gutter (`REQ-009`, `UI-004`, `UI-009`).
///
/// Every value is its `100%` base times the clamped zoom factor (`50%..300%`), so tabs, navigator and gutter grow and
/// shrink together with the editor text. Clickable heights and icon targets are floored at `ChromeHitTarget.minimumPoints`
/// (24 pt, WCAG 2.5.8) so `50%` zoom shrinks text but never targets.
public struct ZoomedChromeMetrics: Equatable, Sendable {
    public let factor: CGFloat

    public init(zoomPercent: Int) {
        factor = CGFloat(EditorPreferences.clampZoom(zoomPercent)) / 100
    }

    private func floored(_ base: CGFloat) -> CGFloat { max(ChromeHitTarget.minimumPoints, base * factor) }

    // Tab strip
    public var tabFontSize: CGFloat { 13 * factor }
    public var tabBadgeSize: CGFloat { 10 * factor }
    public var tabHeight: CGFloat { floored(28) }
    public var tabIconTarget: CGFloat { floored(24) }
    public var tabHorizontalPadding: CGFloat { 10 * factor }
    public var tabMinWidth: CGFloat { 80 * factor }
    public var tabMaxWidth: CGFloat { 240 * factor }
}

extension ZoomedChromeMetrics {
    // Header bar and SwiftEdit command menu (grow and shrink with the editor text, `REQ-021-03`)
    public var headerHeight: CGFloat { max(ChromeHitTarget.minimumPoints + 4, 36 * factor) }
    public var headerFontSize: CGFloat { 13 * factor }
    public var headerLogoSize: CGFloat { 20 * factor }
    public var headerIconSize: CGFloat { 15 * factor }
    public var headerIconButtonWidth: CGFloat { floored(28) }
    public var headerIconButtonHeight: CGFloat { floored(24) }
    public var menuFontSize: CGFloat { 13 * factor }
    public var menuIconSize: CGFloat { 14 * factor }
    public var menuBadgeFontSize: CGFloat { 10 * factor }
    public var menuWidth: CGFloat { 312 * factor }
}

extension ZoomedChromeMetrics {
    // Left navigator
    public var navigatorFontSize: CGFloat { 13 * factor }
    public var navigatorHeaderFontSize: CGFloat { 11.44 * factor }
    public var navigatorIconSize: CGFloat { 13 * factor }
    public var navigatorRowHeight: CGFloat { floored(24) }
    public var navigatorIndent: CGFloat { 12 * factor }

    /// Left diagnostics column (severity bar + hover dot) kept apart from the numbers (V-02).
    public static let gutterDiagnosticsColumn: CGFloat = 16
    /// Gutter width for `lineCount` lines: at least 3 digits of the editor font's digit advance (measured at 100%),
    /// the diagnostics column and the number padding.
    public func gutterWidth(lineCount: Int, digitAdvanceAt100: CGFloat) -> CGFloat {
        let digits = max(3, String(max(1, lineCount)).count)
        return factor * (CGFloat(digits) * digitAdvanceAt100 + Self.gutterDiagnosticsColumn + 14)
    }

    /// Metrics that scale strictly linearly at every zoom `>= 100%` (used by tests and goldens).
    public var scaledValues: [CGFloat] {
        [tabFontSize, tabBadgeSize, tabHeight, tabIconTarget, tabHorizontalPadding, tabMinWidth, tabMaxWidth,
         navigatorFontSize, navigatorHeaderFontSize, navigatorIconSize, navigatorRowHeight, navigatorIndent]
    }
}
