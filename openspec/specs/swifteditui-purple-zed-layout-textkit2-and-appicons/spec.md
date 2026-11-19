# Capability: swifteditui-purple-zed-layout-textkit2-and-appicons

## Purpose
Updates `REQ-001` and `REQ-002` of `swifteditui-purple-zed-layout-textkit2-and-appicons` so `PurpleThemePalette` replaces `public let brandGround` with contrast-verified role-specific semantic Light and Black tokens across all chrome, gutter, tab, sheet, and security-warning surfaces while preserving `21:1` `#FFFFFF`/`#000000` editor contrast and all binary quarantine and Trojan Source BiDi controls.

## Requirements

### Requirement: REQ-001 Concept E2 Purple Chrome Inverted B/W Canvas and 50..300 Percent Zoom
WHEN resolving theme tokens, layout state, or zoom commands across `Light`, `Black`, and `Auto` modes, the theme and zoom controller SHALL expose role-specific Concept E2 Purple surface, foreground, accent, gutter, tab, sheet, highlight, and disabled-binary tokens without `brandGround`, invert the `#FFFFFF`/`#000000` canvas at `21:1` contrast, sync `.auto` to unmasked OS appearance, and scale editor and sidebar zoom across `50%..300%` [UI-001][UI-002][UI-003][UI-004][UI-009].

#### Scenario: P1 Purple Chrome Tokens Inverted B/W Canvas and Zoom Scaling
- **Path**: P1
- **Trait**: positive
- **GIVEN** `PurpleThemePalette` in `.light` and `.black` modes and an `EditorZoomController` at `100%` (`14 pt` base font)
- **WHEN** the palette resolves chrome and canvas tokens and `zoomIn` (`Cmd++`), `zoomOut` (`Cmd+-`), `resetZoom` (`Cmd+0`), and `togglePaneFocus` execute
- **THEN** `.light` resolves `#FFFFFF` canvas background and `#000000` text, `.black` resolves `#000000` canvas background and `#FFFFFF` text with `21.0` contrast ratio alongside Concept E2 `#0B0614`/`#7C3AED`/`#A78BFA`/`#C4B5FD` chrome tokens, and zoom scales font size cleanly without altering buffer text

#### Scenario: N1 Zoom Commands Clamp at 50 Percent and 300 Percent Boundaries
- **Path**: N1
- **Trait**: negative
- **GIVEN** an `EditorZoomController` initialized at `50%` or `300%`
- **WHEN** `zoomOut()` is called at `50%` or `zoomIn()` is called at `300%`
- **THEN** `zoomPercent` remains clamped at `50` and `300` respectively

#### Scenario: P1 Purple Chrome Tokens Default-Collapsed Sidebar Right-Column Tabs Line Gutter and Zoom Scaling
- **Path**: P1
- **Trait**: positive
- **GIVEN** `PurpleThemePalette` in `.light` and `.black` modes, an `EditorZoomController` at `100%` (`14 pt` base font), and a `LineNumberGutterProjection` on a 3-line document
- **WHEN** the palette resolves chrome and canvas tokens, `zoomIn` (`Cmd++`), `zoomOut` (`Cmd+-`), `resetZoom` (`Cmd+0`), and `togglePaneFocus` execute, and the gutter projection evaluates line numbers
- **THEN** `.light` resolves `#FFFFFF` canvas background and `#000000` text, `.black` resolves `#000000` canvas background and `#FFFFFF` text with `21.0` contrast ratio alongside Concept E2 `#0B0614`/`#7C3AED`/`#A78BFA`/`#C4B5FD` chrome tokens, the gutter projection lists `[1, 2, 3]`, and zoom scales font size cleanly without altering buffer text

#### Scenario: N1 Zoom Commands and Empty Gutter Projection Clamp Safely at Boundaries
- **Path**: N1
- **Trait**: negative
- **GIVEN** an `EditorZoomController` initialized at `50%` or `300%` and an empty buffer `""`
- **WHEN** `zoomOut()` is called at `50%`, `zoomIn()` is called at `300%`, and `LineNumberGutterProjection.evaluate(text:caretLocation:)` evaluates `""`
- **THEN** `zoomPercent` remains clamped at `50` and `300` respectively and the gutter projection returns `[1]`

#### Scenario: P4 Highlight Tokens Live Auto Sync and Proportional Sidebar Zoom Scaling
- **Path**: P4
- **Trait**: positive
- **GIVEN** `PurpleThemePalette` resolved for `.light`, `.black`, and `.auto` (with `systemPrefersDark: false` and `true`) and `EditorZoomController` at `150%`
- **WHEN** highlight tokens and `sidebarScaledFontSizePoints` are evaluated
- **THEN** current-line resolves `#161224` in Black and `#F3F0FA` in Light, disabled binary resolves `#9CA3AF` in Black and `#52525B` in Light, nested bracket depth colors and backtick tint tokens are populated, and `sidebarScaledFontSizePoints` equals `19.5`

