# Proposal: PH.SwiftEdit Editor UX, Highlighting, Percentage-Resized Collapsible Sidebar, Tab Reordering & Help About Integrations

## Why
Interactive use of `PH.SwiftEdit` after archiving `007-ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions` uncovered 13 high-priority UX defects and missing ergonomics across editor intelligence, visual highlighting, layout ergonomics, and branding:
1. The Light/Dark/Auto appearance control in the top bar renders clipped/stuck on `Auto`, and `SwiftEditWorkbenchModel` hardcodes `systemPrefersDark: true` instead of tracking live macOS `@Environment(\.colorScheme)`.
2. Editing Markdown files provides no automatic Enter continuation for bullet lists (`-`/`*`/`+`), task lists (`- [ ]`), numbered lists (`1.`/`1)`), or blockquotes (`>`).
3. The editor canvas lacks a subtle current-line background highlight (`#161224` in Dark/Black, `#F3F0FA` in Light), making caret tracking harder in dense documents.
4. `BracketMatcher` runs in `SwiftEditCore` but renders zero visual nested bracket highlighting in `TextKit2EditorView` and lacks `nestingDepth` / `enclosingPairs` metadata for expressions such as `scrivo{ho le graffe, le quadre[dentro le quadre ho le tonde(qua) e (pure qua)]}`.
5. Inline single/multi-backtick spans (`` `...` ``) and multiline fenced code blocks (`` ```...``` ``) are not visually highlighted.
6. The open left navigation panel lacks a manual `pin`/collapse toggle and uses hardcoded fixed pixel bounds (`190..320pt`), causing cramped sizing and multi-display scaling bugs instead of percentage-based resizing.
7. Zoom (`50%..300%`) scales only the editor and line gutter, leaving the left sidebar at fixed unscaled typography.
8. Binary files appear identical to editable text files in the left sidebar instead of disabled gray (`#9CA3AF` Dark / `#52525B` Light).
9. Open tabs in `EditorTabStrip` cannot be reordered left or right.
10. Right-clicking in the left sidebar lacks a context menu on empty folder backgrounds and hardcodes `"New Folder"` / `"Untitled.md"` without prompting for a user-supplied name.
11. Top-bar command buttons right of `PH.SwiftEdit` remain permanently visible instead of hiding until mouse hover while keeping Zoom and Theme controls permanently visible.
12. The Concept E2 brand logo is missing beside `PH.SwiftEdit` in the top bar.
13. The `Help` menu omits `About PH.SwiftEdit`, and `AboutSheetView` uses a placeholder SF Symbol instead of the large Concept E2 logo and lacks the MIT License link.

## What Changes
- **Appearance Selector & Live System ColorScheme Sync (`SwiftEditUI`)**: Replace the clipped segmented `Picker` with a dedicated, always-visible 3-way `Light | Dark | Auto` pill selector; sync `.auto` dynamically to live macOS `@Environment(\.colorScheme)` and apply `.preferredColorScheme` for explicit modes without reloading open buffers (`[UI-001]`, `[UI-003]`).
- **Markdown Smart Enter Continuation (`SwiftEditCore` + `SwiftEditUI`)**: Add `MarkdownSmartNewlineEngine` in `MarkdownLintAndFormat` and wire `NSTextViewDelegate` `insertNewline:` interception for `.md`/`.markdown`/`.mdown`/`.mkd` and Untitled tabs, proposing next list/task/numbered/blockquote markers, exiting lists on empty markers, and suppressing continuation inside fenced `` ``` `` blocks and binary buffers (`[BC-004]`, `[BC-006]`).
- **Visual Current-Line, Nested Bracket & Backtick Highlighting (`SwiftEditCore` + `SwiftEditUI`)**:
  - Extend `BracketPairSpan` with `nestingDepth: Int` and `BracketBalanceResult` with `enclosingPairs: [BracketPairSpan]` (`[AR-004]`, `[AR-012]`).
  - Add bounded linear `BacktickHighlightScanner` in `SearchDiffAndBracketEngine` detecting inline `` `...` `` and multiline `` ```...``` `` spans with `4096` UTF-16 line-length and binary guards (`[BC-011]`, `[SEC-012]`).
  - Extend `PurpleThemePalette` with current-line (`#161224` Dark / `#F3F0FA` Light), nested bracket depth colors, backtick tint tokens, and disabled-binary sidebar grays (`#9CA3AF` Dark / `#52525B` Light) (`[UI-002]`, `[UI-003]`).
  - Subclass `NSTextView` (`SwiftEditNSTextView`) to paint full-width current-line background and apply non-mutating TextKit 2 rendering attributes for nested brackets, active pair, unbalanced brackets, and backtick spans (`[UI-005]`, `[UI-006]`, `[UI-012]`).
