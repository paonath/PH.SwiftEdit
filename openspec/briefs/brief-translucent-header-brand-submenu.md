---
id: "brief-translucent-header-brand-submenu"
change_id: "010-translucent-header-brand-submenu"
capability: "translucent-header-brand-submenu"
branch: "feature/FirstStub"
modifies_specs: "ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions (REQ-004), editor-ux-highlighting-sidebar-pin-tabs-and-about (REQ-006)"
status: "approved-via-qa"
date: "2026-11-20"
owners:
  - "swift-macos-expert"
  - "spec-sdlc-expert"
  - "cyber-security-expert"
---

# TDD Specification Brief: `010-translucent-header-brand-submenu`

## 1. Context & Source Traceability

- **Originating Reasoning Session**: `reasoning/003_theming-header-menu-and-markdown-editor/README.ai.md` (`TASK-02`, `TOPIC-02`, `ADR-02`).
- **Core Problem**:
  1. The horizontal row of abbreviated top-bar buttons (`Folder…`, `File…`, `New`, `Save`, `Cmd+D`, `Format`, `Preview`, `Compare Diff`, `Shortcuts`) right of `PH.SwiftEdit` crowds the header, uses cryptic labels (`Cmd+D`, `Format`), and flashes immediately on `0 ms` casual pointer crossings toward macOS window traffic lights, menu bar, or `EditorTabStrip`.
  2. Duplicate `.keyboardShortcut` modifiers inside `toolbarBar` (`Cmd+S`, `Cmd+D`, `Cmd+-`, `Cmd+0`, `Cmd++`) collide with `SwiftEditCommands`.
  3. `MarkdownLintAndFormatEngine.formatSection` (`UI-009`) has no workbench action or `⌥⇧⌘F` binding, and `Show/Hide Markdown Preview` lacks `Cmd+P` (`CommandGroup(replacing: .printItem)`, zero print-spooler IPC `SEC-004`, default `showMarkdownPreview == false`).
  4. Binary quarantine (`DATA-003`, `UI-008`) is incomplete across command surfaces: `SwiftEditCommands` leaves `Duplicate Line or Selection` (`⌘D`) enabled on binary tabs, and `saveActiveDocumentAsViaPanel()` (`⇧⌘S`) omits `!session.isBinaryReadOnly` before opening `NSSavePanel`.
- **Active Git Branch**: `feature/FirstStub` (baseline SHA `89b4f58`).
- **Consolidated Specs Modified (`modifies_specs`)**:
  - `ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions` (`REQ-004` MODIFIED to replace horizontal middle hover buttons with root-`ZStack` translucent `HeaderBrandSubmenuView`, add `⌘P` and `⌥⇧⌘F` to `KeyboardShortcutsCheatSheetCatalog`, and enforce binary quarantine command lockouts while keeping `N5` and `N9` security gates intact).
  - `editor-ux-highlighting-sidebar-pin-tabs-and-about` (`REQ-006` MODIFIED to replace `isToolbarHovered` horizontal buttons with the `120 ms`-dwell / `180 ms`-grace / `Escape`-latched `HeaderBrandSubmenuView` while keeping `N8` and `N9` sidebar confinement controls intact).
- **New Capability Added**:
  - `translucent-header-brand-submenu` (`REQ-001` `HeaderSubmenuStateMachine` & root-`ZStack` `0.0 pt` layout-shift overlay, `REQ-002` descriptive verb-noun `HeaderCommandCatalog` + badges & single-source `SwiftEditCommands` including `Cmd+P` default-OFF preview and `⌥⇧⌘F` `formatActiveSection()`, `REQ-003` synchronized binary quarantine command lockouts).
- **Governing Constitutional Rules (`v1.3.0`)**: `[AR-003]`, `[AR-006]`, `[AR-008]`, `[AR-009]`, `[AR-010]`, `[BC-004]`, `[BC-006]`, `[DATA-003]`, `[SEC-004]`, `[SEC-009]`, `[SEC-012]`, `[TEST-001]`..`[TEST-006]`, `[UI-001]`, `[UI-003]`, `[UI-004]`, `[UI-005]`, `[UI-008]`, `[UI-009]`, `[UI-010]`, `[UI-011]`, `[UI-012]`, `[SDD-001]`..`[SDD-003]`.

## 2. Domain, Governance & Security Expert Notes

