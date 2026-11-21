# Test Plan: Full-App Semantic Light/Dark/Auto Theming, macOS Window Chrome Sync & UI Token Fitness

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `PurpleThemePalette.resolve` | P1: Resolves distinct `.light` and `.black` §3 surface, foreground, accent, gutter, tab, status-bar, sheet, and `21:1` `#FFFFFF`/`#000000` canvas tokens achieving `>= 4.5:1` text and `>= 3.0:1` UI contrast (`P6` delta) | N1: `reduceTransparency` or `increasedContrast` clamps `submenuTranslucentSurface` and `findBarSurface` to `1.0` alpha and steps up `hairlineBorder` `>= 3.0:1`; N2 [Security]: BiDi, Binary Quarantine, Unbalanced Bracket (`N9`), Inert HTML (`N10`), and `sidebarBinaryDisabledText` pairs satisfy `>= 4.5:1` text and `>= 3.0:1` border contrast |
| `SwiftEditWorkbenchModel` & `MacOSAppearanceSynchronizer` | P2: Cold launch in `.auto` seeds Frame 0 palette synchronously from `systemDarkDetector` and live `.auto -> .black -> .light` switches sync `MacOSAppearanceSynchronizer` without incrementing `BufferRevision` (`P8` delta) | N3 [Security]: Tainted container `colorScheme` signals arriving while `appearanceMode` is `.black` or `.light` (`N11` delta) are ignored so returning to `.auto` restores true OS appearance while preserving binary read-only `canSave == false` lockouts |
| `ArchitectureImportScanner.scanSwiftEditUIThemeTokens` | P3: Live `Sources/SwiftEditUI/Views/*.swift` directory passes static theme token audit with zero violations | N4 [Security]: Synthetic view snippets containing `brandGround`, raw 6-digit hex literals (`#0B0614`), `Color(.sRGB`, or `NSColor(srgbRed:` fail closed with `ArchitectureFitnessViolation` (`CWE-451`) |

## 2. Test Automation Strategy & Commands
- Unit test runner command: `swift test`
- Targeted suite command: `swift test --filter FullAppSemanticThemingAndWindowSyncTests`
- Regression suite command: `swift test --filter "PurpleThemeZoomAndSafetyBannerTests|EditorUXLayoutThemeAndAboutTests|ArchitectureFitnessTests"`

## 3. Testability Seams & Test Doubles
- Real collaborators: `PurpleThemePalette`, `RGBAColorToken`, `EditorZoomController`, `InspectionSafetyBannerState`, `DocumentSession`, `WorkspaceTabSession`, `ArchitectureImportScanner` (`[TEST-002]`, `[TEST-004]`).
- Isolation seams: Injected `systemDarkDetector: @MainActor () -> Bool` closure, ephemeral `UserDefaults(suiteName:)` preferences store, and temporary `SessionRecoveryStore` directories (`[TEST-003]`, `[TEST-004]`).

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | Atomic EARS requirements and declarative Given/When/Then scenarios defined across 3 capability specs (`[SDD-001]`) |
| Path coverage completeness | Verified | Every unit (`PurpleThemePalette`, `SwiftEditWorkbenchModel`/`MacOSAppearanceSynchronizer`, `ArchitectureImportScanner`) defines `P1..P3` and `N1..N4` (`[TEST-001]`, `[TEST-002]`) |
| Security traits tagged | Verified | Anti-camouflage, contrast floor, binary lockout persistence, and static token fitness scenarios tagged `- **Trait**: security` (`[SEC-009]`) |
