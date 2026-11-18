# Spec Delta: Constitution v1.3.0 Governance Sync and Automated Fitness Validation

## Purpose
Synchronizes `openspec/Constitution.md` and its Bare-Bones atomic micro-files (`UI-001`, `DATA-004`, `SEC-004`) to `v1.3.0` and introduces `ConstitutionGovernanceValidator` in `SwiftEditCore` to continuously verify SemVer metadata, `Single-Reference Lock` line caps, active security/governance area floors, and `v1.3.0` layout, `CR` line-ending, MRU, and directory-only `NSWorkspace` confinement invariants.

## ADDED Requirements

### Requirement: REQ-001 Constitution v1.3.0 SemVer Metadata Line Caps and Sync Impact Verification
WHEN validating repository constitutional metadata, the constitution governance validator SHALL verify version `1.3.0`, active `Single-Reference Lock`, Bare-Bones line caps across `Constitution.md` and area mini-indexes, and the `1.3.0` `Sync Impact Report` entry for `UI-001`, `DATA-004`, and `SEC-004` [SDD-004][SDD-005][SDD-006][SDD-009][TEST-006].

#### Scenario: P1 Valid Constitution v1.3.0 Root and Area Mini-Indexes Pass Governance Check
- **Path**: P1
- **Trait**: positive
- **GIVEN** `openspec/Constitution.md` at `version: "1.3.0"` with `single_reference_lock: true`, line count `<= 45`, a `1.3.0` row in `## Sync Impact Report` citing `UI-001`, `DATA-004`, and `SEC-004`, and mini-indexes `03-ui-ux/index.md`, `04-data-persistence/index.md`, and `07-security-privacy/index.md` each `<= 25` lines
- **WHEN** `ConstitutionGovernanceValidator.validateConstitutionRoot(at:)` evaluates the repository `openspec/` directory
- **THEN** validation succeeds with `version == "1.3.0"`, `singleReferenceLock == true`, and an empty `violations` list

#### Scenario: N1 Stale SemVer Missing Sync Impact Row or Line-Cap Overflow Fails Validation
- **Path**: N1
- **Trait**: negative
- **GIVEN** a `Constitution.md` fixture retaining `version: "1.2.0"`, omitting the `1.3.0` `Sync Impact Report` entry, or exceeding `45` lines, or a mini-index exceeding `25` lines
- **WHEN** `ConstitutionGovernanceValidator.validateConstitutionManifest(content:miniIndexes:)` evaluates the input
- **THEN** validation returns non-empty typed `ConstitutionGovernanceViolation` items identifying the stale version, missing sync report row, or line-cap overflow

### Requirement: REQ-002 Active Security and Governance Area Floor Protection
IF a constitutional manifest downgrades active governance or security areas or disables `Single-Reference Lock`, THEN the constitution governance validator SHALL return typed governance security violations [SDD-007][SDD-009][SEC-009][SEC-010][TEST-006].

#### Scenario: P1 Active Testing Security and SDD Governance Areas Pass Floor Check
- **Path**: P1
- **Trait**: positive
- **GIVEN** `openspec/Constitution.md` declaring `06-testing-fitness/`, `07-security-privacy/`, and `08-sdd-governance/` as `active` alongside `single_reference_lock: true`
- **WHEN** `ConstitutionGovernanceValidator.validateConstitutionManifest(content:miniIndexes:)` inspects the routing matrix
- **THEN** zero `SDD-007` or `SDD-009` security floor violations are reported

#### Scenario: N2 Downgrading Active Security or Governance Areas or Disabling Single-Reference Lock Is Rejected
- **Path**: N2
- **Trait**: security
- **GIVEN** a tampered `Constitution.md` fixture that marks `06-testing-fitness/`, `07-security-privacy/`, or `08-sdd-governance/` as `not-applicable` or sets `single_reference_lock: false`
- **WHEN** `ConstitutionGovernanceValidator.validateConstitutionManifest(content:miniIndexes:)` inspects the manifest
- **THEN** validation fails closed returning security governance violations referencing `SDD-007` and `SDD-009`

### Requirement: REQ-003 Bare-Bones v1.3.0 Invariant Verification for UI-001 DATA-004 and SEC-004
WHEN inspecting amended `v1.3.0` constitutional micro-files, the constitution governance validator SHALL verify Bare-Bones syntax alongside default-collapsed sidebar, right-column `EditorTabStrip`, and left `LineNumberGutterView` in `UI-001`, 3-way `LF`/`CRLF`/`CR` and 10-entry MRU rules in `DATA-004`, and offline directory-only `NSWorkspace` confinement in `SEC-004` [UI-001][DATA-004][SEC-004][SDD-004][TEST-006].

