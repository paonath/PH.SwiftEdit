---
id: "brief-ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions"
change_id: "007-ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions"
capability: "ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions"
branch: "feature/FirstStub"
modifies_specs: "swifteditui-purple-zed-layout-textkit2-and-appicons (REQ-001)"
status: "approved-via-qa"
date: "2026-11-19"
owners:
  - "swift-macos-expert"
  - "cyber-security-expert"
---

# TDD Specification Brief: `SwiftEditUI` & `XcodeApp` Minimalist Layout, Left Line Gutter, Classic Menus, Graphical CheatSheet, 11 Sidebar Actions & Parent-Folder `...` Navigator (`TASK-03`)

## 1. Context & Source Traceability

- **Originating Roadmap Task**: `TASK-03` in `reasoning/002_minimal-ui-menus-and-editor-features/README.ai.md` plus user requirement addition: *"1. Nel navigatore a SX DEVO poter salire di livello (pulsante `...` per andare alla folder precedente) SE i permessi utente me lo concedono"*.
- **Active Git Branch**: `feature/FirstStub` (prerequisite `TASK-01` / `005` and `TASK-02` / `006` implemented and archived).
- **Consolidated Specs Modified (`modifies_specs`)**: `swifteditui-purple-zed-layout-textkit2-and-appicons` (`REQ-001`: adds default-collapsed sidebar, auto-expand on folder open, right-column `EditorTabStrip`, left 1-based `LineNumberGutterView`, and bottom-right live `Line/Column/Character count/UTF-8/LF-CRLF-CR` status counter; existing scenarios `P1`/`N1` preserved additively). All other requirements are `ADDED` in `ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions`.
- **Governing Constitutional Rules (`v1.3.0`)**: `[AR-001]`, `[AR-002]`, `[AR-003]`, `[AR-007]`, `[BC-004]`, `[BC-006]`, `[BC-007]`, `[BC-008]`, `[BC-011]`, `[BC-012]`, `[DATA-003]`, `[DATA-004]`, `[DATA-006]`, `[DATA-007]`, `[DATA-008]`, `[SEC-002]`, `[SEC-003]`, `[SEC-004]`, `[SEC-011]`, `[SEC-012]`, `[TEST-001]`..`[TEST-005]`, `[UI-001]`..`[UI-012]`, `[SDD-001]`, `[SDD-002]`.
- **Human Confirmation**: Confirmed via `ask_question` (`(Recommended)`).

## 2. Domain, Architecture & Security Expert Notes

