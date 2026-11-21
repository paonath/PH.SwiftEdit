---
id: "brief-editor-ux-highlighting-sidebar-pin-tabs-and-about"
change_id: "008-editor-ux-highlighting-sidebar-pin-tabs-and-about"
capability: "editor-ux-highlighting-sidebar-pin-tabs-and-about"
branch: "feature/FirstStub"
modifies_specs: "markdown-lint-format-bracket-and-diff (REQ-003), notepadpp-tabs-session-recovery-and-dotfiles (REQ-001, REQ-004), swifteditui-purple-zed-layout-textkit2-and-appicons (REQ-001, REQ-003), ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions (REQ-001, REQ-004, REQ-005)"
status: "approved-via-qa"
date: "2026-11-19"
owners:
  - "swift-macos-expert"
  - "cyber-security-expert"
---

# TDD Specification Brief: `PH.SwiftEdit` Editor UX, Highlighting, Percentage-Resized Collapsible Sidebar, Tab Reordering & Help About Integrations

## 1. Context & Source Traceability

- **Originating User Request**: 13 integrations and bug fixes for `PH.SwiftEdit`:
  1. Fix Light / Dark / Auto appearance selector (currently clipped/stuck on `Auto` and hardcoded `systemPrefersDark: true`).
  2. Markdown smart Enter continuation (propose next list bullet `-`/`*`/`+`, task item `- [ ]`, incremented ordered item `N.`/`N)`, or blockquote `>` on Enter in `.md`/`.markdown`/`.mdown`/`.mkd` and Untitled tabs; exit list on Enter over an empty marker; suppress inside fenced `` ``` `` code blocks).
  3. Subtle current-line background highlight (`#161224` slightly lighter than `#000000` in Dark/Black mode; `#F3F0FA` subtle tint over `#FFFFFF` in Light mode).
  4. Visual nested bracket balancing highlighting (`{}`, `[]`, `()` color-coded by `nestingDepth` across nested expressions such as `scrivo{ho le graffe, le quadre[dentro le quadre ho le tonde(qua) e (pure qua)]}`, plus active-pair emphasis and unbalanced error highlighting).
  5. Inline single/multi-backtick (`` `...` ``) and multiline fenced backtick (`` ```...``` ``) visual highlighting.
  6. Collapsible left navigation panel with manual `pin` control (unpinning collapses sidebar leaving a compact left-edge reopen handle + `Cmd+B`) and **strictly percentage-based** wider resizing (`12%..65%` of container width, zero hardcoded pixel min/max caps across displays).
  7. Zoom (`50%..300%`) scales the left navigation panel typography, icons, and row spacing proportionally alongside the editor and line gutter.
  8. Binary files in the left sidebar render as disabled with gray foreground (light gray `#9CA3AF` in Dark mode, dark gray `#52525B` in Light mode) and ignore open-on-click, while preserving right-click context actions (`Reveal in Finder`, `Delete (Move to Trash)`).
  9. Reorderable tabs left/right in the top `EditorTabStrip` (drag-and-drop and explicit Move Left/Right actions preserving pinned-first partition).
  10. Right-click context menu on the left sidebar (both on entries AND on empty background space) to create a new file or new folder at the clicked position with an interactive single-segment name prompt.
  11. Top-bar command buttons (to the right of `PH.SwiftEdit`) hidden by default and revealed only on mouse hover over the top bar area, while Zoom (`-`/`%`/`+`) and Light/Dark/Auto selector remain ALWAYS visible.
  12. Small Concept E2 vector logo rendered beside `PH.SwiftEdit` in the top bar.
  13. `About PH.SwiftEdit` menu item inside the `Help` menu (in addition to the App menu) opening a modal dialog displaying App Name, large Concept E2 vector logo, application version (`version.json`/`Info.plist`), validated GitHub repository link, and validated MIT License link.
- **Active Git Branch**: `feature/FirstStub` (changes `000..007` archived and passing).
- **Consolidated Specs Modified (`modifies_specs`)**:
  - `markdown-lint-format-bracket-and-diff` (`REQ-003` MODIFIED additively for `nestingDepth` and `enclosingPairs`).
  - `notepadpp-tabs-session-recovery-and-dotfiles` (`REQ-001` MODIFIED additively for tab reordering within pinned/unpinned partitions; `REQ-004` MODIFIED additively for `FolderEntryDescriptor.isBinary` via bounded `8 KiB` probe).
  - `swifteditui-purple-zed-layout-textkit2-and-appicons` (`REQ-001` & `REQ-003` MODIFIED additively for 3-way Light/Dark/Auto live colorScheme sync, current-line/nested-bracket/backtick/binary-disabled tokens, sidebar zoom scaling, and non-mutating TextKit 2 rendering attributes).
  - `ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions` (`REQ-001`, `REQ-004`, `REQ-005` MODIFIED additively for percentage-resized pinned/collapsible sidebar, hover-revealed topbar commands, Concept E2 logo, `Help -> About` with License link, tab reorder controls, and empty-area right-click New File/Folder prompt).
- **Governing Constitutional Rules (`v1.3.0`)**: `[AR-001]`, `[AR-002]`, `[AR-003]`, `[AR-004]`, `[AR-005]`, `[AR-012]`, `[AR-014]`, `[BC-001]`, `[BC-004]`, `[BC-006]`, `[BC-007]`, `[BC-008]`, `[BC-011]`, `[BC-012]`, `[DATA-003]`, `[DATA-007]`, `[DATA-008]`, `[SEC-002]`, `[SEC-003]`, `[SEC-004]`, `[SEC-011]`, `[SEC-012]`, `[TEST-001]`..`[TEST-005]`, `[UI-001]`..`[UI-012]`, `[SDD-001]`..`[SDD-003]`.
- **Human Confirmation**: Confirmed via `ask_question` across 3 turns (including write-in refinement enforcing percentage-only sidebar resize across displays).

## 2. Domain, Architecture & Security Expert Notes

- **`swift-macos-expert`**:
  - **Core Engines (`SwiftEditCore`, zero `AppKit`/`SwiftUI`, `AR-002`)**:
    - `BracketMatcher.swift` (`SearchDiffAndBracketEngine`): extend `BracketPairSpan` with `nestingDepth: Int` (0-based stack depth when opened) and `BracketBalanceResult` with `enclosingPairs: [BracketPairSpan]` (ordered outer-to-inner for the active caret) while preserving backward-compatible initializer default `nestingDepth: Int = 0` and the `4096` UTF-16 line cap.
    - `MarkdownSmartNewlineEngine.swift` (`MarkdownLintAndFormat`): pure value-type engine `evaluateNewline(in:caretLocation:isMarkdownDocument:)` returning `SmartNewlineEdit` (`TextEdit` + `newCaretLocation`) for unordered lists (`- `, `* `, `+ `), task lists (`- [ ] `, `- [x] ` -> `- [ ] `), ordered lists (`N. `, `N) ` -> `(N+1). ` / `(N+1)) `), and blockquotes (`> `, nested `> > `). Pressing Enter on an empty list/quote marker strips the marker to exit the list; inside fenced `` ``` `` code blocks, non-Markdown files, or binary read-only buffers it returns `nil` (standard newline).
    - `BacktickHighlightScanner.swift` (`SearchDiffAndBracketEngine`): pure single-pass UTF-16 scanner detecting `.fencedMultiline` (`` ``` `` or longer, matching closing fence length >= opening length) and `.inlineCode` (matched N-backtick spans outside fenced blocks), guarded by the `4096` UTF-16 line length ceiling and binary read-only refusal.
    - `WorkspaceTabSession.swift` (`WorkspaceAndTabSession`): add `moveTab(id:toIndex:)`, `moveTabLeft(id:)`, `moveTabRight(id:)` enforcing strict pinned-first partitioning (`pinned` tabs reorder exclusively within `0..<pinnedCount`; `unpinned` tabs reorder exclusively within `pinnedCount..<tabs.count`).
    - `DotfileFolderNavigator.swift` (`WorkspaceAndTabSession`): extend `FolderEntryDescriptor` with `isBinary: Bool` (default `false` for backward compatibility) computed by reading at most `DocumentCodec.binaryProbeBytes` (`8 KiB`) on regular non-directory entries within symlink-verified scope using `DocumentCodec.isBinaryPrefix(_:)`.
  - **UI Architecture (`SwiftEditUI`, `@MainActor`, `#if os(macOS)`)**:
    - **Appearance Selector & Live Auto Sync**: replace broken segmented `Picker` with an explicit 3-button pill selector (`Light`, `Dark`, `Auto`) always visible on the right of the top bar. `SwiftEditRootView` observes `@Environment(\.colorScheme)` and forwards updates to `model.updateSystemColorScheme(prefersDark:)` so `.auto` resolves dynamically in real time; apply `.preferredColorScheme` when `.light`/`.black` is explicitly chosen.
    - **Concept E2 Vector Logo (`SwiftEditBrandLogoView`)**: pure SwiftUI `Canvas`/`Shape` faithfully rendering `docs/design/assets/logo-e2-refined.svg` (`#0B0614` rounded ground, `#A78BFA` inverted triangle, `#C4B5FD`->`#7C3AED` feather with `#0B0614` rachis & barbs), rendered at `20x20` beside `PH.SwiftEdit` in the top bar and `84x84` in `AboutSheetView`.
    - **Hover-Revealed Top Bar**: split top bar into persistent left brand group (Logo + `PH.SwiftEdit`), hover-revealed middle command group (`Folder…`, `File…`, `New`, `Save`, `Cmd+D`, `Format`, `Preview`, `Compare Diff`, `Shortcuts`, animated respecting `Reduce Motion` `UI-011`), and persistent right utility group (Zoom `-`/`%`/`+` + `Light`/`Dark`/`Auto`).
    - **TextKit 2 Visual Highlighting (`SwiftEditNSTextView`)**: subclass `NSTextView` (TextKit 2 `usingTextLayoutManager: true`) to: (a) paint full-width current-line highlight in `drawBackground(in:)` (`#161224` in Dark, `#F3F0FA` in Light); (b) apply non-mutating `NSTextLayoutManager` temporary rendering attributes for nested brackets (4+ high-contrast depth colors cycling modulo depth, active pair emphasis, red unbalanced brackets) and backtick spans (inline & multiline code tint); (c) intercept `insertNewline:` in `NSTextViewDelegate` to invoke `MarkdownSmartNewlineEngine` atomically through `DocumentSession` without corrupting undo history.
    - **Percentage-Only Collapsible & Zoomable Sidebar (`SidebarLayoutGeometry`)**: model sidebar width purely as a proportional ratio `sidebarWidthRatio: Double` clamped to `0.12...0.65` (default `0.22`) of the current window/container width (ZERO hardcoded pixel min/max caps). Add a manual `pin` toggle button in the sidebar header (unpinning collapses sidebar and reveals a compact left-edge reopen strip alongside `Cmd+B`). Scale sidebar font size (`baseSidebarFontSizePoints = 13.0 * zoomPercent / 100.0`), icon metrics, and padding via `EditorZoomController`. Render `entry.isBinary == true` rows in disabled gray (`#9CA3AF` Dark, `#52525B` Light) with click disabled while keeping right-click context actions (`Reveal in Finder`, `Delete (Move to Trash)`). Attach right-click `New File…` and `New Folder…` context menus to BOTH entry rows AND empty sidebar background, prompting via modal single-segment name input dialog (`SidebarItemNameValidator`).
    - **Tab Reordering & `Help -> About`**: add drag-and-drop plus context-menu/button Move Left / Move Right to `EditorTabStrip` backed by `WorkspaceTabSession.moveTab*`. Add `Button("About PH.SwiftEdit")` inside `CommandGroup(replacing: .help)` alongside `.appInfo`, and extend `AboutSheetDescriptor` + `AboutSheetView` with `licenseName` (`"MIT License"`) and `licenseURL` (`"https://github.com/paoloinnocenti/PH.SwiftEdit/blob/main/LICENSE"`), both validated through `AboutSheetDescriptor.prepareExternalLinkConfirmation(rawURI:)` (`https`-only, `SEC-004`).
