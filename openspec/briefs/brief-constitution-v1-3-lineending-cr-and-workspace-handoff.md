---
id: "brief-constitution-v1-3-lineending-cr-and-workspace-handoff"
change_id: "005-constitution-v1-3-lineending-cr-and-workspace-handoff"
capability: "constitution-v1-3-governance-and-fitness"
branch: "feature/FirstStub"
modifies_specs: "none"
status: "approved-via-qa"
date: "2026-11-18"
owners:
  - "spec-sdlc-expert"
  - "swift-macos-expert"
  - "cyber-security-expert"
---

# TDD Specification Brief: Synchronize `openspec/Constitution.md` (`v1.2.0` -> `v1.3.0`) and Add `ConstitutionGovernanceValidator` Fitness Suite (`TASK-01`)

## 1. Context & Source Traceability

- **Originating Roadmap Task**: `TASK-01` in `reasoning/002_minimal-ui-menus-and-editor-features/README.ai.md`.
- **Active Git Branch**: `feature/FirstStub` (baseline commit `2cbda86175a0f50a82507f755fdc0a46e6c0242e`).
- **Consolidated Specs Modified (`modifies_specs`)**: `none` (introduces net-new governance capability `constitution-v1-3-governance-and-fitness`; downstream application living specs will be updated in `TASK-02` `006` and `TASK-03` `007`).
- **Constitutional Amendment (`SDD-005`, `SDD-006`)**: `MINOR` (`v1.2.0` -> `v1.3.0`) touching `UI-001` (`03-ui-ux/design-system-and-tokens.md`), `DATA-004` (`04-data-persistence/storage-and-migrations.md`), and `SEC-004` (`07-security-privacy/authn-authz-and-boundaries.md`), explicitly approved via human QA.
- **Governing Constitutional Rules**: `[AR-002]`, `[AR-004]`, `[UI-001]`, `[DATA-004]`, `[SEC-003]`, `[SEC-004]`, `[SEC-009]`, `[SEC-010]`, `[TEST-001]`, `[TEST-002]`, `[TEST-003]`, `[TEST-006]`, `[TEST-008]`, `[SDD-001]`, `[SDD-002]`, `[SDD-004]`, `[SDD-005]`, `[SDD-006]`, `[SDD-007]`, `[SDD-009]`.

## 2. Domain, Architecture & Security Expert Notes

- **`spec-sdlc-expert` (`08-sdd-governance/amendment-and-sync-impact.md`)**:
  - `openspec/Constitution.md` increments `version: "1.3.0"`, updates `last_amended: "2026-11-18"`, updates routing scope summaries for `03-ui-ux/`, `04-data-persistence/`, and `07-security-privacy/`, and appends a `1.3.0` row to `## Sync Impact Report` while staying strictly `<= 45` lines (`SDD-004`, `SDD-005`, `SDD-006`, `SDD-009`).
  - Area mini-indexes (`<= 25` lines) and atomic micro-files (`<= 40` lines) preserve Bare-Bones syntax (zero blockquotes, zero `## Purpose` prose, single-line `- **<PREFIX>-<NNN>**: ... SHALL ...` rules).
- **`swift-macos-expert` (`openspec/agents/swift-macos-expert.agent.md` `v1.3.0`)**:
  - `UI-001` (`03-ui-ux/design-system-and-tokens.md`) codifies the minimalist layout ratified in `002_minimal-ui-menus-and-editor-features`: left Folder Navigator sidebar collapsed by default until `Open Folder`, `EditorTabStrip` positioned strictly above the right-hand editor column, synchronized left 1-based `LineNumberGutterView`, and bottom-right status bar (`Line`, `Column`, `Character count`, `UTF-8`, `LF/CRLF/CR`).
  - `DATA-004` (`04-data-persistence/storage-and-migrations.md`) expands lossless line-ending preservation to 3-way `LF` (`\n`), `CRLF` (`\r\n`), and Classic Mac `CR` (`\r`) alongside a 10-entry deduplicated security-scoped MRU `RecentFilesStore`.
  - `ConstitutionGovernanceValidator` in `Sources/SwiftEditCore/ArchitectureFitness/ConstitutionGovernanceValidator.swift` (pure `Foundation`, `Sendable`) and `ConstitutionFitnessTests` in `Tests/SwiftEditTests/ConstitutionFitnessTests.swift` enforce `v1.3.0` governance invariants during `swift test --parallel` (`AR-002`, `TEST-006`).
- **`cyber-security-expert` (`07-security-privacy/authn-authz-and-boundaries.md`)**:
  - `SEC-004` (`v1.3.0`) preserves 100% offline zero-socket and zero-subprocess execution while permitting—alongside user-confirmed `https`, `http`, or `mailto` URIs—symlink-confined `NSWorkspace` `Finder` reveals and verified **directory-only** Terminal launches (`com.googlecode.iterm2`, `com.apple.Terminal`), neutralizing `CWE-78` script execution on `.command`/`.sh`/`.term` files.
  - `ConstitutionGovernanceValidator` rejects tampered manifests that drop `status: "active"` on `06-testing-fitness/`, `07-security-privacy/`, or `08-sdd-governance/` (`SDD-007`) or weaken `SEC-004` offline/subprocess/directory-only clauses.

## 3. 4-Pillar Breakdown & Path Coverage Matrix

