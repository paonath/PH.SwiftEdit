# Threat Model: Contextual Reveal in Folder Navigator, Start Dictation Here & Empty Untitled Session Filter

## 1. Asset Boundaries & Trust Zones
- **Trusted Core (`SwiftEditCore`)**: Pure-Foundation contextual catalog (`ElementContextualActionCatalog`) and recovery eligibility rules (`SessionRecoveryEligibility`); no AppKit, no filesystem side effects beyond `SessionRecoveryStore` / `DotfileFolderNavigator`.
- **UI & Responder Boundary (`SwiftEditUI` macOS)**: `SwiftEditWorkbenchModel`, `ElementContextualMenuView`, `SwiftEditNSTextView` right-click `NSMenu`, and AppKit responder chain (`startDictation:` routed to out-of-process macOS `DictationIM`).
- **Filesystem & Persistence Boundary**: Local user workspace directories (`DotfileFolderNavigator` with `.skipAndReport` + fail-closed root-escape check) and `Application Support/PH.SwiftEdit/SessionRecovery/` (`0700` dir, `0600` files, excluded from backup, `<= 64 MiB` quota).

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | Symlinked document path masquerading as inside an already-open folder or escaping workspace root during `Reveal in Folder Navigator` | Canonicalize both `selectedFolderURL` and `fileURL.deletingLastPathComponent()` via `resolvingSymlinksInPath().standardizedFileURL` before comparison and navigation; enforce `DotfileFolderNavigator` root-escape fail-closed check (`SEC-002`, `SEC-003`). |
| Tampering | Dictation invoked on a binary read-only or live log-tail document injecting text into a read-only buffer | Strictly gate `canStartDictationHere` on `activeLogTail == nil && safetyBanner.canSave && !session.isBinaryReadOnly`, omit right-click menu item when unavailable, and require `textView.isEditable == true` before dispatching `startDictation:` (`SEC-012`). |
| Repudiation | Silent failure when revealing a deleted/unreadable parent folder or dispatching dictation when unavailable | Emit deterministic, non-destructive `statusBannerMessage` feedback on failed reveal without mutating prior valid sidebar state (`UI-009`, `UI-010`). |
| Information Disclosure | Residual `.recovery` snapshot files remaining on disk after an untitled document is cleared to empty/whitespace-only or skipped at startup | Immediately unlink `.recovery` files in `persistRecoveryState()` when an untitled tab becomes empty/whitespace-only and purge all unreferenced legacy snapshots via `purgeOrphanedSnapshots(keeping:)` at startup (`DATA-006`, `SEC-011`). |
| Denial of Service | Unbounded view-hierarchy traversal searching for `SwiftEditNSTextView` or symlink loop when revealing a folder | Reuse `SwiftEditWorkbenchModel.editableEditorTextView(in:)` bounded by `maxTraversalVisitedNodes` and `visited` set (`CWE-674`); use shallow non-recursive `DotfileFolderNavigator.listEntries` (`SEC-003`, `UI-012`). |
| Elevation of Privilege | Adding microphone/audio entitlements or spawning subprocesses for speech recognition | Zero new entitlements and zero subprocesses; delegate exclusively to macOS's standard AppKit `startDictation:` responder action handled by the OS `DictationIM` (`SEC-001`, `SEC-004`). |

## 3. Abuse Cases & Negative Scenarios
- **Abuse Case 1 (Symlink / Missing Directory Reveal)**: Active document's containing directory is deleted or unreadable before the user triggers `Reveal in Folder Navigator` -> fails closed with `statusBannerMessage` and preserves prior sidebar state (`REQ-031-01 N1`).
- **Abuse Case 2 (Read-Only Buffer Dictation Injection)**: User attempts to invoke `Start Dictation Here` on a binary quarantined tab or live log-tail tab -> action is hidden in both menus and programmatic invocation returns `false` without invoking `dictationTrigger` (`REQ-031-02 N2`).
- **Abuse Case 3 (Stale Untitled Snapshot Retention)**: User types sensitive text into an untitled tab, then deletes it (leaving `""` or `"  \n "`) before quitting -> `persistRecoveryState()` excludes the tab and unlinks its `.recovery` file immediately; legacy empty snapshots are purged at startup (`REQ-002 N10`).

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-25
- Verdict: approved # approved | changes-required
- Open items: none