- **`cyber-security-expert`**:
  - **Binary Probe Confinement (`SEC-002`, `SEC-003`, `CWE-22`, `CWE-400`)**: `DotfileFolderNavigator` binary probing MUST occur strictly after `verifyConfinement` on the symlink-resolved path, reading at most `8 KiB` per regular file (`DocumentCodec.binaryProbeBytes`), with balanced `startAccessing`/`defer { stopAccessing }` and graceful fallback (`isBinary: false` or typed error) without ever reading full multi-GB binaries into RAM.
  - **Sidebar Context-Menu Name Prompt (`CWE-22`, `SEC-003`, `SEC-012`)**: Interactive New File / New Folder prompts MUST pass user input through `SidebarItemNameValidator.validate(_:)` and symlink-confined `FileSystemProviding` (rejecting `/`, `:`, `..`, NUL, BiDi overrides, and symlink escapes).
  - **DoS Bounds on Backtick & Markdown Scanners (`CWE-400`, `BC-011`, `SEC-012`)**: `BacktickHighlightScanner` and `MarkdownSmartNewlineEngine` MUST execute in linear $O(n)$ time with zero backtracking regexes, aborting lines exceeding `4096` UTF-16 code units and rejecting `isBinaryReadOnly` snapshots.
  - **External About Links (`SEC-004`, `UI-008`)**: Both Repository URL and License URL MUST pass `https`-only host validation (`InspectionSafetyBannerState.prepareExternalURIConfirmation`) with explicit user confirmation alert prior to `NSWorkspace.shared.open`.

