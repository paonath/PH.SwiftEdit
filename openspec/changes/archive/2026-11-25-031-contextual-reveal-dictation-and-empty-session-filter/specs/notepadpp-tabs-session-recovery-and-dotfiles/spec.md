# Spec Delta: notepadpp-tabs-session-recovery-and-dotfiles

## Purpose
Refines `SessionRecovery` persistence and startup restoration so empty or whitespace-only untitled documents are never persisted or reopened across app relaunches while preserving all non-empty untitled tabs, disk-backed/pinned tabs, permissions, and orphan garbage collection.

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-002 Atomic SessionRecovery Persistence Immediate Close Unlink and Startup Orphan GC
Security-Waiver: Refines REQ-002 strictly to strengthen data minimization (`SEC-011`) by excluding empty/whitespace-only untitled tabs (`fileURL == nil`) from recovery persistence and startup restoration; preserves all `0700`/`0600` permissions, backup exclusion, immediate close unlink, and startup orphan GC guarantees.
WHEN persisting or restoring recovery state, the session store and workbench SHALL exclude empty or whitespace-only untitled tabs (`fileURL == nil`), save `session-manifest.json` and non-empty untitled or dirty text snapshots inside `SessionRecovery/` with `0700`/`0600` permissions and backup exclusion, unlink snapshots on close or when cleared to empty, and purge orphans at startup [BC-007][BC-008][DATA-001][DATA-005][DATA-006][SEC-007][SEC-011][TEST-005].

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

## REMOVED Requirements

## RENAMED Requirements
