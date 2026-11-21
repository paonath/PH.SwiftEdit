import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("ZoomedChromeMetricsTests")
@MainActor
struct ZoomedChromeMetricsTests {
    private static let advance: CGFloat = 8.4

    @Test("P9: tabs, navigator and gutter scale linearly at 150% and 200%")
    func p9LinearScaling() {
        // GIVEN metrics at 100%, 150% and 200%
        let base = ZoomedChromeMetrics(zoomPercent: 100)
        let mid = ZoomedChromeMetrics(zoomPercent: 150)
        let double = ZoomedChromeMetrics(zoomPercent: 200)
        // WHEN the base values and scaled values are compared
        // THEN the 100% values match the spec and every metric is scaled by the factor
        #expect(base.tabFontSize == 13 && base.tabHeight == 28 && base.navigatorRowHeight == 24)
        #expect(double.tabFontSize == 26 && double.tabHeight == 56 && double.navigatorRowHeight == 48)
        #expect(double.gutterWidth(lineCount: 999, digitAdvanceAt100: Self.advance) == 2 * base.gutterWidth(lineCount: 999, digitAdvanceAt100: Self.advance))
        #expect(mid.scaledValues == base.scaledValues.map { $0 * 1.5 })
    }

    @Test("N9: extreme zoom clamps and 50% keeps 24 pt targets")
    func n9ClampsAndTargetFloor() {
        // GIVEN zoom requests below, at and above the supported range
        let tiny = ZoomedChromeMetrics(zoomPercent: 20)
        let half = ZoomedChromeMetrics(zoomPercent: 50)
        let huge = ZoomedChromeMetrics(zoomPercent: 500)
        // WHEN metrics are computed
        // THEN values clamp to 50% / 300% and hit targets never drop below 24 pt
        #expect(tiny == half)
        #expect(huge == ZoomedChromeMetrics(zoomPercent: 300))
        #expect(half.tabHeight >= 24 && half.tabIconTarget >= 24 && half.navigatorRowHeight >= 24)
        #expect(half.tabFontSize == 6.5)
    }

    @Test("P7 (swifteditui) / P12 (editor-ux): the workbench zoom drives editor, tabs, navigator, sidebar font and gutter together")
    func p7p12WorkbenchZoomDrivesChrome() {
        // GIVEN a workbench with three tabs at 100%
        let (model, dir) = YAMLWorkbenchHarness.makeModel(opening: [("a.md", "a"), ("b.md", "b"), ("c.md", "c")])
        defer { try? FileManager.default.removeItem(at: dir) }
        let base = model.chromeMetrics
        let baseEditor = model.zoomController.scaledFontSizePoints
        // WHEN zoom reaches 150% and then 200% through the zoom commands
        for _ in 0..<5 { model.zoomController.zoomIn() }
        let mid = model.chromeMetrics
        let sidebarFont = model.zoomController.sidebarScaledFontSizePoints
        for _ in 0..<5 { model.zoomController.zoomIn() }
        let double = model.chromeMetrics
        // THEN all chrome metrics follow the editor font factor
        #expect(mid.scaledValues == base.scaledValues.map { $0 * 1.5 })
        #expect(sidebarFont == 19.5)
        #expect(model.zoomController.scaledFontSizePoints == 2 * baseEditor)
        #expect(double.tabFontSize == 2 * base.tabFontSize && double.navigatorRowHeight == 2 * base.navigatorRowHeight)
    }

    @Test("N11 (swifteditui) / N14 (editor-ux): OpenDyslexic keeps 21:1 canvas contrast and 50% keeps 24 pt rows while text halves")
    func n11n14ContrastAndFloor() {
        // GIVEN OpenDyslexic as editor font and zoom at 50%
        let typography = AppTypography(editor: .openDyslexic)
        let light = PurpleThemePalette.resolve(appearance: .light, systemPrefersDark: false)
        let black = PurpleThemePalette.resolve(appearance: .black, systemPrefersDark: true)
        let half = ZoomedChromeMetrics(zoomPercent: 50)
        // WHEN fonts, contrast and metrics are evaluated
        // THEN contrast stays 21:1, the editor font is OpenDyslexic, and targets stay >= 24 pt with half-size text
        #expect(typography.nsFont(.editor, size: 14).familyName == "OpenDyslexic")
        #expect(light.editorCanvasText.contrastRatio(against: light.editorCanvasBackground) == 21.0)
        #expect(black.editorCanvasText.contrastRatio(against: black.editorCanvasBackground) == 21.0)
        #expect(half.navigatorRowHeight == 24 && half.tabHeight == 24 && half.navigatorFontSize == 6.5)
    }
}
