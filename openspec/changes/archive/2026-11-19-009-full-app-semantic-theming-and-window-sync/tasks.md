# Tasks: Full-App Semantic Light/Dark/Auto Theming, macOS Window Chrome Sync & UI Token Fitness

## 1. Unit: ArchitectureThemeTokenFitnessScanner
<!-- Governing rules: AR-002, AR-006, SEC-009, TEST-001, TEST-006 -->

- [x] 1.1 [RED] TASK-001-RED: Write failing `Swift Testing` tests in `Tests/SwiftEditTests/FullAppSemanticThemingAndWindowSyncTests.swift` for `P3` (`ArchitectureImportScanner.scanSwiftEditUIViewsDirectory` returns zero violations on clean semantic view code) and `N4` (`scanSwiftEditUIThemeTokens` rejects snippets referencing `brandGround`, raw 6-digit hex literals like `"#0B0614"`, `Color(.sRGB`, and `NSColor(srgbRed:`); verify failure on assertions [Const: TEST-006 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P3, N4] · tags: security · priority: critical
- [x] 1.2 [GREEN] TASK-001-GREEN: Implement `scanSwiftEditUIThemeTokens(content:filePath:)` and `scanSwiftEditUIViewsDirectory(at:)` in `Sources/SwiftEditCore/ArchitectureFitness/ArchitectureImportScanner.swift` using pure `Foundation` scanning so `N4` passes [Const: AR-006 (01-architecture/dependency-and-layering.md)]
  - paths: [P3, N4] · tags: security · priority: critical
- [x] 1.3 [REFACTOR] TASK-001-REFACTOR: Share comment-stripping and file-enumeration helpers across `scanSwiftEditCoreSource` and `scanSwiftEditUIThemeTokens` while keeping `ArchitectureFitnessTests` green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [P3, N4] · tags: security
- [x] 1.4 [DOC] TASK-001-DOC: Write concise English Swift Markup (`///`) documentation on `scanSwiftEditUIThemeTokens` and `scanSwiftEditUIViewsDirectory` explaining `CWE-451` Light-mode dark-ground leak prevention
  - paths: [P3, N4]

## 2. Unit: SemanticPurpleThemePaletteAndSecurityTokens
<!-- Governing rules: AR-008, AR-009, DATA-003, SEC-004, UI-001, UI-002, UI-003, UI-008, UI-009 -->

- [x] 2.1 [RED] TASK-002-RED: Write failing `Swift Testing` tests in `Tests/SwiftEditTests/FullAppSemanticThemingAndWindowSyncTests.swift` for `P1` / `P6` (`.light` and `.black` resolve all §3 role surfaces, foregrounds, accents, `21:1` `#FFFFFF`/`#000000` canvas, `>= 4.5:1` text contrast, and `>= 3.0:1` UI contrast without `public let brandGround`) and `N1` (`reduceTransparency` or `increasedContrast` clamps `submenuTranslucentSurface` and `findBarSurface` to `1.0` alpha and steps up `hairlineBorder` `>= 3.0:1`); verify failure on assertions [Const: UI-001 (03-ui-ux/design-system-and-tokens.md)]
  - paths: [P1, P6, N1]
- [x] 2.2 [GREEN] TASK-002-GREEN: Refactor `PurpleThemePalette` in `Sources/SwiftEditUI/Theme/PurpleThemeAndZoom.swift` removing `public let brandGround`, adding all §3 semantic surface/foreground/accent/translucent tokens plus centralized `RGBAColorToken.swiftUIColor` and `#if os(macOS)` `nsColor` bridges, and migrating all 6 view files in `Sources/SwiftEditUI/Views/` so `P1`, `P6`, `N1`, and `P3` pass [Const: UI-002 (03-ui-ux/design-system-and-tokens.md)]
  - paths: [P1, P3, P6, N1]
- [x] 2.3 [REFACTOR] TASK-002-REFACTOR: Consolidate banner and sheet styling helpers across `SwiftEditRootView`, `LineNumberGutterView`, `FindReplaceGoToLineBar`, `AboutSheetView`, and `KeyboardShortcutsCheatSheetView` while updating `PurpleThemeZoomAndSafetyBannerTests` (`SwiftEditBrandLogoGeometry.groundHex` + `topBarSurface`) so all suites stay green [Const: UI-009 (03-ui-ux/accessibility-and-cwv.md)]
  - paths: [P1, P3, P6, N1]
- [x] 2.4 [DOC] TASK-002-DOC: Write concise English Swift Markup (`///`) documentation on all new `PurpleThemePalette` role properties, accessibility parameters, and `RGBAColorToken` color bridges
  - paths: [P1, P6, N1]
