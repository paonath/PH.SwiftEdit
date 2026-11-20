# Design: Root-ZStack Translucent Header Brand Submenu, Descriptive Action Badges, Single-Source SwiftEditCommands & Binary Quarantine Guards

## Context
Following `009-full-app-semantic-theming-and-window-sync`, `SwiftEditRootView.toolbarBar` still renders nine abbreviated horizontal buttons (`Folder…`, `File…`, `New`, `Save`, `Cmd+D`, `Format`, `Preview`, `Compare Diff`, `Shortcuts`) that flash immediately on `0 ms` hover, duplicate `.keyboardShortcut` modifiers already declared in `SwiftEditCommands`, omit `Format Markdown Section` (`⌥⇧⌘F`) and `Cmd+P` Preview (`CommandGroup(replacing: .printItem)`), and leave `Duplicate Line or Selection` (`⌘D`) and `Save As…` (`⇧⌘S`) unguarded on binary read-only tabs (`[DATA-003]`, `[SEC-004]`, `[UI-001]`, `[UI-008]`, `[UI-009]`).

## Goals / Non-Goals
- Goals:
  - Replace horizontal top-bar command buttons with `HeaderBrandSubmenuView` mounted in a root `ZStack(alignment: .topLeading)` at `.zIndex(100)` above a `.zIndex(99)` dismissal catcher (`0.0 pt` vertical layout shift), keeping trailing Zoom and `Light | Dark | Auto` controls isolated (`[UI-001]`, `[UI-004]`, `[UI-012]`).
  - Govern submenu open/close lifecycle via deterministic `HeaderSubmenuStateMachine` (`120 ms` hover dwell, `0 ms` click toggle, `180 ms` exit grace, drag lockout, `Escape` suppression latch) testable without `Task.sleep` (`[TEST-004]`, `[UI-010]`, `[UI-011]`).
  - Provide descriptive verb-noun `HeaderCommandCatalog` items + shortcut badges, wire `formatActiveSection()` (`⌥⇧⌘F`) and default-OFF `Cmd+P` Markdown Preview in `SwiftEditCommands.swift`, and enforce complete binary quarantine lockouts (`[BC-004]`, `[DATA-003]`, `[SEC-004]`, `[UI-008]`, `[UI-009]`).
- Non-Goals:
  - `Tab` / `Shift+Tab` CommonMark smart list indentation (deferred to `TASK-03`).
  - GFM viewport syntax highlighting, `CommandMenu("Markdown")` formatting insertions, and local raster image preview rendering (deferred to `TASK-04`).

## Architecture Memory & Module Boundaries (AR-###)
- **AR-001**: `SwiftEditCore` remains untouched (`MarkdownLintAndFormatEngine.formatSection` and `ArchitectureImportScanner.scanSwiftEditUIViewsDirectory` live in `SwiftEditCore` importing only `Foundation` and `Markdown` `[AR-002]`, `[AR-006]`). All new header submenu types (`HeaderSubmenuStateMachine`, `HeaderCommandCatalog`, `HeaderBrandSubmenuView`, `SwiftEditCommands`) reside in `SwiftEditUI` (`#if os(macOS)` around AppKit/macOS view shells `[AR-003]`, `[UI-005]`).
- **AR-018**: `SwiftEditWorkbenchModel` and `SwiftEditCommands` route user commands through `DocumentID`, `BufferRevision`, and `TextRange` value snapshots without bypassing `DocumentSession` or `InspectionSafetyBannerState` domain invariants (`[AR-008]`, `[BC-006]`, `[DATA-003]`).

## Constitutional Alignment & Module Boundaries (AR-### / UI-### / DATA-### / API-###)
- **Single-Reference Lock**: Consulted `openspec/constitution/03-ui-ux/design-system-and-tokens.md` (`UI-001..004`), `03-ui-ux/component-state-and-forms.md` (`UI-005..008`), `03-ui-ux/accessibility-and-cwv.md` (`UI-009..012`), `01-architecture/dependency-and-layering.md` (`AR-006..010`), `02-domain/index.md` (`BC-001..012`), and `07-security-privacy/stride-and-gdpr-privacy.md` (`SEC-009..012`) (`[SDD-001]`, `[SDD-002]`, `[SDD-003]`).

