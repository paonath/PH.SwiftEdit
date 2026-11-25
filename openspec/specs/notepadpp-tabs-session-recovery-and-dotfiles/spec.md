# Capability: notepadpp-tabs-session-recovery-and-dotfiles

## Purpose
Refines `SessionRecovery` persistence and startup restoration so empty or whitespace-only untitled documents are never persisted or reopened across app relaunches while preserving all non-empty untitled tabs, disk-backed/pinned tabs, permissions, and orphan garbage collection.

## Requirements

### Requirement: REQ-001 Notepad++ Tab Ordering Pinning and Binary Tab Exclusion
WHEN managing open document tabs, the workspace tab session SHALL order pinned text tabs ahead of unpinned text tabs, support reordering tabs left or right within their pinned or unpinned partition, preserve active tab selection and caret offsets, block unforced closure of pinned tabs, and reject binary read-only snapshots from persistent tabs and pinning [AR-004][BC-006][BC-008][BC-012][DATA-003][SEC-011][SEC-012].

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

#### Scenario: P4 Reordering Tabs Left and Right Within Pinned and Unpinned Partitions
- **Path**: P4
- **Trait**: positive
- **GIVEN** a `WorkspaceTabSession` holding pinned `[P1, P2]` and unpinned `[U1, U2, U3]`
- **WHEN** `moveTabLeft(id: U3)` and `moveTabRight(id: P1)` execute
- **THEN** `tabs` becomes `[P2, P1, U1, U3, U2]` preserving pinned-first ordering and `activeTabID`

#### Scenario: N7 Cross-Partition Tab Move Clamps Within Partition and Unknown Tab Throws
- **Path**: N7
- **Trait**: negative
- **GIVEN** a `WorkspaceTabSession` holding pinned `[P1]` and unpinned `[U1, U2]`
- **WHEN** `moveTabRight(id: P1)` runs and `moveTabLeft(id: unknownID)` runs
- **THEN** `P1` stays in the pinned partition and `unknownID` throws `DomainError.tabNotFound`

### Requirement: REQ-002 Atomic SessionRecovery Persistence Immediate Close Unlink and Startup Orphan GC
WHEN persisting or restoring recovery state, the session store and workbench SHALL exclude empty or whitespace-only untitled tabs (`fileURL == nil`), save `session-manifest.json` and non-empty untitled or dirty text snapshots inside `SessionRecovery/` with `0700`/`0600` permissions and backup exclusion, unlink snapshots on close or when cleared to empty, and purge orphans at startup [BC-007][BC-008][DATA-001][DATA-005][DATA-006][SEC-007][SEC-011][TEST-005].

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

#### Scenario: P7 Non-Empty Untitled and Disk-Backed Tabs Restore While Empty Untitled Tabs Are Skipped
- **Path**: P7
- **Trait**: positive
- **GIVEN** a workbench holding a non-empty untitled tab (`"Draft note"`), a pinned disk-backed tab (`notes.md`), and an empty untitled tab (`""`)
- **WHEN** `persistRecoveryState()` runs and a fresh workbench restores via `restoreSessionRecoveryIfPresent()`
- **THEN** only the non-empty untitled tab and the pinned disk-backed tab are persisted and restored, and the empty untitled tab is not reopened

#### Scenario: N10 Empty or Whitespace-Only Untitled Tabs and Legacy Empty Snapshots Are Excluded and Purged
- **Path**: N10
- **Trait**: security
- **GIVEN** a `SessionRecovery/` directory containing a legacy manifest referencing an untitled tab with `""` or `"  \n\t "` text, or a previously non-empty untitled tab whose text is cleared to whitespace-only
- **WHEN** `persistRecoveryState()` or `restoreSessionRecoveryIfPresent()` executes
- **THEN** the empty/whitespace-only untitled tab is excluded from the restored tab session, `activeTabID` falls back cleanly to a remaining valid tab or `nil`, and its `.recovery` snapshot file is unlinked and purged from disk

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
WHEN enumerating directories or persisting preferences, the dotfile folder navigator SHALL apply `EscapingSymlinkPolicy` (`.failClosed` default; `.skipAndReport` skipping escaping child symlinks prior to `8 KiB` probing while throwing if folder root escapes scope) with balanced `defer` release and `PreferencesProviding` injection [BC-007][DATA-003][DATA-007][DATA-008][SEC-002][SEC-003][TEST-003][TEST-005].

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

#### Scenario: P5 Shallow Listing Marks NUL-Bearing Binary Files While Keeping Directories and Text False
- **Path**: P5
- **Trait**: positive
- **GIVEN** a granted directory containing subfolder `src`, UTF-8 `README.md`, and binary `image.png` containing `0x00` within its first `8 KiB`
- **WHEN** `DotfileFolderNavigator.listEntries(in:withinScope:)` runs
- **THEN** `image.png` reports `isBinary == true`, `README.md` and `src` report `isBinary == false`, and `startCount == stopCount`

#### Scenario: N8 Escaping Symlink Target Is Rejected Prior to Binary Prefix Probing
- **Path**: N8
- **Trait**: security
- **GIVEN** a granted directory containing a symbolic link pointing to an external binary file outside the workspace scope
- **WHEN** `DotfileFolderNavigator.listEntries(in:withinScope:)` runs
- **THEN** the call aborts with `DomainError.securityScopeViolation` before probing bytes and releases scope in `defer`

#### Scenario: P6 Sidebar SkipAndReport Lists Valid Siblings and Exposes Escaping Symlink Count Without Reading Target
- **Path**: P6
- **Trait**: positive
- **GIVEN** a granted directory containing valid `"notes.md"` plus child symlink `"escape.lnk"` pointing to `"/etc/passwd"` and a spy `FileSystemProviding` tracking probed paths
- **WHEN** `DotfileFolderNavigator.listEntries(in:withinScope:escapingSymlinkPolicy: .skipAndReport)` runs
- **THEN** `"notes.md"` loads normally, `"escape.lnk"` is omitted with `skippedExternalSymlinkCount == 1`, zero bytes of `"/etc/passwd"` or `"escape.lnk"` are read (`8 KiB` probe never runs on it), and `startCount == stopCount`

#### Scenario: N9 Folder Root Escaping Scope Always Throws securityScopeViolation Under Any Policy
- **Path**: N9
- **Trait**: security
- **GIVEN** a folder URL that is itself a symlink resolving outside the granted workspace root and `escapingSymlinkPolicy == .skipAndReport`
- **WHEN** `DotfileFolderNavigator.listEntries` runs on that folder root
- **THEN** the navigator aborts immediately with `DomainError.securityScopeViolation` before inspecting children and executes `stopAccessing` in `defer` (`startCount == stopCount`)
