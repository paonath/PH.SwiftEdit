# Proposal: Synchronize Constitution v1.3.0 (UI-001, DATA-004, SEC-004) and Add ConstitutionGovernanceValidator Fitness Suite

## Why
Guided reasoning session `002_minimal-ui-menus-and-editor-features` (`TASK-01` in `reasoning/002_minimal-ui-menus-and-editor-features/README.ai.md`) ratified five architectural refinements required before implementing the `SwiftEditCore` (`TASK-02`) and `SwiftEditUI` (`TASK-03`) minimal editor feature set: (1) a collapsible left Folder Navigator sidebar closed by default and auto-expanded on `Open Folder`, (2) `EditorTabStrip` positioned strictly above the right-hand editor column, (3) a synchronized left 1-based `LineNumberGutterView` plus bottom-right `Line`/`Column`/`Character count`/`UTF-8`/`LF/CRLF/CR` status bar, (4) 3-way lossless `LF` (`\n`), `CRLF` (`\r\n`), and Classic Mac `CR` (`\r`) line-ending preservation alongside 10 deduplicated MRU bookmarks, and (5) symlink-confined `NSWorkspace` `Finder` reveal and directory-only `iTerm2` (`com.googlecode.iterm2`) / `Terminal.app` (`com.apple.Terminal`) handoffs with zero subprocesses. Per `SDD-005`, `SDD-006`, and `SDD-010` (`Spec > Code`), `openspec/Constitution.md` must be amended from `v1.2.0` to `v1.3.0` (`MINOR`) and guarded by deterministic Swift 6 fitness tests before downstream implementation begins.

## What Changes
- Amend `openspec/Constitution.md` from `version: "1.2.0"` to `version: "1.3.0"` (`last_amended: "2026-11-18"`), update routing scope summaries for `03-ui-ux/`, `04-data-persistence/`, and `07-security-privacy/`, and append the `1.3.0` audit row to `## Sync Impact Report` (`[SDD-005]`, `[SDD-006]`, `[SDD-009]`).
- Update area mini-indexes (`openspec/constitution/03-ui-ux/index.md`, `04-data-persistence/index.md`, `07-security-privacy/index.md`) while keeping each strictly `<= 25` lines (`[SDD-004]`, `[SDD-009]`).
- Amend atomic Bare-Bones micro-files (`<= 40` lines, zero blockquotes):
  - `UI-001` in `openspec/constitution/03-ui-ux/design-system-and-tokens.md`: default-collapsed left sidebar until `Open Folder`, right-column-only `EditorTabStrip`, synchronized left 1-based `LineNumberGutterView`, and bottom-right `Line`/`Column`/`Character count`/`UTF-8`/`LF/CRLF/CR` status bar (`[UI-001]`).
  - `DATA-004` in `openspec/constitution/04-data-persistence/storage-and-migrations.md`: 3-way lossless `LF` (`\n`), `CRLF` (`\r\n`), and Classic Mac `CR` (`\r`) line-ending preservation plus up to `10` deduplicated security-scoped MRU bookmarks (`[DATA-004]`).
  - `SEC-004` in `openspec/constitution/07-security-privacy/authn-authz-and-boundaries.md`: 100% offline zero-socket and zero-subprocess runtime permitting user-confirmed `https`/`http`/`mailto` URIs and symlink-confined `NSWorkspace` `Finder` reveals or verified directory-only Terminal launches (`com.googlecode.iterm2`, `com.apple.Terminal`) (`[SEC-003]`, `[SEC-004]`).
- Implement `ConstitutionGovernanceValidator` in `Sources/SwiftEditCore/ArchitectureFitness/ConstitutionGovernanceValidator.swift` and `ConstitutionFitnessTests` in `Tests/SwiftEditTests/ConstitutionFitnessTests.swift` verifying `v1.3.0` metadata, Bare-Bones line/syntax caps, `SDD-007` active-area non-downgrade, and `UI-001`/`DATA-004`/`SEC-004` invariants (`[AR-002]`, `[AR-004]`, `[TEST-001]`, `[TEST-006]`, `[TEST-008]`).

