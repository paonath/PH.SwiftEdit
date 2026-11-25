# Capability: contextual-reveal-dictation-and-empty-session-filter

## Purpose
Adds contextual `Reveal in Folder Navigator` and `Start Dictation Here` actions to both the `Cmd+Return` contextual palette and the editor right-click menu in `SwiftEditCore` and `SwiftEditUI`, with strict canonical path checks and writable-document guards.

## Requirements

### Requirement: REQ-031-01 Conditional Reveal in Folder Navigator Contextual Action
WHEN the active document is disk-backed and the left Folder Navigator is collapsed, unset, or opened on a different canonical directory, `SwiftEditCore` and `SwiftEditUI` SHALL expose `Reveal in Folder Navigator` in the `Cmd+Return` `Document` group and editor right-click menu, expand the sidebar on invocation, navigate to the containing directory while preserving an ancestor scope root, refresh entries, and highlight the active file [AR-001][BC-006][UI-001][UI-010][SEC-002][SEC-003].

#### Scenario: P1 Collapsed or Different-Folder Sidebar Reveals Active Disk-Backed Document
- **Path**: P1
- **Trait**: positive
- **GIVEN** an active disk-backed document at `/tmp/workspace/sub/notes.md` while the left sidebar is collapsed, has `selectedFolderURL == nil`, or is open on `/tmp/other`
- **WHEN** the user opens the `Cmd+Return` contextual palette or editor right-click menu and invokes `Reveal in Folder Navigator`
- **THEN** `Reveal in Folder Navigator` is present, the sidebar expands (`isLeftSidebarCollapsed == false`), `selectedFolderURL` becomes `/tmp/workspace/sub` (preserving `grantedScopeRootURL` if it is `/tmp/workspace`), `folderEntries` refreshes, and `selectedSidebarEntryURL` equals `/tmp/workspace/sub/notes.md`

#### Scenario: N1 Untitled, Already-Revealed, or Missing-Parent Documents Hide or Fail Closed
- **Path**: N1
- **Trait**: security
- **GIVEN** an untitled tab (`fileURL == nil`), a disk-backed tab whose canonical containing directory already matches the open `selectedFolderURL` (including symlink-equivalent paths), or a tab whose containing directory no longer exists on disk
- **WHEN** contextual action availability is evaluated or `revealActiveDocumentInFolderNavigator()` is invoked on the missing directory
- **THEN** `Reveal in Folder Navigator` is omitted for untitled and already-revealed tabs, and a missing or unreadable parent directory fails closed with a non-destructive `statusBannerMessage` leaving prior sidebar state intact

### Requirement: REQ-031-02 Writable-Document Start Dictation Here Contextual Action
WHEN the cursor is in a writable, non-binary, non-log-tail document, `SwiftEditCore` and `SwiftEditUI` SHALL expose `Start Dictation Here` in the `Cmd+Return` `Document` group (with in-code `AppIcon.microphone`) and editor right-click menu, and upon invocation SHALL close the palette, focus the editable `SwiftEditNSTextView`, and dispatch the native macOS `startDictation:` action through an injectable seam [AR-001][BC-006][UI-001][UI-010][SEC-001][SEC-004][SEC-012].

#### Scenario: P2 Writable Document Dispatches Native Start Dictation Action at Caret
- **Path**: P2
- **Trait**: positive
- **GIVEN** an active writable document tab (with or without a text selection) and an editable `SwiftEditNSTextView`
- **WHEN** the user opens the `Cmd+Return` contextual palette or editor right-click menu and invokes `Start Dictation Here`
- **THEN** the palette closes, the editable `SwiftEditNSTextView` receives first-responder focus, and the `dictationTrigger` seam dispatches macOS `startDictation:` returning `true` without mutating document text directly

#### Scenario: N2 Binary Read-Only, Live Log-Tail, or Missing Editable TextView Refuses Dictation
- **Path**: N2
- **Trait**: security
- **GIVEN** a binary read-only tab, a live log-tail tab, or a workbench with no editable `SwiftEditNSTextView` attached
- **WHEN** contextual action availability is evaluated or `startDictationHere()` is invoked
- **THEN** `Start Dictation Here` is omitted from both contextual menus, `ElementContextualActionCatalog.evaluate(.startDictationHere, ...)` returns `nil`, and `startDictationHere()` returns `false` without invoking `dictationTrigger`
