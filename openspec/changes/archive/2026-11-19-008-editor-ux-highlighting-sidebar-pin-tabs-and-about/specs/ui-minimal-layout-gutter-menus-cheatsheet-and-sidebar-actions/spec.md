# Spec Delta: Percentage Pinned Sidebar Hover Toolbar Concept E2 Logo Tab Reorder and Help About

## Purpose
Extends `REQ-001`, `REQ-004`, and `REQ-005` of `ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions` additively for percentage-only sidebar resizing (`12%..65%`) with manual `pin` collapse, sidebar zoom and disabled binary rows, hover-revealed top-bar commands beside a Concept E2 vector logo, `Help -> About PH.SwiftEdit` with MIT License link, tab left/right reordering, and interactive empty-area plus row right-click file/folder creation.

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-001 Default-Collapsed Sidebar Right-Column Tabs Left Line Gutter and Live Status Counter
WHEN initializing a workspace, opening a folder, pinning or resizing the sidebar, or moving the caret, the workbench SHALL default `isLeftSidebarCollapsed` to `true`, auto-expand on folder open, support manual `pin` collapse with percentage-only width (`12%..65%`) and zoom scaling, disable clicks on binary entries, place `EditorTabStrip` above the editor, project 1-based line numbers, and update status counters [DATA-003][DATA-004][UI-001][UI-002][UI-004][UI-005][UI-012].

Security-Waiver: additive modification only; existing scenarios P1 and N1 and all UI-001, UI-002, UI-004, UI-005, UI-012, and DATA-004 invariants remain preserved while adding manual pin collapse, percentage-only sidebar width ratio, sidebar zoom, and binary click disablement.

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

### Requirement: REQ-004 Classic FocusedValue Menus Graphical CheatSheet and Guarded About Dialog
WHEN rendering the top bar, invoking menu commands, or opening `Help -> About PH.SwiftEdit`, the UI shell SHALL show the Concept E2 vector logo beside `PH.SwiftEdit`, reveal middle command buttons only on top-bar hover while keeping Zoom and Light/Dark/Auto controls always visible, expose `About PH.SwiftEdit` in the `Help` menu, and validate both GitHub repository and MIT License links through `ExternalURIConfirmationPrompt` [AR-014][SEC-004][UI-001][UI-008][UI-009][UI-010][UI-011].

Security-Waiver: additive modification only; existing scenarios P4 and N5 and all SEC-004 external URI confirmation invariants remain preserved while adding the Help -> About entry, Concept E2 vector logo, hover topbar behavior, and validated MIT License link.

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

### Requirement: REQ-005 Confined 11 Sidebar File/Folder Actions and Directory-Only Finder/Terminal/iTerm2 Handoff
WHEN triggering sidebar actions on an entry or empty background or reordering tabs, the workbench and desktop adapter SHALL execute prompted Create File/Folder, CRUD, Cut/Copy/Paste, and Trash inside symlink-verified scope, reorder tabs within pinned or unpinned partitions, and launch verified directory-only URLs in `Finder`, `com.googlecode.iterm2`, or `com.apple.Terminal` with zero subprocesses [AR-003][AR-007][BC-008][BC-012][SEC-002][SEC-003][SEC-004].

Security-Waiver: additive modification only; existing scenarios P5, N6, and N7 and all SEC-002..004 confinement and zero-subprocess invariants remain strictly preserved while adding empty-background creation targeting, interactive name prompting, and tab reordering.

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

## REMOVED Requirements

## RENAMED Requirements
