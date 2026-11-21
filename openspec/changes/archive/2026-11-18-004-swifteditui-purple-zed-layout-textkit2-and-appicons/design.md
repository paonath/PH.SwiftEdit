# Design: Build SwiftEditUI (Concept E2 Purple Chrome, #FFFFFF/#000000 Inverted TextKit 2 Editor, 50%..300% Zoom, Diff View) and Xcode .app Shell with AppIcon.appiconset and nbgv

## Context
With all four `SwiftEditCore` bounded contexts (`001` `DocumentCore`, `002` `MarkdownLintAndFormat` & `SearchDiffAndBracketEngine`, and `003` `WorkspaceAndTabSession`) complete and tested at `92.55%` line coverage, `TASK-05` completes the `PH.SwiftEdit` architecture by implementing `SwiftEditUI` and the `XcodeApp/` bundle resources (`[AR-001]`, `[AR-003]`, `[AR-014]`, `[UI-001..012]`, `[SEC-001]`).

## Goals / Non-Goals
- Goals:
  - Implement the Concept E2 Feather-in-Triangle Purple (`Viola`: `#0B0614`, `#7C3AED`, `#A78BFA`, `#C4B5FD`) chrome palette and inverted `#FFFFFF`/`#000000` (`Light`) and `#000000`/`#FFFFFF` (`Black`) editor canvas (`21:1` WCAG contrast) (`[UI-001..003]`, `[UI-009]`).
  - Implement `50%..300%` `EditorZoomController` (`Cmd++`, `Cmd+-`, `Cmd+0`, pinch magnification, pane focus zoom) without mutating document text (`[UI-004]`).
  - Implement `@MainActor @Observable` `WorkspaceEditorCoordinator`, `TextKit2BufferAdapter` (`NSTextContentStorage` with scoped `performEditingTransaction` updates), and `DiffPaneCoordinator` (Side-by-Side & Inline Myers diff rows, inert plain-text raw HTML preview, VoiceOver labels, Reduce Motion suppression) (`[UI-005..012]`).
  - Bundle `XcodeApp/Assets.xcassets/AppIcon.appiconset` (macOS 10 PNGs), `XcodeApp/iOSAssets.xcassets/AppIcon.appiconset` (iOS 8 PNGs), least-privilege App Sandbox `.entitlements`, and `XcodeApp/Info.plist` stamped from `version.json` (`0.0.1-alpha1`) (`[AR-001]`, `[AR-014]`, `[SEC-001]`, `[TEST-007]`, `[TEST-008]`).
- Non-Goals:
  - External network access, WebKit HTML rendering, or third-party UI dependencies (`[AR-002]`, `[AR-005]`, `[SEC-004]`).

## Architecture Memory & Module Boundaries (AR-###)
- **AR-001**: `XcodeApp/` bundles the official macOS (`10` PNGs) and iOS (`8` PNGs) `AppIcon.appiconset` catalogs alongside least-privilege App Sandbox `.entitlements`.
- **AR-003**: `SwiftEditUI` isolates `AppKit` (`#if os(macOS)`) and `UIKit` (`#if os(iOS)`) behind conditional compilation while annotating all `@Observable` coordinators with `@MainActor` (`[UI-005]`).
- **AR-014**: `XcodeApp/Info.plist` is stamped deterministically from `version.json` (`0.0.1-alpha1`) via `InfoPlistVersionStamper`.
- **Single-Reference Lock**: Loaded `openspec/Constitution.md` alongside `01-architecture/module-topology.md`, `01-architecture/host-and-sagas.md`, `03-ui-ux/design-system-and-tokens.md`, `03-ui-ux/component-state-and-forms.md`, `03-ui-ux/accessibility-and-cwv.md`, `06-testing-fitness/tdd-and-unit-testing.md`, `06-testing-fitness/architecture-fitness-and-quality.md`, `07-security-privacy/authn-authz-and-boundaries.md`, `07-security-privacy/stride-and-gdpr-privacy.md`, and `08-sdd-governance/artifact-traceability.md`.

