# Threat Model: Full-App Semantic Light/Dark/Auto Theming, macOS Window Chrome Sync & UI Token Fitness

## 1. Asset Boundaries & Trust Zones
- **Trusted Core Domain (`SwiftEditCore`)**: Pure `Foundation` value types (`AppearanceMode`, `DocumentSession`, `DocumentSnapshot`, `ArchitectureImportScanner`) holding canonical document revisions, binary quarantine flags (`isBinaryReadOnly`), and static UI token fitness checks (`[AR-002]`, `[AR-006]`, `[DATA-003]`).
- **Presentation & AppKit Bridge (`SwiftEditUI`, `#if os(macOS)`, `@MainActor`)**: Resolves `PurpleThemePalette` `RGBAColorToken` pairs, synchronizes `NSApp.appearance` and `NSScrollView` scrollers via `MacOSAppearanceSynchronizer`, renders `InspectionSafetyBannerState` (`BiDi` Trojan Source `CVE-2021-42574` and `Binary Read-Only` banners), and gates external links via `ExternalURIConfirmationPrompt` (`[SEC-004]`, `[UI-005]`, `[UI-008]`).
- **Untrusted Inputs**: Arbitrary opened text files containing Unicode bidirectional override scalars (`U+202A..U+202E`, `U+2066..U+2069`, `U+061C`), binary payloads (`0x00` within `8 KiB`), raw HTML blocks in Markdown previews, external links (`javascript:`, `file:`, `data:`, `https:`), and host OS appearance notifications (`[SEC-004]`, `[SEC-012]`).

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | Low-contrast `AboutSheetView` (`1.10:1` dark-on-dark in `.light`) obscures application provenance before external URI confirmation (`CWE-451`). | Remove `public let brandGround` from `PurpleThemePalette`, bind modal sheets to `sheetSurface`/`chromeForeground` (`>= 13.08:1`), and synchronize `NSApp.appearance` (`[SEC-004]`, `[UI-008]`, `[UI-009]`). |
| Tampering | Trojan Source BiDi scalars (`CVE-2021-42574`, `CWE-1007`) hide reordered tokens behind washed-out `.opacity(0.25)` warning banners in `.light` mode (`1.09:1` surface delta). | Enforce opaque `PurpleThemePalette` BiDi and Binary Quarantine `RGBAColorToken` triples verified at `>= 8.15:1` text contrast and `>= 4.56:1` border contrast in both `.light` and `.black` modes (`[SEC-009]`, `[UI-008]`, `[UI-009]`). |
| Repudiation | Unreadable `statusBar` (`1.10:1` in `.light`) hides `Lint: N` (`unsafeLinkScheme`) and `Brackets: Unbalanced` diagnostics prior to file save. | Bind `statusBar` to `statusBarSurface` (`#7C3AED` / `#2E1065`) and `statusBarForeground` (`#FFFFFF`, `>= 5.70:1`) across both modes (`[SEC-004]`, `[UI-001]`, `[UI-009]`). |
| Information Disclosure | Non-allowlisted external URI schemes (`file://`, `javascript:`, `data:`) leak local sandbox paths or invoke external handlers during theme state transitions (`CWE-200`). | Preserve `InspectionSafetyBannerState.prepareExternalURIConfirmation` (`https`/`http`/`mailto` allowlist, `https`-only in `AboutSheetDescriptor`) with mandatory user confirmation across all theme modes (`[SEC-003]`, `[SEC-004]`). |
| Denial of Service | Unbalanced bracket pill in `.light` (`3.41:1`) degrades syntax error salience, or theme toggling invokes whole-document `NSTextLayoutManager.ensureLayout` stalling `@MainActor` (`CWE-400`). | Enforce `#991B1B` on `#FEE2E2` (`6.78:1`) in `.light` and `#FCA5A5` on `#450A0A` (`8.20:1`) in `.black`, and restrict `TextKit2EditorView` theme updates to visible viewport fragments (`[SEC-012]`, `[UI-007]`, `[UI-012]`). |
| Elevation of Privilege | Raw HTML in Markdown preview (`<script>`) masquerades as trusted prose, or binary sidebar entries (`2.29:1`) appear brighter than legitimate text files (`1.01:1`) in `.light` mode (`CWE-79`, `CWE-451`). | Render `isInertPlainTextHTML` strictly as monospaced `Text` (`Zero-WebKit`) inside `inertHTMLWarning*` tokens (`>= 8.17:1`), preserve `canSave == false` on binary tabs across theme switches, and enforce `scanSwiftEditUIThemeTokens` fitness checks (`[DATA-003]`, `[SEC-004]`, `[TEST-006]`, `[UI-006]`). |

## 3. Abuse Cases & Negative Scenarios
- **Abuse Case 1 — Light-Mode Dark-Ground Camouflage (`CWE-451`)**: Introducing `brandGround`, a raw `#0B0614` hex literal, `Color(.sRGB`, or `NSColor(srgbRed:` inside `Sources/SwiftEditUI/Views/*.swift` to bypass semantic Light/Black token resolution is rejected fail-closed by `ArchitectureImportScanner.scanSwiftEditUIThemeTokens` (`[AR-006]`, `[SEC-009]`, `[TEST-006]`).
- **Abuse Case 2 — Trojan Source BiDi & Binary Quarantine Reset on Live Theme Toggle (`CVE-2021-42574`, `DATA-003`)**: Switching `AppearanceMode` across `.black -> .light -> .auto` on an inspected Trojan Source (`U+202E`) buffer or a quarantined binary read-only buffer preserves `bidiWarnings` and `canSave == false` / `canFormat == false` / `canPinTab == false` at `>= 4.5:1` contrast without reloading buffers (`[DATA-003]`, `[SEC-012]`, `[UI-003]`, `[UI-008]`).
- **Abuse Case 3 — Forced ColorScheme Override Masking OS Appearance**: Emitting a dark SwiftUI `colorScheme` environment notification while `AppearanceMode` is forced to `.black` on a Light macOS host does not overwrite unmasked `systemPrefersDark`, so restoring `.auto` resolves `.light` immediately (`[UI-003]`).

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-19
- Verdict: approved
- Open items: none
