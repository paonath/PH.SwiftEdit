# Tasks: Root-ZStack Translucent Header Brand Submenu, Descriptive Action Badges, Single-Source SwiftEditCommands & Binary Quarantine Guards

## 1. Unit: HeaderSubmenuStateMachineAndRootOverlay
<!-- Governing rules: AR-008, AR-009, TEST-001, TEST-002, TEST-004, UI-001, UI-003, UI-010, UI-011, UI-012 -->

- [x] 1.1 [RED] TASK-001-RED: Write failing `Swift Testing` tests in `Tests/SwiftEditTests/TranslucentHeaderBrandSubmenuTests.swift` for `P1` (`HeaderSubmenuStateMachine` opens at `120 ms` dwell or `0 ms` click toggle, bridges `<= 180 ms` submenu travel, ignores trailing Zoom/Appearance hover while closed, and keeps `topBarHeight == 36.0` with `0.0 pt` shift) and `N1` (`< 120 ms` pass-through and active drag keep submenu closed; `Escape` closes immediately and latches `isSuppressedUntilPointerExit` until pointer exit or click); verify failure on assertions [Const: TEST-004 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [P1, N1]
- [x] 1.2 [GREEN] TASK-001-GREEN: Implement `HeaderSubmenuStateMachine` and `#if os(macOS)` `HeaderBrandSubmenuView` in `Sources/SwiftEditUI/Views/HeaderBrandSubmenuView.swift` and mount the `.zIndex(100)` overlay + `.zIndex(99)` outside-click catcher inside a root `ZStack(alignment: .topLeading)` in `SwiftEditRootView.swift` (replacing horizontal middle toolbar buttons while keeping trailing Zoom and `Light | Dark | Auto` isolated) so `P1` and `N1` pass [Const: UI-001 (03-ui-ux/design-system-and-tokens.md)]
  - paths: [P1, N1]
- [x] 1.3 [REFACTOR] TASK-001-REFACTOR: Wire cancellable `ContinuousClock` dwell/grace tasks and `accessibilityReduceMotion` animation suppression on `SwiftEditWorkbenchModel` and `SwiftEditRootView` while keeping `EditorUXLayoutThemeAndAboutTests` (`P9`) green [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
  - paths: [P1, P9, N1, N12]
- [x] 1.4 [DOC] TASK-001-DOC: Write concise English Swift Markup (`///`) documentation on `HeaderSubmenuStateMachine`, `HeaderBrandSubmenuView`, and WCAG 2.2 SC 1.4.13 dwell/grace/`Escape` latch invariants
  - paths: [P1, N1]

## 2. Unit: DescriptiveHeaderCommandCatalogAndSingleSourceShortcuts
<!-- Governing rules: AR-006, BC-004, BC-006, DATA-003, SEC-004, SEC-012, TEST-006, UI-008, UI-009, UI-010 -->

- [x] 2.1 [RED] TASK-002-RED: Write failing `Swift Testing` tests in `Tests/SwiftEditTests/TranslucentHeaderBrandSubmenuTests.swift` for `P2`, `P3`, `P9`, and `N3` (`HeaderCommandCatalog` projects descriptive titles and shortcut badges including `Duplicate Line or Selection` `⌘D`, `Format Markdown Document` `⇧⌘F`, `Format Markdown Section` `⌥⇧⌘F`, and `Show/Hide Markdown Preview` `⌘P` with initial `showMarkdownPreview == false`; `formatActiveSection()` formats only the selected section in `+1` `BufferRevision` and safely skips degraded buffers; CheatSheet includes `Cmd+P` & `Cmd+Option+Shift+F`; `scanSwiftEditUIViewsDirectory` reports zero violations and zero duplicate `.keyboardShortcut` calls in `HeaderBrandSubmenuView.swift` / `toolbarBar`); verify failure on assertions [Const: UI-009 (03-ui-ux/accessibility-and-cwv.md)]
  - paths: [P2, P3, P9, N3]
- [x] 2.2 [GREEN] TASK-002-GREEN: Implement `HeaderCommandCatalog`, `SwiftEditWorkbenchModel.formatActiveSection()` and `toggleMarkdownPreview()`, extract `Sources/SwiftEditUI/Views/SwiftEditCommands.swift` with `CommandGroup(replacing: .printItem)` (`⌘P`) and `⌥⇧⌘F`, remove duplicate `.keyboardShortcut` modifiers from `toolbarBar`, and update `KeyboardShortcutsCheatSheetCatalog` so `P2`, `P3`, `P9`, and `N3` pass [Const: TEST-006 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P2, P3, P9, N3]
- [x] 2.3 [REFACTOR] TASK-002-REFACTOR: Deduplicate command invocation routing between `HeaderBrandSubmenuView` and `SwiftEditCommands` while keeping all `SwiftEditTests` suites green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [P2, P3, P9, N3]
- [x] 2.4 [DOC] TASK-002-DOC: Write concise English Swift Markup (`///`) documentation on `HeaderCommandCatalog`, `SwiftEditCommands`, `formatActiveSection()`, and `toggleMarkdownPreview()`
  - paths: [P2, P3, P9, N3]
- [x] 2.5 [RED] [SECURITY] TASK-003-RED: Write failing security tests in `Tests/SwiftEditTests/TranslucentHeaderBrandSubmenuTests.swift` for `N2` and `N11` (when an inspected binary read-only tab is active, `Save Document`, `Save Document As…`, `Duplicate Line or Selection`, `Format Markdown Document`, and `Format Markdown Section` report `isEnabled == false` in `HeaderCommandCatalog`, and invoking `saveActiveDocument()`, `saveActiveDocumentAsViaPanel()`, `performCommandD()`, `formatActiveDocument()`, and `formatActiveSection()` fails closed with zero `BufferRevision` mutation and zero `savePanelProvider` calls); verify failure on assertions [Const: UI-008 (03-ui-ux/component-state-and-forms.md)]
  - paths: [N2, N11] · tags: security · priority: critical
- [x] 2.6 [GREEN] [SECURITY] TASK-003-GREEN: Synchronize `.disabled(!safetyBanner.canSave)` and `.disabled(!safetyBanner.canFormat)` across `HeaderCommandCatalog` and `SwiftEditCommands` (`Duplicate Line or Selection`, `Save`, `Save As…`, `Format Markdown Document`, `Format Markdown Section`) and enforce fail-closed `!session.isBinaryReadOnly` entry guards + injectable `savePanelProvider` in `SwiftEditWorkbenchModel` so `N2` and `N11` pass [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [N2, N11] · tags: security · priority: critical
- [x] 2.7 [REFACTOR] [SECURITY] TASK-003-REFACTOR: Centralize mutating-command eligibility checks across `SwiftEditWorkbenchModel`, `HeaderCommandCatalog`, and `SwiftEditCommands` while keeping the full parallel test suite green [Const: UI-010 (03-ui-ux/accessibility-and-cwv.md)]
  - paths: [N2, N11] · tags: security
- [x] 2.8 [DOC] [SECURITY] TASK-003-DOC: Document `DATA-003`, `SEC-004` (`.printItem` replacement), and `UI-008` binary quarantine command mediation invariants in English Swift Markup (`///`) comments
  - paths: [N2, N11]

## 3. Unit: LivingSpecificationReconciliation

- [x] 3.1 [SYNC] TASK-004-SYNC: Execute `/myspec-sync 010-translucent-header-brand-submenu` to reconcile delta changes into `openspec/specs/translucent-header-brand-submenu/spec.md`, `openspec/specs/ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions/spec.md`, and `openspec/specs/editor-ux-highlighting-sidebar-pin-tabs-and-about/spec.md` [Const: SDD-003 (08-sdd-governance/artifact-traceability.md)]
