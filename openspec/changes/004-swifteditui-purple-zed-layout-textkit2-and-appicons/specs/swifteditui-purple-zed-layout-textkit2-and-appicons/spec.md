# Spec Delta: SwiftEditUI Purple Chrome, Inverted TextKit 2 Editor, Zoom, Diff View, and XcodeApp Packaging

## Purpose
Implements the `SwiftEditUI` presentation and coordination layer and the `XcodeApp/` packaging shell: Concept E2 Feather-in-Triangle Purple (`Viola`: `#0B0614`, `#7C3AED`, `#A78BFA`, `#C4B5FD`) chrome tokens, inverted `#FFFFFF`/`#000000` (`Light`) and `#000000`/`#FFFFFF` (`Black`) TextKit 2 editor canvas (`21:1` contrast), `50%..300%` Zoom Mode, `@MainActor @Observable` workspace and Side-by-Side Myers diff coordinators, binary read-only and Trojan Source BiDi safety banners, and Xcode `.app` `AppIcon.appiconset`, App Sandbox `.entitlements`, and `nbgv` `Info.plist` version stamping.

## ADDED Requirements

### Requirement: REQ-001 Concept E2 Purple Chrome Inverted B/W Canvas and 50..300 Percent Zoom
WHEN resolving theme tokens or zoom commands across `Light`, `Black`, and `Auto` modes, the theme and zoom controller SHALL expose the Concept E2 Purple chrome palette (`#0B0614`, `#7C3AED`, `#A78BFA`, `#C4B5FD`), invert the editor canvas between `#FFFFFF`/`#000000` (`Light`) and `#000000`/`#FFFFFF` (`Black`) at `21:1` contrast, and scale editor typography across `50%..300%` without mutating document text [UI-001][UI-002][UI-003][UI-004][UI-009].

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

### Requirement: REQ-002 Binary Read-Only Lockout BiDi Trojan Source Badges and URI Gate
IF a document snapshot is marked binary read-only, contains Unicode bidirectional control characters, or triggers an external URI handoff, THEN the safety banner evaluator SHALL disable mutating UI commands on binary buffers, emit inline BiDi control-character warnings, and require user confirmation on allowlisted `https`, `http`, or `mailto` URIs while blocking unsafe schemes [DATA-003][SEC-004][SEC-012][UI-008][UI-009].

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

### Requirement: REQ-003 MainActor TextKit 2 Scoped Transactions Diff Coordinator and Inert Preview
WHEN coordinating buffer edits, theme switches, Markdown previews, or Myers diffs on `@MainActor`, the workspace editor and diff coordinator SHALL keep live text in `NSTextContentStorage` with scoped `performEditingTransaction` updates, execute `Cmd+D` and formatting without reloading buffers on theme changes, project Side-by-Side diff rows, and render raw HTML in previews as inert plain text [AR-003][SEC-004][UI-003][UI-005][UI-006][UI-007][UI-009][UI-010][UI-011][UI-012].

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

## MODIFIED Requirements
<!-- When modifying an existing requirement, existing scenarios are preserved additively by default.
     Use optional directives in the requirement body (stripped upon merge):
     - **REMOVED-SCENARIO**: `<Scenario Title>` — **Reason**: <justification>
     - **RENAMED-SCENARIO**: FROM `<Old Title>` TO `<New Title>` -->

## REMOVED Requirements
<!-- When removing a requirement, provide ### Requirement: <Title> and **Reason**: <justification> -->

## RENAMED Requirements
<!-- When renaming a requirement, provide bullet pairs:
     - FROM: `### Requirement: <Old Title>`
     - TO: `### Requirement: <New Title>` -->