| Unit | Path ID | Trait | Summary |
| :--- | :--- | :--- | :--- |
| `ConstitutionVersionAndSyncImpactFitness` | `P1` | `positive` | Validates `openspec/Constitution.md` (`version: "1.3.0"`, `single_reference_lock: true`, `<= 45` lines, `1.3.0` `Sync Impact Report` row citing `UI-001`, `DATA-004`, `SEC-004`) and area mini-indexes (`03-ui-ux/index.md`, `04-data-persistence/index.md`, `07-security-privacy/index.md`, each `<= 25` lines) (`[SDD-004]`, `[SDD-005]`, `[SDD-006]`, `[SDD-009]`, `[TEST-006]`). |
| `ConstitutionVersionAndSyncImpactFitness` | `N1` | `negative` | Rejects `Constitution.md` or mini-index fixtures with stale `1.2.0` version, missing `1.3.0` `Sync Impact Report` entry, or Bare-Bones line-cap violations (`> 45` lines on `Constitution.md` or `> 25` lines on `index.md`) (`[SDD-004]`, `[SDD-006]`, `[SDD-009]`). |
| `ConstitutionVersionAndSyncImpactFitness` | `N2` | `security` | Rejects tampered `Constitution.md` fixtures that set `single_reference_lock: false` or downgrade `06-testing-fitness/`, `07-security-privacy/`, or `08-sdd-governance/` from `active` (`[SDD-007]`, `[SDD-009]`, `[SEC-009]`, `[SEC-010]`). |
| `AmendedMicroFileInvariantsFitness` | `P2` | `positive` | Validates `v1.3.0` Bare-Bones micro-files (`<= 40` lines, zero blockquotes): `UI-001` (default-collapsed sidebar, right-column `EditorTabStrip`, left 1-based `LineNumberGutterView`, status bar `Line`/`Column`/`Character count`/`UTF-8`/`LF/CRLF/CR`), `DATA-004` (`LF`, `CRLF`, `CR` + `10` MRU bookmarks), and `SEC-004` (100% offline zero-socket/zero-subprocess + `https`/`http`/`mailto` + symlink-confined `NSWorkspace` `Finder` and directory-only `com.googlecode.iterm2`/`com.apple.Terminal`) (`[UI-001]`, `[DATA-004]`, `[SEC-004]`, `[SDD-004]`, `[TEST-006]`). |
| `AmendedMicroFileInvariantsFitness` | `N3` | `negative` | Rejects micro-file fixtures missing required `v1.3.0` clauses (`LineNumberGutterView`, default-collapsed sidebar, `CR` line ending, or `10` MRU cap), containing Markdown blockquotes (`>`), or exceeding `40` lines (`[UI-001]`, `[DATA-004]`, `[SDD-004]`). |
| `AmendedMicroFileInvariantsFitness` | `N4` | `security` | Rejects weakened `SEC-004` fixtures that omit `zero socket`, `zero subprocesses`, `symlink-confined`, or `directory-only` Terminal allowlist (`com.googlecode.iterm2`, `com.apple.Terminal`) constraints (`CWE-78`, `[SEC-003]`, `[SEC-004]`, `[SEC-009]`, `[SEC-010]`). |

## 4. Declarative GIVEN-WHEN-THEN Behavior Contracts

```gherkin
Feature: Constitution v1.3.0 Governance Sync and Automated Fitness Validation

  @REQ-CONSTITUTION-V1-3-GOVERNANCE-AND-FITNESS-001
  Scenario: Repository Constitution v1.3.0 and mini-indexes pass governance fitness validation
    Given openspec/Constitution.md amended to version "1.3.0" with single_reference_lock enabled and updated mini-indexes
    When ConstitutionGovernanceValidator evaluates the repository constitution root
    Then validation succeeds with zero violations, confirming line caps and the 1.3.0 Sync Impact Report entry

  @REQ-CONSTITUTION-V1-3-GOVERNANCE-AND-FITNESS-002 @security
  Scenario: Downgrading active security or governance areas fails closed
    Given a Constitution.md payload that marks 07-security-privacy as not-applicable or sets single_reference_lock to false
    When ConstitutionGovernanceValidator evaluates the constitution manifest
    Then validation fails closed with security governance violations citing SDD-007 and SDD-009

  @REQ-CONSTITUTION-V1-3-GOVERNANCE-AND-FITNESS-003
  Scenario: Amended UI-001, DATA-004, and SEC-004 v1.3.0 micro-files pass Bare-Bones invariant checks
    Given updated Bare-Bones micro-files for UI-001, DATA-004, and SEC-004 under openspec/constitution/
    When ConstitutionGovernanceValidator inspects the amended micro-files
    Then validation confirms default-collapsed sidebar, right-column EditorTabStrip, left LineNumberGutterView, 3-way LF/CRLF/CR, 10 MRU cap, and directory-only NSWorkspace confinement

  @REQ-CONSTITUTION-V1-3-GOVERNANCE-AND-FITNESS-004 @security
  Scenario: Weakened SEC-004 omitting zero-subprocess or directory-only Terminal guardrails is rejected
    Given a SEC-004 micro-file fixture that omits zero-subprocess or directory-only Terminal confinement
    When ConstitutionGovernanceValidator evaluates the security micro-file
    Then validation rejects the fixture with a typed SEC-004 security boundary violation
```