- **`swift-macos-expert`**:
  - **Minimalist Layout & Right-Column `EditorTabStrip`**: `isLeftSidebarCollapsed` starts `true` on empty launch or single-file open (`Cmd+O`) and automatically transitions to `false` on `Open Folder` (`Cmd+Shift+O`) or `Open All Files in Folder` (`Cmd+Shift+Option+O`). `EditorTabStrip` sits strictly above the right-hand editor column (`VStack`), never spanning above the left sidebar.
  - **Left `LineNumberGutterView` & Status Bar Metrics**: `LineNumberGutterProjection` computes 1-based line numbers (`1..max(1, lineCount)`) scaled with `EditorZoomController.scaledFontSizePoints` alongside the `#FFFFFF`/`#000000` (`Light`) or `#000000`/`#FFFFFF` (`Black`) TextKit 2 canvas. The status bar renders live `CursorMetricsCalculator.metrics(in:caretLocation:)` (`Ln X, Col Y`, `N chars`), `UTF-8`, and a 3-way `LineEnding` selector (`LF`, `CRLF`, `CR`).
  - **Parent-Folder `...` Up-Navigation in Left Sidebar**: `SwiftEditWorkbenchModel` tracks `grantedScopeRootURL: URL?` (the highest user-authorized directory root) and `selectedFolderURL: URL?` (the currently displayed directory). The left sidebar renders a leading `...` button/row to ascend to `parentURL = selectedFolderURL.deletingLastPathComponent().standardizedFileURL` whenever `selectedFolderURL.path != "/"` and user permissions permit reading `parentURL` (`DotfileFolderNavigator.canNavigateToParent(from:withinScope:)`). If `parentURL` is within `grantedScopeRootURL` or readable under user permissions (expanding `grantedScopeRootURL` to `parentURL` when user permissions allow reading the parent directory), clicking `...` navigates up and refreshes `folderEntries`; if at filesystem root `"/"` or blocked by sandbox permissions/symlink escape, `navigateToParentFolder()` refuses the transition safely without crashing or leaking paths.
  - **Classic `@FocusedValue` Menus, `KeyboardShortcutsCheatSheetView`, `AboutSheetView` & `FindReplaceGoToLineBar`**: `SwiftEditCommands` routes `File` (`New Cmd+N`, `Open File Cmd+O`, `Open Folder Cmd+Shift+O`, `Open All Files in Folder Cmd+Shift+Option+O`, `Open Recent` 10-entry MRU + `Clear Recent`, `Save Cmd+S`, `Save As Cmd+Shift+S`, `Close Document Cmd+W`), `Edit` (`Undo Cmd+Z`, `Redo Cmd+Y`, `Cut Cmd+X`, `Copy Cmd+C`, `Paste Cmd+V`, `Select All Cmd+A`, `Duplicate Line/Selection Cmd+D`, `Find Cmd+F`, `Find & Replace Cmd+H`, `Go to Line Cmd+G`), `View` (`Toggle Sidebar`, `Zoom In/Out/Reset`, `Light/Black/Auto`), `Help` (`Keyboard Shortcuts CheatSheet`), and `About PH.SwiftEdit` (displaying `nbgv` version from `Info.plist`/`version.json` and opening `https://github.com/paoloinnocenti/PH.SwiftEdit` through `InspectionSafetyBannerState.prepareExternalURIConfirmation`).
  - **Dirty Close/Quit Prompts & 11 Confined Sidebar Actions**: Closing a dirty tab (`Cmd+W`) or quitting with dirty tabs (`Cmd+Q`) presents a `Save / Don't Save / Cancel` confirmation state (`DirtyCloseDecision`). The 11 sidebar actions (`Reveal in Finder`, `Open Folder in Finder`, `Open Terminal` preferring `com.googlecode.iterm2` when installed/default else `com.apple.Terminal` on the verified directory URL, `New Folder`, `Rename Folder`, `New File`, `Cut File`, `Copy File`, `Paste File`, `Delete File` to Trash with confirmation, `Rename File`) delegate to `FileSystemProviding`, `WorkspaceTabSession.applyRename`/`applyTrash`, and the `DesktopWorkspaceIntegrating` seam.
- **`cyber-security-expert`**:
  - **Parent-Folder `...` Confinement (`SEC-002`, `SEC-003`)**: Navigating to `...` validates `parentURL.resolvingSymlinksInPath()` against the effective user-permitted scope and checks directory readability; if a symlink attempts to jump to an unauthorized ancestor or unreadable sandbox path, navigation fails closed with `DomainError.securityScopeViolation` and preserves the current folder state.
  - **Zero-Subprocess Directory-Only Terminal Handoff (`SEC-004`, `CWE-78`)**: `DesktopWorkspaceIntegrating.openInTerminal(targetURL:withinScope:)` resolves any selected file URL to its parent directory URL, verifies `resolvingSymlinksInPath()` confinement inside the active workspace scope, checks that the resolved path is a directory (never a `.command`, `.sh`, or executable file), and opens only allowlisted bundle identifiers (`com.googlecode.iterm2` or `com.apple.Terminal`) via `NSWorkspace` with zero `Process`/`posix_spawn`/`osascript` calls.
  - **External Link & Pasteboard Guards (`SEC-004`, `SEC-012`)**: `AboutSheetView` routes the GitHub URL exclusively through `InspectionSafetyBannerState.prepareExternalURIConfirmation(rawURI:)`. Sidebar file Cut/Copy/Paste validates single-segment names and scope confinement before mutating disk.

