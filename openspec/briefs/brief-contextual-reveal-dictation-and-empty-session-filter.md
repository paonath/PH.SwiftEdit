---
slug: "contextual-reveal-dictation-and-empty-session-filter"
date: "2026-11-25"
branch: "main"
mode: "feature-and-fix"
modifies_specs:
  - "notepadpp-tabs-session-recovery-and-dotfiles"
  - "integrations-autocomplete-contextual-menu-and-redesign-plan"
domain_experts:
  - "swift-macos-expert (openspec/agents/swift-macos-expert.agent.md)"
  - "cyber-security-expert"
constitution_rules:
  - "AR-001"
  - "AR-004"
  - "BC-006"
  - "BC-007"
  - "BC-008"
  - "UI-001"
  - "UI-009"
  - "UI-010"
  - "UI-012"
  - "DATA-005"
  - "DATA-006"
  - "DATA-007"
  - "TEST-001"
  - "TEST-005"
  - "SEC-002"
  - "SEC-003"
  - "SEC-004"
  - "SEC-011"
  - "SEC-012"
---

# TDD Specification Brief: Contextual Reveal in Folder Navigator, Start Dictation Here & Empty Untitled Session Filter

## Feature Context & Architectural Baseline

- **Repository**: `PH.SwiftEdit` (Swift 6.4+, `.macOS(.v26)` / `.iOS(.v26)`, SwiftPM `SwiftEditCore` + `SwiftEditUI`, `Swift Testing`).
- **Structural Baseline (`tokensave`)**: `0` circular dependencies across `Sources/`, max class member count `24 <= 25` (`WorkbenchRenderCaches`), max cognitive complexity `10 <= 15` (`formatActiveDocument`).
- **Domain Expert Notes (`swift-macos-expert`)**:
  - Keep `SwiftEditCore` pure `Foundation` + `swift-markdown` (zero `AppKit`/`UIKit`); new contextual action kinds (`revealInFolderNavigator`, `startDictationHere`) and dynamic availability filtering live in `ElementContextualActionCatalog` (`SwiftEditCore`), while `NSApp.sendAction(NSSelectorFromString("startDictation:"), ...)` and `NSMenu` wiring stay isolated under `#if os(macOS)` in `SwiftEditUI`.
  - Respect `UI-001` v1.7.0 in-code `AppIcon` line set (zero SF Symbols): reuse `.folder` (or add a minimal `.microphone` 24x24 vector glyph in `AppIcon`) with full `AppIcon` grid fitness coverage.
  - Keep `SwiftEditWorkbenchModel` nominal member count `<= 25` by placing new helpers in existing extensions (`+WorkspaceAndSidebar`, `+ContextualMenuAndShortcuts`, `+CheatSheetAndHeaderCommands`, `+CoreDiagnosticsAndRecovery`) and passing injectable closures/seams for headless `Swift Testing`.

## Four-Pillar Breakdown

### Pillar 1 — Public Behaviors & Nominal Scenarios
1. **Reveal in Folder Navigator (`Document` group & right-click menu)**:
   - Shown ONLY when the active document is disk-backed (`fileURL != nil`) AND (`isLeftSidebarCollapsed == true` OR `selectedFolderURL == nil` OR canonical `selectedFolderURL != canonical(fileURL.deletingLastPathComponent())`).
   - Invoking it expands the left sidebar (`isLeftSidebarCollapsed = false`), navigates `selectedFolderURL` to the document's containing directory (preserving `grantedScopeRootURL` when it is an ancestor of the containing folder so `...` parent navigation remains intact, otherwise setting `grantedScopeRootURL` to the containing directory), refreshes `folderEntries`, and selects `selectedSidebarEntryURL = fileURL.standardizedFileURL`.
2. **Start Dictation Here (`Document` group & right-click menu)**:
   - Shown whenever the active editor document is writable (not binary read-only, not live log-tail) with a valid caret/selection.
   - Invoking it closes the `Cmd+Return` palette (if open), restores first-responder focus to the editable `SwiftEditNSTextView`, and dispatches macOS's standard AppKit `startDictation:` action (with fallback lookup of the system `Edit -> Start Dictation…` menu item) through an injectable `dictationTrigger` seam so headless tests verify dispatch without invoking macOS UI.
3. **Skip Empty/Whitespace-Only Untitled Documents on App Relaunch (`SessionRecovery`)**:
   - **Write side (`persistRecoveryState`)**: Do NOT persist untitled tabs (`fileURL == nil`) whose text is empty or whitespace/newline-only (`text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty`) into `session-manifest.json` or as `.recovery` snapshots; unlink any stale `.recovery` snapshot if a previously non-empty untitled tab is cleared to empty/whitespace-only.
   - **Read side (`restoreSessionRecoveryIfPresent`)**: Filter out any legacy manifest entry whose `fileURL == nil` and whose recovered text is empty or whitespace/newline-only (or missing snapshot), updating `activeTabID` cleanly to a remaining valid tab (or `nil` if none remain) and purging orphaned snapshots via `purgeOrphanedSnapshots`.
   - Non-empty untitled tabs (containing non-whitespace text) and disk-backed/pinned tabs continue to persist and restore unchanged (`DATA-005`).