#### Scenario: N7 Sidebar Zoom Clamps at 50 and 300 Percent Boundaries
- **Path**: N7
- **Trait**: negative
- **GIVEN** `EditorZoomController` clamped at `50%` and `300%`
- **WHEN** `sidebarScaledFontSizePoints` is evaluated at both boundaries
- **THEN** sidebar typography clamps cleanly at `6.5pt` and `39.0pt`

#### Scenario: P6 Role-Specific Semantic Chrome Tokens Eliminate Light-Mode Dark-Ground Leakage
- **Path**: P6
- **Trait**: positive
- **GIVEN** `PurpleThemePalette` resolved in `.light` and `.black` modes
- **WHEN** `topBarSurface`, `sheetSurface`, `sidebarSurface`, `tabBarSurface`, `gutterSurface`, `statusBarSurface`, `secondaryForeground`, and `nestedBracketPalette` are inspected
- **THEN** `.light` resolves `#F3E8FF`, `#F3E8FF`, `#EDE0FF`, `#E9D5FF`, `#F5F3FF`, `#7C3AED`, and `#5B21B6` with every `.light` nested bracket color achieving at least `4.5:1` contrast on `#FFFFFF`, while `.black` resolves `#0B0614`, `#0B0614`, `#140A24`, `#180C2C`, `#0B0614`, `#2E1065`, and `#C4B5FD`

#### Scenario: N9 Unbalanced Bracket Pill Satisfies WCAG 2.2 AA Contrast in Both Modes
- **Path**: N9
- **Trait**: negative
- **GIVEN** `PurpleThemePalette` resolved in `.light` and `.black` modes
- **WHEN** `unbalancedBracketHighlight` is compared against `unbalancedBracketBackground`
- **THEN** `contrastRatio` is at least `4.5` in both `.light` (`#991B1B` on `#FEE2E2`) and `.black` (`#FCA5A5` on `#450A0A`)

### Requirement: REQ-002 Binary Read-Only Lockout BiDi Trojan Source Badges and URI Gate
IF a document snapshot is binary read-only, contains Unicode BiDi control characters, or triggers an external URI handoff, THEN `InspectionSafetyBannerState` and `PurpleThemePalette` SHALL disable mutating commands on binary buffers, emit BiDi, Binary Quarantine, and Inert HTML `RGBAColorToken` triples at `>= 4.5:1` text and `>= 3.0:1` border contrast across `.light` and `.black`, and require confirmation on allowlisted `https`/`http`/`mailto` URIs [DATA-003][SEC-004][SEC-012][UI-008][UI-009].

#### Scenario: P1 Clean Text Snapshot and Confirmed HTTPS Link
- **Path**: P1
- **Trait**: positive
- **GIVEN** a non-binary `DocumentSnapshot` without BiDi control characters and an external link `"https://swift.org"`
- **WHEN** `InspectionSafetyBannerState.evaluate(snapshot:)` and `prepareExternalURIConfirmation(rawURI:)` run
- **THEN** `isBinaryReadOnlyBannerVisible` is `false`, `canSave`/`canFormat`/`canPinTab` are `true`, `bidiWarnings` is empty, and an `ExternalURIConfirmationPrompt` is returned with canonical `"https://swift.org"`

#### Scenario: N2 Binary Lockout BiDi Trojan Source Detection and Unsafe URI Scheme Block
- **Path**: N2
- **Trait**: security
- **GIVEN** a binary read-only `DocumentSnapshot`, a text snapshot containing `U+202E` (`RLO`) and `U+2066` (`LRI`), and links `"javascript:alert(1)"` and `"file:///etc/passwd"`
- **WHEN** `InspectionSafetyBannerState.evaluate(snapshot:)` and `prepareExternalURIConfirmation(rawURI:)` evaluate the inputs
- **THEN** the binary snapshot sets `isBinaryReadOnlyBannerVisible == true` and `canSave == false` / `canFormat == false` / `canPinTab == false`, the BiDi snapshot reports exact UTF-16 offsets and scalar codes in `bidiWarnings`, and `javascript:` / `file:` links return `nil`

#### Scenario: N10 Security Banner Foreground and Border Tokens Pass Contrast Thresholds in Light and Black Modes
- **Path**: N10
- **Trait**: security
- **GIVEN** `PurpleThemePalette` resolved in `.light` and `.black` modes
- **WHEN** BiDi warning, Binary Quarantine warning, and Inert Raw HTML foreground, background, and border tokens are evaluated
- **THEN** each foreground-to-background ratio is at least `4.5` and each border-to-`chromeSurface` ratio is at least `3.0`

### Requirement: REQ-003 MainActor TextKit 2 Scoped Transactions Diff Coordinator and Inert Preview
WHEN coordinating edits, theme switches, visual highlights, Markdown smart newlines, previews, or Myers diffs on `@MainActor`, the editor and diff coordinators SHALL keep live text in `NSTextContentStorage`, render current-line, nested bracket, and backtick highlights without mutating text, project Side-by-Side diff rows, and render raw HTML previews as inert plain text [AR-003][SEC-004][UI-003][UI-005][UI-006][UI-007][UI-009][UI-010][UI-011][UI-012].

