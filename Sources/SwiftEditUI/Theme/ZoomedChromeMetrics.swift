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

    // Left navigator
    public var navigatorFontSize: CGFloat { 13 * factor }
    public var navigatorHeaderFontSize: CGFloat { 11.44 * factor }
    public var navigatorIconSize: CGFloat { 13 * factor }
    public var navigatorRowHeight: CGFloat { floored(24) }
    public var navigatorIndent: CGFloat { 12 * factor }

    /// Gutter width for `lineCount` lines: at least 3 digits of the editor font's digit advance (measured at 100%) plus padding.
    public func gutterWidth(lineCount: Int, digitAdvanceAt100: CGFloat) -> CGFloat {
        let digits = max(3, String(max(1, lineCount)).count)
        return factor * (CGFloat(digits) * digitAdvanceAt100 + 20)
    }

    /// Metrics that scale strictly linearly at every zoom `>= 100%` (used by tests and goldens).
    public var scaledValues: [CGFloat] {
        [tabFontSize, tabBadgeSize, tabHeight, tabIconTarget, tabHorizontalPadding, tabMinWidth, tabMaxWidth,
         navigatorFontSize, navigatorHeaderFontSize, navigatorIconSize, navigatorRowHeight, navigatorIndent]
    }
}
