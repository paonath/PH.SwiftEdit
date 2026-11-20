# Spec Delta: ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions

## Purpose
Synchronizes `LineNumberGutterView` scroll and soft-wrap geometry (`BUG-012`, `BUG-013`), fixes Find/Replace auto-focus, single Replace, Go-to-Line jump (`BUG-008`, `BUG-009`), resolves `Cmd+H` and duplicate `Redo` collisions (`BUG-004`, `BUG-011`, `BUG-018`), and adds configurable allowlisted terminal preference (`BUG-017`).

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-001 Default-Collapsed Sidebar Right-Column Tabs Left Line Gutter and Live Status Counter
WHEN initializing a workspace, resizing or scrolling the editor, or moving the caret across wrapped paragraphs, the workbench SHALL default `isLeftSidebarCollapsed` to `true`, align `LineNumberGutterView` scroll offsets and soft-wrap heights to TextKit 2 fragments, and highlight every visual line fragment of the active wrapped line [DATA-003][DATA-004][UI-001][UI-002][UI-004][UI-005][UI-012].

Security-Waiver: additive UI layout synchronization extending `REQ-001` (`BUG-012`, `BUG-013`) while preserving existing scenarios `P1`, `N1`, `P6`, and `N8` untouched.

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

### Requirement: REQ-003 Interactive Find Replace Go-to-Line 3-Way LineEnding Switching MRU and Dirty Close/Quit Prompts
WHEN executing Find, Replace Single, Replace All, Go to Line, or multi-tab dirty Quit, the workbench model SHALL focus the bar input automatically, increment `programmaticSelectionToken` to scroll and select targets, restore editor focus on dismiss, support single Replace, and prompt sequentially across all dirty tabs on Quit [BC-004][BC-006][BC-008][BC-011][DATA-004][DATA-006][DATA-008][UI-009].

Security-Waiver: strengthens multi-tab dirty quit data integrity (`BUG-003`) and Find/Replace focus and jump reliability (`BUG-008`, `BUG-009`) while keeping `P3` and `N4` fully intact.

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

Security-Waiver: updates `REQ-004` (`P4` and `P9` superseded via `REMOVED-SCENARIO` for `Cmd+H` -> `Opt+Cmd+F`, click-only submenu, single `Redo`, CheatSheet coverage) while retaining `N5`, `N9`, and `N11` HTTPS and binary quarantine protections identically.

- **REMOVED-SCENARIO**: `P4 Complete Keyboard Shortcuts CheatSheet Catalog and Validated About GitHub Link` — **Reason**: Listed collided `Cmd+H` (`Hide PH.SwiftEdit`) and `Cmd+Y` duplicate Redo (`BUG-004`, `BUG-011`, `BUG-018`); replaced by `P14`.
- **REMOVED-SCENARIO**: `P9 Brand Header Translucent Submenu Updated CheatSheet and Validated About Links` — **Reason**: Referenced obsolete `120 ms` dwell hover opening disabled in favor of click/keyboard-only submenu (`BUG-006`); merged into `P14`.

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

Security-Waiver: refines Terminal target choice (`BUG-017`) between existing `SEC-004` allowlisted bundles `com.apple.Terminal` and `com.googlecode.iterm2` via `PreferredTerminalApp` while keeping `P5`, `N6`, `N7`, `P8`, and `N10` fail-closed confinement untouched.

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

## REMOVED Requirements

## RENAMED Requirements
