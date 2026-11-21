# Capability: ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions

## Purpose
Synchronizes `LineNumberGutterView` scroll and soft-wrap geometry (`BUG-012`, `BUG-013`), fixes Find/Replace auto-focus, single Replace, Go-to-Line jump (`BUG-008`, `BUG-009`), resolves `Cmd+H` and duplicate `Redo` collisions (`BUG-004`, `BUG-011`, `BUG-018`), and adds configurable allowlisted terminal preference (`BUG-017`).

## Requirements

### Requirement: REQ-001 Default-Collapsed Sidebar Right-Column Tabs Left Line Gutter and Live Status Counter
WHEN initializing a workspace, resizing or scrolling the editor, or moving the caret across wrapped paragraphs, the workbench SHALL default `isLeftSidebarCollapsed` to `true`, align `LineNumberGutterView` scroll offsets and soft-wrap heights to TextKit 2 fragments, and highlight every visual line fragment of the active wrapped line [DATA-003][DATA-004][UI-001][UI-002][UI-004][UI-005][UI-012].

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

#### Scenario: P12 Gutter Scroll Sync and Multi-Fragment Wrapped Active Line Highlight Match Editor
- **Path**: P12
- **Trait**: positive
- **GIVEN** a hosted `TextKit2EditorView` containing wrapped long paragraphs scrolled vertically (`editorScrollY > 0`) alongside `LineNumberGutterView`
- **WHEN** the user scrolls down to `y = 480 pt` and places the caret on wrap line `2` of a 3-visual-line paragraph
- **THEN** the gutter clip offset synchronizes to the editor `NSClipView` offset, line number labels align with wrapped paragraph vertical positions, and `currentLineFullWidthRect()` spans all `3` `textLineFragments` of the active paragraph

#### Scenario: N12 Degraded Single-Fragment Line Keeps Finite Bounds Without NaN Geometry
- **Path**: N12
- **Trait**: negative
- **GIVEN** an empty document or zero-width layout container before initial viewport layout completes
- **WHEN** `LineNumberGutterView` and `currentLineFullWidthRect()` compute vertical offsets
- **THEN** both calculations clamp cleanly to finite non-negative coordinates with zero out-of-range array access

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
WHEN executing Find, Replace Single, Replace All, Go to Line, or multi-tab dirty Quit, the workbench model SHALL focus the bar input automatically, increment `programmaticSelectionToken` to scroll and select targets, restore editor focus on dismiss, support single Replace, and prompt sequentially across all dirty tabs on Quit [BC-004][BC-006][BC-008][BC-011][DATA-004][DATA-006][DATA-008][UI-009].

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

#### Scenario: P13 FindBar Auto-Focus Single Replace Programmatic Scroll Jump and Focus Restoration
- **Path**: P13
- **Trait**: positive
- **GIVEN** an editor containing `"one two one three"` with `FindReplaceGoToLineBar` closed and `Escape` restoring editor focus
- **WHEN** `Opt+Cmd+F` opens Find & Replace, `"one"` finds `2` matches, `Replace` runs once, `Find Next` and `Go to Line 1` run, and `Escape` closes the bar
- **THEN** `@FocusState` focuses the query field on open, `executeReplaceSingle()` replaces only the active occurrence leaving `"ONE two one three"`, `programmaticSelectionToken` bumps on every jump updating `NSTextView` selection and scroll, and `Escape` returns first responder to `SwiftEditNSTextView`

#### Scenario: N13 Empty Replace Target Out-of-Range GoToLine and Dirty Multi-Tab Cancel Fail Safely
- **Path**: N13
- **Trait**: negative
- **GIVEN** an empty Find query, Go-to-Line `"999"`, and `2` dirty tabs during `Cmd+Q` where the second prompt receives `.cancel`
- **WHEN** `executeReplaceSingle()`, `executeGoToLine()`, and `resolvePendingDirtyClose(.cancel)` run
- **THEN** single Replace does nothing, out-of-range Go-to-Line leaves selection untouched, and canceling aborts quit keeping remaining dirty tabs intact

