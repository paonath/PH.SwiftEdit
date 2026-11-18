# Proposal: Build SwiftEditUI (Concept E2 Purple Chrome, #FFFFFF/#000000 Inverted TextKit 2 Editor, 50%..300% Zoom, Diff View) and Xcode .app Shell with AppIcon.appiconset and nbgv

## Why
With all four `SwiftEditCore` bounded contexts (`001` `DocumentCore`, `002` `MarkdownLintAndFormat` & `SearchDiffAndBracketEngine`, and `003` `WorkspaceAndTabSession`) implemented and archived, `PH.SwiftEdit` is ready for the fifth and final roadmap deliverable (`TASK-05` in `reasoning/001_project-constitution/README.ai.md`): building **`SwiftEditUI`** and the thin **`XcodeApp/`** packaging shell. This change delivers the Concept E2 Feather-in-Triangle Purple (`Viola`: `#0B0614`, `#7C3AED`, `#A78BFA`, `#C4B5FD`) workspace chrome, the inverted `#FFFFFF`/`#000000` (`Light`) and `#000000`/`#FFFFFF` (`Black`) TextKit 2 editor canvas (`21:1` contrast), `50%..300%` Zoom Mode, `@MainActor @Observable` editor and Side-by-Side Myers diff coordinators, binary read-only and Unicode Trojan Source BiDi warning banners, and the Xcode `.app` shell bundling the official macOS/iOS `AppIcon.appiconset` catalogs, least-privilege App Sandbox `.entitlements`, and `nbgv` `Info.plist` version stamping (`0.0.1-alpha1`).

## What Changes
- Implement `Sources/SwiftEditUI/Theme/`:
  - `RGBAColorToken`, `PurpleThemePalette` (`#0B0614`, `#7C3AED`, `#A78BFA`, `#C4B5FD` chrome tokens + `#FFFFFF`/`#000000` in `Light` and `#000000`/`#FFFFFF` in `Black` with WCAG contrast ratio calculation `>= 4.5:1` on chrome and `21:1` on editor canvas) (`[UI-001]`, `[UI-002]`, `[UI-003]`, `[UI-009]`).
  - `EditorZoomController` scaling monospaced editor font points across `50%..300%` (`zoomIn` `Cmd++`, `zoomOut` `Cmd+-`, `resetZoom` `Cmd+0`, pinch magnification, and pane focus toggle) without mutating document text (`[UI-004]`).
  - `BiDiControlCharacterWarning`, `ExternalURIConfirmationPrompt`, and `InspectionSafetyBannerState` enforcing read-only binary inspection banners (disabling Save, Format, and Pin Tab), detecting Unicode Trojan Source BiDi control characters (`U+202A..U+202E`, `U+2066..U+2069`, `U+061C`), and gating external URI handoffs behind user confirmation on allowlisted `https`/`http`/`mailto` schemes (`[UI-008]`, `[SEC-004]`).
- Implement `Sources/SwiftEditUI/Coordinators/`:
  - `@MainActor @Observable` `WorkspaceEditorCoordinator` and `TextKit2BufferAdapter` (`#if os(macOS)` `NSTextContentStorage` single source of truth with scoped `performEditingTransaction` attribute updates on dirty/viewport ranges and zero whole-document `ensureLayout` calls) (`[AR-003]`, `[UI-005]`, `[UI-006]`, `[UI-007]`, `[UI-012]`).
  - `@MainActor @Observable` `DiffPaneCoordinator` projecting Side-by-Side and Inline Myers `DiffHunk` rows, inert plain-text Markdown preview projection (escaping raw HTML `<script>`/`<iframe>` tags), Reduce Motion animation suppression (`UI-011`), and VoiceOver accessibility descriptors (`UI-010`).
- Implement `XcodeApp/` and `Sources/SwiftEditUI/Packaging/`:
  - `XcodeApp/Assets.xcassets/AppIcon.appiconset` (`10` macOS PNGs `16..1024 px`) and `XcodeApp/iOSAssets.xcassets/AppIcon.appiconset` (`8` opaque iOS PNGs `40..1024 px`) synced from `docs/design/assets/app-icons/` (`[AR-001]`, `[UI-001]`, `[TEST-007]`).
  - `XcodeApp/PH.SwiftEdit.macOS.entitlements` and `XcodeApp/PH.SwiftEdit.iOS.entitlements` enabling strictly App Sandbox user-selected read-write and app-scoped bookmark keys while forbidding network, `files.all`, and `temporary-exception` keys (`[SEC-001]`, `[SEC-004]`).
  - `XcodeApp/Info.plist` and `InfoPlistVersionStamper` + `EntitlementsFitnessValidator` verifying deterministic `nbgv` version stamping (`0.0.1-alpha1` from `version.json`) and sandbox entitlement compliance (`[AR-014]`, `[SEC-001]`, `[TEST-008]`).