## Capabilities
- New Capabilities: `constitution-v1-3-governance-and-fitness`
- Modified Capabilities: None

## Domain Carrier & Decision Ownership (BC-###)
- **BC-001**: `ArchitectureFitness` (`SwiftEditCore` Generic Governance Support) owns static repository fitness verification for SwiftPM manifests, `SwiftEditCore` import isolation, and Bare-Bones `openspec/Constitution.md` (`v1.3.0`) invariants (`[AR-002]`, `[TEST-006]`, `[SDD-004..009]`).
- **Owned Decisions**: Constitutional SemVer metadata validation (`1.3.0`), `Single-Reference Lock` flag and line-cap verification (`<= 45` / `<= 25` / `<= 40` lines), `SDD-007` active security/governance floor checks, and `UI-001`/`DATA-004`/`SEC-004` clause verification.
- **Forbidden Responsibilities**: `ConstitutionGovernanceValidator` MUST NEVER import `AppKit`, `UIKit`, `SwiftUI`, `WebKit`, or `Network` (`[AR-002]`), spawn shell subprocesses (`[SEC-004]`), or mutate files on disk during validation (`[BC-011]`).
- **External Decision References**: `none`.

## Impact
- **Governance Artifacts**: Updates `openspec/Constitution.md` (`v1.3.0`), `03-ui-ux/index.md`, `03-ui-ux/design-system-and-tokens.md`, `04-data-persistence/index.md`, `04-data-persistence/storage-and-migrations.md`, `07-security-privacy/index.md`, and `07-security-privacy/authn-authz-and-boundaries.md` during `/myspec-apply`.
- **Source & Test Modules**: Adds `Sources/SwiftEditCore/ArchitectureFitness/ConstitutionGovernanceValidator.swift` and `Tests/SwiftEditTests/ConstitutionFitnessTests.swift`.
- **Downstream Unblocking**: Unblocks `TASK-02` (`006-core-cr-lineending-mru-batch-search-and-sidebar-fs`) and `TASK-03` (`007-ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions`).

## Security Impact
- Prevents `CWE-78` OS/script command execution via `Terminal.app` or `iTerm2` by enshrining **directory-only** `NSWorkspace` Terminal handoff, explicit bundle allowlisting (`com.googlecode.iterm2`, `com.apple.Terminal`, `Finder`), `resolvingSymlinksInPath()` workspace confinement (`CWE-22`/`CWE-59`), and **zero subprocess spawning** directly in `SEC-004` (`[SEC-003]`, `[SEC-004]`).
- Enforces `SDD-007` and `SDD-009` via automated negative security tests (`Trait: security`) blocking silent deactivation of `06-testing-fitness/`, `07-security-privacy/`, or `08-sdd-governance/` or weakening of `SEC-004` (`[SEC-009]`, `[SEC-010]`).

## Metadata
- Owner: PH.SwiftEdit Team
- Domain: Constitutional SDD Governance & Swift 6 Architecture Fitness
- Reviewer: spec-sdlc-expert, swift-macos-expert, cyber-security-expert
- Branch: feature/FirstStub
- Manual-Steps: none
- Modifies-Specs: none
- Constitutional-Rules: [AR-002, AR-004, UI-001, DATA-004, SEC-003, SEC-004, SEC-009, SEC-010, TEST-001, TEST-002, TEST-003, TEST-006, TEST-008, SDD-001, SDD-002, SDD-004, SDD-005, SDD-006, SDD-007, SDD-009]
- Amends-Constitution: UI-001, DATA-004, SEC-004 (MINOR)

## Prerequisites
- Completed guided reasoning session `002_minimal-ui-menus-and-editor-features` (`README.ai.md` `TASK-01`) and archived `000`..`004` foundation changes.