### Requirement: REQ-004 Classic FocusedValue Menus Graphical CheatSheet and Guarded About Dialog
WHEN rendering header menus, invoking `SwiftEditCommands`, or opening the CheatSheet, the UI shell SHALL bind `Find and Replace…` to `Opt+Cmd+F` (leaving `Cmd+H` to macOS Hide), expose one single tab-aware `Redo` (`Shift+Cmd+Z`), use click-only header submenu open, list Diff/Markdown/Opt+Cmd+F in CheatSheet, and validate About HTTPS links [AR-014][DATA-003][SEC-004][UI-001][UI-008][UI-009][UI-010][UI-011].

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

#### Scenario: N11 Binary Tab Disables Duplicate Save and Format Entries in Command Descriptors
- **Path**: N11
- **Trait**: security
- **GIVEN** an active binary read-only tab (`safetyBanner.canSave == false`, `safetyBanner.canFormat == false`)
- **WHEN** command enablement state is evaluated for `Save`, `Save As…`, `Duplicate Line or Selection`, `Format Markdown Document`, and `Format Markdown Section`
- **THEN** all five mutating commands resolve as disabled while read-only navigation and inspection commands remain enabled

#### Scenario: P14 Opt+Cmd+F Menu Single Redo Click Submenu Expanded CheatSheet and Alpha5 About
- **Path**: P14
- **Trait**: positive
- **GIVEN** a live `PH.SwiftEdit` menu bar, `HeaderBrandSubmenuView`, `KeyboardShortcutsCheatSheetCatalog.allSections`, and `AboutSheetDescriptor`
- **WHEN** inspecting `Edit -> Find and Replace…`, `Edit -> Redo`, `Hide PH.SwiftEdit`, clicking the header brand button, and opening CheatSheet and About
- **THEN** `Cmd+H` stays bound solely to `Hide PH.SwiftEdit`, `Find and Replace…` binds to `Opt+Cmd+F`, only one `Redo` (`Shift+Cmd+Z`, tab-aware enabled) appears, CheatSheet includes `Opt+Cmd+F`, Diff, and Markdown authoring shortcuts, and About shows `"0.0.1-alpha5"` with HTTPS confirmations

#### Scenario: N14 Pressing Cmd+H Hides App Without Intercepting Editor Or Opening Find Bar
- **Path**: N14
- **Trait**: negative
- **GIVEN** an active editor window containing text with `FindReplaceGoToLineBar` hidden
- **WHEN** the user triggers standard macOS `Cmd+H`
- **THEN** macOS hides `PH.SwiftEdit` cleanly without opening `FindReplaceGoToLineBar`, while `Opt+Cmd+F` opens Find & Replace without hiding the application

### Requirement: REQ-005 Confined 11 Sidebar File/Folder Actions and Directory-Only Finder/Terminal/iTerm2 Handoff
WHEN triggering sidebar actions on an entry or background, reordering tabs, or launching Terminal, the workbench and desktop adapter SHALL execute confined CRUD/Copy/Paste/Trash, respect user-configured `PreferredTerminalApp` (`.auto`, `.iTerm2`, `.terminal`), and launch strictly allowlisted bundles with verified directory-only URLs [AR-003][AR-007][BC-008][BC-012][SEC-002][SEC-003][SEC-004].

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

#### Scenario: P15 PreferredTerminalApp Choice Respects Terminal or iTerm2 Without Auto-Forcing iTerm2
- **Path**: P15
- **Trait**: positive
- **GIVEN** a recording `DesktopWorkspaceIntegrating` fake on a machine where both `iTerm2` and `Terminal` are installed and `PreferredTerminalApp.terminal` (or `.auto`) is configured
- **WHEN** `openInTerminal` runs on a verified workspace file `"final.md"`
- **THEN** `openInTerminal` resolves `"final.md"`'s verified parent directory URL and launches `"com.apple.Terminal"` when `.terminal` or system default applies, using `"com.googlecode.iterm2"` only when `.iTerm2` is chosen

#### Scenario: N15 Disallowed Terminal Bundle or Escaping Directory Still Fails Closed
- **Path**: N15
- **Trait**: security
- **GIVEN** an unallowlisted Terminal bundle identifier `"com.untrusted.term"` or symlinked parent folder resolving outside workspace scope
- **WHEN** `openInTerminal` attempts launch
- **THEN** the adapter rejects immediately with `DomainError.securityScopeViolation` and launches zero workspace URLs
