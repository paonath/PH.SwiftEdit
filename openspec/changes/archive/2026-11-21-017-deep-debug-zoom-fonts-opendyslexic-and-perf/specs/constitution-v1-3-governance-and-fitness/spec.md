# Spec Delta: constitution-v1-3-governance-and-fitness

## Purpose
Moves the constitutional governance fitness check from `v1.3.0` to `v1.4.0` so the validator requires the amended `UI-002` (monospaced editor typography as default rather than mandate) and its Sync Impact Report row.

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-001 Constitution v1.3.0 SemVer Metadata Line Caps and Sync Impact Verification
WHEN validating repository constitutional metadata, the constitution governance validator SHALL verify version `1.4.0`, active `Single-Reference Lock`, Bare-Bones line caps across `Constitution.md` and area mini-indexes, and the `1.3.0` (`UI-001`, `DATA-004`, `SEC-004`) and `1.4.0` (`UI-002`) `Sync Impact Report` entries [SDD-004][SDD-005][SDD-006][SDD-009][TEST-006].

Security-Waiver: the version gate moves from `1.3.0` to `1.4.0` for the approved MINOR `UI-002` amendment; the replaced scenarios are re-expressed as `P3`/`N5` with the same strictness (stale version, missing Sync Impact row and line caps still fail), and the security/governance area floor requirement REQ-002 is untouched.

- **REMOVED-SCENARIO**: `P1 Valid Constitution v1.3.0 Root and Area Mini-Indexes Pass Governance Check` — **Reason**: superseded by `P3` after the `v1.4.0` amendment of `UI-002`.
- **REMOVED-SCENARIO**: `N1 Stale SemVer Missing Sync Impact Row or Line-Cap Overflow Fails Validation` — **Reason**: superseded by `N5`, which treats `1.3.0` as stale.

#### Scenario: P3 Valid Constitution v1.4.0 With UI-002 Amendment Passes Governance Check
- **Path**: P3
- **Trait**: positive
- **GIVEN** `openspec/Constitution.md` at `version: "1.4.0"` with `single_reference_lock: true`, line count `<= 45`, `1.3.0` and `1.4.0` Sync Impact rows (the latter citing `UI-002`), and mini-indexes each `<= 25` lines
- **WHEN** `ConstitutionGovernanceValidator.validateConstitutionRoot(at:)` evaluates the repository `openspec/` directory
- **THEN** validation succeeds with `version == "1.4.0"`, `singleReferenceLock == true`, and an empty `violations` list

#### Scenario: N5 Stale v1.3.0 Missing UI-002 Row or Line-Cap Overflow Fails Validation
- **Path**: N5
- **Trait**: negative
- **GIVEN** a `Constitution.md` fixture retaining `version: "1.3.0"`, omitting the `1.4.0` `UI-002` Sync Impact row, exceeding `45` lines, or a mini-index exceeding `25` lines
- **WHEN** `ConstitutionGovernanceValidator.validateConstitutionManifest(content:miniIndexes:)` evaluates the input
- **THEN** validation returns non-empty typed `ConstitutionGovernanceViolation` items identifying the stale version, missing row or line-cap overflow

## REMOVED Requirements

## RENAMED Requirements
