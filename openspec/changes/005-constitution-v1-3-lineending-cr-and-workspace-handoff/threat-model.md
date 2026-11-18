# Threat Model: Synchronize Constitution v1.3.0 (UI-001, DATA-004, SEC-004) and Add ConstitutionGovernanceValidator Fitness Suite

## 1. Asset Boundaries & Trust Zones
- **Constitutional Governance Store (`openspec/Constitution.md` & `openspec/constitution/**`)**: Authoritative machine- and agent-read security, architecture, UI, and persistence rules governing all OpenSpec changes and `SwiftEditCore` / `SwiftEditUI` implementations (`[SDD-001..010]`).
- **Desktop Workspace Boundary (`SEC-004` `v1.3.0` Handoff Contract)**: Defines the narrow App Sandbox boundary between the 100% offline `PH.SwiftEdit` process and external macOS applications (`https`/`http`/`mailto` confirmation plus symlink-confined `NSWorkspace` `Finder` reveals and directory-only `com.googlecode.iterm2` / `com.apple.Terminal` launches with zero subprocesses) (`[SEC-001..004]`).
- **Static Fitness Verification Engine (`ConstitutionGovernanceValidator` in `SwiftEditCore`)**: Pure `Foundation` read-only parser validating repository governance files and in-memory test fixtures (`[AR-002]`, `[TEST-006]`).

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | Untrusted application bundle impersonating a terminal emulator during `Open Terminal` handoff (`CWE-426`, `[SEC-004]`). | `SEC-004` (`v1.3.0`) and `ConstitutionGovernanceValidator` mandate explicit bundle allowlisting restricted to `Finder`, `com.googlecode.iterm2`, and `com.apple.Terminal` (`[SEC-004]`). |
| Tampering | Silent downgrade of `06-testing-fitness/`, `07-security-privacy/`, or `08-sdd-governance/` from `status: active`, disabling `single_reference_lock`, or diluting `SEC-004` clauses (`[SDD-007]`, `[SDD-009]`, `[SEC-010]`). | `ConstitutionGovernanceValidator` fails closed if `single_reference_lock != true`, any mandatory governance/security area is non-active, or required `v1.3.0` `UI-001`/`DATA-004`/`SEC-004` tokens are missing (`[SDD-007]`, `[SDD-009]`, `[TEST-006]`). |
| Repudiation | Unrecorded constitutional edits lacking SemVer bump or `Sync Impact Report` audit entry (`[SDD-005]`, `[SDD-006]`). | `ConstitutionGovernanceValidator` verifies `version: "1.3.0"`, `last_amended`, and the `1.3.0` row in `## Sync Impact Report` citing `UI-001`, `DATA-004`, and `SEC-004` (`[SDD-005]`, `[SDD-006]`). |
| Information Disclosure | Path traversal (`../`) or symlink escape in governance file loading or workspace handoff rules exposing files outside `openspec/` or `workspaceRootURL` (`CWE-22`, `CWE-59`, `[SEC-003]`). | `ConstitutionGovernanceValidator` resolves canonical paths inside `openspec/` via `resolvingSymlinksInPath()`, and `SEC-004` mandates symlink-confined directory/reveal targets (`[SEC-003]`, `[SEC-004]`). |
| Denial of Service | Bloated constitutional markdown files exceeding Single-Reference Lock token budgets (`> 45` / `> 25` / `> 40` lines) or oversized malformed governance inputs (`CWE-400`, `[SDD-004]`, `[SDD-009]`). | `ConstitutionGovernanceValidator` enforces `1 MiB` file read caps and strict Bare-Bones line budgets (`<= 45` lines on `Constitution.md`, `<= 25` on `index.md`, `<= 40` on micro-files) (`[SDD-004]`, `[SDD-009]`). |
| Elevation of Privilege | Passing an executable script file (`.command`, `.sh`, `.term`) to `Terminal.app`/`iTerm2` or spawning `Foundation.Process` shells (`CWE-78`, `[SEC-004]`). | `SEC-004` (`v1.3.0`) explicitly mandates zero socket connections, zero subprocesses, and verified **directory-only** Terminal launches via `NSWorkspace`, validated continuously by `N4` (`Trait: security`) (`[SEC-004]`, `[SEC-009]`, `[SEC-010]`). |

## 3. Abuse Cases & Negative Scenarios
- **Abuse Scenario `N2` (Tampered Constitution Disabling Active Security Floor or `Single-Reference Lock` — `Trait: security`)**: Passing a `Constitution.md` fixture where `07-security-privacy/` (or `06-testing-fitness/` / `08-sdd-governance/`) is changed to `not-applicable` or `single_reference_lock: false` to `ConstitutionGovernanceValidator.validateConstitutionManifest` fails closed with typed `SDD-007` / `SDD-009` security governance violations (`[SDD-007]`, `[SDD-009]`, `[SEC-009]`, `[SEC-010]`).
- **Abuse Scenario `N4` (Weakened `SEC-004` Permitting Subprocesses or File-Based Terminal Execution — `Trait: security`)**: Passing a `07-security-privacy/authn-authz-and-boundaries.md` fixture whose `SEC-004` rule omits `zero socket`, `zero subprocesses`, `symlink-confined`, or `directory-only` Terminal allowlist (`com.googlecode.iterm2`, `com.apple.Terminal`) constraints fails closed with a typed `SEC-004` security boundary violation (`CWE-78`, `[SEC-003]`, `[SEC-004]`, `[SEC-009]`, `[SEC-010]`).

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-18
- Verdict: approved
- Status: approved
- Open items: none