## 3. 4-Pillar Breakdown & Path Coverage Matrix

| Unit | Path ID | Trait | Summary |
| :--- | :--- | :--- | :--- |
| `MinimalWorkspaceLayoutAndLineGutter` | `P1` | `positive` | Sidebar defaults to `isLeftSidebarCollapsed == true` on launch/single-file open, auto-expands on `Open Folder`, places `EditorTabStrip` strictly above right editor column, computes 1-based `LineNumberGutterProjection`, and updates live status bar `Ln/Col/Chars/UTF-8/LF-CRLF-CR` (`[UI-001]`, `[UI-002]`, `[DATA-004]`). |
| `MinimalWorkspaceLayoutAndLineGutter` | `N1` | `negative` | Empty/binary snapshots and out-of-range carets clamp safely in `LineNumberGutterProjection` and status metrics without throwing or mutating buffer text (`[UI-004]`, `[UI-008]`). |
| `SidebarParentFolderUpNavigation` | `P2` | `positive` | Sidebar displays `...` entry and ascends to parent folder (`navigateToParentFolder()`) when inside a subfolder or when user permissions allow reading the parent directory, refreshing `folderEntries` (`[BC-007]`, `[DATA-007]`, `[SEC-002]`). |
| `SidebarParentFolderUpNavigation` | `N2` | `negative` | At filesystem root `"/"` or when parent directory lacks user read permission, `canNavigateToParentFolder` is `false` and `navigateToParentFolder()` is a no-op with a non-destructive status message (`[BC-007]`). |
| `SidebarParentFolderUpNavigation` | `N3` | `security` | Parent traversal via an untrusted symlink escaping granted user permissions is rejected with `DomainError.securityScopeViolation`, leaving `selectedFolderURL` unchanged (`[SEC-002]`, `[SEC-003]`). |
| `FindReplaceGoToLineAndDirtyLifecycle` | `P3` | `positive` | `FindReplaceGoToLineBar` cycles matches, applies `replace` / `replaceAll`, jumps to 1-based line, converts active `LineEnding` (`LF`/`CRLF`/`CR`), records/deduplicates 10-entry MRU, and evaluates `Save / Don't Save / Cancel` on dirty tab close or app quit (`[BC-004]`, `[BC-006]`, `[DATA-004]`, `[DATA-008]`). |
| `FindReplaceGoToLineAndDirtyLifecycle` | `N4` | `negative` | Cancel on dirty close/quit aborts closure keeping tab and buffer intact; batch folder open above `50` files pauses for confirmation until approved (`[BC-008]`, `[BC-011]`). |
| `MenusCheatSheetAndAboutGuard` | `P4` | `positive` | `@FocusedValue` menu commands route `File`/`Edit`/`View`/`Help`/`About`, `KeyboardShortcutsCheatSheetCatalog` exposes all categorized shortcuts (including sidebar `...` parent navigation), and `AboutSheetDescriptor` resolves `nbgv` version + confirmed `https://github.com/paoloinnocenti/PH.SwiftEdit` prompt (`[AR-014]`, `[UI-009]`, `[UI-010]`, `[SEC-004]`). |
| `MenusCheatSheetAndAboutGuard` | `N5` | `security` | Non-HTTPS or tampered About/help URIs (`javascript:`, `file:`, hostless URLs) are rejected (`nil` prompt) and never passed to `NSWorkspace` (`[SEC-004]`, `[UI-008]`). |
| `SidebarCRUDAndDesktopWorkspaceHandoff` | `P5` | `positive` | Sidebar executes all 11 actions (`createDirectory`, `createFile`, `renameItem` with tab sync, `cut`/`copy`/`pasteItem` with collision suffix, confirmed `trashItem` with tab sync, `revealInFinder`, `openFolderInFinder`, and `openInTerminal` resolving files to their parent directory and selecting `com.googlecode.iterm2` when installed/default else `com.apple.Terminal`) (`[BC-012]`, `[SEC-002]`, `[SEC-004]`). |
| `SidebarCRUDAndDesktopWorkspaceHandoff` | `N6` | `negative` | Pasting with an empty sidebar clipboard or declining Trash confirmation performs zero filesystem mutations (`[BC-012]`). |
| `SidebarCRUDAndDesktopWorkspaceHandoff` | `N7` | `security` | `openInTerminal`, `revealInFinder`, or `openFolderInFinder` on a symlink escaping workspace scope or an unverified terminal bundle identifier fails closed with `DomainError.securityScopeViolation` and never passes a file path (`.command`/`.sh`) as the terminal application target (`CWE-78`, `[SEC-003]`, `[SEC-004]`). |

