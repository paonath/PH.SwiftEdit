# Capability: core-cr-lineending-mru-batch-search-and-sidebar-fs

## Purpose
Defines the `SwiftEditCore` engine contracts behind the minimal editor: status bar cursor metrics, a deduplicated ten-entry recent files list with balanced security-scoped bookmarks, shallow batch folder opening, literal find and replace with go-to-line, confined sidebar file operations, and open-tab reconciliation after rename or trash.

## Requirements

### Requirement: REQ-001 Cursor Metrics Status Bar Counters
WHEN computing status bar metrics for a caret location, the cursor metrics calculator SHALL return the 1-based line, the 1-based UTF-16 column, and the Unicode scalar count of the buffer while counting `\n`, `\r\n`, and `\r` each as one line break [BC-004][BC-006][BC-007][TEST-002].

#### Scenario: P2 Line Column and Character Count Across Mixed Line Breaks
- **Path**: P2
- **Trait**: positive
- **GIVEN** the buffer `"ab\ncd\r\nef\rg"` (`11` Unicode scalars)
- **WHEN** `CursorMetricsCalculator.metrics(in:caretLocation:)` runs with caret `8` and then caret `10`
- **THEN** caret `8` yields line `3`, column `2` and caret `10` yields line `4`, column `1`, both with `characterCount == 11`

#### Scenario: N2 Out-of-Range Caret Is Rejected
- **Path**: N2
- **Trait**: negative
- **GIVEN** an `11`-unit UTF-16 buffer
- **WHEN** `CursorMetricsCalculator.metrics(in:caretLocation:)` runs with caret `12` and with caret `-1`
- **THEN** both calls throw `DomainError.invalidTextRange` and return no metrics

### Requirement: REQ-002 Deduplicated Ten-Entry Recent Files List
WHEN a non-binary text file is opened, the recent files store SHALL deduplicate entries by standardized path, move the reopened entry to index 0 with a refreshed last-opened timestamp, and retain at most `10` entries [BC-007][BC-008][DATA-008][SEC-011][TEST-003].

#### Scenario: P3 Reopen Moves Entry to Top and Eleventh File Evicts the Oldest
- **Path**: P3
- **Trait**: positive
- **GIVEN** a recent files store holding `10` existing text files including `"notes.md"` at index `4` and an injected clock advanced by one minute
- **WHEN** `"notes.md"` is recorded again and then a new eleventh file is recorded
- **THEN** `"notes.md"` moved to index `0` with the newer timestamp without duplication, and after the eleventh file the list holds `10` entries with the previously oldest entry evicted

#### Scenario: N3 Binary and Deleted Files Are Excluded
- **Path**: N3
- **Trait**: negative
- **GIVEN** a file with a `0x00` byte in its first `8 KiB` and a recent entry whose file was deleted from disk
- **WHEN** the binary file is recorded and the entries are listed
- **THEN** recording throws `DomainError.binaryFileSaveForbidden` without persisting a bookmark and the deleted file is absent from the listed entries

### Requirement: REQ-003 Balanced Security-Scoped Access for Recent File Bookmarks
WHEN resolving a recent file bookmark, the recent files store SHALL pair every successful `startAccessing` call with a `stopAccessing` call on all normal and throwing exits [DATA-007][SEC-002][SEC-012][TEST-004].

#### Scenario: P4 Resolved Bookmark Releases Scope Exactly Once
- **Path**: P4
- **Trait**: positive
- **GIVEN** a recent entry created through a fake bookmark coder and a counting `SecurityScopedResourceAccessing` fake
- **WHEN** `RecentFilesStore.resolve(entry:)` resolves the entry
- **THEN** the resolved URL equals the recorded standardized path and the start and stop counts are both `1`