## Capabilities
- New Capabilities: `swifteditui-purple-zed-layout-textkit2-and-appicons`
- Modified Capabilities: None

## Domain Carrier & Decision Ownership (BC-###)
- **BC-001**: `SwiftEditUI` is the presentation and `@MainActor` coordination layer consuming `SwiftEditCore` value objects (`DocumentSession`, `DocumentSnapshot`, `MarkdownLintAndFormatEngine`, `SearchDiffAndBracketEngine`, `WorkspaceTabSession`, `SessionRecoveryStore`, `DotfileFolderNavigator`, `EditorPreferencesStore`) (`[AR-003]`, `[AR-006]`, `[BC-009]`).
- **Owned Decisions**: Concept E2 Purple theme token resolution, `#FFFFFF`/`#000000` canvas inversion, `50%..300%` font zoom scaling, `NSTextContentStorage` scoped editing transactions, binary/BiDi warning banner presentation, inert Markdown preview projection, and Xcode `.app` bundle asset/entitlements/version fitness (`[UI-001..012]`, `[AR-001]`, `[AR-014]`, `[SEC-001]`).
- **Forbidden Responsibilities**: `SwiftEditUI` MUST NEVER bypass `DocumentSession` domain guards to save binary buffers (`[BC-003]`, `[DATA-003]`), execute raw HTML/JavaScript inside Markdown previews (`[UI-006]`, `[SEC-004]`), call whole-document `NSTextLayoutManager.ensureLayout` (`[UI-012]`), or enable network/unrestricted-filesystem entitlements (`[SEC-001]`, `[SEC-004]`).
- **External Decision References**: Consumes `DocumentID`, `BufferRevision`, `TabDescriptor`, `DiffHunk`, `BracketPairSpan`, and `MarkdownLintDiagnostic` value types from `SwiftEditCore` (`[BC-006]`).

## Impact
- **Source Modules**: Adds `Sources/SwiftEditUI/Theme/**`, `Sources/SwiftEditUI/Coordinators/**`, `Sources/SwiftEditUI/Packaging/**`, and `XcodeApp/**` (`Assets.xcassets`, `iOSAssets.xcassets`, `.entitlements`, `Info.plist`).
- **Test Suites**: Adds `PurpleThemeZoomAndSafetyBannerTests.swift`, `TextKit2EditorAndDiffCoordinatorTests.swift`, and `XcodeAppShellAndPackagingFitnessTests.swift` under `Tests/SwiftEditTests/`.

## Security Impact
- Mitigates Trojan Source bidirectional spoofing (`CWE-1007`, `[UI-008]`) by scanning buffers for `U+202A..U+202E`, `U+2066..U+2069`, and `U+061C` and surfacing inline BiDi badges.
- Enforces UI-level binary quarantine (`[UI-008]`, `[DATA-003]`): binary inspection tabs display a read-only warning banner and disable Save, Format, and Pin Tab actions.
- Prevents Markdown preview XSS (`CWE-79`, `[UI-006]`) and unsafe URI handoff (`[UI-008]`, `[SEC-004]`) by rendering raw HTML tags as inert plain text and requiring user confirmation on `https`/`http`/`mailto` links while blocking `javascript:`, `file:`, and `data:`.
- Enforces App Sandbox least-privilege entitlements (`[SEC-001]`) via automated `EntitlementsFitnessValidator` checks.

## Metadata
- Owner: PH.SwiftEdit Team
- Domain: Swift 6 SwiftEditUI (Purple Chrome, TextKit 2, Zoom, Diff) & XcodeApp Packaging
- Reviewer: swift-macos-expert, cyber-security-expert, test-quality-auditor
- Branch: feature/FirstStub
- Manual-Steps: none
- Modifies-Specs: none
- Constitutional-Rules: [AR-001, AR-003, AR-006, AR-008, AR-014, BC-009, UI-001, UI-002, UI-003, UI-004, UI-005, UI-006, UI-007, UI-008, UI-009, UI-010, UI-011, UI-012, SEC-001, SEC-004, SEC-009, SEC-010, SEC-012, TEST-001, TEST-002, TEST-003, TEST-006, TEST-007, TEST-008, SDD-001, SDD-002, SDD-003]
- Amends-Constitution: none

## Prerequisites
- Completed `000-promote-design-and-app-icons-to-docs` (`TASK-01`), `001-swifteditcore-document-and-binary-guard` (`TASK-02`), `002-markdown-lint-format-bracket-and-diff` (`TASK-03`), and `003-notepadpp-tabs-session-recovery-and-dotfiles` (`TASK-04`).
