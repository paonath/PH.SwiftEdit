# Capability: ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions

## Purpose
Defines the user-facing `SwiftEditUI` and `XcodeApp` contracts for `TASK-03`: the default-collapsed left sidebar with auto-expand on folder open, the `...` parent-folder up-navigation control under user permissions, the right-column `EditorTabStrip`, the left 1-based `LineNumberGutterView`, the bottom-right live `Line`/`Column`/`Character count`/`UTF-8`/`LF`/`CRLF`/`CR` status bar, `Find`/`Replace`/`Go to Line`, dirty close and quit confirmation, `@FocusedValue` classic macOS menus (`File`, `Edit`, `View`, `Help`, `About`), the graphical keyboard-shortcut `CheatSheet`, and the 11 confined sidebar file/folder and `Finder`/`Terminal`/`iTerm2` actions.

## Requirements

### Requirement: REQ-001 Default-Collapsed Sidebar Right-Column Tabs Left Line Gutter and Live Status Counter
WHEN initializing a workspace window, opening a folder, or moving the caret, the workbench model and layout projection SHALL default `isLeftSidebarCollapsed` to `true`, auto-expand the sidebar when opening a folder, render `EditorTabStrip` strictly above the right editor column, project 1-based line numbers for `LineNumberGutterView`, and update live `Line`, `Column`, `Character count`, `UTF-8`, and `LF`/`CRLF`/`CR` status counters [DATA-004][UI-001][UI-002][UI-004][UI-005][UI-012].

#### Scenario: P1 Default-Collapsed Sidebar Auto-Expand on Folder Open Right-Column Tabs and 1-Based Line Gutter
- **Path**: P1
- **Trait**: positive
- **GIVEN** a newly initialized `SwiftEditWorkbenchModel` with a 3-line `"alpha\r\nbeta\r\ngamma"` document and caret at UTF-16 offset `8`
- **WHEN** the layout state, `LineNumberGutterProjection`, and status bar metrics are evaluated before and after mounting a workspace folder
- **THEN** `isLeftSidebarCollapsed` starts `true`, remains `true` on single-file open, becomes `false` upon `selectWorkspaceFolder(_:)`, `LineNumberGutterProjection` outputs lines `[1, 2, 3]` with active line `2`, and status metrics report line `2`, column `2`, `18` characters, `UTF-8`, and `CRLF`

#### Scenario: N1 Empty or Out-of-Range Caret Clamps Line Gutter and Status Metrics Safely
- **Path**: N1
- **Trait**: negative
- **GIVEN** an empty document buffer `""` and an out-of-range caret offset `99`
- **WHEN** `LineNumberGutterProjection.evaluate(text:caretLocation:)` and the workbench status metrics run
- **THEN** the gutter projection returns `[1]` with active line `1` and the status metrics clamp the caret to line `1`, column `1`, `0` characters without throwing or mutating the buffer

### Requirement: REQ-002 Left Sidebar Parent-Folder Dot-Dot-Dot Up-Navigation Within User Permissions
WHEN the user activates the `...` parent-folder control in the left sidebar navigator, the workbench navigator SHALL ascend from the current folder to its parent directory whenever the current folder is not the filesystem root `"/"` and user permissions allow reading the parent directory within symlink-verified scope [BC-007][DATA-007][SEC-002][SEC-003][UI-001].

#### Scenario: P2 Ascending to Parent Folder via Dot-Dot-Dot Within Granted or User-Readable Scope
- **Path**: P2
- **Trait**: positive
- **GIVEN** a granted workspace root `"/tmp/workspace"` containing subfolder `"/tmp/workspace/Sources"` and a readable parent directory `"/tmp"` under user permissions
- **WHEN** the user enters `"/tmp/workspace/Sources"`, invokes `navigateToParentFolder()` (`...`), and invokes `navigateToParentFolder()` (`...`) a second time with parent read permission enabled
- **THEN** `canNavigateToParentFolder` is `true`, the first `...` action sets `selectedFolderURL` to `"/tmp/workspace"` and refreshes its entries, and the second `...` action ascends to `"/tmp"` while updating the active scope root to `"/tmp"`

