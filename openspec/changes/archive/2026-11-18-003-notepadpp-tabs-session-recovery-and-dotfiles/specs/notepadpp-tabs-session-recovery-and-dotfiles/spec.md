# Spec Delta: Notepad++ Tabs, SessionRecovery GC, Dotfiles, and EditorPreferences

## Purpose
Implements the `WorkspaceAndTabSession` bounded context in `SwiftEditCore`: Notepad++ multi-tab management with tab pinning and binary exclusion (`WorkspaceTabSession`), crash-safe `SessionRecovery` manifest and draft persistence (`0700`/`0600` permissions, `isExcludedFromBackup`, `<= 64 MiB` quota, immediate close unlink, and startup orphan GC), shallow dotfile-inclusive folder navigation with balanced security-scoped resource lifecycle and symlink confinement (`DotfileFolderNavigator`), and schema-clamped `Light`/`Black`/`Auto` + `50%..300%` zoom preferences (`EditorPreferencesStore`).

## ADDED Requirements

### Requirement: REQ-001 Notepad++ Tab Ordering Pinning and Binary Tab Exclusion
WHEN managing open document tabs, the workspace tab session SHALL order pinned text tabs ahead of unpinned text tabs, preserve active tab selection and caret offsets, block unforced closure of pinned tabs, and reject binary read-only snapshots from persistent tabs and pinning [AR-004][BC-006][BC-008][BC-012][DATA-003][SEC-011][SEC-012].

#### Scenario: P1 Opening Activating Pinning and Reordering Text Tabs
- **Path**: P1
- **Trait**: positive
- **GIVEN** an empty `WorkspaceTabSession` and three text `DocumentSnapshot` instances (`docA`, `docB`, `docC`)
- **WHEN** `docA`, `docB`, and `docC` are opened, `docC` is pinned via `setPinned(true, for: docC.id)`, and `updateTabState` records a new `caretLocation` and `BufferRevision` on `docC`
- **THEN** `tabs` orders `docC` first (`[docC, docA, docB]`) with `isPinned == true`, `activeTabID` tracks the selected tab, and `docC` retains the updated `caretLocation` and `BufferRevision`

#### Scenario: N1 Closing Pinned Tab Without Force or Querying Unknown Tab Fails Closed
- **Path**: N1
- **Trait**: negative
- **GIVEN** a `WorkspaceTabSession` containing a pinned tab `docC` and an unpinned tab `docA`
- **WHEN** `closeTab(id: docC.id)` is invoked without unpinning or `activateTab(id:)` is called with an unknown `DocumentID`
- **THEN** the call throws `DomainError.pinnedTabCloseForbidden` or `DomainError.tabNotFound` and leaves `tabs` and `activeTabID` unchanged

#### Scenario: N2 Binary Read-Only Snapshot Rejected From Persistent Tabs and Pinning
- **Path**: N2
- **Trait**: security
- **GIVEN** a binary read-only `DocumentSnapshot` (`isBinaryReadOnly == true`)
- **WHEN** `WorkspaceTabSession.openOrActivate(snapshot:title:fileURL:)` is called with the binary snapshot
- **THEN** the call throws `DomainError.binaryFileSaveForbidden` and never records the binary document in `tabs`

### Requirement: REQ-002 Atomic SessionRecovery Persistence Immediate Close Unlink and Startup Orphan GC
WHEN persisting or restoring workspace recovery state, the session recovery store SHALL write `session-manifest.json` and dirty or unbacked text snapshots inside `SessionRecovery/` with `0700` directory and `0600` file permissions and backup exclusion, unlink snapshots immediately on tab close, and delete unreferenced orphan snapshot files at startup [BC-007][BC-008][DATA-001][DATA-005][DATA-006][SEC-007][SEC-011][TEST-005].

#### Scenario: P2 Saving Restoring Closing and Garbage Collecting SessionRecovery Snapshots
- **Path**: P2
- **Trait**: positive
- **GIVEN** an ephemeral `SessionRecovery/` directory, an active `WorkspaceTabSession` with a dirty text tab (`docA`), an unbacked `Untitled` tab (`docB`), and a stray orphan `<UUID>.recovery` file on disk
- **WHEN** `SessionRecoveryStore` saves the manifest and snapshots, runs `purgeOrphanedSnapshots`, and subsequently unlinks `docA` upon tab closure
- **THEN** `SessionRecovery/` enforces `0700` directory and `0600` file permissions with `isExcludedFromBackup == true`, startup GC deletes the stray orphan file while preserving `docA` and `docB`, and closing `docA` immediately removes `docA`'s `.recovery` file from disk