#### Scenario: P2 Amended UI-001 DATA-004 and SEC-004 Micro-Files Pass Bare-Bones Invariant Check
- **Path**: P2
- **Trait**: positive
- **GIVEN** `03-ui-ux/design-system-and-tokens.md`, `04-data-persistence/storage-and-migrations.md`, and `07-security-privacy/authn-authz-and-boundaries.md` updated to `v1.3.0` with `<= 40` lines and zero blockquotes
- **WHEN** `ConstitutionGovernanceValidator.validateAmendedMicroFiles(uiDesignTokens:dataStorage:securityBoundaries:)` evaluates the three micro-files
- **THEN** validation confirms `UI-001` (collapsed sidebar until `Open Folder`, right-column `EditorTabStrip`, left 1-based `LineNumberGutterView`, and `Line`/`Column`/`Character count`/`UTF-8`/`LF/CRLF/CR` status bar), `DATA-004` (`LF`, `CRLF`, `CR`, and `10` deduplicated MRU bookmarks), and `SEC-004` (`100% offline`, `zero socket`, `zero subprocesses`, `Finder`, `com.googlecode.iterm2`, `com.apple.Terminal`, and `directory-only`) with zero violations

#### Scenario: N3 Missing v1.3.0 UI-001 or DATA-004 Clause Blockquote Prose or 40-Line Overflow Fails Check
- **Path**: N3
- **Trait**: negative
- **GIVEN** micro-file fixtures where `UI-001` omits `LineNumberGutterView` or default-collapsed sidebar, `DATA-004` omits `CR` line endings or the `10` MRU cap, a line starts with blockquote `>`, or total lines exceed `40`
- **WHEN** `ConstitutionGovernanceValidator.validateAmendedMicroFiles(uiDesignTokens:dataStorage:securityBoundaries:)` evaluates the fixtures
- **THEN** validation returns typed `ConstitutionGovernanceViolation` entries pinpointing each missing `v1.3.0` clause or Bare-Bones formatting violation

### Requirement: REQ-004 SEC-004 Offline Zero-Subprocess and Directory-Only Terminal Guard Enforcement
IF an amended `SEC-004` rule omits zero-socket offline isolation, zero-subprocess enforcement, or symlink-confined directory-only Terminal handoff constraints, THEN the constitution governance validator SHALL reject the micro-file with a security boundary violation [SEC-003][SEC-004][SEC-009][SEC-010][SDD-007].

#### Scenario: P2 Compliant SEC-004 Rule Enforcing Zero Subprocesses and Directory-Only Terminal Allowlist Passes
- **Path**: P2
- **Trait**: positive
- **GIVEN** `07-security-privacy/authn-authz-and-boundaries.md` containing a `SEC-004` rule requiring `100% offline`, `zero socket`, `zero subprocesses`, user-confirmed `https`/`http`/`mailto` URIs, and `symlink-confined` `NSWorkspace` `Finder` reveals or `directory-only` Terminal launches (`com.googlecode.iterm2`, `com.apple.Terminal`)
- **WHEN** `ConstitutionGovernanceValidator.validateAmendedMicroFiles(uiDesignTokens:dataStorage:securityBoundaries:)` inspects `SEC-004`
- **THEN** zero security boundary violations are returned

#### Scenario: N4 Weakened SEC-004 Omitting Zero-Subprocess Symlink or Directory-Only Terminal Guard Is Rejected
- **Path**: N4
- **Trait**: security
- **GIVEN** a `07-security-privacy/authn-authz-and-boundaries.md` fixture whose `SEC-004` rule omits `zero socket`, `zero subprocesses`, `symlink-confined`, `directory-only`, or the explicit `com.googlecode.iterm2` and `com.apple.Terminal` allowlist
- **WHEN** `ConstitutionGovernanceValidator.validateAmendedMicroFiles(uiDesignTokens:dataStorage:securityBoundaries:)` evaluates the security micro-file
- **THEN** validation fails closed returning `SEC-004` security boundary violations blocking `CWE-78` script execution regressions

## MODIFIED Requirements
<!-- When modifying an existing requirement, existing scenarios are preserved additively by default.
     Use optional directives in the requirement body (stripped upon merge):
     - **REMOVED-SCENARIO**: `<Scenario Title>` — **Reason**: <justification>
     - **RENAMED-SCENARIO**: FROM `<Old Title>` TO `<New Title>` -->

## REMOVED Requirements
<!-- When removing a requirement, provide ### Requirement: <Title> and **Reason**: <justification> -->

## RENAMED Requirements
<!-- When renaming a requirement, provide bullet pairs:
     - FROM: `### Requirement: <Old Title>`
     - TO: `### Requirement: <New Title>` -->
