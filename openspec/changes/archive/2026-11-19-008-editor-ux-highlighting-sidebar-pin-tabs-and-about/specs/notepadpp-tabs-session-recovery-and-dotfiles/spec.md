# Spec Delta: Tab Left-Right Reordering and Binary Entry Flag in WorkspaceAndTabSession

## Purpose
Extends `REQ-001` and `REQ-004` of `notepadpp-tabs-session-recovery-and-dotfiles` additively to support within-partition left/right tab reordering in `WorkspaceTabSession` and confined `8 KiB` binary classification (`isBinary`) in `DotfileFolderNavigator`.

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-001 Notepad++ Tab Ordering Pinning and Binary Tab Exclusion
WHEN managing open document tabs, the workspace tab session SHALL order pinned text tabs ahead of unpinned text tabs, support reordering tabs left or right within their pinned or unpinned partition, preserve active tab selection and caret offsets, block unforced closure of pinned tabs, and reject binary read-only snapshots from persistent tabs and pinning [AR-004][BC-006][BC-008][BC-012][DATA-003][SEC-011][SEC-012].

Security-Waiver: additive modification only; existing scenarios P1, N1, and N2 and all pinned-first and binary-exclusion invariants remain strictly enforced while adding within-partition moveTabLeft, moveTabRight, and moveTab operations.

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

### Requirement: REQ-004 Shallow Dotfile Folder Navigation Security-Scope Lifecycle and Clamped Preferences
WHEN listing a workspace directory or updating editor preferences, the folder navigator and preferences store SHALL return shallow directory entries including hidden dotfiles and `8 KiB`-probed `isBinary` flags sorted directories-first within symlink-verified scope using balanced security-scoped resource calls and persist `Light`, `Black`, or `Auto` appearance and `50%..300%` clamped zoom in isolated `UserDefaults` [BC-007][DATA-003][DATA-007][DATA-008][SEC-002][SEC-003][TEST-003][TEST-005].

Security-Waiver: additive modification only; existing scenarios P3, N5, and N6 and all SEC-002/SEC-003 symlink-confinement and balanced security-scope lifecycle invariants remain intact while adding bounded 8 KiB binary detection strictly after confinement verification.

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

## REMOVED Requirements

## RENAMED Requirements
