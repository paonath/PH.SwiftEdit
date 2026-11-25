# Proposal: Contextual Reveal in Folder Navigator, Start Dictation Here & Empty Untitled Session Filter

## Why
Users editing disk-backed files opened outside the current Folder Navigator directory (or while the left sidebar is collapsed/unset) currently have no quick contextual action to jump the Folder Navigator directly to the active document's containing directory. In addition, users who dictate prose or Markdown notes on macOS lack a direct contextual action to start native macOS Dictation at the current editor caret. Finally, `SessionRecovery` currently persists and restores empty/whitespace-only untitled tabs (`fileURL == nil`), causing clutter with blank untitled documents whenever the app is relaunched.

## What Changes
- **Contextual Action — `Reveal in Folder Navigator`**:
  - Add `.revealInFolderNavigator` to `ElementContextualActionKind` and the `Document` group in `ElementContextualActionCatalog` (`SwiftEditCore`), conditionally included ONLY when the active document is disk-backed (`fileURL != nil`) and either the left sidebar is collapsed (`isLeftSidebarCollapsed == true`), no folder is open (`selectedFolderURL == nil`), or the open folder's canonical path differs from the active document's canonical containing folder.
  - Expose `Reveal in Folder Navigator` in both the `Cmd+Return` contextual palette and the `SwiftEditNSTextView` right-click `NSMenu`.
  - When invoked, expand the left sidebar, navigate `selectedFolderURL` to the active document's containing directory (preserving `grantedScopeRootURL` if it is an ancestor so `...` parent navigation remains intact, otherwise setting `grantedScopeRootURL` to the containing directory), refresh folder entries, and select the active document in the sidebar (`selectedSidebarEntryURL`).
- **Contextual Action — `Start Dictation Here`**:
  - Add `.startDictationHere` to `ElementContextualActionKind` and the `Document` group in `ElementContextualActionCatalog` (`SwiftEditCore`), included whenever the active document is writable (not binary read-only, not live log-tail).
  - Expose `Start Dictation Here` in both the `Cmd+Return` contextual palette (with a new in-code `AppIcon.microphone` 24x24 vector glyph, zero SF Symbols) and the `SwiftEditNSTextView` right-click `NSMenu`.
  - When invoked, close the palette (if open), restore first-responder focus to the editable `SwiftEditNSTextView`, and dispatch macOS's standard AppKit `startDictation:` action (with fallback lookup of the system `Edit -> Start Dictation…` menu item) via an injectable `dictationTrigger` seam.
- **Session Recovery Fix — Skip Empty/Whitespace-Only Untitled Documents**:
  - Introduce a pure `SessionRecoveryEligibility` predicate in `SwiftEditCore` (`WorkspaceAndTabSession`) that excludes untitled tabs (`fileURL == nil`) whose text is empty or whitespace/newline-only.
  - Apply the filter in both `persistRecoveryState()` (omitting empty untitled tabs from `session-manifest.json` and unlinking any stale `.recovery` file when a previously non-empty untitled tab is cleared) and `restoreSessionRecoveryIfPresent()` (skipping legacy empty untitled entries on startup, reconciling `activeTabID`, and purging orphaned snapshots).

## Capabilities
- New Capabilities: `contextual-reveal-dictation-and-empty-session-filter`
- Modified Capabilities: `notepadpp-tabs-session-recovery-and-dotfiles` (`REQ-002`)

