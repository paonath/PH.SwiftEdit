# Proposal: Root-ZStack Translucent Header Brand Submenu, Descriptive Action Badges, Single-Source SwiftEditCommands & Binary Quarantine Guards

## Why
Interactive testing of `PH.SwiftEdit` after archiving `009-full-app-semantic-theming-and-window-sync` exposed four UX, keyboard-shortcut, and binary-quarantine defects in the top header bar and command dispatch layer:
1. Nine horizontal top-bar buttons (`Folder…`, `File…`, `New`, `Save`, `Cmd+D`, `Format`, `Preview`, `Compare Diff`, `Shortcuts`) right of `PH.SwiftEdit` crowd narrow windows, use cryptic shorthand labels (`Cmd+D`, `Format`, `Preview`), and flash immediately on `0 ms` casual pointer passes toward macOS window traffic lights, the menu bar, or `EditorTabStrip`.
2. Duplicate `.keyboardShortcut` modifiers inside `SwiftEditRootView.toolbarBar` (`Cmd+S`, `Cmd+D`, `Cmd+-`, `Cmd+0`, `Cmd++`) compete with `SwiftEditCommands`.
3. `MarkdownLintAndFormatEngine.formatSection` (`[UI-009]`) has no workbench action or `⌥⇧⌘F` shortcut, and `Show/Hide Markdown Preview` lacks `Cmd+P` (`CommandGroup(replacing: .printItem)`, zero print-spooler IPC `[SEC-004]`, default `showMarkdownPreview == false`).
4. Binary read-only quarantine (`[DATA-003]`, `[UI-008]`) is incomplete across command surfaces: `SwiftEditCommands` leaves `Duplicate Line or Selection` (`⌘D`) enabled on binary tabs, and `saveActiveDocumentAsViaPanel()` (`⇧⌘S`) omits `!session.isBinaryReadOnly` before presenting `NSSavePanel`.

## What Changes
- **Root-`ZStack` Translucent `HeaderBrandSubmenuView` & `HeaderSubmenuStateMachine` (`SwiftEditUI`)**:
  - Replace the horizontal middle buttons in `toolbarBar` with `HeaderBrandSubmenuView` (`width: 312 pt`, offset below the fixed `36 pt` header) mounted inside a root `ZStack(alignment: .topLeading)` at `.zIndex(100)` above a `.zIndex(99)` outside-click dismissal catcher (`0.0 pt` vertical editor displacement), while keeping trailing `[- 100% +]` Zoom and `Light | Dark | Auto` controls isolated and always visible (`[UI-001]`, `[UI-004]`, `[UI-012]`).
  - Implement deterministic `HeaderSubmenuStateMachine` with injectable `Duration` / clock progression enforcing `120 ms` continuous hover-open dwell on Logo + `PH.SwiftEdit` + center bar trigger, `0 ms` instant click/tap/keyboard toggle (`explicitToggleOpened`), `180 ms` hover-exit grace across trigger-to-submenu travel, drag lockout (`draggingTabID != nil || dragStartSidebarRatio != nil`), and `isSuppressedUntilPointerExit` latch on `Escape`, command selection, outside click, or window resign-key (WCAG 2.2 SC 1.4.13) (`[TEST-004]`, `[UI-010]`, `[UI-011]`).
  - Style `HeaderBrandSubmenuView` exclusively with semantic `PurpleThemePalette` tokens (`submenuTranslucentSurface` `0.90` alpha + `.ultraThinMaterial`, clamped to `1.0` opaque under `reduceTransparency || increasedContrast`, `chromeForeground`, `secondaryForeground`, `badgeSurface`, `hairlineBorder`, `chromeAccent`) passing `ArchitectureImportScanner.scanSwiftEditUIViewsDirectory` with zero violations (`[AR-006]`, `[TEST-006]`, `[UI-001]`, `[UI-003]`, `[UI-009]`).