- **Percentage-Resized Pinned/Collapsible Sidebar, Zoomable Sidebar, Binary Disabled Styling & Right-Click Create Prompt (`SwiftEditCore` + `SwiftEditUI`)**:
  - Add `FolderEntryDescriptor.isBinary: Bool` via bounded `8 KiB` `DocumentCodec.isBinaryPrefix` probing strictly after symlink confinement (`[DATA-003]`, `[SEC-002]`, `[SEC-003]`).
  - Add `SidebarLayoutGeometry` enforcing **strictly percentage-based** width ratios (`0.12...0.65` of window/container width, zero hardcoded pixel width bounds across monitors) plus manual `pin`/collapse toggle with compact left-edge reopen handle (`[UI-001]`, `[UI-005]`).
  - Extend `EditorZoomController` with proportional sidebar typography and spacing scaling across `50%..300%` (`[UI-004]`).
  - Render binary sidebar rows in disabled gray and block open-on-click while retaining right-click `Reveal in Finder` / `Delete (Move to Trash)` (`[DATA-003]`, `[UI-008]`).
  - Attach right-click `New File…` and `New Folder…` context menus to both sidebar rows and empty sidebar background, prompting via modal single-segment name input validated by `SidebarItemNameValidator` (`[BC-012]`, `[SEC-003]`, `[SEC-012]`).
- **Tab Left/Right Reordering (`SwiftEditCore` + `SwiftEditUI`)**: Add `moveTab(id:toIndex:)`, `moveTabLeft(id:)`, and `moveTabRight(id:)` to `WorkspaceTabSession` preserving pinned-first partitioning, wired to drag-and-drop and Move Left/Right controls in `EditorTabStrip` (`[BC-006]`, `[BC-008]`).
- **Hover-Revealed Top Bar, Concept E2 Vector Logo & `Help -> About` With License Link (`SwiftEditUI`)**:
  - Add pure SwiftUI vector `SwiftEditBrandLogoView` matching `docs/design/assets/logo-e2-refined.svg`, displayed small beside `PH.SwiftEdit` and large inside `AboutSheetView` (`[UI-001]`).
  - Hide top-bar command buttons right of `PH.SwiftEdit` until mouse hover over the top bar area while keeping Logo/Title, Zoom, and Light/Dark/Auto controls always visible (`[UI-001]`, `[UI-011]`).
  - Expose `About PH.SwiftEdit` inside `CommandGroup(replacing: .help)` alongside `.appInfo` and extend `AboutSheetDescriptor` + `AboutSheetView` with the validated MIT License link (`https://github.com/paoloinnocenti/PH.SwiftEdit/blob/main/LICENSE`) (`[AR-014]`, `[SEC-004]`, `[UI-008]`).

## Capabilities
- New Capabilities: `editor-ux-highlighting-sidebar-pin-tabs-and-about`
- Modified Capabilities: `markdown-lint-format-bracket-and-diff`, `notepadpp-tabs-session-recovery-and-dotfiles`, `swifteditui-purple-zed-layout-textkit2-and-appicons`, `ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions`

## Domain Carrier & Decision Ownership (BC-###)
- **BC-001**: Spans `MarkdownLintAndFormat` (Core — owns `MarkdownSmartNewlineEngine`), `SearchDiffAndBracketEngine` (Supporting — owns `BracketMatcher` nesting depth and `BacktickHighlightScanner`), `WorkspaceAndTabSession` (Supporting — owns `WorkspaceTabSession` tab reordering and `DotfileFolderNavigator` binary entry probing), and `SwiftEditUI` (Presentation — owns theme selector, percentage sidebar layout, hover topbar, vector brand logo, TextKit 2 visual decorations, and `Help -> About` dialog).
- **Owned Decisions**: Markdown Enter continuation edits, nested bracket depth & backtick highlight spans, within-partition tab order transitions, confined `8 KiB` binary classification in shallow folder listings, percentage-based sidebar width clamping, and HTTPS external link validation for About repo/license URLs.
- **Forbidden Responsibilities**: `SwiftEditCore` MUST NEVER import `AppKit`/`SwiftUI`/`WebKit` (`[AR-002]`) or perform unbounded full-file reads for sidebar binary probing (`[BC-011]`). `SwiftEditUI` MUST NEVER bypass `SidebarItemNameValidator`, `FileSystemProviding` symlink confinement, `ExternalLinkGuard`, or `WorkspaceTabSession` pinned-first partitioning (`[BC-008]`, `[SEC-003]`, `[SEC-004]`).
- **External Decision References**: `DocumentID`, `BufferRevision`, `URL` (standardized security-scoped), `ExternalURIConfirmationPrompt`.