### Pillar 2 — Edge Cases, Boundaries & Forbidden Responsibilities
- **Reveal in Folder Navigator**:
  - Untitled (`fileURL == nil`), binary read-only, or live log-tail tabs MUST NOT show `Reveal in Folder Navigator`.
  - When the Folder Navigator is already open (`!isLeftSidebarCollapsed`) and displaying the canonical containing folder (including symlink-equivalent paths like `/var` vs `/private/var`), `Reveal in Folder Navigator` MUST be hidden.
  - If the document's containing folder no longer exists on disk or is unreadable, `revealActiveDocumentInFolderNavigator()` MUST fail closed with a non-destructive `statusBannerMessage` and preserve prior valid sidebar state.
- **Start Dictation Here**:
  - Binary read-only tabs, degraded/unwritable tabs, live log-tail tabs, or missing editable `SwiftEditNSTextView` MUST refuse dictation cleanly (`return false`), without mutating document text.
  - If macOS Dictation is disabled in System Settings, dispatching `startDictation:` fails gracefully without crashing or corrupting editor state.
- **Empty Untitled Session Filter**:
  - A disk-backed empty file (`fileURL != nil`, `text == ""`, e.g. pinned empty `notes.md`) IS disk-backed and MUST NOT be conflated with an untitled empty document.
  - An untitled tab with `"   \n\t  "` (whitespace-only) is excluded; an untitled tab with `"a"` is preserved and restored.
  - A manifest containing only empty untitled tabs restores zero tabs (`tabSession.tabs.isEmpty == true`) and cleans up all stale `.recovery` files.

### Pillar 3 — Testability, Seams & KISS/SOLID Balance
- Pure domain logic in `SwiftEditCore`:
  - `ElementContextualActionCatalog.groups(hasSelection:canRevealInFolderNavigator:canStartDictation:)` (keeping backwards-compatible default `groups(hasSelection:)` overload so existing tests keep passing).
  - Pure helper `SessionRecoveryEligibility.shouldPersistAndRestore(fileURL:text:isBinaryReadOnly:isDirty:isPinned:)` (or focused static helper in `SwiftEditCore` / `SessionRecoveryStore`) for deterministic unit testing of all combinations.
- Injectable seam in `SwiftEditUI`:
  - `dictationTrigger: @MainActor (SwiftEditNSTextView) -> Bool` (defaulting to making `textView` first responder and dispatching `startDictation:` via `NSApp.sendAction` / Edit menu fallback) on `WorkbenchRuntimeHooks` / `SwiftEditWorkbenchModel.init` so `Swift Testing` verifies exact first-responder & dispatch behavior headlessly.
  - Right-click `SwiftEditNSTextView` callbacks: `onRevealInFolderNavigator: (() -> Void)?` (nil when unavailable so menu item is omitted) and `onStartDictationHere: (() -> Void)?` (nil when unavailable).

### Pillar 4 — Security & Abuse Cases (STRIDE)
- **Path Traversal / Symlink Escape (`SEC-002`, `SEC-003`)**: Canonicalize both `selectedFolderURL` and `fileURL.deletingLastPathComponent()` via `resolvingSymlinksInPath().standardizedFileURL` before comparison and navigation; enforce `DotfileFolderNavigator` `.skipAndReport` / root-escape fail-closed checks on the revealed directory.
- **Unauthorized Mutation (`SEC-012`)**: Never expose or dispatch `startDictationHere` on binary read-only or live log-tail views.
- **Privacy & Zero Residual Data (`DATA-006`, `SEC-011`)**: Unlink stale `.recovery` snapshots immediately when an untitled tab becomes empty/whitespace-only or is filtered out during startup restore, ensuring zero orphaned recovery files remain on disk.

## Path Coverage Matrix

| Unit / Capability | Positive Paths | Negative / Security Paths |
|---|---|---|
| `ElementContextualActionCatalog` & `ElementContextualMenuState` | `P1` Document group includes `Reveal in Folder Navigator` when `canRevealInFolderNavigator == true` and `Start Dictation Here` when `canStartDictation == true` (both with and without text selection) | `N1` `Reveal in Folder Navigator` omitted when `canRevealInFolderNavigator == false` (untitled or already in open folder); `Start Dictation Here` omitted when `canStartDictation == false` (binary/log-tail); `evaluate()` returns `nil` for both non-text-edit kinds |
| `SwiftEditWorkbenchModel` Reveal in Folder Navigator | `P2` Collapsed sidebar, `nil` folder, or different folder -> expands sidebar, sets `selectedFolderURL` to containing folder (preserving ancestor `grantedScopeRootURL`), refreshes entries, highlights `selectedSidebarEntryURL` | `N2` Already-open matching canonical folder (incl. symlink equivalence) reports `canRevealActiveDocumentInFolderNavigator == false`; missing/unreadable containing directory fails closed with `statusBannerMessage` and no crash (`security`) |
| `SwiftEditWorkbenchModel` & `SwiftEditNSTextView` Start Dictation Here | `P3` Writable document exposes `Start Dictation Here` in both `Cmd+Return` palette and right-click `NSMenu`; invoking closes palette, focuses editor, and invokes `dictationTrigger` (`startDictation:`) | `N3` Binary read-only, live log-tail, or missing editable text view refuses dictation (`false`) and omits right-click item (`security`) |
| `SessionRecovery` Empty/Untitled Filter (`MODIFIED` `REQ-002`) | `P4` Non-empty untitled tabs and disk-backed/pinned tabs persist and restore normally across relaunch | `N4` Empty (`""`) and whitespace-only (`" \n\t"`) untitled tabs are excluded in both `persistRecoveryState` and `restoreSessionRecoveryIfPresent`, legacy empty `.recovery` files are purged on startup, and clearing a previously non-empty untitled tab unlinks its snapshot (`security`) |
