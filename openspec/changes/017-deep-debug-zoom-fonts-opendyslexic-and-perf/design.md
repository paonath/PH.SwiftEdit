# Design: 3x Deep Debug Audit, Zoomed Tabs/Sidebar/Gutter, System & OpenDyslexic App Fonts and Extreme Performance Passes

## Context
- **Fonts**:
  - typography is hard-coded at ~57 `.font(...)` sites in `SwiftEditUI` (`SwiftEditRootView.swift` alone has 24);
  - the editor uses `EditorRenderingFonts` built on `NSFont.monospacedSystemFont`;
  - `UI-002` mandates monospaced editor typography.
- **Zoom**:
  - `EditorZoomController` (`50%..300%`) already scales the editor (`scaledFontSizePoints`) and part of the sidebar (`sidebarScaledFontSizePoints`);
  - tabs use fixed `.callout`/`.caption2`/`9 pt` fonts, and paddings and heights are constants.
- **Preferences**: `EditorPreferences` persists only `appearanceMode` and `zoomPercent` through `PreferencesProviding`.
- **Prior art**:
  - audit method: `.agents/Memories/macos-debug-audit-playbook.md` (`015`);
  - perf method: `PerfBench016`/`PerfGolden016` (`016`).

## Goals / Non-Goals
- **Goals**:
  - three measured, reproducible audits (baseline, remediation evidence, verification);
  - P0–P2 defects fixed test-first;
  - a user-selectable interface and editor font (system or OpenDyslexic);
  - zoom-driven tabs, navigator and gutter;
  - three benchmark-gated optimization passes;
  - zero new package dependencies or entitlements.
- **Non-Goals**:
  - per-tab fonts, font size independent of zoom, custom font files chosen by the user;
  - zooming header, status bar or panels;
  - iOS Settings UI;
  - changing GFM table alignment rules for proportional fonts (alignment is visual-only);
  - fixing P3 findings.

## Architecture Memory & Module Boundaries (AR-###)
- **AR-001**: placement by ring.
  - `FontChoice`/`TypographyRole` (pure value types) live in `SwiftEditCore/WorkspaceAndTabSession/` next to `EditorPreferences`.
  - `AppTypography`, `ZoomedChromeMetrics`, `SystemFontCatalog`, `OpenDyslexicBundle` and `SettingsView` live in `SwiftEditUI` (AppKit/CoreText allowed).
  - Font binaries are `SwiftEditUI` SwiftPM resources (`Bundle.module`) so tests and the app share one verified location.
- **AR-018**: `SwiftEditWorkbenchModel` coordinates (Settings → preferences → `AppTypography` invalidation) but never decides fallbacks, hashes or scaling curves, which belong to the resolver, bundle and metrics types.

## Constitutional Alignment & Module Boundaries (AR-### / UI-### / DATA-### / API-###)
- **Single-Reference Lock**: one micro-file per active step:
  - `constitution/03-ui-ux/design-system-and-tokens.md` (`UI-002` amended, `UI-004`);
  - `constitution/03-ui-ux/accessibility-and-cwv.md` (`UI-009..UI-012`);
  - `constitution/04-data-persistence/write-read-separation.md` (`DATA-008`);
  - `constitution/07-security-privacy/secrets-and-supply-chain.md` (`SEC-008`);
  - `constitution/06-testing-fitness/tdd-and-unit-testing.md`;
  - `constitution/08-sdd-governance/amendment-and-sync-impact.md` (`SDD-005`, `SDD-006`).
- **Bounded Context Classification (`BC-002`)**:
  - `WorkspaceAndTabSession`: Supporting (font preferences);
  - `DocumentCore`: Core (unchanged invariants);
  - `MarkdownLintAndFormat`: Core (perf-pass candidate only);
  - `SearchDiffAndBracketEngine`: Supporting (perf-pass candidate only).
- **Amendment (`SDD-005`/`SDD-006`)**: `UI-002` is reworded to "monospaced typography by default, with a user-selectable system or bundled OpenDyslexic editor font". Version becomes `1.4.0`, `last_amended` becomes `2026-11-21`, and a Sync Impact row cites `UI-002`. This is MINOR because it is backward compatible: the default behavior is unchanged.

