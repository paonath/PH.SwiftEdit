# Capability: editor-ux-highlighting-sidebar-pin-tabs-and-about

## Purpose
Updates `REQ-006` from `120 ms` dwell header submenu opening to click/keyboard-only activation while aligning `REQ-007`'s About fallback version string to `"0.0.1-alpha5"` and preserving all sidebar confinement, theme, and external HTTPS confirmation security checks.

## Requirements

### Requirement: REQ-001 Nested Bracket Depth and Inline or Multiline Backtick Scanning
WHEN evaluating a non-binary text `DocumentSnapshot`, the bracket and backtick scanning engines SHALL assign 0-based `nestingDepth` and `enclosingPairs` to every matched `()`, `[]`, and `{}` pair, emit inline and multiline fenced backtick spans, and abort lines exceeding `4096` UTF-16 code units [AR-004][AR-012][BC-011][SEC-012][TEST-005].

#### Scenario: P1 Nested Mixed Brackets and Inline Plus Fenced Backtick Spans
- **Path**: P1
- **Trait**: positive
- **GIVEN** a text `DocumentSnapshot` containing `"scrivo{ho le graffe, le quadre[dentro le quadre ho le tonde(qua) e (pure qua)]}"` followed by inline `` `token` `` and a multiline `` ```swift\nlet x = 1\n``` `` block
- **WHEN** `SearchDiffAndBracketEngine.evaluateBrackets` and `BacktickHighlightScanner.scan` evaluate the snapshot with caret inside `"(qua)"`
- **THEN** `{}` has `nestingDepth == 0`, `[]` has `nestingDepth == 1`, both `()` pairs have `nestingDepth == 2`, `enclosingPairs` lists `[{} , [], ()]` outer-to-inner, and `BacktickHighlightScanner` returns one `.inlineCode` span and one `.fencedMultiline` span

#### Scenario: N1 Unclosed Backticks and Unbalanced Nested Brackets Report Deterministically
- **Path**: N1
- **Trait**: negative
- **GIVEN** a text `DocumentSnapshot` containing an unclosed inline backtick `` `orphan ``, an unclosed triple-backtick fence, and mismatched brackets `"{ [ ) }"`
- **WHEN** `SearchDiffAndBracketEngine.evaluateBrackets` and `BacktickHighlightScanner.scan` inspect the snapshot
- **THEN** unbalanced brackets report exact UTF-16 offsets, unclosed inline backticks produce no spurious span, and an unclosed fenced block terminates cleanly at buffer end without crashing

#### Scenario: N2 Overlong Line or Binary Snapshot Degrades Both Scanners Safely
- **Path**: N2
- **Trait**: security
- **GIVEN** a `DocumentSnapshot` with a single `4097`-unit UTF-16 line or `isBinaryReadOnly == true`
- **WHEN** `SearchDiffAndBracketEngine.evaluateBrackets` and `BacktickHighlightScanner.scan` execute
- **THEN** both engines return `.degradedOrTimedOut` without scanning full line payloads or mutating state

### Requirement: REQ-002 Markdown Smart Enter List and Blockquote Continuation
WHEN the user presses Enter in a Markdown or untitled buffer outside fenced code, the smart newline engine SHALL continue bullets, tasks, numbered items, pseudo-outline markers (`a.`, `1.1`), and blockquotes, and clear empty markers, exiting nested empty items in two stages [BC-004][BC-006][BC-011][DATA-003][SEC-012].

#### Scenario: P2 Unordered Task Ordered and Blockquote Continuation Plus Empty Marker Exit
- **Path**: P2
- **Trait**: positive
- **GIVEN** Markdown buffers containing `"  - alpha"`, `"- [x] done"`, `"3. third"`, `"2) second"`, `"> quoted"`, and an empty marker line `"- "`
- **WHEN** `MarkdownSmartNewlineEngine.evaluateNewline(in:caretLocation:isMarkdownDocument:)` evaluates Enter at the end of each line
- **THEN** the engine proposes `"\n  - "`, `"\n- [ ] "`, `"\n4. "`, `"\n3) "`, `"\n> "`, and removes `"- "` on the empty marker line to exit the list

#### Scenario: N3 Fenced Code Block Non-Markdown File or Plain Prose Returns No Smart Edit
- **Path**: N3
- **Trait**: negative
- **GIVEN** a caret positioned inside a `` ```markdown\n- item `` fenced code block, a `.swift` non-Markdown buffer containing `"- item"`, or a plain prose Markdown line
- **WHEN** `MarkdownSmartNewlineEngine.evaluateNewline(in:caretLocation:isMarkdownDocument:)` runs
- **THEN** all three calls return `nil` so standard newline insertion applies

