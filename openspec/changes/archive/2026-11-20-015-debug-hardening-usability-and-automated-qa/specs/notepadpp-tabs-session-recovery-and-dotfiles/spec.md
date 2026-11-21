# Spec Delta: notepadpp-tabs-session-recovery-and-dotfiles

## Purpose
Adds `EscapingSymlinkPolicy` (`.failClosed` default preserving strict folder errors; `.skipAndReport` for sidebar browsing so escaping child symlinks are skipped cleanly prior to `8 KiB` probing and surfaced in a non-destructive UI warning banner) (`BUG-017`) and injects `PreferencesProviding` for stall-free persistence (`PERF-003`, `TEST-001`).

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-004 Shallow Dotfile Folder Navigation Security-Scope Lifecycle and Clamped Preferences
WHEN enumerating directories or persisting preferences, the dotfile folder navigator SHALL apply `EscapingSymlinkPolicy` (`.failClosed` default; `.skipAndReport` skipping escaping child symlinks prior to `8 KiB` probing while throwing if folder root escapes scope) with balanced `defer` release and `PreferencesProviding` injection [BC-007][DATA-003][DATA-007][DATA-008][SEC-002][SEC-003][TEST-003][TEST-005].

Security-Waiver: extends `DotfileFolderNavigator.listEntries` (`BUG-017`) strictly additively: default `policy: .failClosed` retains `N6` and `N8` byte-for-byte, while explicit `.skipAndReport` still checks `resolvingSymlinksInPath()` BEFORE opening or `8 KiB`-probing any file so external symlink targets remain unreadable.

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

## REMOVED Requirements

## RENAMED Requirements
