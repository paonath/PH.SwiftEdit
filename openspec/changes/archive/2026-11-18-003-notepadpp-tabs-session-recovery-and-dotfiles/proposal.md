# Proposal: Implement WorkspaceAndTabSession (Notepad++ Pin, SessionRecovery GC, Dotfiles & EditorPreferences)

## Why
With `DocumentCore` (`001`), `MarkdownLintAndFormat` (`002`), and `SearchDiffAndBracketEngine` (`002`) implemented and archived, `PH.SwiftEdit` requires the fourth and final `SwiftEditCore` bounded context defined in `TASK-04` (`reasoning/001_project-constitution/README.ai.md`): **`WorkspaceAndTabSession`** (`Supporting` subdomain). This change delivers Notepad++ multi-tab management with tab pinning (`WorkspaceTabSession`), crash-safe `SessionRecovery/` autosave with immediate close-unlink and startup orphan garbage collection (`SessionRecoveryStore`), shallow dotfile-inclusive folder navigation with balanced security-scoped resource access and symlink confinement (`DotfileFolderNavigator`), and schema-clamped `Light`/`Black`/`Auto` + `50%..300%` zoom persistence (`EditorPreferencesStore`).

## What Changes
- Extend `DomainError` in `Sources/SwiftEditCore/DocumentCore/DocumentPrimitives.swift` with typed workspace/recovery errors:
  - `case tabNotFound(DocumentID)`
  - `case pinnedTabCloseForbidden(DocumentID)`
  - `case sessionRecoveryQuotaExceeded(byteCount: UInt64)`
  - `case corruptedRecoveryManifest`
- Implement `Sources/SwiftEditCore/WorkspaceAndTabSession/WorkspaceTabSession.swift`:
  - `TabDescriptor` (`id: DocumentID`, `title: String`, `fileURL: URL?`, `isPinned: Bool`, `isDirty: Bool`, `caretLocation: Int`, `revision: BufferRevision`) and `WorkspaceTabSession` value-type state machine managing tab opening, activation, pinning/unpinning (keeping pinned tabs ordered ahead of unpinned tabs), caret/revision synchronization, and fail-closed rejection of binary read-only buffers (`isBinaryReadOnly == true`) (`[AR-004]`, `[BC-006]`, `[BC-008]`, `[DATA-003]`).
- Implement `Sources/SwiftEditCore/WorkspaceAndTabSession/SessionRecoveryStore.swift`:
  - `SessionRecoveryManifest` (`session-manifest.json`) and `<UUID>.recovery` text draft persistence inside `SessionRecovery/` with `0700` directory and `0600` file permissions, iOS `FileProtectionType.complete`, `isExcludedFromBackup = true`, `<= 64 MiB` total recovery quota (`DomainError.sessionRecoveryQuotaExceeded`), synchronous draft file unlink on tab close, and deterministic startup orphan garbage collection (`[DATA-001]`, `[DATA-005]`, `[DATA-006]`, `[SEC-007]`, `[SEC-011]`, `[SEC-012]`).
- Implement `Sources/SwiftEditCore/WorkspaceAndTabSession/DotfileFolderNavigator.swift` and `EditorPreferencesStore.swift`:
  - `SecurityScopedResourceAccessing` seam (`startAccessing(url:)` / `stopAccessing(url:)`), `FolderEntryDescriptor` (`name`, `url`, `isDirectory`, `isHiddenDotfile`), and `DotfileFolderNavigator` listing shallow directory contents including hidden dotfiles (`.env`, `.gitignore`, excluding `.` and `..`) sorted directories-first while enforcing `resolvingSymlinksInPath()` confinement (`DomainError.securityScopeViolation`) (`[BC-007]`, `[DATA-007]`, `[SEC-002]`, `[SEC-003]`).
  - `AppearanceMode` (`.light`, `.black`, `.auto`), `EditorPreferences` (`appearanceMode`, `zoomPercent` clamped to `50...300`), and `EditorPreferencesStore` backed by an isolated `UserDefaults` suite (`[BC-007]`, `[DATA-008]`, `[TEST-003]`).