#### Scenario: N4 Binary Snapshot Out-of-Range Caret or Overlong Line Returns Nil Safely
- **Path**: N4
- **Trait**: security
- **GIVEN** a binary read-only snapshot, a caret offset outside `0...text.utf16.count`, or a line exceeding `4096` UTF-16 code units
- **WHEN** `MarkdownSmartNewlineEngine.evaluateNewline(in:caretLocation:isMarkdownDocument:)` runs
- **THEN** each call returns `nil` without throwing or mutating the document

#### Scenario: P3 Pseudo-Outline Continuation and Two-Stage Nested Empty Exit
- **Path**: P3
- **Trait**: positive
- **GIVEN** Markdown buffers `"    a. alpha"`, `"    1.1 uno"`, and a nested empty item `"2. due\n    1. "`
- **WHEN** `MarkdownSmartNewlineEngine.evaluateNewline` runs at the end of each
- **THEN** it proposes `"\n    b. "` and `"\n    1.2 "`, and on the nested empty item it first outdents it to `"3. "` and on a second Enter clears the marker

### Requirement: REQ-003 Partition-Preserving Tab Left and Right Reordering
WHEN the user reorders an open tab left, right, or to a target index, the workspace tab session SHALL reposition the tab inside its pinned or unpinned partition while preserving `activeTabID` and pinned-first ordering [BC-006][BC-008][TEST-002].

#### Scenario: P3 Reordering Unpinned and Pinned Tabs Preserves Partition Ordering and Active Tab
- **Path**: P3
- **Trait**: positive
- **GIVEN** a `WorkspaceTabSession` with pinned tabs `[P1, P2]` and unpinned tabs `[U1, U2, U3]` with `activeTabID == U3`
- **WHEN** `moveTabLeft(id: U3)` and `moveTabRight(id: P1)` execute
- **THEN** `tabs` orders `[P2, P1, U1, U3, U2]` and `activeTabID` remains `U3`

#### Scenario: N5 Boundary Moves Remain Inert and Unknown Tab ID Throws TabNotFound
- **Path**: N5
- **Trait**: negative
- **GIVEN** a `WorkspaceTabSession` with pinned `[P1]` and unpinned `[U1, U2]`
- **WHEN** `moveTabRight(id: P1)` attempts to cross into unpinned slots, `moveTabLeft(id: U1)` attempts to cross into pinned slots, and `moveTabLeft(id: unknownID)` runs
- **THEN** both cross-partition boundary moves leave `tabs` unchanged and the unknown `DocumentID` throws `DomainError.tabNotFound`

### Requirement: REQ-004 Confined Sidebar Binary Entry Classification and Disabled Interaction
WHEN enumerating shallow workspace entries for the left sidebar, the folder navigator SHALL classify regular files containing `0x00` within their first `8 KiB` as `isBinary == true` inside symlink-verified scope and block click-to-open on binary entries while retaining right-click Finder and Trash actions [BC-007][DATA-003][DATA-007][SEC-002][SEC-003][UI-008].