#### Scenario: N3 Corrupted Recovery Manifest Fails Closed
- **Path**: N3
- **Trait**: negative
- **GIVEN** a `SessionRecovery/` directory containing malformed JSON in `session-manifest.json`
- **WHEN** `SessionRecoveryStore.loadManifest()` is invoked
- **THEN** the call throws `DomainError.corruptedRecoveryManifest` without returning partial state

### Requirement: REQ-003 SessionRecovery 64 MiB Quota Binary Non-Retention and Symlink Guard
IF a recovery operation targets a binary read-only snapshot, exceeds the `64 MiB` aggregate `SessionRecovery/` quota, or encounters a symbolic link in the recovery directory, THEN the session recovery store SHALL abort the write and throw a typed `DomainError` [DATA-003][SEC-003][SEC-007][SEC-011][SEC-012].

#### Scenario: P2 Within-Quota Text Snapshot Persists Cleanly
- **Path**: P2
- **Trait**: positive
- **GIVEN** a non-binary dirty text `DocumentSnapshot` whose byte size keeps `SessionRecovery/` within `64 MiB`
- **WHEN** `SessionRecoveryStore.saveRecoverySnapshot(_:)` writes the snapshot
- **THEN** the `<UUID>.recovery` file is written atomically and can be round-trip restored

#### Scenario: N4 Binary Snapshot Quota Exhaustion or Symlinked Recovery Directory Rejection
- **Path**: N4
- **Trait**: security
- **GIVEN** a binary read-only `DocumentSnapshot`, a recovery payload exceeding the `64 MiB` (`67_108_864` bytes) `SessionRecovery/` quota, or a symlinked recovery file path
- **WHEN** `SessionRecoveryStore.saveRecoverySnapshot(_:)` is invoked
- **THEN** the store aborts before committing and throws `DomainError.binaryFileSaveForbidden`, `DomainError.sessionRecoveryQuotaExceeded`, or `DomainError.securityScopeViolation`

### Requirement: REQ-004 Shallow Dotfile Folder Navigation Security-Scope Lifecycle and Clamped Preferences
WHEN listing a workspace directory or updating editor preferences, the folder navigator and preferences store SHALL return shallow directory entries including hidden dotfiles sorted directories-first within symlink-verified scope using balanced security-scoped resource calls and persist `Light`, `Black`, or `Auto` appearance and `50%..300%` clamped zoom in isolated `UserDefaults` [BC-007][DATA-007][DATA-008][SEC-002][SEC-003][TEST-003][TEST-005].

#### Scenario: P3 Shallow Dotfile Enumeration and Schema-Clamped Preferences Round-Trip
- **Path**: P3
- **Trait**: positive
- **GIVEN** a workspace directory containing a subfolder `src`, a regular file `README.md`, and hidden dotfiles `.env` and `.gitignore`, plus an isolated `UserDefaults` suite
- **WHEN** `DotfileFolderNavigator.listEntries(in:withinScope:)` enumerates the folder and `EditorPreferencesStore` saves `AppearanceMode.black` at `150%` zoom
- **THEN** `listEntries` returns `[src, .env, .gitignore, README.md]` with `isHiddenDotfile == true` on `.env` and `.gitignore` and balanced `startAccessing`/`stopAccessing` counts (`1 == 1`), and `EditorPreferencesStore.load()` returns `.black` and `150`

#### Scenario: N5 Out-of-Bounds Zoom Values and Invalid Appearance Raw Strings Are Clamped
- **Path**: N5
- **Trait**: negative
- **GIVEN** an isolated `UserDefaults` suite seeded with zoom values `10` (`< 50`) or `900` (`> 300`) and an unknown appearance string
- **WHEN** `EditorPreferencesStore.load()` reads the preferences
- **THEN** `zoomPercent` is clamped to `50` and `300` respectively and `appearanceMode` defaults safely to `.auto`

#### Scenario: N6 Symlink Escaping Granted Workspace Scope Fails Closed With Guaranteed Scope Release
- **Path**: N6
- **Trait**: security
- **GIVEN** a workspace directory containing a symbolic link pointing outside the granted workspace scope
- **WHEN** `DotfileFolderNavigator.listEntries(in:withinScope:)` inspects the directory
- **THEN** the call throws `DomainError.securityScopeViolation` and still executes `stopAccessing` in `defer` (`startCount == stopCount`)

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