- **Descriptive Verb-Noun `HeaderCommandCatalog`, `formatActiveSection()` & Single-Source `SwiftEditCommands` (`SwiftEditUI`)**:
  - Introduce pure value-type `HeaderCommandCatalog` projecting full descriptive command titles and monospaced keycap badges (`New Document` `⌘N`, `Open File…` `⌘O`, `Open Folder…` `⇧⌘O`, `Save Document` `⌘S`, `Save Document As…` `⇧⌘S`, `Duplicate Line or Selection` `⌘D`, `Format Markdown Document` `⇧⌘F`, `Format Markdown Section` `⌥⇧⌘F`, `Show Markdown Preview` / `Hide Markdown Preview` `⌘P` with initial `showMarkdownPreview == false`, `Show File Compare Diff` / `Hide File Compare Diff`, `Keyboard Shortcuts CheatSheet` `⌘/`) (`[AR-008]`, `[AR-009]`, `[UI-009]`, `[UI-010]`).
  - Add `SwiftEditWorkbenchModel.formatActiveSection()` delegating to `MarkdownLintAndFormatEngine.formatSection(snapshot:range:)` in one atomic `BufferRevision` step (`[BC-004]`, `[BC-006]`, `[UI-009]`), extract `SwiftEditCommands` into `Sources/SwiftEditUI/Views/SwiftEditCommands.swift` removing duplicate `.keyboardShortcut` modifiers from `toolbarBar`, bind `CommandGroup(replacing: .printItem)` to `toggleMarkdownPreview()` (`⌘P`, zero print-spooler IPC `[SEC-004]`), and update `KeyboardShortcutsCheatSheetCatalog` with `Cmd+P` and `Cmd+Option+Shift+F`.
- **Complete Binary Quarantine Command Mediation (`SwiftEditUI`)**:
  - Synchronize `.disabled(!safetyBanner.canSave)` across `Save Document`, `Save Document As…`, and `Duplicate Line or Selection` (`⌘D`), and `.disabled(!safetyBanner.canFormat)` across `Format Markdown Document` and `Format Markdown Section` in both `HeaderCommandCatalog` / `HeaderBrandSubmenuView` and `SwiftEditCommands`, backed by fail-closed entry guards in `SwiftEditWorkbenchModel` (`[DATA-003]`, `[SEC-004]`, `[SEC-012]`, `[UI-008]`).

## Capabilities
- New Capabilities: `translucent-header-brand-submenu`
- Modified Capabilities: `ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions`, `editor-ux-highlighting-sidebar-pin-tabs-and-about`

## Domain Carrier & Decision Ownership (BC-###)
- **BC-001**: Spans `SwiftEditUI` (Presentation — owns `HeaderSubmenuStateMachine`, `HeaderCommandCatalog`, `HeaderBrandSubmenuView`, `SwiftEditCommands`, and `SwiftEditWorkbenchModel` UI command routing) delegating AST section formatting inward to `MarkdownLintAndFormatEngine` (`BC-004` in `SwiftEditCore`).
- **Owned Decisions**: `120 ms` hover dwell / `180 ms` exit grace / `Escape` suppression state transitions, descriptive verb-noun command labels and shortcut badge projections, single-source `SwiftEditCommands` shortcut bindings (`⌘P`, `⌥⇧⌘F`), and UI/model binary quarantine command gating.
- **Forbidden Responsibilities**: `HeaderBrandSubmenuView` MUST NEVER displace vertical editor layout (`0.0 pt` shift), attach duplicate `.keyboardShortcut` modifiers, use raw color literals (`brandGround`, `#RRGGBB`, `Color(.sRGB`), invoke print-spooler IPC on `⌘P`, or permit `Save`, `Save As…`, `Duplicate`, or `Format` mutations on binary read-only tabs (`[AR-006]`, `[BC-011]`, `[DATA-003]`, `[SEC-004]`, `[UI-008]`, `[UI-012]`).
- **External Decision References**: `DocumentID`, `BufferRevision`, `TextRange`.