#### Scenario: P4 Binary Entry Flagged With Disabled Gray Tokens and Click Blocked
- **Path**: P4
- **Trait**: positive
- **GIVEN** a granted workspace folder containing UTF-8 `"notes.md"` and NUL-bearing `"archive.bin"`
- **WHEN** `DotfileFolderNavigator.listEntries(in:withinScope:)` runs and the workbench resolves palette tokens and invokes `openFolderEntry` on `"archive.bin"`
- **THEN** `"archive.bin"` carries `isBinary == true`, `"notes.md"` carries `isBinary == false`, `PurpleThemePalette` resolves `#9CA3AF` in Dark and `#52525B` in Light for disabled binary rows, and `openFolderEntry` performs zero tab opens on `"archive.bin"` while `sidebarRevealInFinder` and `requestSidebarTrashItem` remain available

#### Scenario: N6 Escaping Symlink Aborts Before Binary Probing With Balanced Scope Release
- **Path**: N6
- **Trait**: security
- **GIVEN** a granted workspace folder containing a symbolic link pointing to an external binary outside the workspace scope
- **WHEN** `DotfileFolderNavigator.listEntries(in:withinScope:)` executes with a counting `SecurityScopedResourceAccessing` fake
- **THEN** the call throws `DomainError.securityScopeViolation` before any `8 KiB` probe occurs and `startCount == stopCount`

### Requirement: REQ-005 Live Light Dark Auto Selector Current-Line Highlighting and Sidebar Zoom Scaling
WHEN switching appearance modes, syncing unmasked system appearance, or adjusting zoom across `50%..300%`, the workbench and theme controller SHALL update `Light`, `Dark`, and `Auto` semantic palettes, synchronize `NSApp.appearance` and `TextKit2EditorView` selection, caret, and scroller styling without reloading buffers or poisoning `systemPrefersDark`, and scale editor and left sidebar typography proportionally [UI-001][UI-002][UI-003][UI-004][UI-005].

#### Scenario: P5 Three-Way Appearance Switch System Auto Sync Highlight Tokens and Sidebar Zoom
- **Path**: P5
- **Trait**: positive
- **GIVEN** a `SwiftEditWorkbenchModel` in `.auto` mode with `EditorZoomController` at `100%`
- **WHEN** `updateSystemColorScheme(prefersDark: false)` runs, then `appearanceMode` switches to `.black`, `.light`, and `.auto` with `prefersDark: true`, and `zoomController.zoomIn()` steps to `150%`
- **THEN** `.auto` switches seamlessly between Light (`#FFFFFF`/`#000000`, current-line `#F3F0FA`) and Black (`#000000`/`#FFFFFF`, current-line `#161224`) without reloading open buffers, nested bracket and backtick tokens are populated for both modes, and `sidebarScaledFontSizePoints` scales proportionally from `13.0` to `19.5`

#### Scenario: N7 Sidebar Zoom Scaling Clamps Safely at 50 and 300 Percent Boundaries
- **Path**: N7
- **Trait**: negative
- **GIVEN** an `EditorZoomController` stepped below `50%` and above `300%`
- **WHEN** `sidebarScaledFontSizePoints` and `scaledFontSizePoints` are read at both limits
- **THEN** `zoomPercent` clamps at `50` (`6.5pt` sidebar) and `300` (`39.0pt` sidebar) without mutating open document text

#### Scenario: P8 Unmasked System Appearance Detector Restores Light Mode After Forced Black Override
- **Path**: P8
- **Trait**: positive
- **GIVEN** a `SwiftEditWorkbenchModel` initialized with `systemDarkDetector: { false }` in `.auto` mode
- **WHEN** `appearanceMode` switches `.auto -> .black`, a forced dark container `colorScheme` signal arrives, and `appearanceMode` switches back to `.auto`
- **THEN** initial Frame 0 mode is `.light`, `.black` resolves `.black`, and returning to `.auto` restores `.light` immediately

#### Scenario: N11 Forced Light or Black Mode Ignores Tainted Container ColorScheme Signals
- **Path**: N11
- **Trait**: negative
- **GIVEN** `SwiftEditWorkbenchModel` initialized with `systemDarkDetector: { true }` and switched explicitly to `.light`
- **WHEN** SwiftUI emits a light container `colorScheme` change (`prefersDark: false`) while `appearanceMode == .light` and the user then switches to `.auto`
- **THEN** `systemPrefersDark` remains `true` and `.auto` resolves `.black`