## Impact
- **Production Modules (`SwiftEditCore`)**:
  - `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownSmartNewlineEngine.swift` (new)
  - `Sources/SwiftEditCore/SearchDiffAndBracketEngine/BracketMatcher.swift` (extended with `nestingDepth` and `enclosingPairs`)
  - `Sources/SwiftEditCore/SearchDiffAndBracketEngine/BacktickHighlightScanner.swift` (new)
  - `Sources/SwiftEditCore/WorkspaceAndTabSession/WorkspaceTabSession.swift` (extended with `moveTab`, `moveTabLeft`, `moveTabRight`)
  - `Sources/SwiftEditCore/WorkspaceAndTabSession/DotfileFolderNavigator.swift` (extended with `FolderEntryDescriptor.isBinary` via bounded `8 KiB` probe)
- **Production Modules (`SwiftEditUI`)**:
  - `Sources/SwiftEditUI/Theme/PurpleThemeAndZoom.swift` (extended with current-line, nested-bracket, backtick, disabled-binary tokens, and sidebar zoom scaling)
  - `Sources/SwiftEditUI/Views/SwiftEditBrandLogoView.swift` (new Concept E2 vector logo view + geometry)
  - `Sources/SwiftEditUI/Views/AboutSheetView.swift` (extended with large Concept E2 logo and validated MIT License link)
  - `Sources/SwiftEditUI/Views/SwiftEditRootView.swift` (fixed 3-way appearance selector + live colorScheme sync, `SwiftEditNSTextView` visual highlighting & smart newline hook, hover-revealed topbar, percentage-resized pinned/collapsible zoomable sidebar, binary disabled rows, empty-space + row right-click New File/Folder prompt, tab drag-and-drop + move left/right, `Help -> About PH.SwiftEdit`)
  - `Sources/SwiftEditUI/Views/KeyboardShortcutsCheatSheetView.swift` (updated with tab reorder and sidebar pin/collapse entries)
- **Test Suites (`SwiftEditTests`)**: New parallel Swift Testing suites covering `P1..P7` and `N1..N10` alongside existing regression suites.
- **External Dependencies**: Zero new SwiftPM dependencies (`[AR-005]`).

## Security Impact
- **App Sandbox & Symlink Confinement (`[SEC-002]`, `[SEC-003]`)**: `DotfileFolderNavigator` executes its `8 KiB` binary probe strictly after `verifyConfinement` on resolved paths with balanced `startAccessing`/`defer { stopAccessing }`. Right-click New File / New Folder prompts validate single-segment names (`SidebarItemNameValidator`) and enforce symlink confinement (`CWE-22`).
- **Algorithmic Complexity & DoS Bounds (`[BC-011]`, `[SEC-012]`)**: `BacktickHighlightScanner`, `BracketMatcher`, and `MarkdownSmartNewlineEngine` run in deterministic linear $O(n)$ scans with zero backtracking regexes, aborting lines exceeding `4096` UTF-16 code units and binary snapshots (`CWE-400`).
- **Offline Zero-Subprocess & External Link Guard (`[SEC-004]`, `[UI-008]`)**: Both GitHub repository and MIT License links in `AboutSheetView` are validated exclusively for `https` with non-empty host via `ExternalURIConfirmationPrompt` requiring explicit user confirmation before `NSWorkspace.shared.open`.

## Metadata
- Owner: swift-macos-expert
- Domain: apple-swift-macos
- Reviewer: cyber-security-expert
- Branch: feature/FirstStub
- Manual-Steps: none
- Modifies-Specs: markdown-lint-format-bracket-and-diff (REQ-003), notepadpp-tabs-session-recovery-and-dotfiles (REQ-001, REQ-004), swifteditui-purple-zed-layout-textkit2-and-appicons (REQ-001, REQ-003), ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions (REQ-001, REQ-004, REQ-005)
- Constitutional-Rules: AR-001, AR-002, AR-003, AR-004, AR-005, AR-012, AR-014, BC-001, BC-004, BC-006, BC-007, BC-008, BC-011, BC-012, DATA-003, DATA-007, DATA-008, SEC-002, SEC-003, SEC-004, SEC-011, SEC-012, TEST-001, TEST-002, TEST-003, TEST-004, UI-001, UI-002, UI-003, UI-004, UI-005, UI-006, UI-008, UI-009, UI-010, UI-011, UI-012, SDD-001, SDD-002, SDD-003
- Amends-Constitution: none

## Prerequisites
- `openspec/Constitution.md` (`v1.3.0`, active)
- `openspec/changes/archive/2026-11-18-002-markdown-lint-format-bracket-and-diff` (archived)
- `openspec/changes/archive/2026-11-18-003-notepadpp-tabs-session-recovery-and-dotfiles` (archived)
- `openspec/changes/archive/2026-11-18-004-swifteditui-purple-zed-layout-textkit2-and-appicons` (archived)
- `openspec/changes/archive/2026-11-19-006-core-cr-lineending-mru-batch-search-and-sidebar-fs` (archived)
- `openspec/changes/archive/2026-11-19-007-ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions` (archived)
- `openspec/briefs/brief-editor-ux-highlighting-sidebar-pin-tabs-and-about.md`
