# Proposal: 3x Deep Debug Audit, Zoomed Tabs/Sidebar/Gutter, System & OpenDyslexic App Fonts and Extreme Performance Passes

## Why
The last full audit (`015`) predates YAML support (`016`) and has never measured human-centred usability metrics. Zoom (`UI-004`) only scales the editor and part of the sidebar, so at `200%` the tab strip and navigator stay small and hard to target. Typography is hard-coded at ~57 `.font(...)` sites and the editor is locked to a monospaced system font by `UI-002`, which excludes users who need a dyslexia-friendly face such as OpenDyslexic or simply prefer another installed family [UI-002][UI-004][UI-009][UI-012].

## What Changes
- **Wave 0: Constitution v1.4.0 and structural setup**:
  - amend `UI-002` (MINOR): monospaced typography becomes the default, not a mandate; any installed system font or the bundled OpenDyslexic may be selected for interface and editor;
  - update `ConstitutionGovernanceValidator` to `1.4.0`;
  - add `SwiftEditUI` SwiftPM font resources (OpenDyslexic + `OFL.txt`, SHA-256 pinned) [SDD-003][SDD-005][SDD-006][SEC-008].
- **Wave 1: baseline 3x deep debug audit** (`docs/qa/debug-audit-report-017-baseline.md`):
  - clean Debug build;
  - CPU (`sample`), memory (`footprint`, `vmmap`, `leaks`) and latency (p50/p95 for cold start, keystroke, caret, open 1k/10k/20k lines, zoom, tab switch, preview, YAML lint);
  - functional probing of every command through a compiled AX/CGEvent driver;
  - human metrics: KLM task times, Fitts index, `>= 24 pt` targets, clicks per task, discoverability;
  - WCAG 2.2 AA accessibility scan: contrast, AX roles/labels, keyboard-only reachability, Reduce Motion;
  - findings classified P0..P3 [UI-009][UI-010][UI-011][UI-012].
- **Wave 2: remediation**: every P0–P2 finding becomes a TDD convergence unit (regression test first); P3 findings stay in the report backlog [TEST-001].
- **Wave 3: typography**:
  - `FontChoice` per `TypographyRole` (`interface`, `editor`), persisted in `EditorPreferences` with fail-closed decoding;
  - `AppTypography` resolver;
  - `SystemFontCatalog`;
  - `OpenDyslexicBundle` with process-scope registration;
  - a `Settings` window (`Cmd+,`) with "Interface font" and "Editor font" pickers (search, live preview, OpenDyslexic pinned on top, Default);
  - every chrome, sheet, panel, gutter and TextKit 2 font routed through `AppTypography` [UI-001][UI-002][UI-005][DATA-008].
- **Wave 4: zoomed chrome**: `ZoomedChromeMetrics` scales tab strip text, badges, height and min/max width, left-navigator rows, headers, icons and spacing, and gutter width linearly over `50%..300%`, with `>= 24 pt` minimum hit targets [UI-004][UI-009].
- **Wave 5: extreme optimization and verification**:
  - 3 benchmark-gated passes (`>= 20%` or `UI-012` budget) on the top measured bottlenecks, with golden fingerprints;
  - a final 3x verification audit (`docs/qa/debug-verification-report-017.md`) proving zero open P0–P2 findings [UI-012][TEST-005].

## Capabilities
- New Capabilities: `deep-debug-zoom-fonts-opendyslexic-and-perf`
- Modified Capabilities: `swifteditui-purple-zed-layout-textkit2-and-appicons`, `editor-ux-highlighting-sidebar-pin-tabs-and-about`, `constitution-v1-3-governance-and-fitness`

## Domain Carrier & Decision Ownership (BC-###)
- **BC-001**: Ownership by layer:
  - `WorkspaceAndTabSession` (Supporting) owns persisted `FontChoice` preferences;
  - `SwiftEditUI` owns font resolution, the font catalog, OpenDyslexic registration, zoomed chrome metrics and the Settings window;
  - `DocumentCore` is untouched: font and zoom never mutate buffers or `BufferRevision`.