### Requirement: REQ-006 Percentage-Based Collapsible Pinned Sidebar Hover Topbar and Confined Right-Click Create
WHEN laying out the left sidebar, interacting with the top bar brand region, or right-clicking the sidebar to create a file or folder, the workbench SHALL size sidebar width as `0.12...0.65` of container width, support manual pin/collapse, toggle `HeaderBrandSubmenuView` solely via click or keyboard, keep Logo, Zoom, and Theme visible, and validate prompted creation names inside scope [BC-012][SEC-003][SEC-012][UI-001][UI-005][UI-011].

#### Scenario: P6 Proportional Sidebar Width Pin Collapse Hover Topbar and Empty-Area Right-Click Create
- **Path**: P6
- **Trait**: positive
- **GIVEN** a `SidebarLayoutGeometry` across `1200pt` and `2560pt` display widths, an expanded pinned sidebar, and a mounted workspace folder
- **WHEN** `sidebarWidthRatio` updates to `0.40`, `toggleSidebarPinCollapse()` runs, `isToolbarHovered` toggles `false -> true`, and `resolveSidebarCreationDirectory(for: nil)` + `sidebarCreateFile(named: "new.md", in:)` execute
- **THEN** computed widths scale strictly to `480pt` and `1024pt` (`40%`), unpinning collapses the sidebar exposing the reopen control, command buttons track `isToolbarHovered` while Logo, Zoom, and Theme remain visible, and `"new.md"` is created inside the current folder

#### Scenario: N8 Out-of-Bounds Sidebar Ratio Zero Container Width or Invalid Prompt Name Fails Safely
- **Path**: N8
- **Trait**: negative
- **GIVEN** candidate sidebar ratios `0.02` and `0.95`, container width `0`, and prompted creation names `""` and `"."`
- **WHEN** `SidebarLayoutGeometry.clampedRatio`, `resolvedWidth(forContainerWidth:)`, and `sidebarCreateFile` / `sidebarCreateFolder` execute
- **THEN** ratios clamp to `0.12` and `0.65`, zero container width resolves safely to `0`, and invalid names are rejected without writing to disk

#### Scenario: N9 Traversal or Symlink Escape in Right-Click Create Fails Closed
- **Path**: N9
- **Trait**: security
- **GIVEN** right-click creation inputs `"../escape.md"`, `"a/b.md"`, a BiDi override name `"a\u{202E}b.md"`, and a symlinked target folder resolving outside workspace scope
- **WHEN** `sidebarCreateFile` and `sidebarCreateFolder` evaluate each input
- **THEN** every attempt fails closed with `DomainError.invalidItemName` or `DomainError.securityScopeViolation` and creates zero files or directories

#### Scenario: P9 Proportional Sidebar Width Pin Collapse Dwell Header Submenu and Empty-Area Right-Click Create
- **Path**: P9
- **Trait**: positive
- **GIVEN** `SidebarLayoutGeometry` across `1200pt` and `2560pt` display widths, an expanded pinned sidebar, `HeaderSubmenuStateMachine`, and a mounted workspace folder
- **WHEN** `sidebarWidthRatio` updates to `0.40`, `toggleSidebarPinCollapse()` runs, brand header dwell reaches `120 ms`, and `resolveSidebarCreationDirectory(for: nil)` + `sidebarCreateFile(named: "new.md", in:)` execute
- **THEN** computed widths scale strictly to `480pt` and `1024pt` (`40%`), unpinning collapses the sidebar, `HeaderBrandSubmenuView` opens without shifting editor layout while Logo, Zoom, and Theme remain visible, and `"new.md"` is created inside the current folder

