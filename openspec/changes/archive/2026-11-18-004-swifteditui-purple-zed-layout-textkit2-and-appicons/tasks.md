# Tasks: Build SwiftEditUI (Concept E2 Purple Chrome, #FFFFFF/#000000 Inverted TextKit 2 Editor, 50%..300% Zoom, Diff View) and Xcode .app Shell with AppIcon.appiconset and nbgv

## 1. Unit: PurpleThemeZoomAndSafetyBanner
<!-- Governing rules: UI-001, UI-002, UI-003, UI-004, UI-008, UI-009, DATA-003, SEC-004, SEC-012, TEST-001, TEST-002, SDD-002, SDD-003 -->

- [x] 1.0 [SETUP] TASK-000-SETUP: Create `Sources/SwiftEditUI/Theme`, `Sources/SwiftEditUI/Coordinators`, `Sources/SwiftEditUI/Packaging`, and `XcodeApp` directories and stage Concept E2 `macos` and `ios` `AppIcon.appiconset` catalogs under `XcodeApp/` before behavioral TDD triads [Const: SDD-003 (08-sdd-governance/artifact-traceability.md)]
  - paths: [P1, P2, P3]
- [x] 1.1 [RED] TASK-001-RED: Write failing `Swift Testing` `@Suite("PurpleThemeZoomAndSafetyBannerTests")` tests in `Tests/SwiftEditTests/PurpleThemeZoomAndSafetyBannerTests.swift` for `P1` (Concept E2 Purple `#0B0614`/`#7C3AED`/`#A78BFA`/`#C4B5FD` tokens, `#FFFFFF`/`#000000` Light and `#000000`/`#FFFFFF` Black `21:1` contrast, `50%..300%` `EditorZoomController`, and `https://` URI confirmation) and `N1` (`50%` and `300%` zoom boundary clamping); verify failure on assertions [Const: UI-001 (03-ui-ux/design-system-and-tokens.md)]
  - paths: [P1, N1]
- [x] 1.2 [GREEN] TASK-001-GREEN: Implement `RGBAColorToken`, `PurpleThemePalette`, `EditorZoomController`, and `InspectionSafetyBannerState` in `Sources/SwiftEditUI/Theme/PurpleThemeAndZoom.swift` so `P1` and `N1` pass [Const: UI-002 (03-ui-ux/design-system-and-tokens.md)]
  - paths: [P1, N1]
- [x] 1.3 [REFACTOR] TASK-001-REFACTOR: Extract WCAG 2.2 relative luminance contrast calculator and zoom step helpers in `PurpleThemeAndZoom.swift` while keeping `P1` and `N1` green [Const: UI-004 (03-ui-ux/design-system-and-tokens.md)]
  - paths: [P1, N1]
- [x] 1.4 [DOC] TASK-001-DOC: Write concise English Swift Markup (`///`) documentation on `RGBAColorToken`, `PurpleThemePalette`, `EditorZoomController`, and `InspectionSafetyBannerState`
  - paths: [P1, N1]
- [x] 1.5 [RED] [SECURITY] TASK-002-RED: Write failing security test `n2SecurityBinaryLockoutBiDiTrojanSourceAndExternalURIGate` in `Tests/SwiftEditTests/PurpleThemeZoomAndSafetyBannerTests.swift` for `N2` verifying binary read-only lockout (`canSave == false`, `canFormat == false`, `canPinTab == false`), Trojan Source BiDi detection (`U+202E`, `U+2066`, `U+061C`), and rejection of `javascript:`/`file:`/`data:` URIs; verify failure on assertions [Const: UI-008 (03-ui-ux/component-state-and-forms.md)]
  - paths: [P1, N2] · tags: security · priority: critical