## Decisions
- **D1 `FontChoice` enum, not a protocol** (`AR-009`): three cases, two roles; family names only (no URLs), validated on decode (printable, `<= 128` scalars).
- **D2 One resolver, one cache**: `AppTypography` resolves `(FontChoice, role, size, weight, italic)` to `NSFont`/`Font`. It is cached in a dictionary invalidated only when a choice changes; zoom changes produce new keys (size), so caches can never go stale (`N11`). Weight and italic come from `NSFontManager.convert(_:toHaveTrait:)` with the regular face as fallback. SwiftUI uses `Font(nsFont)`.
- **D3 OpenDyslexic bundle**:
  - files `OpenDyslexic-Regular.otf`, `-Bold.otf`, `-Italic.otf`, `-Bold-Italic.otf`, `OpenDyslexicMono-Regular.otf` and `OFL.txt` under `Sources/SwiftEditUI/Resources/Fonts/`;
  - fetched by the agent from the official upstream repository after per-file user confirmation (manual step 2), with digests pinned in `OpenDyslexicBundle.pinnedDigests`;
  - verification uses CryptoKit SHA-256 through an injectable `FontFileReading` seam (`AR-007`);
  - registration uses `CTFontManagerRegisterFontsForURL(url, .process, &error)`;
  - when the editor role needs a monospaced OpenDyslexic, the Mono face is preferred.
- **D4 `ZoomedChromeMetrics`**: a pure struct computed from the zoom factor and `AppTypography`. Tab font, badge, height, padding and min/max width, navigator row/header/icon/indent, and gutter width (`max(3, digits) * advance('0') + padding`) all scale linearly. Hit targets use `max(24, scaled)`. Views read only metrics, so there are no constants left in views.
- **D5 Settings scene**: SwiftUI `Settings { SettingsView(model:) }` in `XcodeApp/SwiftEditApp.swift` (`Cmd+,` for free). Two `List`s with `searchable`, each row previewed in its own font (lazy, catalog cached), selection bound to `model.setFontChoice(_:for:)`. There is no Apply button: changes are live and persisted immediately.
- **D6 Typography routing fitness**: `TypographyFitness` static scan (like `ArchitectureImportScanner`) forbids direct `.font(.system(`/`.font(.caption`/`.font(.callout`/`.font(.body`/`monospacedSystemFont(` outside `Theme/AppTypography.swift`.
- **D7 Audit tooling**:
  - reuse the playbook layers: Debug build, 3x `swift test`, a compiled Swift AX/CGEvent driver, a SwiftPM `QAHarness` (both in `.tmp/`), plus `sample`/`footprint`/`vmmap`/`leaks`;
  - human metrics: KLM operator sums per task (K=0.2 s, P=1.1 s, H=0.4 s, M=1.35 s), Fitts ID = log2(D/W+1) per primary target from AX frames, target-size check `>= 24x24 pt`, and a clicks/keystrokes count per task;
  - accessibility: contrast for all palette pairs, AX role/label/value for every interactive element, keyboard traversal order, Reduce Motion;
  - `AuditReportFitness` checks report structure.
- **D8 Perf passes**: candidates are taken from measured audit data only (expected areas: per-render work in `SwiftEditRootView`, background lint frequency, outline index rebuild, font lookup per fragment). Each pass uses a RED benchmark against an in-process reference plus goldens extended with typography and zoom fingerprints.

## Risks / Trade-offs
- Proportional editor fonts break column alignment of tables, code and the gutter-to-text baseline → visual only; the gutter uses editor-font metrics; monospaced remains the default; documented in Settings ("Proportional fonts do not align columns").
- OpenDyslexic Bold/Italic availability varies by release → resolver falls back to regular (`N4`); hashes are pinned at download time.
- AX automation can be flaky → 3 runs, medians, deterministic fixtures; a failure to obtain the Accessibility grant blocks the audit fail-closed (manual step 1).
- Unknown audit findings could inflate scope → P3 to backlog; P0–P2 only, each as an isolated convergence unit.
- Large-zoom tab widths reduce visible tabs → min/max widths scale but the strip scrolls horizontally (existing behavior).

## Migration Plan
- Preferences gain two keys (`swiftedit.font.interface`, `swiftedit.font.editor`); absent keys mean `.default`, so existing users see no change.
- The Constitution is amended in the first structural task; living specs are synced at archive.
- Font resources are added to `Package.swift` (`SwiftEditUI` target `resources`) and appear in the `.app` through the package product bundle.

## Security Review
- Reviewer: cyber-security-expert
- Date: 2026-11-21
- Verdict: approved # approved | changes-required
- Open items: none