## 3. 4-Pillar Breakdown & Path Coverage Matrix

| Unit | Path ID | Trait | Summary |
| :--- | :--- | :--- | :--- |
| `NestedBracketAndBacktickEngine` | `P1` | `positive` | `BracketMatcher` computes exact `nestingDepth` (`0, 1, 2`) and `enclosingPairs` on `scrivo{ho le graffe, le quadre[dentro le quadre ho le tonde(qua) e (pure qua)]}`; `BacktickHighlightScanner` classifies inline `` `code` `` and multiline `` ```swift\n...\n``` `` spans (`[AR-004]`, `[AR-012]`). |
| `NestedBracketAndBacktickEngine` | `N1` | `negative` | Unclosed backticks, mismatched fence counts, and unbalanced nested brackets report deterministic unmatched entries without crashing (`[BC-011]`). |
| `NestedBracketAndBacktickEngine` | `N2` | `security` | Lines exceeding `4096` UTF-16 units or binary read-only snapshots abort with `.degradedOrTimedOut` in both bracket and backtick scanners (`[BC-011]`, `[SEC-012]`). |
| `MarkdownSmartNewlineEngine` | `P2` | `positive` | Pressing Enter in a Markdown buffer continues `- `, `* `, `+ `, `- [ ] `, incremented `1. ` -> `2. `, and `> ` preserving indentation, and exits the list when Enter is pressed on an empty marker (`[BC-004]`, `[BC-006]`). |
| `MarkdownSmartNewlineEngine` | `N3` | `negative` | Pressing Enter inside a fenced `` ``` `` code block, on a plain non-Markdown file, or on a non-list line returns `nil` without mutating text (`[BC-006]`). |
| `MarkdownSmartNewlineEngine` | `N4` | `security` | Binary read-only snapshots, out-of-range carets, or overlong lines (`> 4096` UTF-16) return `nil` safely with zero edits (`[DATA-003]`, `[SEC-012]`). |
| `WorkspaceTabReordering` | `P3` | `positive` | `moveTabLeft`, `moveTabRight`, and `moveTab(id:toIndex:)` reorder unpinned tabs and pinned tabs within their respective partitions while keeping `activeTabID` intact (`[BC-006]`, `[BC-008]`). |
| `WorkspaceTabReordering` | `N5` | `negative` | Moving a boundary tab past its partition edge is a safe no-op; moving a pinned tab cannot cross into unpinned slots (and vice versa); unknown `DocumentID` throws `DomainError.tabNotFound` (`[BC-008]`). |
| `DotfileBinaryEntryDetection` | `P4` | `positive` | `DotfileFolderNavigator.listEntries` flags files containing `0x00` in their first `8 KiB` with `isBinary == true` while text files and directories report `isBinary == false`, with balanced security scope release (`[DATA-003]`, `[DATA-007]`, `[SEC-002]`). |
| `DotfileBinaryEntryDetection` | `N6` | `security` | Escaping symlinks in directory listing abort with `DomainError.securityScopeViolation` before any `8 KiB` binary probe executes, with `startCount == stopCount` (`[SEC-002]`, `[SEC-003]`). |
| `ThemeSelectorCurrentLineAndZoom` | `P5` | `positive` | `SwiftEditWorkbenchModel` switches cleanly among `.light`, `.black`, and `.auto` syncing live `systemPrefersDark`, resolves current-line (`#161224` Dark / `#F3F0FA` Light), nested bracket, backtick, and binary-disabled (`#9CA3AF` Dark / `#52525B` Light) palette tokens, and scales both editor and sidebar font sizes across `50%..300%` (`[UI-001]`, `[UI-002]`, `[UI-003]`, `[UI-004]`). |
| `ThemeSelectorCurrentLineAndZoom` | `N7` | `negative` | Clicking a binary `FolderEntryDescriptor` in the sidebar performs zero open/tab mutations, and zoom scaling clamps sidebar typography safely at `50%` and `300%` (`[DATA-003]`, `[UI-004]`, `[UI-008]`). |
| `PercentageSidebarPinHoverToolbarAndContextCreate` | `P6` | `positive` | `SidebarLayoutGeometry` computes width strictly from `sidebarWidthRatio` (`0.12...0.65`) of container width across arbitrary screen sizes; unpinning collapses the sidebar; top-bar command buttons follow `isToolbarHovered` while Zoom & Theme stay always visible; right-click Create File/Folder resolves target directory on both item rows and empty sidebar background (`[UI-001]`, `[UI-005]`, `[UI-011]`). |
| `PercentageSidebarPinHoverToolbarAndContextCreate` | `N8` | `negative` | Out-of-bounds sidebar ratios (`< 0.12` or `> 0.65`), zero/negative container widths, or invalid single-segment names from Create File/Folder prompt clamp or reject cleanly without mutating disk (`[BC-012]`, `[SEC-012]`). |
| `PercentageSidebarPinHoverToolbarAndContextCreate` | `N9` | `security` | Right-click Create File/Folder targeting an escaping symlink or containing path traversal (`../evil`) or BiDi overrides throws `DomainError.invalidItemName` or `DomainError.securityScopeViolation` (`[SEC-003]`, `[SEC-012]`). |
| `BrandLogoAndHelpAboutDialog` | `P7` | `positive` | `SwiftEditBrandLogoGeometry` exposes valid Concept E2 vector primitives for top bar (small) and About sheet (large); `Help` menu exposes `About PH.SwiftEdit`; `AboutSheetDescriptor` resolves App Name, `nbgv` version, validated GitHub repository link, and validated MIT License link (`[AR-014]`, `[UI-001]`, `[SEC-004]`). |
| `BrandLogoAndHelpAboutDialog` | `N10` | `security` | Tampered or non-HTTPS repository or license URIs (`javascript:`, `file:`, `http://`) return `nil` from `prepareExternalLinkConfirmation` and never open via `NSWorkspace` (`[SEC-004]`, `[UI-008]`). |

