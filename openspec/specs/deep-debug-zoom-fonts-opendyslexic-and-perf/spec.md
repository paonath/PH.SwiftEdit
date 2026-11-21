# Capability: deep-debug-zoom-fonts-opendyslexic-and-perf

## Purpose
Runs a repeatable 3x deep Debug audit (CPU, memory, latency, functional probing, human usability metrics, accessibility) and remediates its findings. It also lets users choose any installed system font or the bundled OpenDyslexic for the interface and the editor, scales tabs, navigator and gutter with zoom, and ends with three benchmark-gated optimization passes and a 3x verification audit.

## Requirements

### Requirement: REQ-001 Repeatable 3x Baseline Deep Debug Audit Report
WHEN the baseline audit runs on a clean Debug build, the audit workflow SHALL execute every measurement 3 times and write `docs/qa/debug-audit-report-017-baseline.md` with CPU, memory, latency p50/p95, functional probe, human-metric and WCAG 2.2 AA accessibility sections, classify each finding P0..P3 with reproduction steps, and contain no document contents [UI-009][UI-010][UI-012][SEC-011].

#### Scenario: P1 Three-Run Report Contains All Sections and Classified Findings
- **Path**: P1
- **Trait**: positive
- **GIVEN** a clean Debug build, the synthetic `.tmp/qa-workspace` fixtures and the Accessibility grant from manual step 1
- **WHEN** the audit playbook runs 3 times
- **THEN** the report lists 3 timed runs, the sections `CPU`, `Memory`, `Latency`, `Functional`, `Human Metrics` and `Accessibility`, and every finding carries an ID, a severity `P0..P3`, a reproduction and a measured value

#### Scenario: N1 Incomplete Runs Missing Sections or Leaked Content Fail the Report Gate
- **Path**: N1
- **Trait**: negative
- **GIVEN** a report with only 2 runs, a missing `Accessibility` section, or a line containing fixture body text
- **WHEN** `AuditReportFitness` checks the report
- **THEN** the check fails and names the missing run, the missing section or the leaking line

### Requirement: REQ-002 Test-First Remediation of P0 to P2 Audit Findings
WHEN the baseline report lists a P0, P1 or P2 finding, the remediation workflow SHALL add a failing regression test reproducing it before fixing it, keep every P3 finding as backlog in the report, and record the fixing test name next to each resolved finding [TEST-001][TEST-002].

#### Scenario: P2 Every P0 to P2 Finding Maps to a Passing Regression Test
- **Path**: P2
- **Trait**: positive
- **GIVEN** a baseline report with findings of severity P0, P1, P2 and P3
- **WHEN** remediation completes
- **THEN** each P0–P2 finding is marked `resolved` with the name of a regression test that passes, and P3 findings are marked `backlog`

#### Scenario: N2 A P0 to P2 Finding Without a Regression Test Blocks Completion
- **Path**: N2
- **Trait**: negative
- **GIVEN** a P1 finding marked `resolved` without a test reference, or a referenced test that does not exist
- **WHEN** `AuditReportFitness` cross-checks findings and tests
- **THEN** the check fails naming the finding ID

### Requirement: REQ-003 Fail-Closed Per-Role Font Preference Persistence
The `EditorPreferences` store SHALL persist one `FontChoice` (`default`, `system(family)` or `openDyslexic`) for each `TypographyRole` (`interface`, `editor`) as family names only, decode missing, malformed, oversized (`> 128` scalars) or control-character values to `default`, and keep pre-017 preferences readable [DATA-008][SEC-012].

#### Scenario: P3 Font Choices Round-Trip Per Role and Legacy Preferences Still Load
- **Path**: P3
- **Trait**: positive
- **GIVEN** an in-memory preferences store and a pre-017 payload holding only `appearanceMode` and `zoomPercent`
- **WHEN** `interface = .system("Avenir Next")` and `editor = .openDyslexic` are saved and reloaded, and the legacy payload is loaded
- **THEN** both choices round-trip exactly, and the legacy payload loads with both roles `.default` and its zoom and appearance intact

#### Scenario: N3 Path-Like Oversized and Control-Character Values Decode to Default
- **Path**: N3
- **Trait**: security
- **GIVEN** stored values `"../../../tmp/x.otf"`, a 10,000-character name, `"Menlo\u{0}"` and a non-string value
- **WHEN** preferences are loaded
- **THEN** every affected role resolves to `.default` and no file-system access occurs

### Requirement: REQ-004 Cached Role-Aware Typography Resolution With Fallback
WHEN a view or the editor requests a font for a role, size and weight, the `AppTypography` resolver SHALL return the chosen family with the requested weight and italic traits when available, fall back to the regular face and then to the default role font when a family or trait is missing, and cache results per choice, role, size and weight [UI-002][UI-005][UI-012].

