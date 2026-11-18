# Design: Synchronize Constitution v1.3.0 (UI-001, DATA-004, SEC-004) and Add ConstitutionGovernanceValidator Fitness Suite

## Context
Guided reasoning session `002_minimal-ui-menus-and-editor-features` (`README.ai.md` `TASK-01`) ratified structural UI, persistence, and App Sandbox workspace handoff updates over `openspec/Constitution.md` (`v1.2.0`). Before `TASK-02` (`SwiftEditCore`) and `TASK-03` (`SwiftEditUI` & `XcodeApp`) implement code against these invariants, `openspec/Constitution.md` and its atomic micro-files (`UI-001`, `DATA-004`, `SEC-004`) must be promoted to `v1.3.0` (`MINOR` amendment per `SDD-005` and `SDD-006`) and protected by a fast, deterministic `SwiftEditCore` architecture fitness validator (`[AR-002]`, `[TEST-006]`, `[SDD-004..010]`).

## Goals / Non-Goals
- Goals:
  - Synchronize `openspec/Constitution.md` (`v1.2.0` -> `v1.3.0`), `03-ui-ux/index.md`, `04-data-persistence/index.md`, `07-security-privacy/index.md`, and Bare-Bones rules `UI-001`, `DATA-004`, and `SEC-004` (`[UI-001]`, `[DATA-004]`, `[SEC-004]`, `[SDD-004..006]`).
  - Provide a pure `Foundation`, `Sendable` `ConstitutionGovernanceValidator` in `Sources/SwiftEditCore/ArchitectureFitness/ConstitutionGovernanceValidator.swift` and `ConstitutionFitnessTests` in `Tests/SwiftEditTests/ConstitutionFitnessTests.swift` verifying line caps (`<= 45` / `<= 25` / `<= 40`), `SDD-007` active floors, and `v1.3.0` rule clauses (`[AR-002]`, `[AR-004]`, `[TEST-006]`).
- Non-Goals:
  - Implementing `LineEnding.cr`, `RecentFilesStore`, `ShallowFolderBatchLoader`, `DocumentSearchEngine`, or sidebar `FileSystemProviding` methods (`TASK-02` / `006`).
  - Implementing `SwiftEditLayout`, `LineNumberGutterView`, `@FocusedValue` menus, `CheatSheet`, or `MacOSWorkspaceAdapter` (`TASK-03` / `007`).

## Architecture Memory & Module Boundaries (AR-###)
- **AR-001**: Resides inside `Sources/SwiftEditCore/ArchitectureFitness/` alongside `ArchitectureImportScanner.swift` and is exercised by `Tests/SwiftEditTests/ConstitutionFitnessTests.swift` across `.macOS(.v26)` and `.iOS(.v26)` (`[AR-001]`, `[AR-002]`).
- **AR-002**: Imports exclusively `Foundation` (`Sendable` value types only, zero `AppKit`/`UIKit`/`SwiftUI`/`Network` imports, zero subprocesses) (`[AR-002]`, `[AR-004]`, `[SEC-004]`).
- **Single-Reference Lock**: Loaded `openspec/Constitution.md` alongside `01-architecture/module-topology.md`, `02-domain/bounded-context-ownership.md`, `03-ui-ux/design-system-and-tokens.md`, `04-data-persistence/storage-and-migrations.md`, `06-testing-fitness/architecture-fitness-and-quality.md`, `07-security-privacy/authn-authz-and-boundaries.md`, and `08-sdd-governance/amendment-and-sync-impact.md` (`[SDD-009]`).

## Bounded Context Classification & Exact `v1.3.0` Constitutional Clauses (`BC-002`, `SDD-004`)

- **Classification**: `ArchitectureFitness` — `Generic` Governance Support module inside `SwiftEditCore` (`[BC-002]`).
- **Normative `v1.3.0` Bare-Bones Rule Statements**:
  - **`UI-001` (`openspec/constitution/03-ui-ux/design-system-and-tokens.md`)**:
    `- **UI-001**: The SwiftEditUI workspace shell and Assets.xcassets catalog SHALL bundle the Concept E2 macOS and iOS AppIcon.appiconset catalogs with Purple (#0B0614, #7C3AED, #A78BFA, #C4B5FD) chrome across Light, Black, and Auto modes while defaulting the left sidebar to collapsed until Open Folder, placing EditorTabStrip strictly above the right editor column, rendering a left 1-based LineNumberGutterView, and showing Line, Column, Character count, UTF-8, and LF/CRLF/CR in the status bar.`
  - **`DATA-004` (`openspec/constitution/04-data-persistence/storage-and-migrations.md`)**:
    `- **DATA-004**: WHEN executing an explicit user Save command or recording recent files, the SwiftEditCore persistence layer SHALL preserve original character encoding, byte-order mark, and 3-way LF (\n), CRLF (\r\n), or Classic Mac CR (\r) line endings via atomic NSFileCoordinator sibling replacement without implicit autosave-in-place mutation while capping deduplicated security-scoped MRU bookmarks at 10 existing non-binary files.`
  - **`SEC-004` (`openspec/constitution/07-security-privacy/authn-authz-and-boundaries.md`)**:
    `- **SEC-004**: The application runtime on macOS and iOS SHALL execute 100% offline with zero socket connections and zero subprocesses while restricting external handoffs to user-confirmed https, http, or mailto URIs and symlink-confined NSWorkspace Finder reveals or verified directory-only Terminal launches (com.googlecode.iterm2, com.apple.Terminal).`

