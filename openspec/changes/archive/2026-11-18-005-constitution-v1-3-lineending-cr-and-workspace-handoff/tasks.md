# Tasks: Synchronize Constitution v1.3.0 (UI-001, DATA-004, SEC-004) and Add ConstitutionGovernanceValidator Fitness Suite

## 1. Unit: ConstitutionVersionAndSyncImpactFitness
<!-- Governing rules: AR-002, AR-004, SDD-004, SDD-005, SDD-006, SDD-007, SDD-009, SEC-009, SEC-010, TEST-001, TEST-002, TEST-006 -->

- [x] 1.1 [RED] TASK-001-RED: Write failing `Swift Testing` `@Suite("ConstitutionFitnessTests")` tests in `Tests/SwiftEditTests/ConstitutionFitnessTests.swift` for `P1` (`openspec/Constitution.md` at `version: "1.3.0"`, `single_reference_lock: true`, `<= 45` lines, `1.3.0` `Sync Impact Report` row citing `UI-001`, `DATA-004`, `SEC-004`, and `03-ui-ux`/`04-data-persistence`/`07-security-privacy` `index.md` files `<= 25` lines) and `N1` (stale `1.2.0` version, missing `1.3.0` sync report row, or `> 45` / `> 25` line-cap overflow); verify failure on assertions [Const: SDD-006 (08-sdd-governance/amendment-and-sync-impact.md)]
  - paths: [P1, N1]
- [x] 1.2 [GREEN] TASK-001-GREEN: Update `openspec/Constitution.md` (`v1.3.0`), `openspec/constitution/03-ui-ux/index.md`, `openspec/constitution/04-data-persistence/index.md`, and `openspec/constitution/07-security-privacy/index.md`, and implement `ConstitutionGovernanceViolation`, `ConstitutionValidationSummary`, `validateConstitutionRoot`, and `validateConstitutionManifest` in `Sources/SwiftEditCore/ArchitectureFitness/ConstitutionGovernanceValidator.swift` so `P1` and `N1` pass [Const: SDD-005 (08-sdd-governance/amendment-and-sync-impact.md)]
  - paths: [P1, N1]
- [x] 1.3 [REFACTOR] TASK-001-REFACTOR: Extract frontmatter key-value parser and Bare-Bones line-budget helper in `ConstitutionGovernanceValidator.swift` while keeping `P1` and `N1` green [Const: AR-002 (01-architecture/module-topology.md)]
  - paths: [P1, N1]
- [x] 1.4 [DOC] TASK-001-DOC: Write concise English Swift Markup (`///`) documentation on `ConstitutionGovernanceViolation`, `ConstitutionValidationSummary`, and `ConstitutionGovernanceValidator` root manifest methods
  - paths: [P1, N1]
- [x] 1.5 [RED] [SECURITY] TASK-002-RED: Write failing security test `n2SecurityActiveGovernanceAndSecurityAreasCannotBeDowngraded` in `Tests/SwiftEditTests/ConstitutionFitnessTests.swift` for `N2` verifying rejection of tampered `Constitution.md` fixtures that downgrade `06-testing-fitness/`, `07-security-privacy/`, or `08-sdd-governance/` from `active` or set `single_reference_lock: false`, plus symlink escape outside `openspec/`; verify failure on assertions [Const: SDD-007 (08-sdd-governance/amendment-and-sync-impact.md)]
  - paths: [P1, N2] · tags: security · priority: critical
- [x] 1.6 [GREEN] [SECURITY] TASK-002-GREEN: Enforce `SDD-007` mandatory `active` status on `06-testing-fitness/`, `07-security-privacy/`, and `08-sdd-governance/`, `single_reference_lock == true`, and `resolvingSymlinksInPath()` confinement inside `openspec/` in `ConstitutionGovernanceValidator.swift` so `N2` passes [Const: SEC-003 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P1, N2] · tags: security · priority: critical
- [x] 1.7 [REFACTOR] [SECURITY] TASK-002-REFACTOR: Consolidate routing-table row parsing and canonical path confinement checks in `ConstitutionGovernanceValidator.swift` while keeping all suites green [Const: TEST-006 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P1, N2] · tags: security
- [x] 1.8 [DOC] [SECURITY] TASK-002-DOC: Document `SDD-007`, `SDD-009`, and `SEC-003` governance floor and symlink-confinement invariants in English Swift Markup (`///`) comments
  - paths: [P1, N2]