## Impact
- `Sources/SwiftEditCore/MarkdownLintAndFormat/ElementContextualActions.swift` (`ElementContextualActionKind`, `ElementContextualActionCatalog.groups(...)`)
- `Sources/SwiftEditCore/WorkspaceAndTabSession/SessionRecoveryStore.swift` (or sibling `SessionRecoveryEligibility.swift`)
- `Sources/SwiftEditUI/Theme/AppIcons.swift` (`AppIcon.microphone` vector path)
- `Sources/SwiftEditUI/Workbench/WorkbenchPresentationModels.swift` (`ElementContextualMenuState`)
- `Sources/SwiftEditUI/Workbench/WorkbenchDependenciesAndCaches.swift` (`dictationTrigger` seam in `WorkbenchRuntimeHooks` / `WorkbenchDependencies`)
- `Sources/SwiftEditUI/Workbench/SwiftEditWorkbenchModel.swift` (optional `dictationTrigger` init parameter with default)
- `Sources/SwiftEditUI/Workbench/SwiftEditWorkbenchModel+WorkspaceAndSidebar.swift` (`canRevealActiveDocumentInFolderNavigator`, `revealActiveDocumentInFolderNavigator()`)
- `Sources/SwiftEditUI/Workbench/SwiftEditWorkbenchModel+ContextualMenuAndShortcuts.swift` (`canStartDictationHere`, `presentElementContextualMenu`, `startDictationHere()`)
- `Sources/SwiftEditUI/Workbench/SwiftEditWorkbenchModel+CheatSheetAndHeaderCommands.swift` (`performElementContextualAction`)
- `Sources/SwiftEditUI/Workbench/SwiftEditWorkbenchModel+CoreDiagnosticsAndRecovery.swift` (`persistRecoveryState`, `restoreSessionRecoveryIfPresent`)
- `Sources/SwiftEditUI/Views/SwiftEditNSTextViewAndUndoRegistry.swift` and `Sources/SwiftEditUI/Views/TextKit2EditorView.swift` (right-click `NSMenu` callbacks)
- `Tests/SwiftEditTests/ContextualRevealDictationAndSessionFilterTests.swift` (new Swift Testing suite)

## Security Impact
- **Path Canonicalization & Confinement (`SEC-002`, `SEC-003`)**: `Reveal in Folder Navigator` canonicalizes paths via `resolvingSymlinksInPath().standardizedFileURL` before comparison and delegates directory listing to `DotfileFolderNavigator` (`.skipAndReport` with fail-closed root-escape rejection). Missing or unreadable containing directories fail closed with a status banner.
- **No New Entitlements (`SEC-001`, `SEC-004`)**: `Start Dictation Here` invokes macOS's out-of-process system `DictationIM` via the standard AppKit `startDictation:` responder action; zero microphone entitlements or subprocesses are added. Binary read-only and live log-tail views strictly block dictation (`SEC-012`).
- **Residual Data Minimization (`DATA-006`, `SEC-011`)**: Empty/whitespace-only untitled tabs are never retained in `SessionRecovery/`, and stale `.recovery` snapshots are immediately unlinked when cleared or purged on startup.

## Metadata
- Owner: Paolo Innocenti
- Domain: Swift 6.4+ / macOS 26+ SwiftEditCore & SwiftEditUI
- Reviewer: swift-macos-expert, cyber-security-expert
- Branch: main
- Manual-Steps: none
- Modifies-Specs: notepadpp-tabs-session-recovery-and-dotfiles (REQ-002)
- Constitutional-Rules: AR-001, AR-004, BC-006, BC-007, BC-008, UI-001, UI-009, UI-010, UI-012, DATA-005, DATA-006, DATA-007, TEST-001, TEST-005, SEC-001, SEC-002, SEC-003, SEC-004, SEC-011, SEC-012, SDD-001, SDD-002, SDD-003
- Amends-Constitution: none

## Prerequisites
- Brief: [brief-contextual-reveal-dictation-and-empty-session-filter.md](../../briefs/brief-contextual-reveal-dictation-and-empty-session-filter.md)
- Existing consolidated specs: `openspec/specs/notepadpp-tabs-session-recovery-and-dotfiles/spec.md`, `openspec/specs/integrations-autocomplete-contextual-menu-and-redesign-plan/spec.md`, `openspec/specs/send-to-terminal-contextual-action/spec.md`
