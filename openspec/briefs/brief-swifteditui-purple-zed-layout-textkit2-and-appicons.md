---
id: "brief-swifteditui-purple-zed-layout-textkit2-and-appicons"
change_id: "004-swifteditui-purple-zed-layout-textkit2-and-appicons"
capability: "swifteditui-purple-zed-layout-textkit2-and-appicons"
branch: "feature/FirstStub"
modifies_specs: "none"
status: "approved-via-qa"
date: "2026-11-18"
owners:
  - "swift-macos-expert"
  - "cyber-security-expert"
  - "test-quality-auditor"
---

# TDD Specification Brief: `SwiftEditUI` (Concept E2 Purple Chrome, `#FFFFFF`/`#000000` Inverted TextKit 2 Editor, `50%..300%` Zoom, Diff View) & Xcode `.app` Shell with `AppIcon.appiconset` and `nbgv` (`TASK-05`)

## 1. Context & Source Traceability

- **Originating Roadmap Task**: `TASK-05` in `reasoning/001_project-constitution/README.ai.md`.
- **Active Git Branch**: `feature/FirstStub` (`Nerdbank.GitVersioning` `0.0.1-alpha1`).
- **Consolidated Specs Modified (`modifies_specs`)**: `none` (existing living specs `design-assets-promotion`, `document-core-and-spm-scaffold`, `markdown-lint-format-bracket-and-diff`, and `notepadpp-tabs-session-recovery-and-dotfiles` are untouched; all requirements in `swifteditui-purple-zed-layout-textkit2-and-appicons` are `ADDED`).
- **Governing Constitutional Rules**: `[AR-001]`, `[AR-003]`, `[AR-006]`, `[AR-008]`, `[AR-014]`, `[BC-009]`, `[UI-001]`, `[UI-002]`, `[UI-003]`, `[UI-004]`, `[UI-005]`, `[UI-006]`, `[UI-007]`, `[UI-008]`, `[UI-009]`, `[UI-010]`, `[UI-011]`, `[UI-012]`, `[SEC-001]`, `[SEC-004]`, `[SEC-009]`, `[SEC-010]`, `[SEC-012]`, `[TEST-001]`, `[TEST-002]`, `[TEST-003]`, `[TEST-006]`, `[TEST-007]`, `[TEST-008]`, `[SDD-001]`, `[SDD-002]`, `[SDD-003]`.

## 2. Domain, Architecture & Security Expert Notes

- **`swift-macos-expert` (`openspec/agents/swift-macos-expert.agent.md` v1.2.0)**:
  - `SwiftEditUI` isolates `AppKit` (`#if os(macOS)`) and `UIKit` (`#if os(iOS)`) behind conditional compilation while keeping all `@Observable` coordinators (`WorkspaceEditorCoordinator`, `DiffPaneCoordinator`) annotated with `@MainActor` (`AR-003`, `UI-005`).
  - `PurpleThemePalette` encodes the official Concept E2 Feather-in-Triangle brand tokens (`#0B0614` dark ground, `#7C3AED` primary accent, `#A78BFA` lavender stroke, `#C4B5FD` highlight) across `Light`, `Black`, and `Auto` modes while enforcing `#FFFFFF` background / `#000000` text in `Light` mode and `#000000` background / `#FFFFFF` text in `Black` mode (`21:1` WCAG contrast) (`UI-001`, `UI-002`, `UI-003`, `UI-009`).
  - `EditorZoomController` scales editor typography from `50%` to `300%` (`Cmd++` `+10%`, `Cmd+-` `-10%`, `Cmd+0` `100%`, pinch magnification, and pane focus toggle) without mutating document text (`UI-004`).
  - `TextKit2BufferAdapter` (`#if os(macOS)` `NSTextContentStorage`) keeps text inside `NSTextContentStorage` without per-keystroke SwiftUI copies, applies highlight attributes exclusively to dirty/viewport ranges inside `performEditingTransaction`, renders raw HTML in Markdown previews as inert plain text, and avoids whole-document `ensureLayout` calls (`UI-006`, `UI-007`, `UI-012`).