#### Scenario: N4 Stale Bookmark Fails Closed with Balanced Release
- **Path**: N4
- **Trait**: security
- **GIVEN** a recent entry whose bookmark data the fake coder cannot resolve, or resolves to a different path than recorded
- **WHEN** `RecentFilesStore.resolve(entry:)` runs
- **THEN** the call throws a typed `DomainError`, the entry is pruned from the list, and the start and stop counts remain equal

### Requirement: REQ-004 Recent Files Clear and Fail-Closed Persistence
WHEN the user clears recent documents or the persisted list is unreadable, the recent files store SHALL erase every persisted bookmark blob and return an empty list [BC-007][SEC-011][SEC-012][DATA-008].

#### Scenario: P5 Clear Removes All Persisted Bookmark Data
- **Path**: P5
- **Trait**: positive
- **GIVEN** an isolated `UserDefaults` suite holding `3` recent entries with bookmark blobs
- **WHEN** `RecentFilesStore.clear()` runs
- **THEN** `entries()` returns an empty list and the `UserDefaults` key holding the list is absent

#### Scenario: N5 Corrupted or Oversized Persisted List Fails Closed
- **Path**: N5
- **Trait**: security
- **GIVEN** an isolated `UserDefaults` suite whose recents value is malformed JSON or exceeds `1 MiB`
- **WHEN** `RecentFilesStore.entries()` loads it
- **THEN** the result is an empty list, the stored value is removed, and no archive deserialization API is invoked

### Requirement: REQ-005 Shallow Folder Batch Selection
WHEN opening all files in a folder, the shallow folder batch loader SHALL select only first-level regular non-binary files of at most `64 MiB` each and require user confirmation when more than `50` files are eligible [BC-007][BC-012][DATA-002][DATA-003][SEC-003].

#### Scenario: P6 Fifty-Two Text Files Require Confirmation While Binary Files and Subfolders Are Skipped
- **Path**: P6
- **Trait**: positive
- **GIVEN** a granted folder with `52` text files, `3` binary files containing `0x00`, and `2` subfolders
- **WHEN** `ShallowFolderBatchLoader.plan(folder:withinScope:)` runs
- **THEN** the plan lists exactly the `52` text files, reports `3` skipped binary files and `2` skipped folders, and sets `requiresConfirmation` to `true`

#### Scenario: N6 Folder Without Eligible Files Yields an Empty Plan
- **Path**: N6
- **Trait**: negative
- **GIVEN** a granted folder holding only binary files and subfolders
- **WHEN** `ShallowFolderBatchLoader.plan(folder:withinScope:)` runs
- **THEN** the plan lists zero files, `requiresConfirmation` is `false`, and no error is thrown

### Requirement: REQ-006 Batch Open Confinement and Cumulative Ceiling
IF a first-level folder entry resolves outside the granted scope through `resolvingSymlinksInPath()` or the cumulative size of eligible files exceeds `256 MiB`, THEN the shallow folder batch loader SHALL abort with a typed `DomainError` before opening any file [BC-011][DATA-002][SEC-002][SEC-003][SEC-012].

#### Scenario: P7 Batch Exactly at the Ceiling Is Accepted
- **Path**: P7
- **Trait**: positive
- **GIVEN** a loader configured with a `1 KiB` test ceiling and eligible files whose sizes total exactly `1 KiB`
- **WHEN** `ShallowFolderBatchLoader.plan(folder:withinScope:)` runs
- **THEN** the plan succeeds with the files listed and a balanced security-scoped access count

#### Scenario: N7 Escaping Symlink or Oversized Batch Aborts Before Any File Opens
- **Path**: N7
- **Trait**: security
- **GIVEN** one folder containing a symlink that resolves outside the granted scope and another whose eligible files exceed the configured ceiling by one byte
- **WHEN** `ShallowFolderBatchLoader.plan(folder:withinScope:)` runs on each
- **THEN** the first throws `DomainError.securityScopeViolation`, the second throws `DomainError.batchLimitExceeded`, and neither returns a plan

