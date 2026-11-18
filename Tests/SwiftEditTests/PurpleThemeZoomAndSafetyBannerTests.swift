import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("PurpleThemeZoomAndSafetyBannerTests")
struct PurpleThemeZoomAndSafetyBannerTests {

    @Test("P1: PurpleThemePalette resolves Concept E2 Viola tokens, inverted #FFFFFF/#000000 canvas (21:1 contrast), and EditorZoomController scales 50%..300%")
    func p1PurpleChromeTokensInvertedCanvasAndZoomScaling() throws {
        // GIVEN Light, Black, and Auto theme modes, a 14pt zoom controller, and a clean text snapshot
        let lightPalette = PurpleThemePalette.resolve(appearance: .light)
        let blackPalette = PurpleThemePalette.resolve(appearance: .black)
        let autoDarkPalette = PurpleThemePalette.resolve(appearance: .auto, systemPrefersDark: true)

        var zoom = EditorZoomController(zoomPercent: 100, baseFontSizePoints: 14.0)
        let session = DocumentSession(text: "unchanged document text")

        // WHEN applying Cmd++ (zoomIn), pinch 1.5x, togglePaneFocus, Cmd+0 (resetZoom), and evaluating clean safety state
        zoom.zoomIn()
        let afterStepPoints = zoom.scaledFontSizePoints
        zoom.applyPinchMagnification(1.5)
        let afterPinchPercent = zoom.zoomPercent
        zoom.togglePaneFocus()
        zoom.resetZoom()

        let safetyState = InspectionSafetyBannerState.evaluate(snapshot: session.snapshot)
        let httpsPrompt = try #require(InspectionSafetyBannerState.prepareExternalURIConfirmation(rawURI: "https://swift.org/documentation"))

        // THEN Concept E2 tokens (#0B0614, #7C3AED, #A78BFA, #C4B5FD), 21:1 B/W canvas, >= 4.5:1 chrome contrast, zoom scaling, and HTTPS confirmation match spec
        #expect(lightPalette.brandGround.hex == "#0B0614")
        #expect(lightPalette.primaryAccent.hex == "#7C3AED")
        #expect(lightPalette.strokeLavender.hex == "#A78BFA")
        #expect(lightPalette.featherHighlight.hex == "#C4B5FD")
        #expect(lightPalette.editorCanvasBackground.hex == "#FFFFFF")
        #expect(lightPalette.editorCanvasText.hex == "#000000")
        #expect(blackPalette.editorCanvasBackground.hex == "#000000")
        #expect(blackPalette.editorCanvasText.hex == "#FFFFFF")
        #expect(autoDarkPalette == blackPalette)
        #expect(lightPalette.editorCanvasBackground.contrastRatio(against: lightPalette.editorCanvasText) >= 20.9)
        #expect(blackPalette.editorCanvasBackground.contrastRatio(against: blackPalette.editorCanvasText) >= 20.9)
        #expect(lightPalette.chromeSurface.contrastRatio(against: lightPalette.chromeForeground) >= 4.5)
        #expect(blackPalette.chromeSurface.contrastRatio(against: blackPalette.chromeForeground) >= 4.5)
        #expect(abs(afterStepPoints - 15.4) < 0.01)
        #expect(afterPinchPercent == 165)
        #expect(zoom.isPaneFocusZoomed == true)
        #expect(zoom.zoomPercent == 100)
        #expect(session.text == "unchanged document text")
        #expect(safetyState == InspectionSafetyBannerState(
            isBinaryReadOnlyBannerVisible: false,
            canSave: true,
            canFormat: true,
            canPinTab: true,
            bidiWarnings: []
        ))
        #expect(httpsPrompt == ExternalURIConfirmationPrompt(
            scheme: "https",
            canonicalURI: "https://swift.org/documentation",
            requiresUserConfirmation: true
        ))
    }

    @Test("N1: EditorZoomController clamps zoomOut at 50% and zoomIn at 300% boundaries")
    func n1ZoomCommandsClampAt50And300PercentBoundaries() {
        // GIVEN controllers at 50%, 300%, and out-of-bounds constructor inputs
        var minZoom = EditorZoomController(zoomPercent: 50)
        var maxZoom = EditorZoomController(zoomPercent: 300)
        let underflowInit = EditorZoomController(zoomPercent: 10)
        let overflowInit = EditorZoomController(zoomPercent: 500)

        // WHEN stepping beyond bounds
        minZoom.zoomOut()
        maxZoom.zoomIn()

        // THEN all zoom percentages remain strictly clamped in 50...300
        #expect(minZoom.zoomPercent == 50)
        #expect(maxZoom.zoomPercent == 300)
        #expect(underflowInit.zoomPercent == 50)
        #expect(overflowInit.zoomPercent == 300)
    }

    @Test("N2 [Security]: InspectionSafetyBannerState locks out binary mutations, detects Trojan Source BiDi scalars, and blocks unsafe external URI schemes")
    func n2SecurityBinaryLockoutBiDiTrojanSourceAndExternalURIGate() {
        // GIVEN a binary snapshot, a Trojan Source BiDi text snapshot, and safe vs dangerous external URIs
        let binarySnapshot = DocumentSession(text: "BIN", isBinaryReadOnly: true).snapshot
        let bidiText = "let a = \u{202E}evil\n\u{2066}iso\u{061C}"
        let bidiSnapshot = DocumentSession(text: bidiText).snapshot

        // WHEN evaluating safety banners and external URI handoff prompts
        let binaryBanner = InspectionSafetyBannerState.evaluate(snapshot: binarySnapshot)
        let bidiBanner = InspectionSafetyBannerState.evaluate(snapshot: bidiSnapshot)
        let jsPrompt = InspectionSafetyBannerState.prepareExternalURIConfirmation(rawURI: "javascript:alert(1)")
        let filePrompt = InspectionSafetyBannerState.prepareExternalURIConfirmation(rawURI: "file:///etc/passwd")
        let dataPrompt = InspectionSafetyBannerState.prepareExternalURIConfirmation(rawURI: "data:text/html;base64,AA==")
        let mailtoPrompt = InspectionSafetyBannerState.prepareExternalURIConfirmation(rawURI: "mailto:security@example.com")

        // THEN binary tabs disable Save/Format/Pin, BiDi scalars emit inline badges, and unsafe schemes are blocked
        #expect(binaryBanner == InspectionSafetyBannerState(
            isBinaryReadOnlyBannerVisible: true,
            canSave: false,
            canFormat: false,
            canPinTab: false,
            bidiWarnings: []
        ))
        #expect(bidiBanner.bidiWarnings == [
            BiDiControlCharacterWarning(utf16Offset: 8, line: 1, scalarHex: "U+202E", name: "RIGHT-TO-LEFT OVERRIDE"),
            BiDiControlCharacterWarning(utf16Offset: 14, line: 2, scalarHex: "U+2066", name: "LEFT-TO-RIGHT ISOLATE"),
            BiDiControlCharacterWarning(utf16Offset: 18, line: 2, scalarHex: "U+061C", name: "ARABIC LETTER MARK"),
        ])
        #expect(jsPrompt == nil)
        #expect(filePrompt == nil)
        #expect(dataPrompt == nil)
        #expect(mailtoPrompt == ExternalURIConfirmationPrompt(
            scheme: "mailto",
            canonicalURI: "mailto:security@example.com",
            requiresUserConfirmation: true
        ))
    }
}