#### Scenario: P2 Scoped TextKit 2 Transactions Cmd+D Format Theme Switch and Side-by-Side Diff
- **Path**: P2
- **Trait**: positive
- **GIVEN** a `@MainActor` `WorkspaceEditorCoordinator` managing an open Markdown buffer and a `DiffPaneCoordinator` comparing two snapshots
- **WHEN** `performCommandD`, `formatDocument`, appearance switching (`.light` -> `.black`), and `DiffPaneCoordinator.compare(lhs:rhs:)` execute
- **THEN** `TextKit2BufferAdapter` updates `NSTextContentStorage` via scoped `performEditingTransaction` without reloading the buffer on theme switch, `DiffPaneCoordinator` produces aligned Side-by-Side rows, and VoiceOver labels + Reduce Motion flags are exposed

#### Scenario: N3 Mutating Commands on Binary Tab Surface Non-Destructive Warning Banner
- **Path**: N3
- **Trait**: negative
- **GIVEN** a `@MainActor` `WorkspaceEditorCoordinator` inspecting a binary read-only `DocumentSession`
- **WHEN** `performCommandD` or `formatDocument` is invoked
- **THEN** the buffer remains untouched and `lastErrorBannerMessage` records a non-destructive read-only warning

#### Scenario: N4 Raw HTML in Markdown Preview Is Projected as Inert Plain Text
- **Path**: N4
- **Trait**: security
- **GIVEN** a Markdown `DocumentSnapshot` containing `"# Heading\n\n<script>alert(1)</script>\n\n<iframe src=\"https://evil.example\"></iframe>"`
- **WHEN** `WorkspaceEditorCoordinator.projectMarkdownPreview(from:)` builds preview blocks
- **THEN** raw HTML nodes are marked `isInertPlainTextHTML == true` and preserved as literal plain text without script execution

#### Scenario: P5 Non-Mutating Visual Highlight Projection for Current Line Nested Brackets and Backticks
- **Path**: P5
- **Trait**: positive
- **GIVEN** a `@MainActor` `SwiftEditWorkbenchModel` holding `"scrivo{a[b(c)]} `code`"` with caret inside `"(c)"`
- **WHEN** visual highlight state is projected for TextKit 2 rendering
- **THEN** active line, depth-colored bracket spans, and backtick ranges are projected without incrementing `BufferRevision` or mutating `session.text`

#### Scenario: N8 Binary Read-Only Buffer Suppresses Smart Newline and Visual Edit Mutation
- **Path**: N8
- **Trait**: negative
- **GIVEN** a `@MainActor` `SwiftEditWorkbenchModel` holding a binary read-only snapshot
- **WHEN** `handleSmartNewline(at:)` is invoked
- **THEN** the call returns `false` and leaves the binary buffer unmodified

### Requirement: REQ-004 XcodeApp AppIcon Catalogs Sandbox Entitlements and nbgv Info.plist Stamping
WHEN validating or stamping the `XcodeApp/` application shell, the packaging fitness validator SHALL verify the bundled Concept E2 macOS and iOS `AppIcon.appiconset` catalogs, enforce least-privilege App Sandbox `.entitlements` without network or `files.all` keys, and stamp `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist` deterministically from `version.json` [AR-001][AR-014][SEC-001][SEC-004][SEC-008][TEST-007][TEST-008][UI-001].

#### Scenario: P3 Bundled AppIcon Catalogs Valid Sandbox Entitlements and nbgv Info.plist Version Stamping
- **Path**: P3
- **Trait**: positive
- **GIVEN** `XcodeApp/Assets.xcassets/AppIcon.appiconset`, `XcodeApp/iOSAssets.xcassets/AppIcon.appiconset`, `XcodeApp/PH.SwiftEdit.macOS.entitlements`, `XcodeApp/PH.SwiftEdit.iOS.entitlements`, `XcodeApp/Info.plist`, and root `version.json` (`"0.0.1-alpha1"`)
- **WHEN** `EntitlementsFitnessValidator` and `InfoPlistVersionStamper` inspect the `XcodeApp/` bundle files
- **THEN** both `AppIcon.appiconset` catalogs pass slot and pixel verification, both `.entitlements` files pass least-privilege sandbox validation, and `XcodeApp/Info.plist` carries `CFBundleShortVersionString == "0.0.1"` and `CFBundleVersion == "0.0.1-alpha1"`

#### Scenario: N5 Malformed version.json or Info.plist Fails Version Stamping
- **Path**: N5
- **Trait**: negative
- **GIVEN** a malformed `version.json` missing the `"version"` field
- **WHEN** `InfoPlistVersionStamper.parseVersionDescriptor(from:)` is called
- **THEN** the call throws `PackagingFitnessError.invalidVersionManifest`

#### Scenario: N6 Over-Privileged or Unsandboxed Entitlements Plist Rejected
- **Path**: N6
- **Trait**: security
- **GIVEN** an `.entitlements` plist that disables `com.apple.security.app-sandbox` or enables `com.apple.security.network.client`, `com.apple.security.files.all`, or `com.apple.security.temporary-exception.files.absolute-path.read-write`
- **WHEN** `EntitlementsFitnessValidator.validate(plistData:platform:)` evaluates the plist
- **THEN** validation fails closed returning the exact forbidden entitlement violations