### Requirement: REQ-007 Literal Find Replace-All and Go-to-Line
WHEN a find, replace-all, or go-to-line command targets a text snapshot, the document search engine SHALL return literal case-aware UTF-16 match ranges, a non-overlapping `TextEdit` batch, or the 1-based line range without mutating the snapshot [AR-004][BC-004][BC-006][BC-011].

#### Scenario: P8 Find Replace-All and Go-to-Line on a Mixed Line-Break Snapshot
- **Path**: P8
- **Trait**: positive
- **GIVEN** a snapshot with text `"Alpha beta\nalpha BETA\r\ngamma"`
- **WHEN** the engine finds `"alpha"` case-insensitively and case-sensitively, builds a replace-all batch for `"omega"`, and resolves line `3`
- **THEN** the matches are `(0,5)` and `(11,5)` insensitively and `(11,5)` sensitively, the batch holds two edits that `DocumentSession.applyTextEdits` applies in one revision, and line `3` resolves to `TextRange(location: 23, length: 5)`

#### Scenario: N8 Empty Query and Out-of-Range Line Are Inert
- **Path**: N8
- **Trait**: negative
- **GIVEN** a three-line snapshot
- **WHEN** the engine finds an empty query and resolves lines `0` and `4`
- **THEN** find and replace-all return no ranges or edits and both line requests return `nil`

#### Scenario: N9 Oversized Query Match Flood Binary or Degraded Snapshot Degrades
- **Path**: N9
- **Trait**: security
- **GIVEN** a query of `1025` UTF-16 units, a snapshot producing more than `100000` matches, and a binary snapshot
- **WHEN** the engine runs find on each
- **THEN** each call returns `EngineEvaluationOutcome.degradedOrTimedOut` with `inputTooLarge`, `matchLimitExceeded`, and `binarySnapshot` reasons and produces no ranges

### Requirement: REQ-008 Confined Single-Segment Create and Rename
WHEN creating or renaming a sidebar file or folder, the workspace file operator SHALL accept only a single-segment name and mutate only paths inside the symlink-verified granted scope [BC-007][BC-012][SEC-002][SEC-003][SEC-012].

#### Scenario: P9 Create Folder Create File and Rename Inside Scope
- **Path**: P9
- **Trait**: positive
- **GIVEN** a granted workspace folder on disk
- **WHEN** the operator creates folder `"docs"`, creates file `"notes.md"`, and renames `"notes.md"` to `"final.md"`
- **THEN** `"docs"` and `"final.md"` exist inside the workspace, `"notes.md"` no longer exists, and each call returns the new standardized URL

#### Scenario: N10 Invalid Names and Existing Targets Are Rejected
- **Path**: N10
- **Trait**: negative
- **GIVEN** the names `""`, `"."`, `".."`, `"a/b"`, `"a:b"`, a name with a NUL byte, a name with `U+202E`, and a name of `256` UTF-8 bytes, plus an already existing `"final.md"`
- **WHEN** create or rename uses each name
- **THEN** each invalid name throws `DomainError.invalidItemName`, the existing target throws `DomainError.destinationAlreadyExists`, and the disk is unchanged

#### Scenario: N11 Escaping Parent and Scope Root Mutation Are Blocked
- **Path**: N11
- **Trait**: security
- **GIVEN** a workspace folder containing a symlinked subfolder that resolves outside the scope
- **WHEN** the operator creates a file in that symlinked parent and renames the scope root itself
- **THEN** both calls throw `DomainError.securityScopeViolation` and nothing is created, renamed, or written

### Requirement: REQ-009 Non-Overwriting Paste
WHEN pasting a sidebar item, the workspace file operator SHALL move a cut item without overwriting and copy a copied item under the first free `name copy`, `name copy 2`, or next free ordinal suffix [BC-012][DATA-004][SEC-003][SEC-012].

