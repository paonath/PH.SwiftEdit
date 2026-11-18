# Design: Implement WorkspaceAndTabSession (Notepad++ Pin, SessionRecovery GC, Dotfiles & EditorPreferences)

## Context
Following the completion of `DocumentCore` (`001`), `MarkdownLintAndFormat` (`002`), and `SearchDiffAndBracketEngine` (`002`), `TASK-04` implements the fourth bounded context of `SwiftEditCore`: **`WorkspaceAndTabSession`** (`Supporting` subdomain). It provides the pure domain state and Anti-Corruption Layer (`ACL`) adapters for Notepad++ tab management and pinning, crash-safe `SessionRecovery/` persistence with immediate close-unlink and startup orphan garbage collection, shallow dotfile-inclusive folder navigation, and schema-clamped `EditorPreferences` (`[BC-001]`, `[BC-007]`, `[BC-008]`, `[DATA-005..008]`).

## Goals / Non-Goals
- Goals:
  - Keep `WorkspaceAndTabSession` 100% free of `AppKit`/`UIKit`/`SwiftUI` imports (`[AR-002]`, `[BC-002]`).
  - Enforce Notepad++ tab pinning invariants: pinned tabs are always ordered ahead of unpinned tabs, cannot be closed without explicit unpinning or force flag, and binary read-only buffers (`isBinaryReadOnly == true`) are rejected from tabs, pinning, and `SessionRecovery` (`[BC-008]`, `[DATA-003]`, `[SEC-011]`).
  - Enforce `SessionRecovery/` security and lifecycle invariants: `0700` directory permissions, `0600` file permissions, `FileProtectionType.complete` on iOS, `isExcludedFromBackup = true`, `<= 64 MiB` total quota, immediate unlink on tab close, and startup orphan GC (`[DATA-005]`, `[DATA-006]`, `[SEC-007]`, `[SEC-011]`).
  - Enforce shallow dotfile-inclusive folder navigation with balanced `startAccessingSecurityScopedResource()` / `defer { stopAccessingSecurityScopedResource() }` calls and `resolvingSymlinksInPath()` confinement (`[DATA-007]`, `[SEC-002]`, `[SEC-003]`), plus schema-clamped `EditorPreferences` (`Light`/`Black`/`Auto`, zoom `50%..300%`) (`[DATA-008]`).
- Non-Goals:
  - `SwiftEditUI` SwiftUI views, TextKit 2 editor canvas, and Xcode `.app` shell (`TASK-05`).
  - Recursive workspace indexing or SQLite/CoreData databases (`[BC-005]`, `[DATA-001]`).

## Architecture Memory & Module Boundaries (AR-###)
- **AR-002 & AR-004**: All `WorkspaceAndTabSession` types reside under `Sources/SwiftEditCore/WorkspaceAndTabSession/`, import only `Foundation`, and model tab descriptors, recovery manifests, folder entries, and preferences as `Sendable` value types.
- **AR-007**: `SecurityScopedResourceAccessing` and configurable `SessionRecoveryStore` directory URLs + isolated `UserDefaults(suiteName:)` instances provide deterministic test seams (`[TEST-003]`, `[TEST-004]`).
- **Single-Reference Lock**: Loaded `openspec/Constitution.md` alongside `01-architecture/module-topology.md`, `02-domain/bounded-context-ownership.md`, `02-domain/negative-ownership-and-refs.md`, `02-domain/ubiquitous-language-and-policy.md`, `04-data-persistence/storage-and-migrations.md`, `04-data-persistence/write-read-separation.md`, `06-testing-fitness/tdd-and-unit-testing.md`, `06-testing-fitness/architecture-fitness-and-quality.md`, `07-security-privacy/authn-authz-and-boundaries.md`, `07-security-privacy/secrets-and-supply-chain.md`, `07-security-privacy/stride-and-gdpr-privacy.md`, and `08-sdd-governance/artifact-traceability.md`.

## Bounded Context Classification & Ubiquitous Language Glossary (`BC-002`, `BC-009`)