- [x] 2.5 [RED] [SECURITY] TASK-003-RED: Write failing security contrast tests in `Tests/SwiftEditTests/FullAppSemanticThemingAndWindowSyncTests.swift` for `N2`, `N9`, and `N10` (BiDi Trojan Source, Binary Quarantine, Unbalanced Bracket `#991B1B`/`#FEE2E2` & `#FCA5A5`/`#450A0A`, Inert Raw HTML, `.light` `nestedBracketPalette`, and `sidebarBinaryDisabledText` achieve `>= 4.5:1` text and `>= 3.0:1` border contrast across `.light` and `.black`); verify failure on assertions [Const: UI-008 (03-ui-ux/component-state-and-forms.md)]
  - paths: [P1, N2, N9, N10] · tags: security · priority: critical
- [x] 2.6 [GREEN] [SECURITY] TASK-003-GREEN: Populate BiDi, Binary Quarantine, Unbalanced Bracket, Inert Raw HTML, and darkened `.light` nested-bracket `RGBAColorToken` properties in `PurpleThemePalette.resolve` and wire them into `safetyAndErrorBanners`, `markdownPreviewPanel`, and `TextKit2EditorView` so `N2`, `N9`, and `N10` pass [Const: SEC-009 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [P1, N2, N9, N10] · tags: security · priority: critical
- [x] 2.7 [REFACTOR] [SECURITY] TASK-003-REFACTOR: Audit every paired foreground/background and border/surface token in `PurpleThemePalette` with parameterized `@Test(arguments: [ResolvedThemeMode.light, .black])` checks while keeping full test suite green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [P1, N2, N9, N10] · tags: security
- [x] 2.8 [DOC] [SECURITY] TASK-003-DOC: Document `CVE-2021-42574`, `CWE-451`, and WCAG 2.2 `4.5:1` / `3.0:1` security salience invariants on `PurpleThemePalette` warning tokens in English Swift Markup (`///`) comments
  - paths: [P1, N2, N9, N10]

## 3. Unit: MacOSAppearanceSynchronizerAndWorkbenchAutoSync
<!-- Governing rules: AR-003, BC-006, DATA-003, SEC-012, TEST-004, UI-003, UI-005, UI-007, UI-012 -->

- [x] 3.1 [RED] TASK-004-RED: Write failing `Swift Testing` tests in `Tests/SwiftEditTests/FullAppSemanticThemingAndWindowSyncTests.swift` for `P2` / `P8` (Frame 0 `.auto` initialization via `systemDarkDetector: { false }` resolves `.light` immediately without `.black` FOUC; live `.auto -> .black -> .light` switches sync `MacOSAppearanceSynchronizer` without incrementing dirty `BufferRevision`) and `N3` / `N11` (tainted container `colorScheme` signals arriving while `appearanceMode != .auto` are ignored so returning to `.auto` restores true OS appearance while keeping binary read-only `canSave == false`); verify failure on assertions [Const: UI-003 (03-ui-ux/design-system-and-tokens.md)]
  - paths: [P2, P8, N3, N11] · tags: security · priority: critical
- [x] 3.2 [GREEN] TASK-004-GREEN: Implement `#if os(macOS)` `@MainActor` `MacOSAppearanceSynchronizer`, add injectable `systemDarkDetector` (`AppleInterfaceStyle` + `DistributedNotificationCenter` notification) to `SwiftEditWorkbenchModel` and `WorkspaceEditorCoordinator`, guard `onChange(of: systemColorScheme)` behind `appearanceMode == .auto`, and update `TextKit2EditorView` (`usesAdaptiveColorMappingForDarkAppearance = false`, `selectedTextAttributes`, `insertionPointColor`, `NSScrollView` background & `scrollerKnobStyle`, viewport-only refresh) so `P2`, `P8`, `N3`, and `N11` pass [Const: UI-007 (03-ui-ux/component-state-and-forms.md)]
  - paths: [P2, P8, N3, N11] · tags: security · priority: critical
- [x] 3.3 [REFACTOR] TASK-004-REFACTOR: Ensure `MacOSAppearanceSynchronizer` handles headless `NSApp == nil` unit test environments cleanly without side effects and verify all `SwiftEditTests` suites pass in parallel (`<= 150 ms` cold start, zero `ensureLayout`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
  - paths: [P2, P8, N3, N11] · tags: security
- [x] 3.4 [DOC] TASK-004-DOC: Write concise English Swift Markup (`///`) documentation on `MacOSAppearanceSynchronizer`, `systemDarkDetector`, and `TextKit2EditorView` live viewport restyling invariants
  - paths: [P2, P8, N3, N11]

## 4. Unit: LivingSpecificationReconciliation

- [x] 4.1 [SYNC] TASK-005-SYNC: Execute `/myspec-sync 009-full-app-semantic-theming-and-window-sync` to reconcile delta changes into `openspec/specs/full-app-semantic-theming-and-window-sync/spec.md`, `openspec/specs/swifteditui-purple-zed-layout-textkit2-and-appicons/spec.md`, and `openspec/specs/editor-ux-highlighting-sidebar-pin-tabs-and-about/spec.md` [Const: SDD-003 (08-sdd-governance/artifact-traceability.md)]
