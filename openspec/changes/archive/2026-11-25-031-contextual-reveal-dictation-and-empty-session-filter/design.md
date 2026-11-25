# Design: Contextual Reveal in Folder Navigator, Start Dictation Here & Empty Untitled Session Filter

## Context
- **Codebase**: `PH.SwiftEdit` (Swift 6.4+, `.macOS(.v26)` / `.iOS(.v26)` SwiftPM package: pure-Foundation `SwiftEditCore` + AppKit/SwiftUI `SwiftEditUI`).
- **TokenSave Structural Baseline (`Sources/`)**:
  - `Acyclicity`: `0` circular file dependencies (`tokensave_circular(path="Sources")`).
  - `God-Class Ceiling`: `SwiftEditWorkbenchModel` has `20` nominal members (`<= 25`), `WorkbenchRenderCaches` has `24` (`<= 25`), `ElementContextualMenuState` has `15` (`<= 25`).
  - `Complexity Ceiling`: highest cognitive complexity in `Sources/SwiftEditUI/Workbench` is `10 <= 15` (`formatActiveDocument`).
- **Current Gaps**:
  1. `ElementContextualActionCatalog` (`Document` group) currently contains only `.duplicateDocument`; users have no contextual way to reveal an open disk-backed file in the left Folder Navigator or start native macOS Dictation at the editor caret.
  2. `SwiftEditNSTextView.menu(for:)` only injects `Send to Terminal` when a selection is active.
  3. `persistRecoveryState()` saves every untitled tab (`session.fileURL == nil`) even when empty/whitespace-only, and `restoreSessionRecoveryIfPresent()` reopens them on relaunch.

## Goals / Non-Goals
- Goals:
  - Expose `Reveal in Folder Navigator` conditionally in both the `Cmd+Return` `Document` group and editor right-click `NSMenu` only when `fileURL != nil` and (`isLeftSidebarCollapsed || selectedFolderURL == nil || canonical(selectedFolderURL) != canonical(fileURL.deletingLastPathComponent())`).
  - Expose `Start Dictation Here` in both the `Cmd+Return` `Document` group (with in-code `AppIcon.microphone`) and editor right-click `NSMenu` for writable documents, dispatching macOS's standard `startDictation:` action via an injectable seam.
  - Exclude empty/whitespace-only untitled tabs from `SessionRecovery` persistence and restoration (both write and read sides) while unlinking/purging stale `.recovery` snapshots.
  - Keep `0` cycles, all nominal types `<= 25` members, and all new functions `cognitive_complexity <= 15` (KISS-First + SOLID).
- Non-Goals:
  - No custom `SFSpeechRecognizer` / `AVAudioEngine` pipeline or microphone entitlement changes (`SEC-001`, `SEC-004`).
  - No recursive tree expansion in the shallow Folder Navigator (`DATA-007`).
  - No filtering of disk-backed empty files (`fileURL != nil`, e.g. pinned empty `notes.md`).

## Constitutional Alignment & Module Boundaries (AR-### / UI-### / DATA-### / API-###)
- **AR-001**: `SwiftEditCore` stays pure `Foundation` + `swift-markdown` (holds `ElementContextualActionKind`, `ElementContextualActionCatalog`, and `SessionRecoveryEligibility`); `SwiftEditUI` isolates AppKit `NSMenu` and `startDictation:` under `#if os(macOS)`.
- **Single-Reference Lock**: Loaded `openspec/constitution/03-ui-ux/accessibility-and-cwv.md` (`UI-009..UI-012`) and `openspec/constitution/04-data-persistence/write-read-separation.md` (`DATA-005..DATA-008`).

## Decisions
- **Conditional `ElementContextualActionCatalog` Filtering (KISS-First)**:
  - Add `.revealInFolderNavigator` and `.startDictationHere` cases to `ElementContextualActionKind`.
  - Add `ElementContextualActionCatalog.groups(hasSelection:canRevealInFolderNavigator:canStartDictation:)` (keeping `groups(hasSelection:)` forwarding with defaults `false, false` or `false, true`? Keep `groups(hasSelection: Bool)` defaulting `canRevealInFolderNavigator: false, canStartDictation: false` so every existing unit test asserting exact row counts in `Integrations020Tests` stays 100% deterministic, while `SwiftEditWorkbenchModel.presentElementContextualMenu()` passes the live `canRevealActiveDocumentInFolderNavigator` and `canStartDictationHere` flags!).
  - Rationale: Zero breaking changes to existing contextual menu tests, pure value-type filtering in `SwiftEditCore`, no UI branching inside `ElementContextualMenuView`.
