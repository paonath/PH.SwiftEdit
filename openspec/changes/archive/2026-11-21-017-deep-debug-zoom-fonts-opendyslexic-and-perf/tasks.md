# Tasks: 3x Deep Debug Audit, Zoomed Tabs/Sidebar/Gutter, System & OpenDyslexic App Fonts and Extreme Performance Passes

## 1. Unit: ManualOperationsPreconditions
<!-- Manual steps 1-2 (manual-steps.md, lang: it) before audit and font download -->

- [x] 1.1 [MANUAL] TASK-001-MANUAL: Execute manual step 1 (grant Accessibility permission to the agent host) listed in manual-steps.md and confirm completion via qa — outcome: user chose a REDUCED audit (AXIsProcessTrusted=false after granting; live AX/CGEvent probing replaced by headless workbench tests and a static AX label scan) [Const: SDD-008 (08-sdd-governance/convergence-and-gates.md)]
- [x] 1.2 [MANUAL] TASK-001-MANUAL-2: Execute manual step 2 (confirm each OpenDyslexic file download: name, official source, size) listed in manual-steps.md and confirm completion via qa [Const: SDD-008 (08-sdd-governance/convergence-and-gates.md)]

## 2. Unit: ConstitutionV140Amendment
<!-- Structural first (SDD-003): amend UI-002 MINOR -> v1.4.0 (modified constitution REQ-001: P3/N5) -->