## Impact
- **Production Modules (`SwiftEditCore`)**: None (`MarkdownLintAndFormatEngine.formatSection` and `ArchitectureImportScanner.scanSwiftEditUIViewsDirectory` are consumed as-is `[AR-002]`, `[AR-006]`).
- **Production Modules (`SwiftEditUI`)**:
  - `Sources/SwiftEditUI/Views/HeaderBrandSubmenuView.swift` (new: `HeaderSubmenuRegion`, `HeaderSubmenuOpenOrigin`, `HeaderSubmenuStateMachine`, `HeaderCommandID`, `HeaderCommandItem`, `HeaderCommandCatalog`, and `#if os(macOS)` `HeaderBrandSubmenuView`)
  - `Sources/SwiftEditUI/Views/SwiftEditCommands.swift` (new extracted file: single-source `FocusedValues.workbenchModel` + `SwiftEditCommands` with `.printItem` `⌘P` Preview, `⌥⇧⌘F` Format Section, and binary quarantine `.disabled(...)` bindings)
  - `Sources/SwiftEditUI/Views/SwiftEditRootView.swift` (root `ZStack(alignment: .topLeading)` overlay + `.zIndex(99)` outside-click shield, simplified `36 pt` `toolbarBar` without middle horizontal buttons or duplicate `.keyboardShortcut` modifiers, `formatActiveSection()`, `toggleMarkdownPreview()`, and hardened `performCommandD()` / `saveActiveDocumentAsViaPanel()` binary guards)
  - `Sources/SwiftEditUI/Views/KeyboardShortcutsCheatSheetView.swift` (`Cmd+Option+Shift+F` `Format Markdown Section` and `Cmd+P` `Toggle Markdown Preview` added to `KeyboardShortcutsCheatSheetCatalog`)
- **Test Suites (`SwiftEditTests`)**: Updated `EditorUXLayoutThemeAndAboutTests.swift` and `MinimalLayoutGutterAndParentNavigationTests.swift` (if referencing `isToolbarHovered`), plus new `TranslucentHeaderBrandSubmenuTests.swift`.
- **External Dependencies**: Zero new SwiftPM dependencies (`[AR-005]`).

## Security Impact
- **Binary Quarantine Command Mediation (`[DATA-003]`, `[SEC-012]`, `[UI-008]`)**: Closes the UI/menu gap where `Duplicate Line or Selection` (`⌘D`) remained enabled in `SwiftEditCommands` and `Save As…` (`⇧⌘S`) could invoke `NSSavePanel` on binary read-only buffers, enforcing fail-closed guards across submenu items, menu bar commands, and `SwiftEditWorkbenchModel` methods.
- **Print-Spooler Surface Elimination (`[SEC-004]`)**: `CommandGroup(replacing: .printItem)` binds `⌘P` strictly to in-memory Zero-WebKit Markdown Preview toggling (`showMarkdownPreview` defaulting to `false`), preventing unintended print-dialog IPC inside the App Sandbox.
- **Anti-Camouflage & UI Redressing (`CWE-451`, `[SEC-009]`, `[TEST-006]`, `[UI-009]`)**: `HeaderBrandSubmenuView` and `SwiftEditCommands` enforce `PurpleThemePalette` semantic tokens (`>= 4.5:1` text contrast, `1.0` alpha clamping under `reduceTransparency || increasedContrast`) verified continuously by `ArchitectureImportScanner.scanSwiftEditUIViewsDirectory`.

## Metadata
- Owner: swift-macos-expert
- Domain: apple-swift-macos
- Reviewer: cyber-security-expert
- Branch: feature/FirstStub
- Manual-Steps: none
- Modifies-Specs: ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions (REQ-004), editor-ux-highlighting-sidebar-pin-tabs-and-about (REQ-006)
- Constitutional-Rules: AR-003, AR-005, AR-006, AR-008, AR-009, AR-010, BC-001, BC-004, BC-006, BC-011, DATA-003, SEC-004, SEC-009, SEC-012, TEST-001, TEST-002, TEST-003, TEST-004, TEST-006, UI-001, UI-003, UI-004, UI-005, UI-008, UI-009, UI-010, UI-011, UI-012, SDD-001, SDD-002, SDD-003
- Amends-Constitution: none

## Prerequisites
- `openspec/Constitution.md` (`v1.3.0`, active)
- `openspec/changes/archive/2026-11-19-009-full-app-semantic-theming-and-window-sync` (archived — provides `submenuTranslucentSurface` and `reduceTransparency` / `increasedContrast` clamping)
- `openspec/briefs/brief-translucent-header-brand-submenu.md`