#### Scenario: N2 Filesystem Root or Unpermitted Parent Disables Dot-Dot-Dot Up-Navigation
- **Path**: N2
- **Trait**: negative
- **GIVEN** a folder navigator positioned at `"/"` or at a folder whose parent directory is not readable under current user permissions
- **WHEN** `canNavigateToParentFolder` is queried and `navigateToParentFolder()` is invoked
- **THEN** `canNavigateToParentFolder` is `false`, `selectedFolderURL` and `folderEntries` remain unchanged, and a non-destructive status message is recorded

#### Scenario: N3 Symlinked Parent Escaping User-Permitted Scope Fails Closed
- **Path**: N3
- **Trait**: security
- **GIVEN** a workspace subfolder whose resolved parent path traverses a symbolic link pointing to an unpermitted external directory
- **WHEN** `navigateToParentFolder()` is invoked
- **THEN** the operation aborts with `DomainError.securityScopeViolation` and leaves `selectedFolderURL` and `folderEntries` unchanged

### Requirement: REQ-003 Interactive Find Replace Go-to-Line 3-Way LineEnding Switching MRU and Dirty Close/Quit Prompts
WHEN the user executes Find, Replace, Go to Line, switches line endings, reopens a recent file, batch-opens a folder, or closes/quits with dirty tabs, the workbench model SHALL apply literal search edits, switch between `LF`, `CRLF`, and `CR`, maintain the 10-entry deduplicated MRU list, enforce the 50-file batch confirmation gate, and prompt `Save / Don't Save / Cancel` before discarding unsaved edits [BC-004][BC-006][BC-008][BC-011][DATA-004][DATA-006][DATA-008][UI-009].

#### Scenario: P3 Find Replace Go-to-Line LineEnding Switch MRU Reopen and Confirmed Dirty Close
- **Path**: P3
- **Trait**: positive
- **GIVEN** an active document `"one\ntwo\none"`, a `RecentFilesStore`, and dirty unsaved changes
- **WHEN** the user finds `"one"`, replaces all with `"ONE"`, jumps to line `2`, switches line ending to `.cr`, records a saved file in `Open Recent`, and requests tab close choosing `.dontSave`
- **THEN** the buffer becomes `"ONE\ntwo\nONE"` with `LineEnding.cr`, ` currentSelection.location` moves to line `2`, the recent files list holds the saved file at index `0` without duplicates, and `.dontSave` closes the tab and unlinks its recovery snapshot

#### Scenario: N4 Canceling Dirty Close or Quit Preserves Tabs and Over-50 Batch Open Awaits Confirmation
- **Path**: N4
- **Trait**: negative
- **GIVEN** a dirty open tab and a folder batch plan containing `52` shallow text files (`requiresConfirmation == true`)
- **WHEN** the user requests `requestCloseTab` or `requestApplicationTermination` and chooses `.cancel`, and invokes `openAllFilesInFolder` before confirming the batch alert
- **THEN** the dirty tab stays open with its text intact, application termination is canceled (`false`), and the `52` files are not opened until `confirmPendingBatchOpen()` is called

### Requirement: REQ-004 Classic FocusedValue Menus Graphical CheatSheet and Guarded About Dialog
WHEN the user invokes menu commands, opens the Keyboard Shortcuts CheatSheet from the Help menu or toolbar button, or opens About PH.SwiftEdit, the UI command catalog SHALL expose all categorized keyboard shortcuts (`File`, `Edit`, `View`, `Navigation`, `Sidebar` including `...` parent navigation), display the `nbgv` bundle version, and validate the GitHub link through `InspectionSafetyBannerState.prepareExternalURIConfirmation` [AR-014][SEC-004][UI-008][UI-009][UI-010].