| Bounded Context / Type | Classification / Kind | Normative Definition (`BC-009`) |
| :--- | :--- | :--- |
| `WorkspaceAndTabSession` | `Supporting` Subdomain | Context owning multi-tab ordering, Notepad++ tab pinning, `SessionRecovery` lifecycle, shallow dotfile navigation, and `EditorPreferences`. |
| `TabDescriptor` | Value Object (`struct`, `Codable`, `Sendable`) | Immutable tab state `(id: DocumentID, title: String, fileURL: URL?, isPinned: Bool, isDirty: Bool, caretLocation: Int, revision: BufferRevision)`. |
| `WorkspaceTabSession` | Aggregate / State Value (`struct`, `Sendable`) | Value-type tab bar state machine maintaining pinned-first ordering, `activeTabID`, pinned-close protection, and binary buffer exclusion (`[BC-008]`). |
| `SessionRecoveryManifest` | Value Object (`struct`, `Codable`, `Sendable`) | Serializable manifest (`session-manifest.json`) recording `tabs: [TabDescriptor]` and `activeTabID: DocumentID?` (`[DATA-005]`). |
| `RecoveredDocumentSnapshot` | Value Object (`struct`, `Codable`, `Sendable`) | Serializable `<UUID>.recovery` draft payload recording `id`, `revision`, `text`, `encoding`, and `lineEnding` for dirty or unbacked text tabs (`[DATA-005]`). |
| `SessionRecoveryStore` | ACL Persistence Adapter (`struct`, `Sendable`) | Manages `SessionRecovery/` with `0700`/`0600` permissions, backup exclusion, `64 MiB` quota, immediate close unlink, and startup orphan GC (`[DATA-005]`, `[DATA-006]`, `[SEC-007]`). |
| `SecurityScopedResourceAccessing` | Seam Protocol (`Sendable`) | Narrow port wrapping `startAccessing(url:)` and `stopAccessing(url:)` for deterministic lifecycle testing (`[DATA-007]`, `[SEC-002]`, `[TEST-004]`). |
| `FolderEntryDescriptor` | Value Object (`struct`, `Equatable`, `Sendable`) | Shallow folder node `(name: String, url: URL, isDirectory: Bool, isHiddenDotfile: Bool)` (`[BC-007]`, `[DATA-007]`). |
| `DotfileFolderNavigator` | ACL Filesystem Adapter (`struct`, `Sendable`) | Enumerates shallow folder entries including hidden dotfiles sorted directories-first within `resolvingSymlinksInPath()` scope (`[DATA-007]`, `[SEC-002]`, `[SEC-003]`). |
| `AppearanceMode` | Value Object (`enum`, `String`, `Codable`, `Sendable`) | Theme mode: `.light`, `.black`, `.auto` (`[DATA-008]`, `[UI-003]`). |
| `EditorPreferences` | Value Object (`struct`, `Codable`, `Equatable`, `Sendable`) | Schema-clamped preferences `(appearanceMode: AppearanceMode, zoomPercent: Int)` with `zoomPercent` clamped to `50...300` (`[DATA-008]`, `[UI-007]`). |
| `EditorPreferencesStore` | ACL Preferences Adapter (`struct`, `Sendable`) | Reads and writes `EditorPreferences` inside an isolated `UserDefaults` instance (`[DATA-008]`, `[TEST-003]`). |

## Decisions
- **Decision 1 — Pinned-First Partitioned `WorkspaceTabSession` (`KISS-First`)**:
  - *Rationale*: Maintaining `tabs` partitioned with all `isPinned == true` tabs ahead of `isPinned == false` tabs guarantees `O(N)` deterministic reordering on pin/unpin without complex tree structures. Closing a pinned tab requires unpinning first (throwing `DomainError.pinnedTabCloseForbidden` otherwise).
- **Decision 2 — UUID-Keyed `SessionRecoveryStore` with Synchronous Unlink & Startup GC**:
  - *Rationale*: Storing each dirty/unbacked text draft in `<DocumentID.uuidString>.recovery` alongside `session-manifest.json` allows O(1) synchronous unlink when a tab closes (`removeRecoverySnapshot(for:)`) and a simple set-difference pass (`purgeOrphanedSnapshots(keeping:)`) at startup (`[DATA-005]`, `[DATA-006]`, `[SEC-011]`).
- **Decision 3 — `SecurityScopedResourceAccessing` Seam & Dotfile Enumeration**:
  - *Rationale*: Passing `.skipsSubdirectoryDescendants` and `.skipsPackageDescendants` WITHOUT `.skipsHiddenFiles` to `FileManager.default.contentsOfDirectory(at:includingPropertiesForKeys:options:)` surfaces `.env`, `.gitignore`, and other dotfiles while checking every entry with `resolvingSymlinksInPath()` against the workspace root (`[DATA-007]`, `[SEC-002]`, `[SEC-003]`).

## Risks / Trade-offs
- **`URLResourceValues.isExcludedFromBackup` on Ephemeral Directories** -> Applied immediately on both the `SessionRecovery/` directory and each written file so Time Machine / iCloud never backs up unsaved recovery blobs (`[SEC-007]`).
- **Parallel Test Isolation** -> Every test uses a unique `.tmp/test-results/` directory and `UserDefaults(suiteName: "test-\(UUID().uuidString)")` (`[TEST-003]`).

## Migration Plan
1. Extend `DomainError` in `DocumentPrimitives.swift` and create `Sources/SwiftEditCore/WorkspaceAndTabSession/` in `1.0 [SETUP]`.
2. Execute TDD quads (`[RED] -> [GREEN] -> [REFACTOR] -> [DOC]`) across `WorkspaceTabBarState`, `SessionRecoveryStore`, and `DotfileNavigatorAndPreferences`.
3. Verify `swift test --parallel -Xswiftc -warnings-as-errors` passes with `>= 85%` `SwiftEditCore` line coverage.

## Security Review
- Reviewer: cyber-security-expert
- Date: 2026-11-18
- Verdict: approved
- Status: approved
- Open items: none