#### Scenario: P10 Copy Suffixes and Cut Move Inside Scope
- **Path**: P10
- **Trait**: positive
- **GIVEN** a workspace containing `"final.md"` and a subfolder `"docs"`
- **WHEN** `"final.md"` is copied twice into the same folder and the first copy is cut into `"docs"`
- **THEN** the copies are named `"final copy.md"` and `"final copy 2.md"`, the original is untouched, and the cut item now exists only under `"docs"`

#### Scenario: N12 Self-Descendant Paste and Cut Collision Are Rejected
- **Path**: N12
- **Trait**: negative
- **GIVEN** a folder `"src"` containing `"nested"` and a cut item whose name already exists in the destination
- **WHEN** `"src"` is pasted into `"src/nested"` and the cut item is pasted into the colliding destination
- **THEN** the first throws `DomainError.invalidPasteTarget`, the second throws `DomainError.destinationAlreadyExists`, and no file is overwritten or moved

#### Scenario: N13 Hostile Copy Source or Out-of-Scope Destination Is Refused Without Partial Copy
- **Path**: N13
- **Trait**: security
- **GIVEN** a source folder containing a symlink, another exceeding a configured copy cap by one item, and a destination that resolves outside the scope
- **WHEN** each paste is attempted
- **THEN** the symlink source and out-of-scope destination throw `DomainError.securityScopeViolation`, the oversized source throws `DomainError.batchLimitExceeded`, and no partial copy remains

### Requirement: REQ-010 Trash Instead of Permanent Delete
WHEN deleting a sidebar item, the workspace file operator SHALL hand the item to the system Trash seam instead of permanently removing it [BC-012][SEC-003][SEC-012].

#### Scenario: P11 Deleted Item Goes Through the Trash Seam
- **Path**: P11
- **Trait**: positive
- **GIVEN** a workspace file `"draft.md"` and a recording `ItemTrashing` fake
- **WHEN** `trashItem(at:withinScope:)` runs
- **THEN** the seam receives exactly the standardized URL of `"draft.md"` once and the file is gone from the workspace folder

#### Scenario: N14 Scope Root and Escaping Targets Are Never Trashed
- **Path**: N14
- **Trait**: security
- **GIVEN** the workspace scope root and a symlink inside the workspace that resolves outside it
- **WHEN** `trashItem(at:withinScope:)` runs on each
- **THEN** both calls throw `DomainError.securityScopeViolation` and the seam is never invoked

### Requirement: REQ-011 Open Tab Reconciliation After Rename or Trash
WHEN a sidebar rename or trash changes a path backing an open tab, the workspace tab session SHALL update renamed tabs in place, close clean trashed tabs, and detach dirty trashed tabs without closing them [BC-006][BC-008][DATA-006][TEST-002].

#### Scenario: P12 Rename Updates Tabs and Trash Closes Clean Tabs
- **Path**: P12
- **Trait**: positive
- **GIVEN** open tabs for `"/w/draft.md"`, `"/w/src/a.md"`, and `"/w/old.md"` with no unsaved edits
- **WHEN** `applyRename` renames `"/w/draft.md"` to `"/w/final.md"` and folder `"/w/src"` to `"/w/lib"`, and `applyTrash` trashes `"/w/old.md"`
- **THEN** the first tab shows title `"final.md"` at `"/w/final.md"`, the second points to `"/w/lib/a.md"`, both keep their `DocumentID`, and the third tab is closed

#### Scenario: N15 Dirty Trashed Tab Is Detached and Prefix-Sibling Paths Are Untouched
- **Path**: N15
- **Trait**: negative
- **GIVEN** a dirty tab for `"/w/draft.md"` and a tab for `"/w/draft.md.bak"`
- **WHEN** `applyTrash(of: "/w/draft.md")` runs
- **THEN** the dirty tab remains open with `fileURL == nil` and `isDirty == true`, and the `"/w/draft.md.bak"` tab is unchanged