## 4. Declarative GIVEN-WHEN-THEN Behavior Contracts

```gherkin
Feature: PH.SwiftEdit Editor UX, Highlighting, Percentage-Resized Collapsible Sidebar, Tab Reordering, and Help About

  @REQ-EDITOR-UX-HIGHLIGHTING-SIDEBAR-PIN-TABS-AND-ABOUT-001
  Scenario: Three-way Light Dark Auto selector tracks system color scheme and resolves current-line, nested bracket, backtick, and disabled-binary tokens
    Given a SwiftEditWorkbenchModel initialized with AppearanceMode.auto and an active editor buffer
    When the user switches between Light, Black, and Auto while the macOS system colorScheme changes between light and dark
    Then the palette switches dynamically without reloading buffers, exposing #161224 Dark and #F3F0FA Light current-line tokens, nested bracket depth colors, backtick tint tokens, and #9CA3AF Dark / #52525B Light disabled-binary tokens

  @REQ-EDITOR-UX-HIGHLIGHTING-SIDEBAR-PIN-TABS-AND-ABOUT-002
  Scenario: Markdown smart Enter continues lists and quotes and exits cleanly on empty markers
    Given an active Markdown buffer containing "- first item", "1. step one", "- [ ] todo", and "> quote"
    When the user presses Enter at the end of each line and again on the newly proposed empty marker
    Then the engine proposes "- ", "2. ", "- [ ] ", and "> " respectively, removes the empty marker on the second Enter, and does not trigger inside fenced triple-backtick blocks

  @REQ-EDITOR-UX-HIGHLIGHTING-SIDEBAR-PIN-TABS-AND-ABOUT-003 @security
  Scenario: Nested bracket depth and inline or multiline backtick scanners respect line-length and binary bounds
    Given a buffer containing nested brackets "scrivo{ho le graffe, le quadre[dentro le quadre ho le tonde(qua) e (pure qua)]}" and inline plus fenced backtick code spans
    When SearchDiffAndBracketEngine evaluates brackets and BacktickHighlightScanner scans backticks
    Then each bracket pair carries its exact nestingDepth (0, 1, 2), inline and fenced backtick ranges are returned deterministically, and binary or >4096 UTF-16 lines degrade safely

  @REQ-EDITOR-UX-HIGHLIGHTING-SIDEBAR-PIN-TABS-AND-ABOUT-004 @security
  Scenario: Percentage-resized pinned sidebar scales with zoom, disables binary clicks, and supports confined right-click creation
    Given a workspace folder containing text and binary files displayed in an open sidebar across varying window widths
    When the user unpins to collapse, resizes by percentage ratio, zooms to 150%, clicks a binary file, and right-clicks empty sidebar space to create a file or folder
    Then sidebar width stays strictly proportional (12%..65% of container width), sidebar font scales with zoom, binary rows stay disabled on click, and right-click creation validates single-segment names within symlink-confined scope

  @REQ-EDITOR-UX-HIGHLIGHTING-SIDEBAR-PIN-TABS-AND-ABOUT-005 @security
  Scenario: Tabs reorder left and right within partitions, topbar commands reveal on hover, and Help About shows large E2 logo with validated repo and license links
    Given an open workspace with multiple tabs, the top toolbar, and the Help menu
    When the user reorders tabs left or right, hovers over the top bar, and opens Help -> About PH.SwiftEdit
    Then tabs reorder preserving pinned-first ordering, command buttons reveal only on hover while Logo, Zoom, and Theme remain always visible, and About shows Name, large Concept E2 Logo, version, validated GitHub URL, and validated MIT License URL
```
