---
id: "brief-deep-debug-zoom-fonts-opendyslexic-and-perf"
change_id: "017-deep-debug-zoom-fonts-opendyslexic-and-perf"
capability: "deep-debug-zoom-fonts-opendyslexic-and-perf"
branch: "feature/FirstStub"
modifies_specs:
  - "swifteditui-purple-zed-layout-textkit2-and-appicons (REQ-001: zoom scales tabs, sidebar and gutter width; editor font no longer forced monospaced)"
  - "editor-ux-highlighting-sidebar-pin-tabs-and-about (REQ-005: proportional zoom extended from sidebar typography to tab strip, sidebar metrics and gutter)"
  - "constitution-v1-3-governance-and-fitness (REQ-001: governance validator expects v1.4.0 and the UI-002 Sync Impact row)"
amends_constitution: "UI-002 (MINOR -> v1.4.0)"
status: "approved-via-qa"
date: "2026-11-21"
owners:
  - "swift-macos-expert"
  - "oop-architecture-expert"
  - "cyber-security-expert"
  - "qa-agent"
---

# TDD Specification Brief: `017-deep-debug-zoom-fonts-opendyslexic-and-perf`

## 1. Context & Scope

- **Request**: ONE spec covering (1) a deep Debug-build audit of the app — CPU, memory, speed, functional probing, usability by human metrics and an accessibility scan — repeated at least 3 times; (2) improvements: zoom drives tab and left-navigator size, a system font selectable as app font (whole app and text editing), OpenDyslexic selectable as app font (whole app and editing); (3) "extreme" code optimization driven by the audit's measured bottlenecks.
- **QA decisions** (6 answers + final confirmation):
  1. Amend Constitution `UI-002` (MINOR, `v1.4.0`): monospaced stays the default, any system font or OpenDyslexic may be chosen for UI and editor.
  2. OpenDyslexic: the agent downloads the official files from the upstream OpenDyslexic repository during `/myspec-apply`, asking the user to confirm each download (file name, source, size); SIL OFL 1.1 license bundled; SHA-256 pinned; process-scope registration only.
  3. Zoom (`50%..300%`) scales editor, tab strip (text, badges, height, min/max width), left navigator (rows, headers, icons, spacing) and gutter width; header, status bar and panels stay fixed.
  4. Audit findings: P0–P2 fixed automatically as TDD convergence units, P3 kept as backlog in the report.
  5. Font choice UI: new Settings window (`Cmd+,`) with separate "Interface font" and "Editor font" pickers (system families with search and live preview, OpenDyslexic pinned on top, Default).
  6. Manual-steps runbook in Italian (grant Accessibility permission to the agent host; optional manual VoiceOver pass).
- **Governing rules**: `AR-005`, `AR-006`, `AR-007`, `AR-009`, `AR-010`, `BC-001`, `UI-001..UI-004`, `UI-005`, `UI-009..UI-012`, `DATA-004`, `DATA-008`, `TEST-001..TEST-005`, `SEC-001`, `SEC-004`, `SEC-008`, `SEC-009`, `SEC-012`, `SDD-001..SDD-007`.

## 2. Expert Notes