- **`cyber-security-expert` (`03-ui-ux/component-state-and-forms.md` & `07-security-privacy/authn-authz-and-boundaries.md`)**:
  - `InspectionSafetyBannerState` detects binary read-only buffers (`isBinaryReadOnly == true`, disabling Save, Format, and Pin Tab actions) and Unicode Trojan Source bidirectional control characters (`U+202A..U+202E`, `U+2066..U+2069`, `U+061C`, `CWE-1007`), and requires explicit user confirmation on canonicalized `https`, `http`, or `mailto` URIs while blocking `javascript:`, `file:`, and `data:` handoffs (`UI-008`, `SEC-004`).
  - `XcodeApp/` bundles least-privilege `.entitlements` (`com.apple.security.app-sandbox`, `com.apple.security.files.user-selected.read-write`, `com.apple.security.files.bookmarks.app-scope`, with zero `network.client`, `network.server`, `files.all`, or `temporary-exception` keys), the official Concept E2 `macos/AppIcon.appiconset` (`10` PNGs `16..1024 px`) and `ios/AppIcon.appiconset` (`8` PNGs `40..1024 px`), and `Info.plist` deterministically stamped from `version.json` (`0.0.1-alpha1`) via `InfoPlistVersionStamper` (`AR-001`, `AR-014`, `SEC-001`, `TEST-007`, `TEST-008`).

## 3. 4-Pillar Breakdown & Path Coverage Matrix

| Unit | Path ID | Trait | Summary |
| :--- | :--- | :--- | :--- |
| `PurpleThemeZoomAndSafetyBanner` | `P1` | `positive` | Resolves Concept E2 Purple (`Viola`: `#0B0614`, `#7C3AED`, `#A78BFA`, `#C4B5FD`) chrome tokens and inverted `#FFFFFF`/`#000000` (`Light`) and `#000000`/`#FFFFFF` (`Black`) editor canvas colors (`21:1` contrast), and scales editor font size across `50%..300%` (`Cmd++`, `Cmd+-`, `Cmd+0`, pane focus) without mutating buffer text (`[UI-001..004]`, `[UI-009]`). |
| `PurpleThemeZoomAndSafetyBanner` | `N1` | `negative` | Zoom step commands at `50%` (`zoomOut`) or `300%` (`zoomIn`) clamp deterministically within `50...300` without underflow or overflow (`[UI-004]`, `[DATA-008]`). |
| `PurpleThemeZoomAndSafetyBanner` | `N2` | `security` | Binary read-only buffers activate the read-only warning banner disabling `canSave`, `canFormat`, and `canPinTab`; Unicode BiDi Trojan Source characters (`U+202E`, `U+2066`, `U+061C`) emit inline warning badges; and external URI handoff rejects `javascript:`/`file:`/`data:` schemes while requiring confirmation on `https:` (`[UI-008]`, `[SEC-004]`, `[SEC-012]`). |
| `TextKit2EditorAndDiffCoordinator` | `P2` | `positive` | `@MainActor` `WorkspaceEditorCoordinator` and `TextKit2BufferAdapter` synchronize `NSTextContentStorage` scoped `performEditingTransaction` updates, execute `Cmd+D` and `Format Document`/`Section` without reloading buffers on theme switch, project Side-by-Side Myers diff rows (`DiffPaneCoordinator`), and expose VoiceOver labels + Reduce Motion suppression (`[AR-003]`, `[UI-005..012]`). |
| `TextKit2EditorAndDiffCoordinator` | `N3` | `negative` | Attempting `Cmd+D` or `Format Document` through `WorkspaceEditorCoordinator` on a binary read-only tab or invalid selection surfaces a non-destructive error banner without mutating buffer state (`[UI-008]`, `[UI-009]`). |
| `TextKit2EditorAndDiffCoordinator` | `N4` | `security` | Markdown preview projection in `WorkspaceEditorCoordinator` renders raw `<script>` and `<iframe>` HTML blocks as inert escaped plain text and strips/blocks unsafe URI activation (`[UI-006]`, `[UI-008]`, `[SEC-004]`). |
| `XcodeAppShellAndPackagingFitness` | `P3` | `positive` | Verifies `XcodeApp/` bundle resources: Concept E2 `Assets.xcassets/AppIcon.appiconset` (`10` macOS PNGs) and `iOSAssets.xcassets/AppIcon.appiconset` (`8` iOS PNGs), least-privilege App Sandbox `.entitlements`, and deterministic `nbgv` version stamping of `XcodeApp/Info.plist` (`0.0.1-alpha1`) from `version.json` (`[AR-001]`, `[AR-014]`, `[SEC-001]`, `[TEST-007]`, `[TEST-008]`). |
| `XcodeAppShellAndPackagingFitness` | `N5` | `negative` | `InfoPlistVersionStamper` rejects missing or malformed `version.json` / `Info.plist` payloads with a typed error (`[AR-014]`, `[TEST-008]`). |
| `XcodeAppShellAndPackagingFitness` | `N6` | `security` | `EntitlementsFitnessValidator` rejects `.entitlements` manifests that omit `com.apple.security.app-sandbox` or include forbidden `network.client`, `network.server`, `files.all`, `temporary-exception`, or `cs.disable-library-validation` keys (`[SEC-001]`, `[SEC-004]`, `[SEC-008]`). |