## Glossario & Convenzioni
- `HeaderSubmenuStateMachine`: Value-type state machine tracking pointer regions (`brandOrBarTrigger`, `submenuPanel`, `trailingControls`, `outside`), `120 ms` dwell, `180 ms` grace, drag lockout, and `isSuppressedUntilPointerExit` (`[AR-008]`, `[TEST-004]`, `[UI-010]`).
- `HeaderCommandCatalog`: Stateless value-type factory projecting `HeaderCommandItem` descriptors (descriptive title, SF Symbol icon, monospaced shortcut badge, `isEnabled` flag) from `SwiftEditWorkbenchModel` state (`[AR-009]`, `[UI-009]`).
- `HeaderBrandSubmenuView`: `#if os(macOS)` translucent overlay panel (`312 pt` width, `y: 36 pt`, `.zIndex(100)`) styled with `PurpleThemePalette.submenuTranslucentSurface` (`[UI-001]`, `[UI-003]`).
- `SwiftEditCommands`: Extracted macOS `Commands` struct owning all global `.keyboardShortcut` bindings (`[SEC-004]`, `[UI-009]`, `[UI-010]`).

## Decisions
- **D1 — Pure Value-Type `HeaderSubmenuStateMachine` Driven by Explicit `Duration` Steps (`KISS` + `TEST-004`)**: Modeling dwell (`120 ms`) and exit grace (`180 ms`) as a pure value-type state machine stepped deterministically in unit tests (and driven at runtime by cancellable `@MainActor` `Task` timers using `ContinuousClock`) eliminates flaky `Task.sleep` wall-clock waits in `SwiftEditTests` while satisfying WCAG 2.2 SC 1.4.13 (`Dismissible`, `Hoverable`, `Persistent`) (`[AR-008]`, `[AR-009]`, `[TEST-004]`).
- **D2 — Root `ZStack(alignment: .topLeading)` Overlay + `.zIndex(99)` Click-Outside Shield**: AppKit `NSScrollView` / `SwiftEditNSTextView` sits below `toolbarBar`; placing `HeaderBrandSubmenuView` inside `toolbarBar.overlay` would lose hit-testing and outside-click dismissal over the `NSViewRepresentable` editor. Mounting at the root `ZStack` (`.zIndex(100)` over `.zIndex(99)` shield) guarantees `0.0 pt` editor displacement and reliable dismissal (`[UI-001]`, `[UI-012]`).
- **D3 — Single-Source `SwiftEditCommands` & Descriptive `HeaderCommandCatalog`**: Removing `.keyboardShortcut` modifiers from `toolbarBar` and omitting them from `HeaderBrandSubmenuView` eliminates shortcut collisions while keeping global shortcuts (`⌘D`, `⇧⌘F`, `⌥⇧⌘F`, `⌘P` via `CommandGroup(replacing: .printItem)`) active when the submenu is closed (`[SEC-004]`, `[UI-009]`).

## Risks / Trade-offs
- Existing tests in `EditorUXLayoutThemeAndAboutTests.swift` reference `model.isToolbarHovered` -> Keep a computed compatibility read property `isToolbarHovered` reflecting `headerSubmenuState.isPointerInsideTrigger || headerSubmenuState.isOpen` (or update scenario `P6` -> `P9` cleanly) so existing layout tests remain green while testing the new `120 ms` dwell state machine directly.
- Save-panel side effects during unit tests if `saveActiveDocumentAsViaPanel()` were invoked unguarded -> Guard `guard let session = activeDocumentSession, !session.isBinaryReadOnly` BEFORE instantiating `NSSavePanel`, and expose an injectable `savePanelProvider: @MainActor () -> URL?` seam in `SwiftEditWorkbenchModel` (`[TEST-004]`, `[UI-008]`).

## Migration Plan
1. Create `Sources/SwiftEditUI/Views/HeaderBrandSubmenuView.swift` (`HeaderSubmenuStateMachine`, `HeaderCommandCatalog`, `HeaderBrandSubmenuView`).
2. Extract `SwiftEditCommands` into `Sources/SwiftEditUI/Views/SwiftEditCommands.swift` adding `.printItem` `⌘P` Preview, `⌥⇧⌘F` `formatActiveSection()`, and binary `.disabled(...)` guards.
3. Update `SwiftEditRootView.swift` (root `ZStack` overlay, simplified `36 pt` `toolbarBar`, `formatActiveSection()`, `toggleMarkdownPreview()`, binary guards) and `KeyboardShortcutsCheatSheetView.swift`.
4. Verify `swift test --parallel` and `ArchitectureImportScanner.scanSwiftEditUIViewsDirectory` pass 100%.

## Security Review
- Reviewer: cyber-security-expert
- Date: 2026-11-20
- Verdict: approved
- Open items: none