#### Scenario: P4 System Family OpenDyslexic and Default Resolve With Traits
- **Path**: P4
- **Trait**: positive
- **GIVEN** choices `.system("Helvetica Neue")` for interface, `.openDyslexic` for editor (bundle registered) and `.default`
- **WHEN** fonts are resolved at `14 pt` regular, bold and italic
- **THEN** interface fonts belong to `Helvetica Neue` with bold and italic traits, editor fonts belong to the bundled OpenDyslexic faces, default editor fonts are monospaced, and a second identical request returns the cached instance

#### Scenario: N4 Missing Family or Trait Falls Back Without Failing
- **Path**: N4
- **Trait**: negative
- **GIVEN** `.system("NoSuchFamily 123")` and a family without an italic face
- **WHEN** regular and italic fonts are resolved
- **THEN** the missing family yields the role's default font and the missing italic yields the family's regular face, with no error thrown

### Requirement: REQ-005 Cached Searchable System Font Catalog With OpenDyslexic Pinned
The `SystemFontCatalog` SHALL enumerate installed font families once per process into a case-insensitively sorted list, filter it by a case- and diacritic-insensitive substring query, and present `Default` then `OpenDyslexic` (when the bundle is verified) above the system families [UI-005][UI-012].

#### Scenario: P5 Sorted Families Search and Pinned Entries
- **Path**: P5
- **Trait**: positive
- **GIVEN** a catalog source returning `["menlo", "Avenir Next", "Helvetica"]` and a verified OpenDyslexic bundle
- **WHEN** the catalog is built and queried with `""` and `"hel"`
- **THEN** the empty query returns `Default`, `OpenDyslexic`, `Avenir Next`, `Helvetica`, `menlo`, the `"hel"` query returns `Default`, `OpenDyslexic`, `Helvetica`, and the source is enumerated once

#### Scenario: N5 No Match and Unverified Bundle Are Handled Safely
- **Path**: N5
- **Trait**: negative
- **GIVEN** an unverified OpenDyslexic bundle and the query `"zzz"`
- **WHEN** the catalog is queried
- **THEN** only `Default` is returned and OpenDyslexic is absent

### Requirement: REQ-006 Hash-Verified Process-Scope OpenDyslexic Registration
WHEN the app starts, the `OpenDyslexicBundle` SHALL verify each bundled OpenDyslexic file and its `OFL.txt` against pinned SHA-256 digests, register the verified fonts with `CTFontManagerScope.process` only, resolve them by PostScript name from the registered URLs, and disable the OpenDyslexic choice when any file is missing or mismatched [SEC-008][SEC-012][AR-007].

#### Scenario: P6 Verified Files Register Once and Resolve by PostScript Name
- **Path**: P6
- **Trait**: positive
- **GIVEN** the bundled OpenDyslexic files whose digests match the pinned values
- **WHEN** `OpenDyslexicBundle.registerIfNeeded()` runs twice
- **THEN** it reports `.available` with the registered PostScript names, registration happens once, and the faces are not visible to other processes

#### Scenario: N6 Tampered Missing or Shadowed Fonts Disable the Choice Fail-Closed
- **Path**: N6
- **Trait**: security
- **GIVEN** a bundle directory with one file whose bytes differ from its pinned digest, another with a missing file, and an installed system family named `OpenDyslexic`
- **WHEN** verification runs through the injected file reader
- **THEN** the result is `.unavailable(reason:)` without registering anything, the `.openDyslexic` choice resolves to the default font, and the system font named `OpenDyslexic` is never used for it

### Requirement: REQ-007 Settings Window With Live Interface and Editor Font Pickers
WHEN the user opens Settings (`Cmd+,`), the `SwiftEditUI` SHALL show "Interface font" and "Editor font" pickers backed by the catalog with search and live preview, apply a selection immediately to every window and open editor without mutating any buffer, persist it, and expose VoiceOver labels and full keyboard operation [UI-005][UI-009][UI-010][DATA-008].

#### Scenario: P7 Selecting Fonts Applies Live and Persists Without Touching Buffers
- **Path**: P7
- **Trait**: positive
- **GIVEN** an open dirty Markdown tab at revision `4` and the Settings view model
- **WHEN** the user selects `Avenir Next` for interface and `OpenDyslexic` for editor
- **THEN** the workbench typography updates both roles, preferences store both choices, and the tab text, revision `4` and dirty flag are unchanged

#### Scenario: N7 Unavailable Choices Are Not Selectable and Controls Are Accessible
- **Path**: N7
- **Trait**: negative
- **GIVEN** an unverified OpenDyslexic bundle and the Settings view
- **WHEN** rows are built and inspected
- **THEN** OpenDyslexic is absent, every picker row has an accessibility label naming the family, and the pickers are reachable with `Tab` and selectable with arrow keys and `Return`

### Requirement: REQ-008 App-Wide Typography Routing Including the TextKit 2 Editor
The `SwiftEditUI` target SHALL route every chrome, sheet, popover, panel, gutter and TextKit 2 editor font, including GFM bold/italic and the YAML key weight, through `AppTypography`, leaving zero hard-coded `.font(.system(...))`, `.font(.caption…)` or `NSFont.monospacedSystemFont` call sites outside the resolver [UI-001][UI-002][UI-005].