- **Owned Decisions**: font fallback order, trait synthesis, metric scaling curves and clamps, audit severity classification (P0..P3), benchmark acceptance thresholds.
- **Forbidden Responsibilities**:
  - typography and zoom MUST NEVER change document text, revision or dirty state;
  - the app MUST NEVER download fonts at runtime, register them system-wide, or load font files from user-selected paths;
  - perf passes MUST NEVER change golden outputs;
  - `SwiftEditCore` MUST NEVER import `AppKit`/`SwiftUI` [AR-002][BC-011].
- **External Decision References**: `DocumentID`, `BufferRevision`.

## Impact
- **Sources**:
  - `SwiftEditCore/WorkspaceAndTabSession/EditorPreferencesStore.swift` (font preferences);
  - new `SwiftEditCore/WorkspaceAndTabSession/FontChoice.swift`;
  - new `SwiftEditUI/Theme/AppTypography.swift`, `SwiftEditUI/Theme/ZoomedChromeMetrics.swift`, `SwiftEditUI/Fonts/OpenDyslexicBundle.swift`, `SwiftEditUI/Views/SettingsView.swift`;
  - updated `SwiftEditRootView.swift`, `TextKit2EditorView.swift`, `LineNumberGutterView.swift`, `PropertiesPanelView.swift`, `DocumentNavigatorOverlayView.swift`, `FindReplaceGoToLineBar.swift`, sheets and popovers;
  - `XcodeApp/SwiftEditApp.swift` (`Settings` scene);
  - `SwiftEditCore/ArchitectureFitness/ConstitutionGovernanceValidator.swift`.
- **Packaging**: `Package.swift` gains `resources: [.copy("Resources/Fonts")]` on `SwiftEditUI` (no new dependency).
- **Docs**: `docs/qa/debug-audit-report-017-baseline.md`, `docs/qa/debug-verification-report-017.md`, `docs/qa/perf-analysis-017.md`.
- **Constitution**: `UI-002` in `constitution/03-ui-ux/design-system-and-tokens.md`, version `1.4.0` and Sync Impact row in `Constitution.md`.

## Security Impact
- **New supply-chain asset (OpenDyslexic font binaries)**:
  - downloaded once by the agent from the official upstream repository after explicit user confirmation per file;
  - SHA-256 pinned in source and verified before registration, failing closed;
  - OFL license shipped;
  - registered with `CTFontManagerScope.process` only [SEC-008][SEC-012].
- The app stays 100% offline: no font downloads at runtime, no new entitlements, no user-path font loading [SEC-001][SEC-004].
- **Audit tooling**: the GUI driver needs Accessibility permission for the agent host (manual step). All artefacts stay in `.tmp/` and are deleted afterwards; reports contain no document contents [SEC-011].

## Metadata
- Owner: swift-macos-expert
- Domain: Debug Audit, Usability & Accessibility, Typography, Zoom, Performance
- Reviewer: cyber-security-expert
- Branch: feature/FirstStub
- Manual-Steps: manual-steps.md (lang: it)
- Modifies-Specs: swifteditui-purple-zed-layout-textkit2-and-appicons (REQ-001), editor-ux-highlighting-sidebar-pin-tabs-and-about (REQ-005), constitution-v1-3-governance-and-fitness (REQ-001)
- Constitutional-Rules: AR-002, AR-005, AR-006, AR-009, AR-010, BC-001, BC-011, UI-001, UI-002, UI-003, UI-004, UI-005, UI-009, UI-010, UI-011, UI-012, DATA-004, DATA-008, TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, SEC-001, SEC-004, SEC-008, SEC-009, SEC-011, SEC-012, SDD-001, SDD-002, SDD-003, SDD-005, SDD-006
- Amends-Constitution: MINOR (UI-002)

## Prerequisites
- `openspec/Constitution.md` (`v1.3.0`, amended to `v1.4.0` by this change)
- `openspec/briefs/brief-deep-debug-zoom-fonts-opendyslexic-and-perf.md`
- `.agents/Memories/macos-debug-audit-playbook.md` (audit method)
- Archived `016-yaml-native-support-frontmatter-properties-and-perf` (`PerfBench016`/`PerfGolden016` patterns)