- [x] 2.1 [PHASE: RED] TASK-002-RED: Write failing governance tests covering modified-capability paths `P3`/`N5` (`ConstitutionGovernanceValidator` expects `1.4.0`, a `1.4.0` Sync Impact row citing `UI-002`, and rejects `1.3.0`); verify they fail on assertions (`paths: [P3, N5]`) [Const: SDD-006 (08-sdd-governance/amendment-and-sync-impact.md)]
- [x] 2.2 [PHASE: GREEN] TASK-002-GREEN: Amend `UI-002` in `constitution/03-ui-ux/design-system-and-tokens.md` (monospaced default, user-selectable system or OpenDyslexic font), bump `Constitution.md` to `1.4.0`, `last_amended: 2026-11-21`, append the Sync Impact row, and update `expectedConstitutionVersion`; verify path tests pass (`paths: [P3, N5]`) [Const: SDD-005 (08-sdd-governance/amendment-and-sync-impact.md)]
- [x] 2.3 [PHASE: REFACTOR] TASK-002-REFACTOR: Keep the v1.3.0 invariant checks (`UI-001`, `DATA-004`, `SEC-004`) intact and confirm the full suite green; verify suite remains green (`paths: [P3, N5]`) [Const: TEST-005 (06-testing-fitness/architecture-fitness-and-quality.md)]
- [x] 2.4 [PHASE: DOC] TASK-002-DOC: Document the amendment rationale in the validator and the micro-file context line (`paths: [P3, N5]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 3. Unit: OpenDyslexicBundle
<!-- REQ-006 + structural Package.swift resources -->

- [x] 3.1 [PHASE: RED] TASK-003-RED: Write failing tests covering `P6` (bundled files exist under `Sources/SwiftEditUI/Resources/Fonts/`, digests equal `pinnedDigests`, `registerIfNeeded()` twice reports `.available` with PostScript names and registers once); verify they fail on assertions (`paths: [P6]`) [Const: SEC-008 (07-security-privacy/secrets-and-supply-chain.md)]
- [x] 3.2 [PHASE: GREEN] TASK-003-GREEN: Add `resources: [.copy("Resources/Fonts")]` to the `SwiftEditUI` target, download the official OpenDyslexic `.otf` files and `OFL.txt` only after manual step 2 confirmations, pin SHA-256 digests, implement `OpenDyslexicBundle` with CryptoKit verification and `CTFontManagerScope.process` registration; verify path tests pass (`paths: [P6]`) [Const: AR-005 (01-architecture/dependency-and-layering.md)]
- [x] 3.3 [PHASE: REFACTOR] TASK-003-REFACTOR: Isolate file reading behind `FontFileReading` and keep registration idempotent; verify suite remains green (`paths: [P6]`) [Const: AR-007 (01-architecture/dependency-and-layering.md)]
- [x] 3.4 [PHASE: DOC] TASK-003-DOC: Document provenance, license and process-scope rationale (`paths: [P6]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]
- [x] 3.5 [PHASE: RED] [SECURITY] TASK-003-SEC-RED: Write failing abuse tests covering `N6` (tampered bytes, missing file, installed family named `OpenDyslexic`) via injected readers; verify they fail on assertions (`paths: [N6] · tags: security · priority: critical`) [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
- [x] 3.6 [PHASE: GREEN] [SECURITY] TASK-003-SEC-GREEN: Fail closed: no registration on any mismatch, `.unavailable(reason:)`, resolution by registered PostScript names only; verify path tests pass (`paths: [N6] · tags: security · priority: critical`) [Const: SEC-008 (07-security-privacy/secrets-and-supply-chain.md)]
- [x] 3.7 [PHASE: REFACTOR] [SECURITY] TASK-003-SEC-REFACTOR: Audit that no code path registers fonts system-wide or reads font paths from preferences; verify suite remains green (`paths: [N6] · tags: security`) [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
- [x] 3.8 [PHASE: DOC] [SECURITY] TASK-003-SEC-DOC: Document supply-chain verification and shadow-font defence (`paths: [N6]`) [Const: SDD-002 (08-sdd-governance/artifact-traceability.md)]

## 4. Unit: BaselineDebugAudit
<!-- REQ-001 Wave 1: 3x baseline audit per the 015 playbook -->

- [x] 4.1 [PHASE: RED] TASK-004-RED: Write failing `AuditReportFitness` tests covering `P1` and `N1` (report exists, 3 runs, sections CPU/Memory/Latency/Functional/Human Metrics/Accessibility, every finding has ID/severity/repro/value, no fixture body text); verify they fail on assertions (`paths: [P1, N1]`) [Const: TEST-005 (06-testing-fitness/architecture-fitness-and-quality.md)]
- [x] 4.2 [PHASE: GREEN] TASK-004-GREEN: Run the playbook 3x in `.tmp/` (clean Debug build, `sample`, `footprint`, `vmmap`, `leaks`, latency p50/p95, compiled AX/CGEvent functional probe of every command, KLM/Fitts/target-size/click-count metrics, WCAG 2.2 AA contrast + AX label/keyboard/Reduce Motion scan) and write `docs/qa/debug-audit-report-017-baseline.md` with P0..P3 findings; clean `.tmp/`; verify path tests pass (`paths: [P1, N1]`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 4.3 [PHASE: REFACTOR] TASK-004-REFACTOR: Consolidate the driver and harness commands into the report appendix so runs are reproducible; verify suite remains green (`paths: [P1, N1]`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 4.4 [PHASE: DOC] TASK-004-DOC: Document the audit method updates in `.agents/Memories/macos-debug-audit-playbook.md` (human metrics + a11y layer) (`paths: [P1, N1]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 5. Unit: AuditFindingsRemediation
<!-- REQ-002: one RED regression test per P0-P2 finding (apply may split into Convergence_<slug> units) -->

- [x] 5.1 [PHASE: RED] TASK-005-RED: Write one failing regression test per P0, P1 and P2 finding of the baseline report plus the `AuditReportFitness` cross-check covering `P2` and `N2`; verify they fail on assertions (`paths: [P2, N2]`) [Const: TEST-001 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 5.2 [PHASE: GREEN] TASK-005-GREEN: Fix each finding minimally until its regression test passes; mark it `resolved` with the test name and keep P3 findings as `backlog`; verify path tests pass (`paths: [P2, N2]`) [Const: TEST-001 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 5.3 [PHASE: REFACTOR] TASK-005-REFACTOR: Remove duplication introduced by the fixes and confirm the full suite green; verify suite remains green (`paths: [P2, N2]`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 5.4 [PHASE: DOC] TASK-005-DOC: Document each fix's root cause in code where non-obvious (`paths: [P2, N2]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 6. Unit: FontChoicePreferences
<!-- REQ-003 -->

- [x] 6.1 [PHASE: RED] TASK-006-RED: Write failing tests covering `P3` (per-role round trip, legacy pre-017 payload loads with `.default`); verify they fail on assertions (`paths: [P3]`) [Const: DATA-008 (04-data-persistence/write-read-separation.md)]
- [x] 6.2 [PHASE: GREEN] TASK-006-GREEN: Add `FontChoice`/`TypographyRole` to `SwiftEditCore` and extend `EditorPreferences`/`EditorPreferencesStore` with `swiftedit.font.interface` and `swiftedit.font.editor` keys; verify path tests pass (`paths: [P3]`) [Const: BC-001 (02-domain/bounded-context-ownership.md)]
- [x] 6.3 [PHASE: REFACTOR] TASK-006-REFACTOR: Share validation between encode and decode in one `FontChoice.validated(_:)` function; verify suite remains green (`paths: [P3]`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 6.4 [PHASE: DOC] TASK-006-DOC: Document the storage format and backward compatibility (`paths: [P3]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]
- [x] 6.5 [PHASE: RED] [SECURITY] TASK-006-SEC-RED: Write failing abuse tests covering `N3` (path-like, 10,000-character, NUL and non-string values decode to `.default`); verify they fail on assertions (`paths: [N3] · tags: security · priority: critical`) [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
- [x] 6.6 [PHASE: GREEN] [SECURITY] TASK-006-SEC-GREEN: Enforce printable, `<= 128`-scalar family names and fail-closed decoding; verify path tests pass (`paths: [N3] · tags: security · priority: critical`) [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
- [x] 6.7 [PHASE: REFACTOR] [SECURITY] TASK-006-SEC-REFACTOR: Audit that `FontChoice` never carries URLs or paths; verify suite remains green (`paths: [N3] · tags: security`) [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
- [x] 6.8 [PHASE: DOC] [SECURITY] TASK-006-SEC-DOC: Document the fail-closed decoding policy (`paths: [N3]`) [Const: SDD-002 (08-sdd-governance/artifact-traceability.md)]

## 7. Unit: AppTypographyResolver
<!-- REQ-004 -->

- [x] 7.1 [PHASE: RED] TASK-007-RED: Write failing tests covering `P4` and `N4` (system family, OpenDyslexic, default monospaced, bold/italic traits, cache identity, missing family/trait fallback); verify they fail on assertions (`paths: [P4, N4]`) [Const: UI-002 (03-ui-ux/design-system-and-tokens.md)]
- [x] 7.2 [PHASE: GREEN] TASK-007-GREEN: Implement `AppTypography` (`NSFont` + SwiftUI `Font`) with `NSFontManager` trait conversion, Mono preference for OpenDyslexic in the editor role, and a keyed cache invalidated on choice change; verify path tests pass (`paths: [P4, N4]`) [Const: UI-005 (03-ui-ux/component-state-and-forms.md)]
- [x] 7.3 [PHASE: REFACTOR] TASK-007-REFACTOR: Collapse per-role lookups into one keyed function and confirm suite green; verify suite remains green (`paths: [P4, N4]`) [Const: AR-009 (01-architecture/dependency-and-layering.md)]
- [x] 7.4 [PHASE: DOC] TASK-007-DOC: Document the fallback order and cache keying (`paths: [P4, N4]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 8. Unit: SystemFontCatalog
<!-- REQ-005 -->

- [x] 8.1 [PHASE: RED] TASK-008-RED: Write failing tests covering `P5` and `N5` with an injected `FontFamilySource`; verify they fail on assertions (`paths: [P5, N5]`) [Const: TEST-004 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 8.2 [PHASE: GREEN] TASK-008-GREEN: Implement the cached, case/diacritic-insensitive sorted catalog with `Default` and verified `OpenDyslexic` pinned; verify path tests pass (`paths: [P5, N5]`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 8.3 [PHASE: REFACTOR] TASK-008-REFACTOR: Make enumeration lazy and single-shot per process; verify suite remains green (`paths: [P5, N5]`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 8.4 [PHASE: DOC] TASK-008-DOC: Document catalog ordering and caching (`paths: [P5, N5]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 9. Unit: SettingsWindow
<!-- REQ-007 -->

- [x] 9.1 [PHASE: RED] TASK-009-RED: Write failing headless tests covering `P7` and `N7` (live apply to workbench typography, persistence, buffer text/revision/dirty unchanged, unavailable OpenDyslexic absent, accessibility labels); verify they fail on assertions (`paths: [P7, N7]`) [Const: UI-010 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 9.2 [PHASE: GREEN] TASK-009-GREEN: Add the SwiftUI `Settings` scene (`Cmd+,`) in `XcodeApp/SwiftEditApp.swift` with searchable "Interface font" and "Editor font" pickers, live preview rows and `model.setFontChoice(_:for:)`; verify path tests pass (`paths: [P7, N7]`) [Const: UI-005 (03-ui-ux/component-state-and-forms.md)]
- [x] 9.3 [PHASE: REFACTOR] TASK-009-REFACTOR: Extract a `SettingsViewModel` so the view holds no logic; verify suite remains green (`paths: [P7, N7]`) [Const: AR-010 (01-architecture/dependency-and-layering.md)]
- [x] 9.4 [PHASE: DOC] TASK-009-DOC: Document keyboard operation and VoiceOver labelling (`paths: [P7, N7]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 10. Unit: AppWideTypographyRouting
<!-- REQ-008 -->

- [x] 10.1 [PHASE: RED] TASK-010-RED: Write failing `TypographyFitness` scan and `EditorRenderingFonts` tests covering `P8` and `N8`; verify they fail on assertions (`paths: [P8, N8]`) [Const: TEST-005 (06-testing-fitness/architecture-fitness-and-quality.md)]
- [x] 10.2 [PHASE: GREEN] TASK-010-GREEN: Route every `.font(...)` site in `SwiftEditUI` (root view, tabs, sidebar, sheets, popovers, Properties panel, Navigator, Find bar, cheat sheet, About, preview, gutter) and `EditorRenderingFonts` through `AppTypography`; verify path tests pass (`paths: [P8, N8]`) [Const: UI-001 (03-ui-ux/design-system-and-tokens.md)]
- [x] 10.3 [PHASE: REFACTOR] TASK-010-REFACTOR: Delete now-unused font constants and confirm suite green; verify suite remains green (`paths: [P8, N8]`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 10.4 [PHASE: DOC] TASK-010-DOC: Document the single-resolver rule for future views (`paths: [P8, N8]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 11. Unit: ZoomedChromeMetrics
<!-- REQ-009 + modified swifteditui REQ-001 (P7/N11) and editor-ux REQ-005 (P12/N14) -->

- [x] 11.1 [PHASE: RED] TASK-011-RED: Write failing tests covering `P9`, `N9` and modified-capability paths `P7`/`N11` (swifteditui) and `P12`/`N14` (editor-ux); verify they fail on assertions (`paths: [P9, N9, P7, N11, P12, N14]`) [Const: UI-004 (03-ui-ux/design-system-and-tokens.md)]
- [x] 11.2 [PHASE: GREEN] TASK-011-GREEN: Implement `ZoomedChromeMetrics` and apply it to tab strip, sidebar navigator and gutter width; keep `>= 24 pt` targets; verify path tests pass (`paths: [P9, N9, P7, N11, P12, N14]`) [Const: UI-009 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 11.3 [PHASE: REFACTOR] TASK-011-REFACTOR: Replace remaining layout constants in tab and sidebar views with metrics and confirm suite green; verify suite remains green (`paths: [P9, N9, P7, N11, P12, N14]`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 11.4 [PHASE: DOC] TASK-011-DOC: Document scaling curves and the 24 pt floor (`paths: [P9, N9, P7, N11, P12, N14]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 12. Unit: PerfAnalysisAndGoldens017
<!-- REQ-010 analysis -->

- [x] 12.1 [PHASE: RED] TASK-012-RED: Write failing tests requiring `docs/qa/perf-analysis-017.md` with `>= 3` ranked measured bottlenecks and `PerfGolden017` fingerprints (existing 016 groups + typography + zoom metrics); verify they fail on assertions (`paths: [P10, N10]`) [Const: TEST-005 (06-testing-fitness/architecture-fitness-and-quality.md)]
- [x] 12.2 [PHASE: GREEN] TASK-012-GREEN: Rank bottlenecks from the baseline audit and benchmarks, record baselines and capture goldens; verify path tests pass (`paths: [P10, N10]`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 12.3 [PHASE: REFACTOR] TASK-012-REFACTOR: Reuse `PerfBench016` helpers instead of duplicating them; verify suite remains green (`paths: [P10, N10]`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 12.4 [PHASE: DOC] TASK-012-DOC: Document methodology in the report (`paths: [P10, N10]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 13. Unit: PerfPass1_017
<!-- REQ-010 pass 1 -->

- [x] 13.1 [PHASE: RED] TASK-013-RED: Write a failing benchmark for the top-ranked bottleneck #1 requiring `>= 20%` gain or the `UI-012` budget, plus golden equivalence; verify they fail on assertions (`paths: [P10, N10]`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 13.2 [PHASE: GREEN] TASK-013-GREEN: Apply the minimal refactor removing the bottleneck; verify path tests pass (`paths: [P10, N10]`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 13.3 [PHASE: REFACTOR] TASK-013-REFACTOR: Clean up and confirm full suite and goldens green; verify suite remains green (`paths: [P10, N10]`) [Const: TEST-001 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 13.4 [PHASE: DOC] TASK-013-DOC: Record before/after timings in `docs/qa/perf-analysis-017.md` (`paths: [P10, N10]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 14. Unit: PerfPass2_017
<!-- REQ-010 pass 2 -->

- [x] 14.1 [PHASE: RED] TASK-014-RED: Write a failing benchmark for the top-ranked bottleneck #2 plus font/metrics cache staleness `N11` requiring `>= 20%` gain or the `UI-012` budget, plus golden equivalence; verify they fail on assertions (`paths: [P10, N10, N11] · tags: security`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 14.2 [PHASE: GREEN] TASK-014-GREEN: Apply the minimal refactor removing the bottleneck; verify path tests pass (`paths: [P10, N10, N11] · tags: security`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 14.3 [PHASE: REFACTOR] TASK-014-REFACTOR: Clean up and confirm full suite and goldens green; verify suite remains green (`paths: [P10, N10, N11]`) [Const: TEST-001 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 14.4 [PHASE: DOC] TASK-014-DOC: Record before/after timings in `docs/qa/perf-analysis-017.md` (`paths: [P10, N10, N11]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 15. Unit: PerfPass3_017
<!-- REQ-010 pass 3 -->

- [x] 15.1 [PHASE: RED] TASK-015-RED: Write a failing benchmark for the top-ranked bottleneck #3 requiring `>= 20%` gain or the `UI-012` budget, plus golden equivalence; verify they fail on assertions (`paths: [P10, N10]`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 15.2 [PHASE: GREEN] TASK-015-GREEN: Apply the minimal refactor removing the bottleneck; verify path tests pass (`paths: [P10, N10]`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 15.3 [PHASE: REFACTOR] TASK-015-REFACTOR: Clean up and confirm full suite and goldens green; verify suite remains green (`paths: [P10, N10]`) [Const: TEST-001 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 15.4 [PHASE: DOC] TASK-015-DOC: Record before/after timings in `docs/qa/perf-analysis-017.md` (`paths: [P10, N10]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 16. Unit: VerificationAudit
<!-- REQ-011 final 3x verification -->

- [x] 16.1 [PHASE: RED] TASK-016-RED: Write failing `AuditReportFitness` tests covering `P11` and `N12` for `docs/qa/debug-verification-report-017.md`; verify they fail on assertions (`paths: [P11, N12]`) [Const: TEST-005 (06-testing-fitness/architecture-fitness-and-quality.md)]
- [x] 16.2 [PHASE: GREEN] TASK-016-GREEN: Re-run the full 3x audit and write the verification report comparing every baseline metric; zero open P0-P2; verify path tests pass (`paths: [P11, N12]`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 16.3 [PHASE: REFACTOR] TASK-016-REFACTOR: Clean `.tmp/` and remove temporary tooling; verify suite remains green (`paths: [P11, N12]`) [Const: TEST-003 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 16.4 [PHASE: DOC] TASK-016-DOC: Update the debug playbook memory with validated numbers (`paths: [P11, N12]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 17. Unit: ManualOperationsClosure
<!-- Manual steps 3-4 -->

- [x] 17.1 [MANUAL] TASK-017-MANUAL: Execute manual step 3 (optional VoiceOver pass) listed in manual-steps.md and confirm completion via qa — outcome: user skipped optional manual VoiceOver pass [Const: SDD-008 (08-sdd-governance/convergence-and-gates.md)]
- [x] 17.2 [MANUAL] TASK-017-MANUAL-2: Execute manual step 4 (revoke Accessibility permission) listed in manual-steps.md and confirm completion via qa — outcome: user deferred revoking Accessibility permission to later [Const: SDD-008 (08-sdd-governance/convergence-and-gates.md)]

## 18. Unit: LivingSpecificationReconciliation
<!-- MODIFIED: swifteditui REQ-001, editor-ux REQ-005, constitution REQ-001 -->

- [x] 18.1 [SYNC] TASK-018-SYNC: Execute `/myspec-sync 017-deep-debug-zoom-fonts-opendyslexic-and-perf` to reconcile delta changes into `openspec/specs/<capability>/spec.md` [Const: SDD-010 (08-sdd-governance/convergence-and-gates.md)]