- **Canonical Parent Comparison & Scope Preservation for `Reveal in Folder Navigator`**:
  - Compute canonical directory URLs via `url.resolvingSymlinksInPath().standardizedFileURL`.
  - When revealing `fileURL`: verify parent directory exists and is a readable directory (`deps.parentPermissionChecker(parentURL)` + existence check); if missing/unreadable, set a non-destructive `statusBannerMessage` and return `false` without mutating sidebar state.
  - If `grantedScopeRootURL` is non-nil and `canonicalParent.path` is equal to or nested inside `canonicalScope.path` (with `/` boundary check), preserve `grantedScopeRootURL` so `...` parent navigation continues to work up to the workspace root; otherwise set `grantedScopeRootURL = canonicalParent`. Set `selectedFolderURL = canonicalParent`, `isLeftSidebarCollapsed = false`, call `refreshFolderEntries()`, and set `selectedSidebarEntryURL = fileURL.standardizedFileURL`.
- **Native macOS Dictation Dispatch Seam (`startDictation:`)**:
  - Inject `dictationTrigger: @MainActor (SwiftEditNSTextView) -> Bool` in `WorkbenchDependencies` (defaulting to a cohesive `MacOSDictationDispatcher.startDictation(in:)` helper that makes `textView` first responder, checks `NSApp.sendAction(NSSelectorFromString("startDictation:"), to: nil, from: textView)`, and falls back to locating the system `Edit` menu item with action `startDictation:`).
  - Rationale: Avoids adding new stored properties to `SwiftEditWorkbenchModel` (keeps member count at `20 <= 25`), requires zero entitlements, and is 100% unit-testable headlessly.
- **In-Code `AppIcon.microphone` Vector Glyph (`UI-001`)**:
  - Add `.microphone` to `AppIcon` with a clean `24x24` rounded-capsule + arc + stem path (no SF Symbols), automatically covered by existing `AppIcon` geometry fitness tests.
- **Dual-Side `SessionRecoveryEligibility` Filter (`DATA-005`, `DATA-006`, `SEC-011`)**:
  - Add a small pure `SessionRecoveryEligibility` enum in `SwiftEditCore` (`WorkspaceAndTabSession`) with:
    - `static func isEmptyUntitled(fileURL: URL?, text: String) -> Bool` (`fileURL == nil && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty`)
    - `static func shouldPersistManifestEntry(fileURL: URL?, text: String, isBinaryReadOnly: Bool) -> Bool`
    - `static func shouldPersistSnapshot(fileURL: URL?, text: String, isDirty: Bool, isBinaryReadOnly: Bool) -> Bool`
    - `static func shouldRestoreRecoveredTab(fileURL: URL?, text: String) -> Bool`
  - In `persistRecoveryState()`: filter `manifestTabs` using `shouldPersistManifestEntry` (falling back `activeTabID` to `nil` if the active tab is excluded), save snapshots only when `shouldPersistSnapshot` is `true`, and immediately call `removeRecoverySnapshot(for:)` + clear `lastPersistedRecoveryRevisions` for any untitled tab that was cleared to empty/whitespace-only.
  - In `restoreSessionRecoveryIfPresent()`: skip any recovered tab where `!shouldRestoreRecoveredTab(fileURL: tab.fileURL, text: recovered.text)`; reconcile `activeTabID` if the manifest's active tab was skipped; let the existing `purgeOrphanedSnapshots(keeping:)` delete any skipped legacy `.recovery` files on disk.

## Risks / Trade-offs
- **Risk**: macOS Dictation disabled in System Settings causes `startDictation:` to return `false` -> **Mitigation**: `startDictationHere()` handles `false` cleanly without mutating text or crashing, and surfaces a concise non-destructive status message if dispatch was declined.
- **Risk**: Symlinked paths (e.g. `/var/folders/...` vs `/private/var/folders/...` on macOS) causing false-positive `Reveal in Folder Navigator` visibility -> **Mitigation**: Always canonicalize both `selectedFolderURL` and `fileURL.deletingLastPathComponent()` with `resolvingSymlinksInPath().standardizedFileURL` before equality comparison.
- **Risk**: Existing `SessionRecovery` tests opening an empty untitled tab and expecting it to persist -> **Mitigation**: Check existing tests during `/myspec-apply` and align any legacy test asserting empty untitled persistence with the new `MODIFIED` `REQ-002` contract (while preserving all tests for non-empty untitled tabs and disk-backed tabs).

## Migration Plan
- No schema migration required (`session-manifest.json` wire format is unchanged).
- Legacy manifests already on disk containing empty untitled tabs are automatically filtered on the next app launch by `restoreSessionRecoveryIfPresent()`, and their stale `.recovery` files are purged by `purgeOrphanedSnapshots(keeping:)`.

## Security Review
- Reviewer: cyber-security-expert
- Date: 2026-11-25
- Verdict: approved # approved | changes-required
- Open items: none