- **`swift-macos-expert` & `spec-sdlc-expert`**:
  - Implement deterministic `@MainActor` (or pure value-type + `Duration` / `ElapsedTimeProviding` seam) `HeaderSubmenuStateMachine` enforcing `120 ms` continuous hover-open dwell on the brand/center bar trigger, `0 ms` instant click/tap/keyboard toggle (`explicitToggleOpened`), `180 ms` hover-exit grace across trigger <-> submenu travel, drag lockout (`isDraggingTabOrSidebar == true`), and `isSuppressedUntilPointerExit` latch on `Escape`, command selection, outside click, or window resign-key (WCAG 2.2 SC 1.4.13).
  - Mount `HeaderBrandSubmenuView` (`width: 312 pt`, offset `y: 36 pt`) inside a root `ZStack(alignment: .topLeading)` at `.zIndex(100)` above an outside-click dismissal catcher at `.zIndex(99)`, keeping `toolbarBar` fixed at `36 pt` (`0.0 pt` vertical editor displacement) and isolating right-hand Zoom (`-`, `100%`, `+`) and `Light | Dark | Auto` controls from submenu hover events.
  - Extract `SwiftEditCommands` into `Sources/SwiftEditUI/Views/SwiftEditCommands.swift` as the single source of keyboard shortcuts (zero `.keyboardShortcut` modifiers inside `toolbarBar` or `HeaderBrandSubmenuView`), binding `CommandGroup(replacing: .printItem)` for `Show/Hide Markdown Preview` (`⌘P`, default `false`) and `⌥⇧⌘F` (`[.command, .shift, .option]`) for `formatActiveSection()`.
  - Ensure all new view files in `Sources/SwiftEditUI/Views/` use semantic `PurpleThemePalette` tokens (`submenuTranslucentSurface`, `chromeForeground`, `secondaryForeground`, `badgeSurface`, `hairlineBorder`, `chromeAccent`) so `ArchitectureImportScanner.scanSwiftEditUIViewsDirectory` continues passing with zero violations.
- **`cyber-security-expert`**:
  - Synchronize `.disabled(!safetyBanner.canSave)` across `Save Document` (`⌘S`), `Save Document As…` (`⇧⌘S`), and `Duplicate Line or Selection` (`⌘D`), and `.disabled(!safetyBanner.canFormat)` across `Format Markdown Document` (`⇧⌘F`) and `Format Markdown Section` (`⌥⇧⌘F`) in both `HeaderCommandCatalog` / `HeaderBrandSubmenuView` and `SwiftEditCommands`.
  - Enforce fail-closed entry guards inside `SwiftEditWorkbenchModel.performCommandD()`, `saveActiveDocument()`, `saveActiveDocumentAsViaPanel()`, `formatActiveDocument()`, and `formatActiveSection()` when `session.isBinaryReadOnly == true` (`DATA-003`, `SEC-012`, `UI-008`).
  - Replace `.printItem` cleanly with in-memory `toggleMarkdownPreview()` (`SEC-004`, zero print-spooler IPC).

## 3. Path Coverage Matrix (`P1..P3`, `N1..N4`)

| Unit | Path ID | Trait | Scenario Summary |
| :--- | :--- | :--- | :--- |
| `HeaderSubmenuStateMachine` & Root Overlay | `P1` | `positive` | `120 ms` brand/bar hover opens submenu (`0 ms` on explicit click toggle), `<= 180 ms` travel into submenu retains open state, trailing Zoom/Appearance hover never triggers open, and `toolbarBarHeight` stays fixed at `36 pt` (`0.0 pt` layout shift) |
| `HeaderSubmenuStateMachine` Dwell & Escape Latch | `N1` | `negative` | Transient `< 120 ms` hover pass-through never opens submenu; active tab/sidebar drag blocks open; pressing `Escape` closes immediately and latches `isSuppressedUntilPointerExit` until pointer exits and re-enters or explicit click occurs |
| `HeaderCommandCatalog` & `SwiftEditCommands` | `P2` | `positive` | Descriptive verb-noun items expose exact titles and shortcut badges (`Duplicate Line or Selection` `⌘D`, `Format Markdown Section` `⌥⇧⌘F`, `Show Markdown Preview` / `Hide Markdown Preview` `⌘P` with initial `showMarkdownPreview == false`), `formatActiveSection()` formats only the selected Markdown range in 1 `BufferRevision` step, and `KeyboardShortcutsCheatSheetCatalog` includes `Cmd+P` and `Cmd+Option+Shift+F` |
| `HeaderCommandCatalog` & `SwiftEditWorkbenchModel` Binary Guards | `N2` | `security` | On a binary read-only tab (`isBinaryReadOnly == true`), `Save Document`, `Save Document As…`, `Duplicate Line or Selection`, `Format Markdown Document`, and `Format Markdown Section` resolve `isEnabled == false` in `HeaderCommandCatalog` and fail closed in `SwiftEditWorkbenchModel` without mutating `BufferRevision` or invoking `NSSavePanel` |
| `HeaderBrandSubmenuView` & `SwiftEditCommands` Token Fitness | `P3` | `positive` | New `HeaderBrandSubmenuView.swift` and extracted `SwiftEditCommands.swift` pass `ArchitectureImportScanner.scanSwiftEditUIViewsDirectory` with zero violations and respect `submenuTranslucentSurface` `0.90` / `1.0` alpha clamping |
| `SwiftEditWorkbenchModel.formatActiveSection` Degraded/Empty Guard | `N3` | `negative` | Invoking `formatActiveSection()` on an already-formatted range, out-of-bounds range, or degraded `> 10 MiB` plain-text snapshot preserves buffer text and surfaces a non-destructive status message without crashing |