## Capabilities
- New Capabilities: `notepadpp-tabs-session-recovery-and-dotfiles`
- Modified Capabilities: None

## Domain Carrier & Decision Ownership (BC-###)
- **BC-001**: `WorkspaceAndTabSession` (`Supporting` subdomain) owns multi-tab ordering, Notepad++ tab pinning, `SessionRecovery` manifest/draft lifecycle, shallow dotfile-inclusive folder listing, and `EditorPreferences` serialization (`[BC-002]`, `[BC-006]`, `[BC-007]`, `[BC-008]`).
- **Owned Decisions**: Pinned-first tab ordering, pinned tab close protection, `SessionRecovery` draft creation/unlink/startup orphan GC, `64 MiB` recovery quota enforcement, shallow dotfile directory enumeration, and `50%..300%` zoom clamping (`[DATA-005]`, `[DATA-006]`, `[DATA-007]`, `[DATA-008]`).
- **Forbidden Responsibilities**: `WorkspaceAndTabSession` MUST NEVER mutate `DocumentSession` text buffers directly (`[BC-003]`), persist or pin binary read-only buffers (`[BC-008]`, `[DATA-003]`, `[SEC-011]`), perform recursive workspace indexing or SQLite/CoreData storage (`[BC-005]`, `[DATA-001]`), or import `AppKit`/`UIKit`/`SwiftUI` (`[AR-002]`).
- **External Decision References**: References open documents exclusively via immutable `DocumentID` and `BufferRevision` values (`[BC-006]`).

## Impact
- **Source Modules**: Adds `Sources/SwiftEditCore/WorkspaceAndTabSession/**` (`WorkspaceTabSession.swift`, `SessionRecoveryStore.swift`, `DotfileFolderNavigator.swift`, `EditorPreferencesStore.swift`) and extends `DomainError` in `Sources/SwiftEditCore/DocumentCore/DocumentPrimitives.swift`.
- **Test Suites**: Adds `WorkspaceTabSessionTests.swift`, `SessionRecoveryStoreTests.swift`, and `DotfileNavigatorAndPreferencesTests.swift` under `Tests/SwiftEditTests/`.

## Security Impact
- Enforces GDPR Art. 5(1)(c) & Art. 25 storage minimization (`[SEC-011]`): synchronous unlink of `<UUID>.recovery` draft files on tab close, startup orphan garbage collection, and strict exclusion of binary files from tabs, pinning, and `SessionRecovery`.
- Protects `SessionRecovery/` at rest (`[SEC-007]`, `CWE-312`, `CWE-400`): `0700` directory / `0600` file permissions, `isExcludedFromBackup = true`, `<= 64 MiB` total quota, and symlink rejection.
- Enforces balanced `startAccessingSecurityScopedResource()` / `defer { stopAccessingSecurityScopedResource() }` lifecycle and `resolvingSymlinksInPath()` confinement (`DomainError.securityScopeViolation`, `CWE-22`) during dotfile folder navigation (`[DATA-007]`, `[SEC-002]`, `[SEC-003]`).

## Metadata
- Owner: PH.SwiftEdit Team
- Domain: Swift 6 Workspace Tabs, SessionRecovery & Dotfile Navigator
- Reviewer: swift-macos-expert, ddd-expert, cyber-security-expert
- Branch: feature/FirstStub
- Manual-Steps: none
- Modifies-Specs: none
- Constitutional-Rules: [AR-002, AR-004, AR-007, AR-008, BC-001, BC-002, BC-006, BC-007, BC-008, BC-009, BC-012, DATA-001, DATA-003, DATA-005, DATA-006, DATA-007, DATA-008, TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, TEST-008, SEC-002, SEC-003, SEC-006, SEC-007, SEC-009, SEC-010, SEC-011, SEC-012, SDD-001, SDD-002, SDD-003]
- Amends-Constitution: none

## Prerequisites
- Completed `001-swifteditcore-document-and-binary-guard` (`TASK-02`), `002-markdown-lint-format-bracket-and-diff` (`TASK-03`), and ratified `openspec/Constitution.md` (`v1.2.0`).