#### Scenario: P4 Complete Keyboard Shortcuts CheatSheet Catalog and Validated About GitHub Link
- **Path**: P4
- **Trait**: positive
- **GIVEN** `KeyboardShortcutsCheatSheetCatalog.allSections` and `AboutSheetDescriptor.resolve(versionManifestData:)` with root `version.json`
- **WHEN** the user toggles the graphical CheatSheet or opens About PH.SwiftEdit
- **THEN** the CheatSheet contains every required shortcut across `File` (`Cmd+N`, `Cmd+O`, `Cmd+Shift+O`, `Cmd+Shift+Option+O`, `Cmd+S`, `Cmd+Shift+S`, `Cmd+W`, `Cmd+Q`), `Edit` (`Cmd+Z`, `Cmd+Y`, `Cmd+X`, `Cmd+C`, `Cmd+V`, `Cmd+A`, `Cmd+D`), `Navigation` (`Cmd+F`, `Cmd+H`, `Cmd+G`, `Home`, `End`), `View` (`Cmd++`, `Cmd+-`, `Cmd+0`), and `Sidebar` (including `...` parent folder and the 11 sidebar actions), and `AboutSheetDescriptor` exposes version `"0.0.1-alpha1"` with a confirmed `"https://github.com/paoloinnocenti/PH.SwiftEdit"` prompt

#### Scenario: N5 Unsafe or Tampered About URI Is Blocked by ExternalLinkGuard
- **Path**: N5
- **Trait**: security
- **GIVEN** tampered external URI strings `"javascript:alert(1)"`, `"file:///etc/passwd"`, and `"https://"`
- **WHEN** `AboutSheetDescriptor.prepareRepositoryLinkConfirmation(rawURI:)` evaluates each URI
- **THEN** all three calls return `nil` and prevent external link opening

### Requirement: REQ-005 Confined 11 Sidebar File/Folder Actions and Directory-Only Finder/Terminal/iTerm2 Handoff
WHEN the user triggers any of the 11 sidebar actions, the workbench and desktop workspace adapter SHALL execute CRUD, Cut/Copy/Paste, and Trash within symlink-verified workspace scope, reconcile open tabs, and hand off verified directory-only URLs to `Finder`, `com.googlecode.iterm2` (when installed/default), or `com.apple.Terminal` via `NSWorkspace` with zero subprocesses [AR-003][AR-007][BC-012][SEC-002][SEC-003][SEC-004].

#### Scenario: P5 Sidebar CRUD Cut/Copy/Paste Confirmed Trash Tab Sync and Directory-Only iTerm2/Terminal Resolution
- **Path**: P5
- **Trait**: positive
- **GIVEN** an authorized workspace folder containing `"draft.md"` open in a tab, a `SidebarFileClipboard`, and a recording `DesktopWorkspaceIntegrating` fake configured with `iTerm2` installed and preferred
- **WHEN** the user creates folder `"docs"`, creates `"note.md"`, renames `"draft.md"` to `"final.md"`, copies and pastes `"final.md"`, confirms Delete (Trash) on the copy, reveals `"final.md"` in Finder, opens `"docs"` in Finder, and invokes `Open Terminal` while `"final.md"` (a file) is selected
- **THEN** the open tab updates in place to `"final.md"`, copy-paste produces `"final copy.md"`, confirmed Delete moves `"final copy.md"` to Trash, Finder reveals `"final.md"` and opens `"docs"`, and `Open Terminal` resolves the file `"final.md"` to its parent workspace directory URL and launches `"com.googlecode.iterm2"` (falling back to `"com.apple.Terminal"` when `iTerm2` is absent)

#### Scenario: N6 Empty Sidebar Clipboard Paste or Canceled Delete Performs Zero Mutations
- **Path**: N6
- **Trait**: negative
- **GIVEN** an empty `SidebarFileClipboard` and a pending Delete confirmation prompt for `"final.md"`
- **WHEN** `sidebarPasteItem(into:)` is called with no cut/copied item and `cancelPendingTrashItem()` is called
- **THEN** no file is created, moved, or trashed and `"final.md"` remains on disk and in its open tab

#### Scenario: N7 Escaping Symlink Executable File Target or Unallowlisted Terminal Bundle Fails Closed
- **Path**: N7
- **Trait**: security
- **GIVEN** a workspace containing `"deploy.command"`, a symlink escaping the workspace scope, and an unallowlisted terminal bundle identifier `"com.evil.shell"`
- **WHEN** `openInTerminal` is called on `"deploy.command"`, on the escaping symlink, and with `"com.evil.shell"`
- **THEN** `"deploy.command"` is never passed as a file URL to the terminal (only its verified parent directory URL is eligible), while the escaping symlink and `"com.evil.shell"` both throw `DomainError.securityScopeViolation` with zero workspace launches
