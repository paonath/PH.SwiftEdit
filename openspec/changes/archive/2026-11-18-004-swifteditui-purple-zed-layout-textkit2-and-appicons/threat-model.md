# Threat Model: Build SwiftEditUI (Concept E2 Purple Chrome, #FFFFFF/#000000 Inverted TextKit 2 Editor, 50%..300% Zoom, Diff View) and Xcode .app Shell with AppIcon.appiconset and nbgv

## 1. Asset Boundaries & Trust Zones
- **Untrusted Document & Markdown Preview Zone**: User-opened source or Markdown files which may contain Unicode Trojan Source bidirectional override characters (`U+202A..U+202E`, `U+2066..U+2069`, `U+061C`), embedded raw HTML (`<script>`, `<iframe>`, `onload=`), `javascript:`/`file:`/`data:` links, or binary inspection payloads (`isBinaryReadOnly == true`).
- **`@MainActor` UI Coordination & TextKit 2 Zone (`SwiftEditUI`)**: Isolates `AppKit`/`UIKit` behind `#if os(macOS)` / `#if os(iOS)`, keeps buffer text inside `NSTextContentStorage` with scoped `performEditingTransaction` updates, renders raw HTML as inert plain text, and requires canonical URI confirmation (`[AR-003]`, `[UI-005..008]`, `[SEC-004]`).
- **App Sandbox & Packaging Boundary (`XcodeApp/`)**: Enforces macOS and iOS `.entitlements` (App Sandbox enabled, zero network/temporary-exception/files.all entitlements), Concept E2 `AppIcon.appiconset` integrity, and deterministic `nbgv` `Info.plist` version stamping (`[AR-001]`, `[AR-014]`, `[SEC-001]`).

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | Unicode bidirectional control characters (`U+202A..U+202E`, `U+2066..U+2069`, `U+061C`) visually reordering source code or URIs (`CWE-1007`), or deceptive Markdown link labels hiding external targets (`[UI-008]`, `[SEC-004]`). | `InspectionSafetyBannerState` scans buffers for BiDi control scalars emitting exact UTF-16 offset badges (`BiDiControlCharacterWarning`) and produces an `ExternalURIConfirmationPrompt` displaying the full canonical destination URI before handoff (`[UI-008]`, `[SEC-004]`). |
| Tampering | UI actions (`Save`, `Format Document`, `Pin Tab`, `Cmd+D`) invoked on a binary read-only inspection tab corrupting binary files (`[DATA-003]`, `[UI-008]`, `[SEC-012]`). | `InspectionSafetyBannerState` and `WorkspaceEditorCoordinator` disable `canSave`, `canFormat`, and `canPinTab` on binary tabs and surface a non-destructive read-only warning banner if an edit command is triggered (`[UI-008]`, `[UI-009]`). |
| Repudiation | Undetected version drift between `version.json` and packaged `Info.plist` bundles (`[AR-014]`, `[TEST-008]`). | `InfoPlistVersionStamper` deterministically stamps and validates `CFBundleShortVersionString` and `CFBundleVersion` from `version.json` (`0.0.1-alpha1`) (`[AR-014]`, `[TEST-008]`). |
| Information Disclosure | Embedded `<script>`, `<img>`, or `<iframe>` HTML in Markdown previews executing script or exfiltrating local files via WebKit (`CWE-79`, `[AR-002]`, `[UI-006]`, `[SEC-004]`). | `SwiftEditUI` never imports `WebKit`; Markdown previews are projected natively from `swift-markdown` AST blocks with raw HTML rendered strictly as inert plain text (`[UI-006]`, `[SEC-004]`). |
| Denial of Service | Per-keystroke whole-document `NSTextLayoutManager.ensureLayout` calls or full-string copies freezing `@MainActor` (`[UI-006]`, `[UI-007]`, `[UI-012]`). | `TextKit2BufferAdapter` mutates only dirty paragraph or viewport `TextRange` spans inside `NSTextContentStorage.performEditingTransaction` with zero whole-document `ensureLayout` calls (`[UI-006]`, `[UI-007]`, `[UI-012]`). |
| Elevation of Privilege | Over-privileged `.entitlements` granting network sockets (`com.apple.security.network.client`), `files.all`, or `cs.disable-library-validation` (`[SEC-001]`, `[SEC-004]`, `[SEC-008]`). | `EntitlementsFitnessValidator` parses `.entitlements` plists and fails closed if `com.apple.security.app-sandbox` is missing or any forbidden network, filesystem, or library-validation entitlement is present (`[SEC-001]`, `[SEC-004]`, `[SEC-008]`). |

## 3. Abuse Cases & Negative Scenarios
- **Abuse Scenario `N2` (Binary Read-Only Lockout, Trojan Source BiDi Detection & Unsafe URI Rejection — `Trait: security`)**: Inspecting a binary read-only snapshot activates the binary warning banner (`canSave == false`, `canFormat == false`, `canPinTab == false`), a buffer containing `U+202E` (`RLO`) or `U+2066` (`LRI`) emits `BiDiControlCharacterWarning` badges with exact UTF-16 offsets, and requesting external URI handoff for `javascript:alert(1)` or `file:///etc/passwd` is rejected (`nil`) while `https://swift.org` requires explicit confirmation (`[UI-008]`, `[SEC-004]`, `[SEC-012]`).
- **Abuse Scenario `N4` (Inert Raw HTML in Markdown Preview Projection — `Trait: security`)**: Projecting a Markdown document containing `<script>alert(1)</script>` and `<iframe src="https://evil.example">` through `WorkspaceEditorCoordinator` classifies the block as inert plain text (`isInertPlainTextHTML == true`) without interpreting or stripping the visible literal characters into executable markup (`[UI-006]`, `[UI-008]`, `[SEC-004]`).
- **Abuse Scenario `N6` (Forbidden Network, `files.all`, or Missing Sandbox Entitlement Rejection — `Trait: security`)**: Passing an `.entitlements` plist that disables `com.apple.security.app-sandbox` or enables `com.apple.security.network.client`, `com.apple.security.files.all`, or `com.apple.security.temporary-exception.files.absolute-path.read-write` to `EntitlementsFitnessValidator` fails closed with typed violation diagnostics (`[SEC-001]`, `[SEC-004]`, `[SEC-008]`).

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-18
- Verdict: approved
- Status: approved
- Open items: none
