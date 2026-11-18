# Test Plan: Synchronize Constitution v1.3.0 (UI-001, DATA-004, SEC-004) and Add ConstitutionGovernanceValidator Fitness Suite

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `ConstitutionVersionAndSyncImpactFitness` (`ConstitutionGovernanceValidator.validateConstitutionRoot`, `validateConstitutionManifest`) | `P1`: Live `openspec/Constitution.md` (`version: "1.3.0"`, `single_reference_lock: true`, `<= 45` lines, `1.3.0` `Sync Impact Report` row citing `UI-001`, `DATA-004`, `SEC-004`) and mini-indexes (`03-ui-ux/index.md`, `04-data-persistence/index.md`, `07-security-privacy/index.md`, each `<= 25` lines) pass with zero violations (`[SDD-004..006]`, `[SDD-009]`, `[TEST-006]`). | `N1`: Rejects fixtures with stale `version: "1.2.0"`, missing `1.3.0` `Sync Impact Report` entry, `Constitution.md` `> 45` lines, or mini-index `> 25` lines; `N2` (`security`): Rejects tampered `Constitution.md` fixtures that downgrade `06-testing-fitness/`, `07-security-privacy/`, or `08-sdd-governance/` from `active` or set `single_reference_lock: false` (`[SDD-007]`, `[SDD-009]`, `[SEC-009]`, `[SEC-010]`). |
| `AmendedMicroFileInvariantsFitness` (`ConstitutionGovernanceValidator.validateAmendedMicroFiles`) | `P2`: Live `03-ui-ux/design-system-and-tokens.md` (`UI-001`), `04-data-persistence/storage-and-migrations.md` (`DATA-004`), and `07-security-privacy/authn-authz-and-boundaries.md` (`SEC-004`) pass Bare-Bones checks (`<= 40` lines, zero blockquotes) and verify collapsed sidebar, right-column `EditorTabStrip`, left `LineNumberGutterView`, 3-way `LF`/`CRLF`/`CR`, `10` MRU cap, and offline directory-only `NSWorkspace` confinement (`[UI-001]`, `[DATA-004]`, `[SEC-004]`, `[SDD-004]`, `[TEST-006]`). | `N3`: Rejects micro-file fixtures missing `LineNumberGutterView`, collapsed sidebar, `CR` line ending, or `10` MRU cap, containing `>` blockquotes, or exceeding `40` lines; `N4` (`security`): Rejects weakened `SEC-004` fixtures omitting `zero socket`, `zero subprocesses`, `symlink-confined`, `directory-only`, or `com.googlecode.iterm2` / `com.apple.Terminal` allowlist tokens (`[SEC-003]`, `[SEC-004]`, `[SEC-009]`, `[SEC-010]`). |

## 2. Test Automation Strategy & Commands
- Unit test runner command: `swift test --parallel`
- Targeted fitness suite command: `swift test --parallel --filter ConstitutionFitnessTests`
- Security trait / filter command: `swift test --parallel --filter Security`

## 3. Testability Seams & Test Doubles
- Real collaborators: Live repository `openspec/Constitution.md`, `openspec/constitution/{03-ui-ux,04-data-persistence,07-security-privacy}/index.md`, and `UI-001`/`DATA-004`/`SEC-004` micro-files read read-only from `#filePath`-anchored `repoRoot`.
- Isolation seams: Pure in-memory Markdown string inputs (`validateConstitutionManifest` and `validateAmendedMicroFiles`) and ephemeral `.tmp/test-results/` symlink fixtures (cleaned via `defer`) for parallel, zero-side-effect negative and security tests (`[TEST-003]`, `[TEST-004]`).

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | Given/When/Then scenarios defined in `specs/constitution-v1-3-governance-and-fitness/spec.md` (`REQ-001..REQ-004`) |
| Path coverage completeness | Verified | Both units cover positive (`P1`, `P2`) and negative (`N1..N4`) paths |
| Security traits tagged | Verified | Abuse cases `N2` and `N4` tagged `- **Trait**: security` (`[SDD-007]`, `[SDD-009]`, `[SEC-003]`, `[SEC-004]`, `[SEC-009]`, `[SEC-010]`) |