## 4. Declarative GIVEN-WHEN-THEN Behavior Contracts

```gherkin
Feature: SwiftEditUI Minimalist Layout, Line Gutter, Parent Folder Navigation, Classic Menus, CheatSheet, and 11 Confined Sidebar Actions

  @REQ-UI-MINIMAL-LAYOUT-GUTTER-MENUS-CHEATSHEET-AND-SIDEBAR-ACTIONS-001
  Scenario: Sidebar starts collapsed, auto-expands on Open Folder, and renders right-column tabs with left 1-based line gutter
    Given a newly initialized SwiftEditWorkbenchModel
    When the user inspects the default layout and then opens a workspace folder
    Then isLeftSidebarCollapsed transitions from true to false, EditorTabStrip stays above the right editor column, LineNumberGutterProjection lists 1-based lines, and the status bar reports Line, Column, Character count, UTF-8, and LF/CRLF/CR

  @REQ-UI-MINIMAL-LAYOUT-GUTTER-MENUS-CHEATSHEET-AND-SIDEBAR-ACTIONS-002 @security
  Scenario: Left sidebar ... button ascends to parent folder when user permissions allow and blocks symlink escape
    Given a workspace folder "/Users/test/Project" open in the sidebar and a child subfolder "/Users/test/Project/Sources"
    When the user enters "Sources" and activates the "..." parent folder button
    Then the navigator ascends to "/Users/test/Project" (and further to "/Users/test" if readable under user permissions) while rejecting any symlinked parent that escapes unauthorized paths

  @REQ-UI-MINIMAL-LAYOUT-GUTTER-MENUS-CHEATSHEET-AND-SIDEBAR-ACTIONS-003
  Scenario: Search bar, dirty close/quit confirmation, CheatSheet, and About dialog operate deterministically
    Given an open dirty document tab with unsaved edits
    When the user runs Find/Replace/Go-to-Line, requests Close Tab (Cmd+W) selecting Cancel, and opens the CheatSheet and About dialog
    Then the tab remains open on Cancel, the CheatSheet lists all keyboard shortcuts across File/Edit/View/Navigation/Sidebar, and About validates https://github.com/paoloinnocenti/PH.SwiftEdit via ExternalLinkGuard

  @REQ-UI-MINIMAL-LAYOUT-GUTTER-MENUS-CHEATSHEET-AND-SIDEBAR-ACTIONS-004 @security
  Scenario: Sidebar 11 actions and directory-only Terminal/Finder handoff enforce workspace confinement
    Given an authorized workspace folder containing "script.sh"
    When the user invokes Open Terminal on "script.sh" or attempts a Finder/Terminal handoff on an escaping symlink
    Then Open Terminal resolves "script.sh" to its verified parent directory URL and launches com.googlecode.iterm2 or com.apple.Terminal with zero subprocesses while the escaping symlink is blocked with securityScopeViolation
```