#### Scenario: P8 Changing Fonts Restyles Chrome and Editor Through One Resolver
- **Path**: P8
- **Trait**: positive
- **GIVEN** an editor showing GFM bold text and YAML keys with the interface font `Avenir Next` and the editor font `OpenDyslexic`
- **WHEN** `EditorRenderingFonts` and chrome fonts are derived
- **THEN** editor regular, bold, italic and YAML-key fonts all come from the OpenDyslexic family with matching traits, and chrome fonts come from `Avenir Next`

#### Scenario: N8 Static Fitness Rejects Hard-Coded Font Call Sites
- **Path**: N8
- **Trait**: negative
- **GIVEN** the `Sources/SwiftEditUI` tree
- **WHEN** `TypographyFitness` scans for `.font(.system(`, `.font(.caption`, `.font(.callout`, `.font(.body` and `monospacedSystemFont(` outside `Theme/AppTypography.swift`
- **THEN** zero matches are found, and a fixture file containing one is reported with its path and line

### Requirement: REQ-009 Linear Zoomed Chrome Metrics for Tabs Navigator and Gutter
WHEN zoom changes within `50%..300%`, the `ZoomedChromeMetrics` SHALL scale tab text, badge size, height, horizontal padding and min/max width, navigator row height, header size, icon size and indent, and gutter width linearly with the zoom factor, never shrinking any clickable target below `24 pt` [UI-004][UI-009][UI-012].

#### Scenario: P9 Tabs Navigator and Gutter Scale Linearly With Zoom
- **Path**: P9
- **Trait**: positive
- **GIVEN** metrics at `100%` with tab font `13 pt`, tab height `28 pt`, navigator row `24 pt` and a 3-digit gutter
- **WHEN** zoom is set to `200%` and to `150%`
- **THEN** at `200%` the tab font is `26 pt`, tab height `56 pt`, navigator row `48 pt` and the gutter width doubles, and at `150%` every metric is `1.5x` its `100%` value

#### Scenario: N9 Small Zoom Keeps 24 pt Targets and Extreme Values Clamp
- **Path**: N9
- **Trait**: negative
- **GIVEN** zoom requests of `50%`, `20%` and `500%`
- **WHEN** metrics are computed
- **THEN** `20%` clamps to `50%` and `500%` to `300%`, and at `50%` tab height, close-button size and navigator row height stay `>= 24 pt`

### Requirement: REQ-010 Three Benchmark-Gated Extreme Optimization Passes
WHEN remediation is complete, the optimization workflow SHALL rank the baseline audit's measured bottlenecks in `docs/qa/perf-analysis-017.md` and run 3 passes, each starting from a failing benchmark that requires `>= 20%` improvement or the `UI-012` budget, with golden fingerprints proving identical observable outputs and no stale font or metrics caches [UI-012][TEST-001][TEST-005].

#### Scenario: P10 Each Pass Turns Its Benchmark Green
- **Path**: P10
- **Trait**: positive
- **GIVEN** the ranked analysis and baseline timings
- **WHEN** passes 1, 2 and 3 are applied
- **THEN** each targeted benchmark improves by `>= 20%` or meets the `UI-012` budget and the full suite stays green

#### Scenario: N10 Behavior-Changing Optimizations Are Rejected by Goldens
- **Path**: N10
- **Trait**: negative
- **GIVEN** golden fingerprints of spans, lint, outline, gutter, status bar, typography resolution and zoom metrics captured before pass 1
- **WHEN** an optimization alters any of them
- **THEN** the golden equivalence test fails

#### Scenario: N11 Font and Zoom Caches Never Serve Stale Values
- **Path**: N11
- **Trait**: security
- **GIVEN** cached fonts and metrics for `Menlo` at `100%`
- **WHEN** the editor font changes to `OpenDyslexic` and zoom to `150%`
- **THEN** the next resolution returns OpenDyslexic at `1.5x` size and no view renders with the previous font or metrics

### Requirement: REQ-011 Final 3x Verification Audit With Zero Open P0 to P2 Findings
WHEN all improvements and passes are complete, the audit workflow SHALL re-run the full 3x audit, write `docs/qa/debug-verification-report-017.md` comparing every baseline metric, and report zero open P0–P2 findings with `UI-012` budgets met [UI-012][TEST-005].

#### Scenario: P11 Verification Shows Improvements and No Open Severe Findings
- **Path**: P11
- **Trait**: positive
- **GIVEN** the baseline report and the final build
- **WHEN** the verification audit runs 3 times
- **THEN** the report shows baseline versus final values for every metric, zero open P0–P2 findings and every `UI-012` budget met

#### Scenario: N12 Any Regression or Open Severe Finding Fails Verification
- **Path**: N12
- **Trait**: negative
- **GIVEN** a final metric more than `10%` worse than baseline or one open P1 finding
- **WHEN** `AuditReportFitness` checks the verification report
- **THEN** the check fails naming the regressed metric or the open finding