## Bounded Context Classification & Ubiquitous Language Glossary (`BC-002`, `BC-009`)

| Component / Type | Classification / Kind | Normative Definition (`BC-009`) |
| :--- | :--- | :--- |
| `RGBAColorToken` | Value Object (`struct`, `Equatable`, `Sendable`) | Hex and sRGB color descriptor `(hex: String, red: Double, green: Double, blue: Double, alpha: Double)` with WCAG 2.2 relative luminance and contrast ratio calculation (`[UI-001]`, `[UI-002]`, `[UI-009]`). |
| `PurpleThemePalette` | Value Object (`struct`, `Equatable`, `Sendable`) | Resolved Concept E2 Purple (`Viola`) chrome and `#FFFFFF`/`#000000` inverted editor canvas token set for `.light` or `.black` mode (`[UI-001..003]`). |
| `EditorZoomController` | Value Object (`struct`, `Equatable`, `Sendable`) | Manages `50%..300%` editor zoom scaling (`zoomIn`, `zoomOut`, `resetZoom`, `applyPinchMagnification`, `isPaneFocusZoomed`) over a base monospaced font size without mutating buffer text (`[UI-004]`). |
| `BiDiControlCharacterWarning` | Value Object (`struct`, `Equatable`, `Sendable`) | Inline warning badge descriptor `(utf16Offset: Int, line: Int, scalarHex: String, name: String)` for Trojan Source bidirectional scalars (`U+202A..U+202E`, `U+2066..U+2069`, `U+061C`) (`[UI-008]`). |
| `ExternalURIConfirmationPrompt` | Value Object (`struct`, `Equatable`, `Sendable`) | Canonicalized external URI handoff prompt `(scheme: String, canonicalURI: String, requiresUserConfirmation: Bool)` restricted to `https`, `http`, and `mailto` (`[UI-008]`, `[SEC-004]`). |
| `InspectionSafetyBannerState` | Value Object (`struct`, `Equatable`, `Sendable`) | Computed safety state for an active buffer `(isBinaryReadOnlyBannerVisible: Bool, canSave: Bool, canFormat: Bool, canPinTab: Bool, bidiWarnings: [BiDiControlCharacterWarning])` (`[UI-008]`). |
| `TextKit2BufferAdapter` | `@MainActor` Adapter (`final class`) | Wraps `#if os(macOS)` `NSTextContentStorage` (and cross-platform storage state) applying scoped `performEditingTransaction` attribute updates on dirty/viewport `TextRange` spans (`[UI-006]`, `[UI-007]`, `[UI-012]`). |
| `MarkdownPreviewBlock` | Value Object (`struct`, `Equatable`, `Sendable`) | Native AST-projected preview block `(kind: Kind, text: String, isInertPlainTextHTML: Bool)` rendering raw HTML strictly as inert plain text (`[UI-006]`). |
| `WorkspaceEditorCoordinator` | `@MainActor @Observable` Coordinator (`final class`) | Coordinates `DocumentSession`, `WorkspaceTabSession`, `PurpleThemePalette`, `EditorZoomController`, `TextKit2BufferAdapter`, `InspectionSafetyBannerState`, VoiceOver descriptors, and Reduce Motion state (`[UI-005..012]`). |
| `SideBySideDiffRow` | Value Object (`struct`, `Equatable`, `Sendable`) | Aligned Side-by-Side or Inline Myers diff row `(lhsLineNumber: Int?, lhsText: String?, rhsLineNumber: Int?, rhsText: String?, kind: DiffHunkKind)` (`[UI-007]`). |
| `DiffPaneCoordinator` | `@MainActor @Observable` Coordinator (`final class`) | Computes and projects Myers `FileCompareDiffResult` into `SideBySideDiffRow` items (`[UI-005]`, `[UI-007]`). |
| `EntitlementsFitnessValidator` | Packaging Validator (`enum`, `Sendable`) | Audits macOS and iOS `.entitlements` plists against `SEC-001` least-privilege App Sandbox rules (`[SEC-001]`, `[SEC-004]`). |
| `InfoPlistVersionStamper` | Packaging Utility (`enum`, `Sendable`) | Parses `version.json` (`Nerdbank.GitVersioning`) and stamps/verifies `CFBundleShortVersionString` and `CFBundleVersion` in `XcodeApp/Info.plist` (`[AR-014]`, `[TEST-008]`). |