- [x] 1.6 [GREEN] [SECURITY] TASK-002-GREEN: Implement binary action lockout, Unicode BiDi scalar scanner (`U+202A..U+202E`, `U+2066..U+2069`, `U+061C`), and `https`/`http`/`mailto` URI confirmation gate in `InspectionSafetyBannerState` so `N2` passes [Const: SEC-004 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P1, N2] · tags: security · priority: critical
- [x] 1.7 [REFACTOR] [SECURITY] TASK-002-REFACTOR: Consolidate BiDi scalar table and URI scheme allowlist check in `InspectionSafetyBannerState` while keeping all suites green [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [P1, N2] · tags: security
- [x] 1.8 [DOC] [SECURITY] TASK-002-DOC: Document Trojan Source BiDi (`CWE-1007`), binary lockout, and canonical URI confirmation invariants in English Swift Markup (`///`) comments
  - paths: [P1, N2]

## 2. Unit: TextKit2EditorAndDiffCoordinator
<!-- Governing rules: AR-003, UI-003, UI-005, UI-006, UI-007, UI-008, UI-009, UI-010, UI-011, UI-012, SEC-004 -->

- [x] 2.1 [RED] TASK-003-RED: Write failing `Swift Testing` `@Suite("TextKit2EditorAndDiffCoordinatorTests")` tests in `Tests/SwiftEditTests/TextKit2EditorAndDiffCoordinatorTests.swift` for `P2` (`@MainActor` `TextKit2BufferAdapter` scoped `performEditingTransaction` updates, `WorkspaceEditorCoordinator` `Cmd+D` / `Format Document` / dynamic theme switching without buffer reload, `DiffPaneCoordinator` Side-by-Side rows, VoiceOver labels, and Reduce Motion suppression) and `N3` (binary tab edit/format blocked with non-destructive warning banner); verify failure on assertions [Const: UI-005 (03-ui-ux/component-state-and-forms.md)]
  - paths: [P2, N3]
- [x] 2.2 [GREEN] TASK-003-GREEN: Implement `TextKit2BufferAdapter`, `WorkspaceEditorCoordinator`, and `DiffPaneCoordinator` in `Sources/SwiftEditUI/Coordinators/WorkspaceEditorAndDiffCoordinators.swift` so `P2` and `N3` pass [Const: UI-007 (03-ui-ux/component-state-and-forms.md)]
  - paths: [P2, N3]
- [x] 2.3 [REFACTOR] TASK-003-REFACTOR: Extract Side-by-Side diff row alignment and VoiceOver accessibility summary builders while keeping `P2` and `N3` green [Const: UI-010 (03-ui-ux/accessibility-and-cwv.md)]
  - paths: [P2, N3]
- [x] 2.4 [DOC] TASK-003-DOC: Write concise English Swift Markup (`///`) documentation on `TextKit2BufferAdapter`, `WorkspaceEditorCoordinator`, `SideBySideDiffRow`, and `DiffPaneCoordinator`
  - paths: [P2, N3]
- [x] 2.5 [RED] [SECURITY] TASK-004-RED: Write failing security test `n4SecurityMarkdownPreviewRendersRawHTMLAsInertPlainText` in `Tests/SwiftEditTests/TextKit2EditorAndDiffCoordinatorTests.swift` for `N4` verifying that `<script>` and `<iframe>` blocks in Markdown are projected with `isInertPlainTextHTML == true`; verify failure on assertions [Const: UI-006 (03-ui-ux/component-state-and-forms.md)]
  - paths: [P2, N4] · tags: security · priority: critical
- [x] 2.6 [GREEN] [SECURITY] TASK-004-GREEN: Implement AST/line Markdown preview block projection in `WorkspaceEditorCoordinator` marking raw HTML blocks and inline HTML tags `isInertPlainTextHTML = true` so `N4` passes [Const: SEC-004 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P2, N4] · tags: security · priority: critical
- [x] 2.7 [REFACTOR] [SECURITY] TASK-004-REFACTOR: Refine fenced-code vs raw-HTML classification in `projectMarkdownPreview` while keeping all suites green [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
  - paths: [P2, N4] · tags: security
- [x] 2.8 [DOC] [SECURITY] TASK-004-DOC: Document zero-WebKit inert HTML preview rendering (`UI-006`, `SEC-004`) in English Swift Markup (`///`) comments
  - paths: [P2, N4]

## 3. Unit: XcodeAppShellAndPackagingFitness
<!-- Governing rules: AR-001, AR-014, UI-001, SEC-001, SEC-004, SEC-008, TEST-007, TEST-008 -->

- [x] 3.1 [RED] TASK-005-RED: Write failing `Swift Testing` `@Suite("XcodeAppShellAndPackagingFitnessTests")` tests in `Tests/SwiftEditTests/XcodeAppShellAndPackagingFitnessTests.swift` for `P3` (`XcodeApp/` macOS/iOS `AppIcon.appiconset` completeness, least-privilege `.entitlements`, and `nbgv` `Info.plist` version stamping from `version.json`) and `N5` (`PackagingFitnessError.invalidVersionManifest` on malformed `version.json`); verify failure on assertions [Const: AR-014 (01-architecture/host-and-sagas.md)]
  - paths: [P3, N5]
- [x] 3.2 [GREEN] TASK-005-GREEN: Create `XcodeApp/PH.SwiftEdit.macOS.entitlements`, `XcodeApp/PH.SwiftEdit.iOS.entitlements`, and `XcodeApp/Info.plist`, and implement `EntitlementsFitnessValidator` and `InfoPlistVersionStamper` in `Sources/SwiftEditUI/Packaging/XcodePackagingFitness.swift` so `P3` and `N5` pass [Const: AR-001 (01-architecture/module-topology.md)]
  - paths: [P3, N5]
- [x] 3.3 [REFACTOR] TASK-005-REFACTOR: Extract SemVer prefix parser (`0.0.1-alpha1` -> short version `0.0.1`) in `InfoPlistVersionStamper` while keeping `P3` and `N5` green [Const: TEST-007 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P3, N5]
- [x] 3.4 [DOC] TASK-005-DOC: Write concise English Swift Markup (`///`) documentation on `PackagingFitnessError`, `EntitlementsFitnessValidator`, and `InfoPlistVersionStamper`
  - paths: [P3, N5]
- [x] 3.5 [RED] [SECURITY] TASK-006-RED: Write failing security test `n6SecurityEntitlementsValidatorRejectsUnsandboxedNetworkAndFilesAllKeys` in `Tests/SwiftEditTests/XcodeAppShellAndPackagingFitnessTests.swift` for `N6` verifying rejection of missing `app-sandbox` or enabled `network.client`, `network.server`, `files.all`, `temporary-exception`, or `cs.disable-library-validation` keys; verify failure on assertions [Const: SEC-001 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P3, N6] · tags: security · priority: critical
- [x] 3.6 [GREEN] [SECURITY] TASK-006-GREEN: Enforce forbidden-key denylist and mandatory `com.apple.security.app-sandbox == true` check in `EntitlementsFitnessValidator` so `N6` passes [Const: SEC-008 (07-security-privacy/secrets-and-supply-chain.md)]
  - paths: [P3, N6] · tags: security · priority: critical
- [x] 3.7 [REFACTOR] [SECURITY] TASK-006-REFACTOR: Verify zero compiler warnings and `>= 85%` `SwiftEditCore` & `SwiftEditUI` line coverage across all parallel test suites [Const: TEST-008 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P3, N6] · tags: security
- [x] 3.8 [DOC] [SECURITY] TASK-006-DOC: Document App Sandbox least-privilege entitlement rules (`SEC-001`, `SEC-004`, `SEC-008`) in English Swift Markup (`///`) comments
  - paths: [P3, N6]