## Decisions
- **Decision 1 — Pure Value-Type `ConstitutionGovernanceValidator` in `SwiftEditCore` (`KISS-First`)**:
  - *Rationale*: Placing `ConstitutionGovernanceViolation` (`struct`, `Equatable`, `Sendable`), `ConstitutionValidationSummary` (`struct`, `Equatable`, `Sendable`), and `ConstitutionGovernanceValidator` (`enum`, `Sendable`) next to `ArchitectureImportScanner` avoids external scripts or `Process` spawning during `swift test --parallel`, keeping test execution sub-millisecond and deterministic (`[AR-002]`, `[AR-004]`, `[TEST-003]`, `[TEST-006]`).
- **Decision 2 — Dual Disk-Root and In-Memory String Entry Points**:
  - *Rationale*: Providing `validateConstitutionRoot(at openspecRoot: URL)` (with `resolvingSymlinksInPath()` confinement inside `openspec/` and a `1 MiB` read cap) alongside pure string entry points (`validateConstitutionManifest(content:miniIndexes:)` and `validateAmendedMicroFiles(uiDesignTokens:dataStorage:securityBoundaries:)`) allows `P1`/`P2` to verify the live repository files while `N1..N4` exercise failure and security abuse cases in parallel with zero disk mutation (`[SEC-003]`, `[TEST-002]`, `[TEST-003]`).
- **Decision 3 — Directory-Only Terminal Clause Enshrined in `SEC-004`**:
  - *Rationale*: Explicitly requiring `zero subprocesses`, `symlink-confined`, and `directory-only` `NSWorkspace` Terminal launches (`com.googlecode.iterm2`, `com.apple.Terminal`) in `SEC-004` prevents downstream specs or code from passing `.command`, `.sh`, or `.term` files to a terminal emulator (`CWE-78`, `[SEC-004]`).

## Risks / Trade-offs
- **Overly Brittle Exact-String Matching on Markdown Prose** -> Mitigated by asserting structural Bare-Bones rules (line caps `<= 45` / `<= 25` / `<= 40`, zero `>` blockquotes, YAML frontmatter keys, `Sync Impact Report` `1.3.0` row, `SDD-007` active area statuses) and targeted normative tokens (`LineNumberGutterView`, `EditorTabStrip`, `collapsed`, `Open Folder`, `CRLF`, `CR`, `10`, `100% offline`, `zero socket`, `zero subprocesses`, `symlink-confined`, `directory-only`, `com.googlecode.iterm2`, `com.apple.Terminal`, `Finder`) rather than fragile byte-for-byte file hashes.
- **Symlink Traversal in `validateConstitutionRoot(at:)`** -> Mitigated by resolving `openspecRoot` and each inspected Markdown file via `resolvingSymlinksInPath()` and rejecting paths escaping `openspecRoot` (`[SEC-003]`).

## Migration Plan
1. Execute Unit 1 (`ConstitutionVersionAndSyncImpactFitness`) `[RED] -> [GREEN] -> [REFACTOR] -> [DOC]` to update `openspec/Constitution.md` (`v1.3.0`), update `03-ui-ux/index.md`, `04-data-persistence/index.md`, and `07-security-privacy/index.md`, and implement `validateConstitutionRoot` / `validateConstitutionManifest` + `SDD-007` security floor checks.
2. Execute Unit 2 (`AmendedMicroFileInvariantsFitness`) `[RED] -> [GREEN] -> [REFACTOR] -> [DOC]` to update `UI-001`, `DATA-004`, and `SEC-004` micro-files and implement `validateAmendedMicroFiles` + `SEC-004` security guard checks.
3. Run `swift test --parallel` and verify zero Swift 6 compiler warnings and `>= 85%` `SwiftEditCore` line coverage (`[TEST-008]`).

## Security Review
- Reviewer: cyber-security-expert
- Date: 2026-11-18
- Verdict: approved
- Status: approved
- Open items: none