## Decisions
- **Decision 1 — Pure Value-Type Theme, Contrast & Safety Models + `@MainActor @Observable` Coordinators (`KISS-First`)**:
  - *Rationale*: Separating `PurpleThemePalette`, `EditorZoomController`, and `InspectionSafetyBannerState` as `Sendable` value types while keeping `WorkspaceEditorCoordinator`, `TextKit2BufferAdapter`, and `DiffPaneCoordinator` `@MainActor @Observable` satisfies `UI-005` and enables fast deterministic unit tests in `SwiftEditTests`.
- **Decision 2 — Scoped `NSTextContentStorage.performEditingTransaction` Adapter**:
  - *Rationale*: On macOS (`#if os(macOS)`), `TextKit2BufferAdapter` owns an `NSTextContentStorage` instance and applies attribute dictionaries strictly to the requested dirty paragraph or viewport `NSRange` inside `textContentStorage.performEditingTransaction { ... }`, recording `scopedTransactionCount` and never invoking whole-document `ensureLayout` (`[UI-006]`, `[UI-007]`, `[UI-012]`).
- **Decision 3 — Tracked `XcodeApp/` Shell Resources & Deterministic `nbgv` Stamping**:
  - *Rationale*: Storing `XcodeApp/Assets.xcassets/AppIcon.appiconset`, `XcodeApp/iOSAssets.xcassets/AppIcon.appiconset`, `XcodeApp/PH.SwiftEdit.macOS.entitlements`, `XcodeApp/PH.SwiftEdit.iOS.entitlements`, and `XcodeApp/Info.plist` directly in the repository allows `XcodeAppShellAndPackagingFitnessTests` to verify `AR-001`, `AR-014`, `SEC-001`, `TEST-007`, and `TEST-008` in milliseconds during `swift test --parallel`.

## Risks / Trade-offs
- **Raw HTML in Markdown Previews** -> Mitigated by projecting CommonMark `HTMLBlock` and `InlineHTML` nodes with `isInertPlainTextHTML = true` so raw `<script>` or `<iframe>` tags are displayed verbatim as plain text (`[UI-006]`, `[SEC-004]`).
- **BiDi Trojan Source Spoofing (`CWE-1007`)** -> Mitigated by scanning Unicode scalars for `0x202A...0x202E`, `0x2066...0x2069`, and `0x061C` and surfacing inline `BiDiControlCharacterWarning` badges (`[UI-008]`).

## Migration Plan
1. Create `Sources/SwiftEditUI/Theme/`, `Sources/SwiftEditUI/Coordinators/`, `Sources/SwiftEditUI/Packaging/`, and `XcodeApp/` directories (copying the verified macOS and iOS `AppIcon.appiconset` catalogs from `docs/design/assets/app-icons/`) in `1.0 [SETUP]`.
2. Execute TDD quads (`[RED] -> [GREEN] -> [REFACTOR] -> [DOC]`) across `PurpleThemeZoomAndSafetyBanner`, `TextKit2EditorAndDiffCoordinator`, and `XcodeAppShellAndPackagingFitness`.
3. Verify `swift test --parallel -Xswiftc -warnings-as-errors` passes with `0` warnings and `>= 85%` `SwiftEditCore` line coverage.

## Security Review
- Reviewer: cyber-security-expert
- Date: 2026-11-18
- Verdict: approved
- Status: approved
- Open items: none