## 2. Unit: AmendedMicroFileInvariantsFitness
<!-- Governing rules: UI-001, DATA-004, SEC-003, SEC-004, SEC-009, SEC-010, SDD-004, TEST-006, TEST-008 -->

- [x] 2.1 [RED] TASK-003-RED: Write failing tests in `Tests/SwiftEditTests/ConstitutionFitnessTests.swift` for `P2` (live `v1.3.0` Bare-Bones micro-files `UI-001`, `DATA-004`, and `SEC-004` `<= 40` lines with zero blockquotes and all required `v1.3.0` clauses) and `N3` (missing `LineNumberGutterView`/collapsed sidebar in `UI-001`, missing `CR` or `10` MRU cap in `DATA-004`, `>` blockquote prose, or `> 40` lines); verify failure on assertions against `v1.2.0` micro-files [Const: UI-001 (03-ui-ux/design-system-and-tokens.md)]
  - paths: [P2, N3]
- [x] 2.2 [GREEN] TASK-003-GREEN: Update `UI-001` in `openspec/constitution/03-ui-ux/design-system-and-tokens.md`, `DATA-004` in `openspec/constitution/04-data-persistence/storage-and-migrations.md`, and `SEC-004` in `openspec/constitution/07-security-privacy/authn-authz-and-boundaries.md` to `v1.3.0`, and implement `validateAmendedMicroFiles` in `ConstitutionGovernanceValidator.swift` so `P2` and `N3` pass [Const: DATA-004 (04-data-persistence/storage-and-migrations.md)]
  - paths: [P2, N3]
- [x] 2.3 [REFACTOR] TASK-003-REFACTOR: Deduplicate rule-extraction and Bare-Bones syntax checks (`<= 40` lines, zero `>` blockquotes, single-line `- **<ID>**:`) in `ConstitutionGovernanceValidator.swift` while keeping `P2` and `N3` green [Const: TEST-006 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P2, N3]
- [x] 2.4 [DOC] TASK-003-DOC: Write concise English Swift Markup (`///`) documentation on `validateAmendedMicroFiles` and `UI-001`/`DATA-004` clause contracts
  - paths: [P2, N3]
- [x] 2.5 [RED] [SECURITY] TASK-004-RED: Write failing security test `n4SecuritySEC004RejectsMissingZeroSubprocessOrDirectoryOnlyTerminalGuards` in `Tests/SwiftEditTests/ConstitutionFitnessTests.swift` for `N4` verifying rejection of `SEC-004` fixtures omitting `zero socket`, `zero subprocesses`, `symlink-confined`, `directory-only`, or the `com.googlecode.iterm2` / `com.apple.Terminal` allowlist; verify failure on assertions [Const: SEC-004 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P2, N4] · tags: security · priority: critical
- [x] 2.6 [GREEN] [SECURITY] TASK-004-GREEN: Implement `SEC-004` required security-clause checks (`100% offline`, `zero socket`, `zero subprocesses`, `symlink-confined`, `directory-only`, `Finder`, `com.googlecode.iterm2`, `com.apple.Terminal`) in `ConstitutionGovernanceValidator.swift` so `N4` passes [Const: SEC-004 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P2, N4] · tags: security · priority: critical
- [x] 2.7 [REFACTOR] [SECURITY] TASK-004-REFACTOR: Run `swift test --parallel -Xswiftc -warnings-as-errors`, verify `ArchitectureFitnessTests` and `ConstitutionFitnessTests` remain green with `>= 85%` `SwiftEditCore` coverage, and clean `./.tmp/` [Const: TEST-008 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P2, N4] · tags: security
- [x] 2.8 [DOC] [SECURITY] TASK-004-DOC: Document `CWE-78` directory-only Terminal handoff and zero-subprocess enforcement invariants on `SEC-004` validation helpers in English Swift Markup (`///`) comments
  - paths: [P2, N4]
