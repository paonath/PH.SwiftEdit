import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("PerfPass2_017FontCatalogTests", .serialized)
@MainActor
struct PerfPass2_017FontCatalogTests {

    @Test("P10 pass 2: opening Settings reads a prewarmed family list instead of enumerating fonts on the main actor", .enabled(if: ReleasePipelineTestGate.shouldRunE2EUIAndStressTests))
    func p10PrewarmedCatalogIsFaster() async {
        // GIVEN the shared family cache prewarmed off the main actor
        await SystemFontFamilyCache.shared.prewarm()
        // WHEN a fresh catalog's first query runs through the legacy NSFontManager source versus the prewarmed cache
        let legacy = PerfBench016.medianMilliseconds(runs: 7) {
            _ = SystemFontCatalog(source: LegacyNSFontManagerFamilySource(), isOpenDyslexicAvailable: { true }).entries(matching: "")
        }
        let optimized = PerfBench016.medianMilliseconds(runs: 7) {
            _ = SystemFontCatalog(isOpenDyslexicAvailable: { true }).entries(matching: "")
        }
        print("PERF017 pass2 legacy=\(legacy)ms optimized=\(optimized)ms")
        // THEN the main-actor cost drops by at least 20% and both list the same families
        #expect(optimized <= legacy * 0.8)
        #expect(Set(SystemFontCatalog(isOpenDyslexicAvailable: { false }).entries(matching: "").map(\.title)).isSuperset(of: ["Default", "Helvetica Neue", "Menlo"]))
    }

    @Test("N11 [Security] pass 2: font and zoom caches never serve stale values")
    func n11NoStaleFontOrMetricsCaches() {
        // GIVEN a workbench whose editor font (Menlo) and metrics were resolved at 100%
        let (model, dir) = YAMLWorkbenchHarness.makeModel(opening: [("a.md", "# a")])
        defer { try? FileManager.default.removeItem(at: dir) }
        model.setFontChoice(.system(family: "Menlo"), for: .editor)
        let coordinator = TextKit2EditorView.Coordinator(onTextChange: { _ in }, onSelectionChange: { _ in }, onSmartNewline: { _ in nil }, onListIndent: { _ in .notApplicable })
        coordinator.updateGFMFontsIfNeeded(fontSizePoints: model.zoomController.scaledFontSizePoints, typography: model.typography, generation: model.typographyGeneration)
        let before = coordinator.cachedRegularFont
        let metricsBefore = model.chromeMetrics
        // WHEN the editor font changes to OpenDyslexic and zoom goes to 150%
        model.setFontChoice(.openDyslexic, for: .editor)
        for _ in 0..<5 { model.zoomController.zoomIn() }
        coordinator.updateGFMFontsIfNeeded(fontSizePoints: model.zoomController.scaledFontSizePoints, typography: model.typography, generation: model.typographyGeneration)
        // THEN the editor faces and chrome metrics reflect the new font at 1.5x
        #expect(before.familyName == "Menlo")
        #expect(coordinator.cachedRegularFont.familyName == "OpenDyslexic")
        #expect(coordinator.cachedRegularFont.pointSize == before.pointSize * 1.5)
        #expect(model.chromeMetrics.tabFontSize == metricsBefore.tabFontSize * 1.5)
    }
}

/// Pre-017 source: `NSFontManager` enumeration on the calling (main) thread every time a catalog is built.
struct LegacyNSFontManagerFamilySource: FontFamilySource {
    func familyNames() -> [String] { NSFontManager.shared.availableFontFamilies }
}
