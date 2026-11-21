# Test Plan: 3x Deep Debug Audit, Zoomed Tabs/Sidebar/Gutter, System & OpenDyslexic App Fonts and Extreme Performance Passes

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `ConstitutionGovernanceValidator` v1.4.0 (modified constitution REQ-001) | P3: `1.4.0` + `UI-002` row pass | N5: `1.3.0`, missing row, line-cap overflow fail |
| `OpenDyslexicBundle` | P6: pinned digests match, process registration once, PostScript resolution | N6 (security): tampered, missing, shadowed system family → unavailable, default font |
| `AuditReportFitness` (baseline) | P1: 3 runs, 6 sections, classified findings | N1: 2 runs / missing section / leaked fixture text fail |
| `AuditFindingsRemediation` | P2: every P0–P2 resolved with passing test; P3 backlog | N2: resolved without test reference fails |
| `FontChoice` + `EditorPreferencesStore` | P3: per-role round trip, legacy payload loads | N3 (security): path-like, oversized, NUL, non-string → default |
| `AppTypography` | P4: system family, OpenDyslexic, default with traits; cache hit | N4: missing family / trait falls back |
| `SystemFontCatalog` | P5: sorted, searched, pinned entries, single enumeration | N5: no match / unverified bundle |
| `SettingsView` + workbench | P7: live apply + persist, buffer revision and dirty unchanged | N7: unavailable choice absent; labels and keyboard operation |
| `TypographyFitness` + `EditorRenderingFonts` | P8: chrome and editor (bold/italic/YAML key) from chosen families | N8: hard-coded font call site detected |
| `ZoomedChromeMetrics` (+ modified swifteditui REQ-001, editor-ux REQ-005) | P9 / P7 / P12: linear scaling 150% and 200% | N9 / N11 / N14: clamps 50–300%, `>= 24 pt` targets, 21:1 canvas with OpenDyslexic |
| `PerfPass1..3` | P10: each `>= 20%` or `UI-012` | N10: goldens; N11 (security): no stale font/metrics cache |
| `AuditReportFitness` (verification) | P11: baseline vs final, zero open P0–P2 | N12: `> 10%` regression or open P1 fails |

Note: `P3`/`N5` in the modified constitution delta, `P7`/`N11` in the modified swifteditui delta and `P12`/`N14` in the modified editor-ux delta use those capabilities' own path namespaces.

## 2. Test Automation Strategy & Commands
- Unit test runner command: `swift test --parallel`
- Targeted filter command: `swift test --filter "FontChoice|AppTypography|SystemFontCatalog|OpenDyslexic|Settings|TypographyFitness|ZoomedChrome|AuditReport|Constitution"`
- Security trait filter command: `swift test --filter "Security|Tamper|Malicious"`
- Benchmark command: `swift test -c release --filter "PerfPass017"`
- Audit commands (Wave 1 and final): `./Scripts/build-app.sh --configuration Debug --clean --derived-data .tmp/DerivedData`, the compiled `.tmp/gui-driver` AX/CGEvent driver, `.tmp/qa-harness` microbenchmarks, `sample`, `footprint`, `vmmap --summary`, `leaks --atExit` (3 runs each, per the 015 playbook)

## 3. Testability Seams & Test Doubles
- **Real collaborators**: `EditorZoomController`, `ZoomedChromeMetrics`, `FontChoice`, `EditorPreferences`, `PurpleThemePalette`, the headless `SwiftEditWorkbenchModel`, and the real bundled OpenDyslexic files for `P6`.
- **Isolation seams**:
  - `PreferencesProviding` (`InMemoryKeyValueStore`);
  - `FontFileReading` (in-memory bytes for tampered/missing cases);
  - `FontFamilySource` (fixed family list for the catalog);
  - `ContinuousClock` for benchmarks only;
  - no `Task.sleep` (`TEST-004`).
- **Static fitness**: `TypographyFitness` and `AuditReportFitness` read repository files, as the existing architecture fitness tests do (`TEST-005`).

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | Given/When/Then for REQ-001..REQ-011 and the three MODIFIED requirements |
| Path coverage completeness | Verified | All 12 units have P# and N# paths |
| Security traits tagged | Verified | N3, N6, N11 tagged `security`; STRIDE in `threat-model.md` |
| Constitutional traceability | Verified | Every artifact cites `[<PREFIX>-###]`; amendment declared in `proposal.md` |
