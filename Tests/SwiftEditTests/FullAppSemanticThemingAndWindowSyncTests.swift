import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("FullAppSemanticThemingAndWindowSyncTests")
struct FullAppSemanticThemingAndWindowSyncTests {

    private static var repoRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test("P3: ArchitectureImportScanner.scanSwiftEditUIViewsDirectory returns zero violations on clean semantic view code")
    func p3CleanSemanticViewDirectoryPassesStaticThemeTokenAudit() throws {
        // GIVEN a temporary Views directory containing only semantic PurpleThemePalette token references and comments
        let tempDir = Self.repoRootURL
            .appendingPathComponent(".tmp/test-results/clean-views-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let cleanViewSource = """
        import SwiftUI

        // Historical note: replaces legacy #0B0614 brandGround surface with topBarSurface
        /* Block comment mentioning Color(.sRGB and NSColor(srgbRed: */
        struct SampleHeaderView: View {
            let palette: PurpleThemePalette
            var body: some View {
                Text("PH.SwiftEdit")
                    .foregroundStyle(palette.chromeForeground.swiftUIColor)
                    .background(palette.topBarSurface.swiftUIColor)
            }
        }
        """
        let viewFileURL = tempDir.appendingPathComponent("SampleHeaderView.swift")
        try cleanViewSource.write(to: viewFileURL, atomically: true, encoding: .utf8)

        // WHEN auditing the directory with scanSwiftEditUIViewsDirectory
        let violations = try ArchitectureImportScanner.scanSwiftEditUIViewsDirectory(at: tempDir)

        // THEN zero ArchitectureFitnessViolation items are returned
        #expect(violations.isEmpty)
    }

    @Test(
        "N4 [Security]: ArchitectureImportScanner.scanSwiftEditUIThemeTokens rejects brandGround, raw 6-digit hex literals, Color(.sRGB, and NSColor(srgbRed:",
        arguments: [
            ("let bg = palette.brandGround", "brandGround"),
            ("let rawHex = \"#0B0614\"", "#0B0614"),
            ("let inlineColor = Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)", "Color(.sRGB"),
            ("let inlineNSColor = NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)", "NSColor(srgbRed:"),
        ]
    )
    func n4ForbiddenViewColorConstructsFailClosed(snippetLine: String, expectedToken: String) {
        // GIVEN a SwiftEditUI view snippet containing a forbidden non-semantic color construct
        let snippet = """
        import SwiftUI
        struct RogueView {
            func render() {
                \(snippetLine)
            }
        }
        """

        // WHEN scanning the view snippet via scanSwiftEditUIThemeTokens
        let violations = ArchitectureImportScanner.scanSwiftEditUIThemeTokens(
            content: snippet,
            filePath: "Sources/SwiftEditUI/Views/RogueView.swift"
        )

        // THEN fail-closed ArchitectureFitnessViolation is reported naming the file and forbidden token
        #expect(!violations.isEmpty)
        #expect(violations.first?.filePath == "Sources/SwiftEditUI/Views/RogueView.swift")
        #expect(violations.first?.reason.contains(expectedToken) == true)
    }

    @Test("P1 & P6: PurpleThemePalette resolves Section 3 Light/Black semantic role tokens, 21:1 canvas, >= 4.5:1 text, >= 3.0:1 UI contrast, and excludes brandGround")
    func p1AndP6SemanticRolePaletteHexAnchorsContrastAndNoBrandGround() {
        // GIVEN PurpleThemePalette resolved for Light and Black modes with default accessibility flags
        let light = PurpleThemePalette.resolve(appearance: .light, reduceTransparency: false, increasedContrast: false)
        let black = PurpleThemePalette.resolve(appearance: .black, reduceTransparency: false, increasedContrast: false)

        let lightMemberNames = Set(Mirror(reflecting: light).children.compactMap(\.label))

        // WHEN / THEN brandGround is absent from PurpleThemePalette and all Section 3 Light/Black hex anchors & WCAG floors hold
        #expect(!lightMemberNames.contains("brandGround"))
        #expect(light.topBarSurface.hex == "#F6F5F9")
        #expect(light.sheetSurface.hex == "#F8F7FA")
        #expect(light.sidebarSurface.hex == "#F3F2F7")
        #expect(light.tabBarSurface.hex == "#EFEDF4")
        #expect(light.tabActiveSurface.hex == "#FFFFFF")
        #expect(light.pinnedTabBadge.hex == "#7C3AED")
        #expect(light.gutterSurface.hex == "#F1F0F4")
        #expect(light.gutterForeground.hex == "#6E6A7A")
        #expect(light.statusBarSurface.hex == "#F6F5F9")
        #expect(light.statusBarForeground.hex == "#5E5A6B")
        #expect(light.secondaryForeground.hex == "#5E5A6B")
        #expect(light.chromeAccent.hex == "#7C3AED")
        #expect(light.selectionBackground.hex == "#6D28D9")
        #expect(light.selectionForeground.hex == "#FFFFFF")
        #expect(light.wordOccurrenceBackground.hex == "#DDD6FE")
        #expect(light.diffInsertedBackground.hex == "#DCFCE7")
        #expect(light.diffRemovedBackground.hex == "#FEE2E2")
        #expect(light.editorCanvasBackground.hex == "#FFFFFF")
        #expect(light.editorCanvasText.hex == "#000000")

        #expect(black.topBarSurface.hex == "#100E14")
        #expect(black.sheetSurface.hex == "#121017")
        #expect(black.sidebarSurface.hex == "#0C0B10")
        #expect(black.tabBarSurface.hex == "#16131C")
        #expect(black.tabActiveSurface.hex == "#000000")
        #expect(black.pinnedTabBadge.hex == "#C4B5FD")
        #expect(black.gutterSurface.hex == "#121117")
        #expect(black.gutterForeground.hex == "#8A8597")
        #expect(black.statusBarSurface.hex == "#100E14")
        #expect(black.statusBarForeground.hex == "#A29EAE")
        #expect(black.secondaryForeground.hex == "#A29EAE")
        #expect(black.chromeAccent.hex == "#A78BFA")
        #expect(black.selectionBackground.hex == "#A78BFA")
        #expect(black.selectionForeground.hex == "#000000")
        #expect(black.wordOccurrenceBackground.hex == "#3B1D6E")
        #expect(black.diffInsertedBackground.hex == "#052E16")
        #expect(black.diffRemovedBackground.hex == "#450A0A")
        #expect(black.editorCanvasBackground.hex == "#000000")
        #expect(black.editorCanvasText.hex == "#FFFFFF")

        #expect(light.editorCanvasBackground.contrastRatio(against: light.editorCanvasText) >= 20.9)
        #expect(black.editorCanvasBackground.contrastRatio(against: black.editorCanvasText) >= 20.9)
        #expect(light.chromeForeground.contrastRatio(against: light.topBarSurface) >= 4.5)
        #expect(light.chromeForeground.contrastRatio(against: light.sidebarSurface) >= 4.5)
        #expect(light.chromeForeground.contrastRatio(against: light.tabBarSurface) >= 4.5)
        #expect(light.chromeForeground.contrastRatio(against: light.sheetSurface) >= 4.5)
        #expect(light.secondaryForeground.contrastRatio(against: light.topBarSurface) >= 4.5)
        #expect(light.secondaryForeground.contrastRatio(against: light.sidebarSurface) >= 4.5)
        #expect(light.secondaryForeground.contrastRatio(against: light.sheetSurface) >= 4.5)
        #expect(light.gutterForeground.contrastRatio(against: light.gutterSurface) >= 4.5)
        #expect(light.gutterActiveForeground.contrastRatio(against: light.gutterSurface) >= 4.5)
        #expect(light.statusBarForeground.contrastRatio(against: light.statusBarSurface) >= 4.5)
        #expect(light.activeControlForeground.contrastRatio(against: light.activeControlFill) >= 4.5)
        #expect(light.chromeAccent.contrastRatio(against: light.topBarSurface) >= 3.0)
        #expect(light.chromeAccent.contrastRatio(against: light.sidebarSurface) >= 3.0)
        #expect(light.chromeAccent.contrastRatio(against: light.tabBarSurface) >= 3.0)
        #expect(light.nestedBracketPalette.allSatisfy { $0.contrastRatio(against: light.editorCanvasBackground) >= 4.5 })

        #expect(black.chromeForeground.contrastRatio(against: black.topBarSurface) >= 4.5)
        #expect(black.chromeForeground.contrastRatio(against: black.sidebarSurface) >= 4.5)
        #expect(black.chromeForeground.contrastRatio(against: black.tabBarSurface) >= 4.5)
        #expect(black.chromeForeground.contrastRatio(against: black.sheetSurface) >= 4.5)
        #expect(black.secondaryForeground.contrastRatio(against: black.topBarSurface) >= 4.5)
        #expect(black.secondaryForeground.contrastRatio(against: black.sidebarSurface) >= 4.5)
        #expect(black.secondaryForeground.contrastRatio(against: black.sheetSurface) >= 4.5)
        #expect(black.gutterForeground.contrastRatio(against: black.gutterSurface) >= 4.5)
        #expect(black.gutterActiveForeground.contrastRatio(against: black.gutterSurface) >= 4.5)
        #expect(black.statusBarForeground.contrastRatio(against: black.statusBarSurface) >= 4.5)
        #expect(black.activeControlForeground.contrastRatio(against: black.activeControlFill) >= 4.5)
        #expect(black.chromeAccent.contrastRatio(against: black.topBarSurface) >= 3.0)
        #expect(black.chromeAccent.contrastRatio(against: black.sidebarSurface) >= 3.0)
        #expect(black.chromeAccent.contrastRatio(against: black.tabBarSurface) >= 3.0)
    }

    @Test(
        "N1: reduceTransparency or increasedContrast clamps submenuTranslucentSurface and findBarSurface to 1.0 alpha and steps up hairlineBorder >= 3.0:1",
        arguments: [
            (AppearanceMode.light, true, false),
            (AppearanceMode.light, false, true),
            (AppearanceMode.black, true, false),
            (AppearanceMode.black, false, true),
        ]
    )
    func n1ReduceTransparencyOrIncreasedContrastClampsAlphaAndStepsUpBorders(
        mode: AppearanceMode,
        reduceTransparency: Bool,
        increasedContrast: Bool
    ) {
        // GIVEN PurpleThemePalette resolved with reduceTransparency or increasedContrast enabled
        let palette = PurpleThemePalette.resolve(
            appearance: mode,
            reduceTransparency: reduceTransparency,
            increasedContrast: increasedContrast
        )

        // WHEN / THEN translucent surfaces clamp alpha to 1.0 and hairlineBorder achieves >= 3.0:1 against chromeSurface
        #expect(palette.submenuTranslucentSurface.alpha == 1.0)
        #expect(palette.findBarSurface.alpha == 1.0)
        #expect(palette.hairlineBorder.contrastRatio(against: palette.chromeSurface) >= 3.0)
    }

    @Test("P3 (Live): Production Sources/SwiftEditUI/Views directory passes static theme token audit with zero violations")
    func p3LiveSwiftEditUIViewsDirectoryPassesZeroViolations() throws {
        // GIVEN the live Sources/SwiftEditUI/Views directory
        let liveViewsDirectory = Self.repoRootURL.appendingPathComponent("Sources/SwiftEditUI/Views")

        // WHEN scanning all production view files via scanSwiftEditUIViewsDirectory
        let violations = try ArchitectureImportScanner.scanSwiftEditUIViewsDirectory(at: liveViewsDirectory)

        // THEN zero forbidden color constructs exist in any SwiftEditUI View file
        #expect(violations.isEmpty)
    }

    @Test(
        "N2, N9 & N10 [Security]: BiDi Trojan Source, Binary Quarantine, Unbalanced Bracket, Inert HTML, and sidebarBinaryDisabledText pass >= 4.5:1 text and >= 3.0:1 border contrast",
        arguments: [
            (AppearanceMode.light, "#991B1B", "#FEE2E2"),
            (AppearanceMode.black, "#FCA5A5", "#450A0A"),
        ]
    )
    func n2AndN9AndN10SecurityWarningTokensMaintainHighSalienceContrast(
        mode: AppearanceMode,
        expectedUnbalancedFg: String,
        expectedUnbalancedBg: String
    ) {
        // GIVEN PurpleThemePalette resolved in Light or Black mode
        let palette = PurpleThemePalette.resolve(appearance: mode)

        // WHEN / THEN Unbalanced Bracket, BiDi, Binary Quarantine, Inert HTML, and sidebarBinaryDisabledText pass WCAG security thresholds
        #expect(palette.unbalancedBracketHighlight.hex == expectedUnbalancedFg)
        #expect(palette.unbalancedBracketBackground.hex == expectedUnbalancedBg)
        #expect(palette.unbalancedBracketHighlight.contrastRatio(against: palette.unbalancedBracketBackground) >= 4.5)

        #expect(palette.bidiWarningForeground.contrastRatio(against: palette.bidiWarningBackground) >= 4.5)
        #expect(palette.bidiWarningBorder.contrastRatio(against: palette.chromeSurface) >= 3.0)

        #expect(palette.binaryQuarantineForeground.contrastRatio(against: palette.binaryQuarantineBackground) >= 4.5)
        #expect(palette.binaryQuarantineBorder.contrastRatio(against: palette.chromeSurface) >= 3.0)

        #expect(palette.inertHTMLWarningForeground.contrastRatio(against: palette.inertHTMLWarningBackground) >= 4.5)
        #expect(palette.inertHTMLWarningBorder.contrastRatio(against: palette.chromeSurface) >= 3.0)

        let binarySidebarContrast = palette.sidebarBinaryDisabledText.contrastRatio(against: palette.sidebarSurface)
        let normalSidebarContrast = palette.chromeForeground.contrastRatio(against: palette.sidebarSurface)
        #expect(binarySidebarContrast >= 4.5)
        #expect(binarySidebarContrast < normalSidebarContrast)
    }

    @Test(
        "P1 & N2 [Security Audit]: Every paired foreground/surface and border/surface token in PurpleThemePalette satisfies WCAG 2.2 AA",
        arguments: [ResolvedThemeMode.light, .black]
    )
    func exhaustivePairedForegroundAndBorderContrastAudit(resolvedMode: ResolvedThemeMode) {
        // GIVEN a PurpleThemePalette resolved for the target mode
        let mode: AppearanceMode = (resolvedMode == .light) ? .light : .black
        let palette = PurpleThemePalette.resolve(appearance: mode)
        let highContrastPalette = PurpleThemePalette.resolve(appearance: mode, increasedContrast: true)

        // WHEN / THEN all normal-text pairs >= 4.5:1, canvas == 21:1, selection/diff text >= 4.5:1, and accents/borders >= 3.0:1
        #expect(palette.mode == resolvedMode)
        #expect(palette.editorCanvasText.contrastRatio(against: palette.editorCanvasBackground) >= 20.9)
        #expect(palette.selectionForeground.contrastRatio(against: palette.selectionBackground) >= 7.0)
        #expect(palette.selectionBackground.contrastRatio(against: palette.editorCanvasBackground) >= 7.0)
        #expect(palette.editorCanvasText.contrastRatio(against: palette.wordOccurrenceBackground) >= 12.0)
        #expect(palette.editorCanvasText.contrastRatio(against: palette.diffInsertedBackground) >= 4.5)
        #expect(palette.editorCanvasText.contrastRatio(against: palette.diffRemovedBackground) >= 4.5)
        #expect(palette.backtickForeground.contrastRatio(against: palette.backtickInlineBackground) >= 4.5)
        #expect(palette.backtickForeground.contrastRatio(against: palette.backtickMultilineBackground) >= 4.5)
        #expect(palette.chromeForeground.contrastRatio(against: palette.badgeSurface) >= 4.5)
        #expect(palette.chromeForeground.contrastRatio(against: palette.findBarSurface) >= 4.5)
        #expect(palette.chromeForeground.contrastRatio(against: palette.submenuTranslucentSurface) >= 4.5)
        #expect(palette.pinnedTabBadge.contrastRatio(against: palette.tabBarSurface) >= 3.0)
        // v1.7.0 Zed-neutral chrome: muted status bar, gutter and secondary text keep AA on their surfaces.
        #expect(palette.statusBarForeground.contrastRatio(against: palette.statusBarSurface) >= 4.5)
        #expect(palette.gutterForeground.contrastRatio(against: palette.gutterSurface) >= 4.5)
        #expect(palette.secondaryForeground.contrastRatio(against: palette.tabBarSurface) >= 4.5)
        #expect(palette.chromeForeground.contrastRatio(against: palette.accentSoftSurface) >= 4.5)
        #expect(palette.chromeAccent.contrastRatio(against: palette.topBarSurface) >= 3.0)
        #expect(highContrastPalette.hairlineBorder.contrastRatio(against: highContrastPalette.chromeSurface) >= 3.0)
    }

    @Test("P2 & P8: Cold-start Auto seeds Frame 0 from systemDarkDetector without Black FOUC and live Auto->Black->Light preserves dirty BufferRevision")
    @MainActor
    func p2AndP8ColdStartAutoDetectorWindowSyncAndDirtyBufferPreservation() throws {
        // GIVEN an ephemeral in-memory preferences store in .auto mode, systemDarkDetector reporting Light OS (false), and a dirty Markdown buffer at revision 3
        let recoveryDir = Self.repoRootURL.appendingPathComponent(".tmp/test-results/rec-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: recoveryDir)
        }

        let prefsKV = InMemoryKeyValueStore()
        let prefsStore = EditorPreferencesStore(store: prefsKV)
        prefsStore.save(EditorPreferences(appearanceMode: .auto, zoomPercent: 100))

        let model = SwiftEditWorkbenchModel(
            preferencesStore: prefsKV,
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: recoveryDir,
            systemDarkDetector: { false }
        )

        let frame0Mode = model.palette.mode
        let frame0WindowTarget = model.lastWindowAppearanceTarget

        model.newUntitledTab()
        model.handleEditorTextChanged("# Step 1")
        model.handleEditorTextChanged("# Step 2")
        let dirtySessionBefore = try #require(model.activeDocumentSession)
        let revisionBefore = dirtySessionBefore.revision
        let textBefore = dirtySessionBefore.text

        // WHEN switching .auto -> .black -> .light -> .auto with a tainted dark container signal in between
        model.appearanceMode = .black
        let blackMode = model.palette.mode
        let blackWindowTarget = model.lastWindowAppearanceTarget
        model.updateSystemColorScheme(prefersDark: true)

        model.appearanceMode = .light
        let lightMode = model.palette.mode
        let lightWindowTarget = model.lastWindowAppearanceTarget

        model.appearanceMode = .auto
        let restoredAutoMode = model.palette.mode
        let restoredWindowTarget = model.lastWindowAppearanceTarget

        let dirtySessionAfter = try #require(model.activeDocumentSession)

        // THEN Frame 0 resolved .light immediately, window targets tracked .systemAutomatic -> .darkAqua -> .aqua -> .systemAutomatic, and BufferRevision stayed untouched
        #expect(frame0Mode == .light)
        #expect(frame0WindowTarget == .systemAutomatic)
        #expect(blackMode == .black)
        #expect(blackWindowTarget == .darkAqua)
        #expect(lightMode == .light)
        #expect(lightWindowTarget == .aqua)
        #expect(restoredAutoMode == .light)
        #expect(restoredWindowTarget == .systemAutomatic)
        #expect(dirtySessionAfter.isDirty == true)
        #expect(dirtySessionAfter.revision == revisionBefore)
        #expect(dirtySessionAfter.text == textBefore)
    }

    @Test("N3 & N11 [Security]: Forced Black or Light mode ignores tainted container colorScheme signals and preserves binary quarantine across theme switches")
    @MainActor
    func n3AndN11TaintedColorSchemeIgnoredAndBinaryQuarantinePersists() throws {
        // GIVEN a Dark OS detector (true) switched to .light and a Light OS detector (false) with an open binary read-only buffer switched to .black
        let tempDir = Self.repoRootURL.appendingPathComponent(".tmp/test-results/bin-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let binaryFileURL = tempDir.appendingPathComponent("payload.bin")
        let binaryPayload = Data([0x50, 0x4B, 0x00, 0x04, 0x41, 0x42])
        try binaryPayload.write(to: binaryFileURL)

        let darkHostModel = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: tempDir.appendingPathComponent("recA"),
            systemDarkDetector: { true }
        )
        darkHostModel.appearanceMode = .light
        // Tainted container signal emitted by forced .light preferredColorScheme
        darkHostModel.updateSystemColorScheme(prefersDark: false)
        darkHostModel.appearanceMode = .auto

        let lightHostModel = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: tempDir.appendingPathComponent("recB"),
            systemDarkDetector: { false }
        )
        lightHostModel.openFile(at: binaryFileURL, withinScope: tempDir)
        lightHostModel.appearanceMode = .black
        // Tainted container signal emitted by forced .black preferredColorScheme
        lightHostModel.updateSystemColorScheme(prefersDark: true)
        lightHostModel.appearanceMode = .auto

        // WHEN / THEN N11 restores .black on the Dark host, N3 restores .light on the Light host, and binary quarantine lockouts remain enforced
        #expect(darkHostModel.systemPrefersDark == true)
        #expect(darkHostModel.palette.mode == .black)

        #expect(lightHostModel.palette.mode == .light)
        #expect(lightHostModel.lastWindowAppearanceTarget == .systemAutomatic)
        #expect(lightHostModel.safetyBanner.isBinaryReadOnlyBannerVisible == true)
        #expect(lightHostModel.safetyBanner.canSave == false)
        #expect(lightHostModel.safetyBanner.canFormat == false)
        #expect(lightHostModel.safetyBanner.canPinTab == false)

        let coordinator = WorkspaceEditorCoordinator(
            session: DocumentSession(text: "hello"),
            appearanceMode: .auto,
            systemDarkDetector: { false }
        )
        #expect(coordinator.palette.mode == .light)
        #expect(coordinator.bufferReloadCount == 1)
    }
}
