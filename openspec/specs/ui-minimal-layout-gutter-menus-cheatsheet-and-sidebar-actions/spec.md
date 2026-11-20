# Capability: ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions

## Purpose
Updates `REQ-004` of `ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions` to replace inline horizontal top-bar hover buttons with the root-`ZStack` translucent `HeaderBrandSubmenuView`, add `Cmd+P` (`Toggle Markdown Preview`) and `Cmd+Option+Shift+F` (`Format Markdown Section`) to `KeyboardShortcutsCheatSheetCatalog`, and enforce binary quarantine command lockouts across `SwiftEditCommands` while preserving all HTTPS external-link guards.

## Requirements

### Requirement: REQ-001 Default-Collapsed Sidebar Right-Column Tabs Left Line Gutter and Live Status Counter
WHEN initializing a workspace, opening a folder, pinning or resizing the sidebar, or moving the caret, the workbench SHALL default `isLeftSidebarCollapsed` to `true`, auto-expand on folder open, support manual `pin` collapse with percentage-only width (`12%..65%`) and zoom scaling, disable clicks on binary entries, place `EditorTabStrip` above the editor, project 1-based line numbers, and update status counters [DATA-003][DATA-004][UI-001][UI-002][UI-004][UI-005][UI-012].

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

#### Scenario: P6 Percentage Sidebar Width Pin Collapse and Disabled Binary Sidebar Click
- **Path**: P6
- **Trait**: positive
- **GIVEN** an open sidebar with `sidebarWidthRatio == 0.35`, container widths `1000pt` and `2000pt`, and a binary `FolderEntryDescriptor` (`isBinary == true`)
- **WHEN** `SidebarLayoutGeometry` evaluates widths, `toggleSidebarPinCollapse()` runs, and `openFolderEntry` is invoked on the binary entry
- **THEN** computed widths equal `350pt` and `700pt`, unpinning sets `isLeftSidebarCollapsed == true`, and clicking the binary entry opens no tab

#### Scenario: N8 Out-of-Range Sidebar Width Ratio Clamps Into 12 to 65 Percent
- **Path**: N8
- **Trait**: negative
- **GIVEN** candidate sidebar ratios `0.05` and `0.90`
- **WHEN** `updateSidebarWidthRatio(_:)` runs
- **THEN** `sidebarWidthRatio` clamps to `0.12` and `0.65` respectively

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
WHEN rendering the header, opening `HeaderBrandSubmenuView`, invoking `SwiftEditCommands`, or opening `About PH.SwiftEdit`, the UI shell SHALL show the Concept E2 logo with a dwell-gated translucent submenu, isolate Zoom and Appearance on the right, list `Cmd+P` and `Cmd+Option+Shift+F` in the CheatSheet, disable mutating commands on binary tabs, and guard external About links [AR-014][DATA-003][SEC-004][UI-001][UI-008][UI-009][UI-010][UI-011].

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

#### Scenario: P7 Hover-Revealed Topbar Concept E2 Logo Help About Entry and Validated License Link
- **Path**: P7
- **Trait**: positive
- **GIVEN** `SwiftEditWorkbenchModel`, `SwiftEditBrandLogoGeometry`, and `AboutSheetDescriptor.resolve(versionManifestData:)`
- **WHEN** top-bar hover transitions `false -> true` and `AboutSheetDescriptor` prepares repository and license links
- **THEN** middle command buttons stay hidden until hover while Logo, Zoom, and Theme remain always visible, and both `"https://github.com/paoloinnocenti/PH.SwiftEdit"` and `"https://github.com/paoloinnocenti/PH.SwiftEdit/blob/main/LICENSE"` produce valid HTTPS confirmation prompts

#### Scenario: N9 Non-HTTPS License URI Is Rejected by ExternalLinkGuard
- **Path**: N9
- **Trait**: security
- **GIVEN** tampered license URIs `"http://example.com/LICENSE"` and `"file:///etc/passwd"`
- **WHEN** `AboutSheetDescriptor.prepareExternalLinkConfirmation(rawURI:)` evaluates each URI
- **THEN** both calls return `nil`

#### Scenario: P9 Brand Header Translucent Submenu Updated CheatSheet and Validated About Links
- **Path**: P9
- **Trait**: positive
- **GIVEN** `SwiftEditWorkbenchModel`, `HeaderCommandCatalog`, `KeyboardShortcutsCheatSheetCatalog.allSections`, and `AboutSheetDescriptor.resolve(versionManifestData:)`
- **WHEN** the brand header dwell completes (`120 ms`), the CheatSheet catalog is inspected, and `AboutSheetDescriptor` validates repository and MIT License links
- **THEN** `HeaderBrandSubmenuView` opens with descriptive titles and badges while Zoom and Appearance stay isolated on the right, the CheatSheet includes `Cmd+Option+Shift+F` (`Format Markdown Section`) and `Cmd+P` (`Toggle Markdown Preview`), and both official GitHub HTTPS URLs produce valid confirmation prompts

#### Scenario: N11 Binary Tab Disables Duplicate Save and Format Entries in Command Descriptors
- **Path**: N11
- **Trait**: security
- **GIVEN** an active binary read-only tab (`safetyBanner.canSave == false`, `safetyBanner.canFormat == false`)
- **WHEN** command enablement state is evaluated for `Save`, `Save As…`, `Duplicate Line or Selection`, `Format Markdown Document`, and `Format Markdown Section`
- **THEN** all five mutating commands resolve as disabled while read-only navigation and inspection commands remain enabled

### Requirement: REQ-005 Confined 11 Sidebar File/Folder Actions and Directory-Only Finder/Terminal/iTerm2 Handoff
WHEN triggering sidebar actions on an entry or empty background or reordering tabs, the workbench and desktop adapter SHALL execute prompted Create File/Folder, CRUD, Cut/Copy/Paste, and Trash inside symlink-verified scope, reorder tabs within pinned or unpinned partitions, and launch verified directory-only URLs in `Finder`, `com.googlecode.iterm2`, or `com.apple.Terminal` with zero subprocesses [AR-003][AR-007][BC-008][BC-012][SEC-002][SEC-003][SEC-004].

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

#### Scenario: P8 Empty-Area Sidebar Create Target Resolution and Workbench Tab Reorder
- **Path**: P8
- **Trait**: positive
- **GIVEN** a mounted workspace folder `"/tmp/ws"` with subfolder `"/tmp/ws/docs"`, file `"/tmp/ws/readme.md"`, and three open unpinned tabs `[A, B, C]`
- **WHEN** `resolveSidebarCreationDirectory` evaluates `nil` (empty area), `"docs"`, and `"readme.md"`, creates `"draft.md"` in `"/tmp/ws"`, and runs `moveTabLeft(id: C)`
- **THEN** creation targets resolve to `"/tmp/ws"`, `"/tmp/ws/docs"`, and `"/tmp/ws"` respectively, `"draft.md"` is created inside scope, and tabs reorder to `[A, C, B]`

#### Scenario: N10 Traversal Name in Prompted Sidebar Create Fails Closed
- **Path**: N10
- **Trait**: security
- **GIVEN** an interactive sidebar Create File or Create Folder name `"../outside.md"`
- **WHEN** `sidebarCreateFile(named: "../outside.md", in:)` runs
- **THEN** the operation fails closed with `DomainError.invalidItemName` and creates no file on disk
