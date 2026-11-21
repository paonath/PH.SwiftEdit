# Capability: full-app-semantic-theming-and-window-sync

## Purpose
Establishes exhaustive full-application semantic `Light`, `Black`, and `Auto` Purple theming across all 12 workspace, gutter, find-bar, preview, diff, status-bar, banner, and modal sheet surfaces without `brandGround` leakage, synchronizes macOS `NSApp.appearance` and `TextKit2EditorView` viewport styling via unmasked OS interface detection, and enforces static UI theme token fitness checks.

## Requirements

### Requirement: REQ-001 Exhaustive Semantic Role Palette and Accessibility Opacity Clamping
The `PurpleThemePalette` value type SHALL resolve distinct `.light` and `.black` surface, foreground, accent, gutter, tab, diff, status-bar, sheet, translucent-submenu, and security-warning `RGBAColorToken` properties without exposing `brandGround`, maintaining at least `4.5:1` text contrast, `3.0:1` UI/border contrast, `21.0:1` `#FFFFFF`/`#000000` canvas contrast, and `1.0` alpha clamping under `reduceTransparency` or `increasedContrast` [AR-008][AR-009][UI-001][UI-002][UI-003][UI-009].

#### Scenario: P1 Semantic Role Tokens Satisfy Section 3 Hex Anchors and WCAG 2.2 AA Contrast Floors
- **Path**: P1
- **Trait**: positive
- **GIVEN** `PurpleThemePalette` resolved for `.light` and `.black` modes with `reduceTransparency: false` and `increasedContrast: false`
- **WHEN** surface, foreground, accent, gutter, tab, diff, status-bar, sheet, and canvas tokens are inspected
- **THEN** `.light` resolves `topBarSurface` `#F3E8FF`, `sidebarSurface` `#EDE0FF`, `tabBarSurface` `#E9D5FF`, `gutterSurface` `#F5F3FF`, `statusBarSurface` `#7C3AED` (`#FFFFFF` foreground), and `#FFFFFF`/`#000000` (`21.0:1`) canvas, `.black` resolves `#0B0614`, `#140A24`, `#180C2C`, `#0B0614`, `#2E1065` (`#FFFFFF` foreground), and `#000000`/`#FFFFFF` (`21.0:1`) canvas, every normal-text pair achieves `contrastRatio >= 4.5`, and `chromeAccent` achieves `contrastRatio >= 3.0` against all chrome surfaces

#### Scenario: N1 Reduce Transparency or Increased Contrast Clamps Translucent Surfaces to Opaque Alpha
- **Path**: N1
- **Trait**: negative
- **GIVEN** `PurpleThemePalette` resolved in `.light` and `.black` modes with `reduceTransparency: true` or `increasedContrast: true`
- **WHEN** `submenuTranslucentSurface`, `findBarSurface`, and `hairlineBorder` are evaluated
- **THEN** `submenuTranslucentSurface.alpha` and `findBarSurface.alpha` equal `1.0` and `hairlineBorder` achieves at least `3.0:1` contrast against `chromeSurface`

#### Scenario: N2 Security Warning Tokens Maintain High-Salience Contrast Across Light and Black Modes
- **Path**: N2
- **Trait**: security
- **GIVEN** `PurpleThemePalette` resolved in `.light` and `.black` modes
- **WHEN** Trojan Source BiDi warning, Binary Quarantine warning, Unbalanced Bracket highlight, Inert Raw HTML container, and `sidebarBinaryDisabledText` token pairs are evaluated
- **THEN** every security warning foreground against its background achieves `contrastRatio >= 4.5`, every warning border against `chromeSurface` achieves `contrastRatio >= 3.0`, and `sidebarBinaryDisabledText` achieves `contrastRatio >= 4.5` against `sidebarSurface` while remaining lower-luminance-contrast than `chromeForeground`

### Requirement: REQ-002 Unmasked Auto OS Detection MacOSAppearanceSynchronizer and Live TextKit 2 Sync
WHEN initializing `SwiftEditWorkbenchModel` or switching `AppearanceMode` among `.light`, `.black`, and `.auto`, the workbench SHALL seed Frame 0 `.auto` state from unmasked OS appearance, sync `NSApp.appearance` and `TextKit2EditorView` viewport styling without incrementing `BufferRevision`, and ignore tainted container `colorScheme` signals when `appearanceMode` is not `.auto` [AR-003][BC-006][DATA-003][SEC-012][UI-003][UI-005][UI-007][UI-008][UI-012].

#### Scenario: P2 Cold-Start Auto Detection and Live Mode Switching Preserve Dirty Buffer Revision
- **Path**: P2
- **Trait**: positive
- **GIVEN** an injected `systemDarkDetector` reporting Light macOS (`false`), saved preferences in `.auto` mode, and a dirty Markdown `DocumentSession` at revision `3`
- **WHEN** `SwiftEditWorkbenchModel` initializes on Frame 0 and switches `.auto -> .black -> .light`
- **THEN** initial `palette.mode` resolves to `.light` without an intermediate `.black` state, `MacOSAppearanceSynchronizer` maps `.black` to `.darkAqua` and `.light` to `.aqua`, and the active document remains dirty at revision `3` with identical text

#### Scenario: N3 Forced Appearance Override Does Not Poison Subsequent Auto Restoration or Binary Quarantine
- **Path**: N3
- **Trait**: security
- **GIVEN** `systemDarkDetector` reporting Light macOS (`false`), an active binary read-only tab (`canSave == false`), and `SwiftEditWorkbenchModel` switched to `.black`
- **WHEN** a container `colorScheme` override reports `prefersDark: true` while `appearanceMode == .black` and the user then selects `.auto`
- **THEN** `MacOSAppearanceSynchronizer` clears the override to `nil`, `palette.mode` restores to `.light`, and the binary tab retains `isBinaryReadOnlyBannerVisible == true` with `canSave == false`, `canFormat == false`, and `canPinTab == false`

### Requirement: REQ-003 Static SwiftEditUI View Theme Token Fitness Gate
IF any Swift source file under `Sources/SwiftEditUI/Views` references `brandGround`, a raw 6-digit hex color literal, `Color(.sRGB`, or `NSColor(srgbRed:`, THEN `ArchitectureImportScanner.scanSwiftEditUIThemeTokens` SHALL return an `ArchitectureFitnessViolation` identifying the offending file and token [AR-006][SEC-009][TEST-006][UI-001][UI-009].

#### Scenario: P3 Live SwiftEditUI View Files Pass Static Theme Token Audit
- **Path**: P3
- **Trait**: positive
- **GIVEN** all production `.swift` files inside `Sources/SwiftEditUI/Views`
- **WHEN** `ArchitectureImportScanner.scanSwiftEditUIViewsDirectory(at:)` audits the directory
- **THEN** zero `ArchitectureFitnessViolation` items are returned

#### Scenario: N4 Hardcoded BrandGround Hex Literal or Inline sRGB Constructor in Views Fails Audit
- **Path**: N4
- **Trait**: security
- **GIVEN** synthetic view source snippets referencing `palette.brandGround`, `"#0B0614"`, `Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)`, and `NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)`
- **WHEN** `ArchitectureImportScanner.scanSwiftEditUIThemeTokens(content:filePath:)` scans each snippet
- **THEN** each snippet produces at least one `ArchitectureFitnessViolation` flagging the forbidden color construct
