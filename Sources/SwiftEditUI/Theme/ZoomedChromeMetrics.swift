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

extension ZoomedChromeMetrics {
    // Markdown preview typography and spacing scaled linearly by `factor` (`50%..300%`, `REQ-003`, `UI-004`, `UI-009`).
    public var previewHeaderLabelFontSize: CGFloat { 10 * factor }
    public var previewH1FontSize: CGFloat { 22 * factor }
    public var previewH2FontSize: CGFloat { 17 * factor }
    public var previewH3FontSize: CGFloat { 15 * factor }
    public var previewBodyFontSize: CGFloat { 13 * factor }
    public var previewCodeFontSize: CGFloat { 13 * factor }
    public var previewCaptionFontSize: CGFloat { 10 * factor }
    public var previewBlockSpacing: CGFloat { 10 * factor }
    public var previewIndentStep: CGFloat { 4 * factor }
    public var previewQuoteBarWidth: CGFloat { max(2, 3 * factor) }
    public var previewThumbnailMaxWidth: CGFloat { 480 * factor }
    public var previewActionTarget: CGFloat { floored(24) }

    // Diff view & compare header scaled linearly by `factor` (`50%..300%`, `REQ-005`, `UI-004`, `UI-009`).
    public var diffFontSize: CGFloat { 13 * factor }
    public var diffHeaderFontSize: CGFloat { 12 * factor }
    public var diffHeaderBadgeFontSize: CGFloat { 10 * factor }
    public var diffLineNumberWidth: CGFloat { max(32, 40 * factor) }
    public var diffActionTarget: CGFloat { floored(24) }
}