- **swift-macos-expert**: today fonts are hard-coded at ~57 `.font(...)` sites; tabs use fixed `.callout`/`.caption2`; the sidebar already scales via `EditorZoomController.sidebarScaledFontSizePoints`; editor fonts come from `EditorRenderingFonts` (monospaced system). Introduce a pure `SwiftEditCore` `FontChoice` value (`.default`, `.system(family:)`, `.openDyslexic`) per `TypographyRole` (`.interface`, `.editor`) persisted in `EditorPreferences` (backward-compatible decoding), and a `SwiftEditUI` `AppTypography` token resolving `NSFont`/`Font` per role, size and weight with fallbacks (missing family → default; bold/italic via `NSFontManager` traits, falling back to the regular face). Zoom: `ZoomedChromeMetrics` derived from `EditorZoomController` for tab height/padding/min-max width/badge size, sidebar row height/icon size/indent, and gutter width (digit count × glyph advance of the editor font). Settings: SwiftUI `Settings` scene (`Cmd+,`) with searchable family lists from `NSFontManager.availableFontFamilies` (cached once), live preview, VoiceOver labels.
- **OpenDyslexic**: bundled as `SwiftEditUI` SwiftPM resources (`Resources/Fonts/*.otf` + `OFL.txt`), verified against pinned SHA-256 before `CTFontManagerRegisterFontsForURL(_, .process, _)`; tampered or missing files disable the entry fail-closed; no runtime download, no system-wide install.
- **qa-agent / audit**: reuse `.agents/Memories/macos-debug-audit-playbook.md` (5 layers, compiled AX/CGEvent driver, QAHarness, `sample`, `footprint`, `vmmap`, `leaks`), 3 runs each. Human metrics: Keystroke-Level Model task times, Fitts index of difficulty for primary targets, target size `>= 24x24 pt` (WCAG 2.5.8), clicks/keystrokes per task, discoverability of every command via menu + shortcut. Accessibility: WCAG 2.2 AA contrast for every palette token pair, AX role/label/value audit of every interactive element, keyboard-only reachability, Reduce Motion. Report `docs/qa/debug-audit-report-017-baseline.md` with P0..P3 findings; final verification report `docs/qa/debug-verification-report-017.md`.
- **cyber-security-expert**: new supply-chain asset (font binaries) → pinned hashes (`SEC-008`), process-scope registration, Settings never reads arbitrary font files from disk; preference decoding fail-closed (unknown family → default).
- **Perf**: 3 benchmark-gated passes (`>= 20%` or `UI-012` budget) on the top measured bottlenecks of the baseline audit, with golden fingerprints (reuse `PerfBench016`/`PerfGolden016` style) plus new goldens for typography and zoom metrics.

## 3. Path Coverage Matrix

| Unit | Path | Trait | Summary |
| :--- | :--- | :--- | :--- |
| `ConstitutionV140Amendment` (constitution delta) | P3/N5 | positive/negative | validator accepts `1.4.0` + UI-002 row; rejects `1.3.0` |
| `BaselineDebugAudit` | P1/N1 | positive/negative | 3-run report with all 6 sections and P0..P3; missing run/section/leak fails |
| `AuditFindingsRemediation` | P2/N2 | positive/negative | every P0–P2 finding has a passing regression test; P3 only in backlog |
| `FontChoicePreferences` | P3/N3 | positive/security | round-trip per role, legacy load; path-like/oversized/NUL values fail closed |
| `AppTypographyResolver` | P4/N4 | positive/negative | system family, OpenDyslexic, default with traits; missing family/trait falls back |
| `SystemFontCatalog` | P5/N5 | positive/negative | sorted families, search, OpenDyslexic pinned; no match / unverified bundle safe |
| `OpenDyslexicBundle` | P6/N6 | positive/security | hashes match, process registration once; tampered/missing/shadowed disables entry |
| `SettingsWindow` | P7/N7 | positive/negative | `Cmd+,` pickers apply live without buffer mutation; accessible, unavailable choices hidden |
| `AppWideTypographyRouting` | P8/N8 | positive/negative | chrome and editor through one resolver; hard-coded font sites rejected |
| `ZoomedChromeMetrics` (+ swifteditui P7/N11, editor-ux P12/N14) | P9/N9 | positive/negative | linear 50–300% scaling of tabs, navigator, gutter; clamps and 24 pt targets |
| `PerfPass1..3` | P10/N10/N11 | positive/negative/security | each `>= 20%`; goldens unchanged; no stale font/metrics cache |
| `VerificationAudit` | P11/N12 | positive/negative | final 3x audit: zero open P0–P2, budgets met; regression fails |