#### Scenario: P10 Proportional Sidebar Width Pin Collapse Click Header Submenu and Empty-Area Create
- **Path**: P10
- **Trait**: positive
- **GIVEN** `SidebarLayoutGeometry` across `1200pt` and `2560pt` widths, an expanded pinned sidebar, `HeaderSubmenuStateMachine`, and a mounted workspace folder
- **WHEN** `sidebarWidthRatio` updates to `0.40`, `toggleSidebarPinCollapse()` runs, `clickToggle()` activates the brand button, and `sidebarCreateFile(named: "new.md", in:)` runs
- **THEN** computed widths scale to `480pt` and `1024pt`, unpinning collapses the sidebar, `HeaderBrandSubmenuView` stays persistently open past `1000 ms` with `0.0 pt` shift, and `"new.md"` is created inside scope

#### Scenario: N13 Pointer Hover and Active Sidebar Divider Drag Never Open Submenu
- **Path**: N13
- **Trait**: negative
- **GIVEN** a `SwiftEditWorkbenchModel` during normal pointer hover over the brand header or an active sidebar divider drag (`isDraggingTabOrSidebar == true`)
- **WHEN** hover ticks and drag events run without a click or keyboard activation
- **THEN** `HeaderSubmenuStateMachine.isOpen` remains `false` and sidebar ratio clamping (`0.12...0.65`) operates uninterrupted

### Requirement: REQ-007 Concept E2 Vector Brand Logo and Help About Dialog With Validated Repo and License Links
WHEN rendering the top bar brand header or opening `Help -> About PH.SwiftEdit`, the UI shell SHALL display the Concept E2 vector logo small beside `PH.SwiftEdit` and large inside the About dialog alongside App Name, `nbgv` version (fallback `"0.0.1-alpha5"`), validated GitHub repo link, and validated MIT License link [AR-014][SEC-004][UI-001][UI-008][UI-010].

#### Scenario: P7 Small Topbar Logo Large About Logo Version and Validated Repo Plus License Links
- **Path**: P7
- **Trait**: positive
- **GIVEN** `SwiftEditBrandLogoGeometry`, `SwiftEditCommands` Help menu descriptors, and `AboutSheetDescriptor.resolve(versionManifestData:)`
- **WHEN** the top bar and `Help -> About PH.SwiftEdit` resolve brand metadata and prepare confirmation prompts for both repository and license links
- **THEN** the Concept E2 vector geometry matches `#0B0614`/`#A78BFA`/`#C4B5FD`->`#7C3AED`, the Help menu exposes `"About PH.SwiftEdit"`, and `AboutSheetDescriptor` exposes `"PH.SwiftEdit"`, `"0.0.1-alpha1"`, `"https://github.com/paoloinnocenti/PH.SwiftEdit"`, and `"MIT License"` (`"https://github.com/paoloinnocenti/PH.SwiftEdit/blob/main/LICENSE"`) with HTTPS confirmation prompts

#### Scenario: N10 Tampered or Non-HTTPS License or Repository URI Is Blocked
- **Path**: N10
- **Trait**: security
- **GIVEN** tampered license or repository URIs `"http://github.com/paoloinnocenti/PH.SwiftEdit/blob/main/LICENSE"`, `"javascript:alert(1)"`, and `"file:///LICENSE"`
- **WHEN** `AboutSheetDescriptor.prepareExternalLinkConfirmation(rawURI:)` validates each URI
- **THEN** all three calls return `nil` and block `NSWorkspace.shared.open`

#### Scenario: P11 AboutSheetDescriptor Fallback Matches Bundle Version Alpha5 When Manifest Absent
- **Path**: P11
- **Trait**: positive
- **GIVEN** a `nil` bundle resource and missing `CFBundleShortVersionString` in `AboutSheetDescriptor.resolve(versionManifestData: nil)`
- **WHEN** `AboutSheetDescriptor` resolves its deterministic version fallback
- **THEN** the resolved fallback string equals `"0.0.1-alpha5"` instead of stale `"0.0.1-alpha3"`, and official GitHub HTTPS repo and MIT License prompts remain valid
