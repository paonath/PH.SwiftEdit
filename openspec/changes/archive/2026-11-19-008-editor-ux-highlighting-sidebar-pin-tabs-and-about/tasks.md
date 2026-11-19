# Tasks: PH.SwiftEdit Editor UX, Highlighting, Percentage-Resized Collapsible Sidebar, Tab Reordering & Help About Integrations

## 1. Unit: NestedBracketAndBacktickEngine
<!-- Governing rules: AR-002, AR-004, AR-012, BC-011, SEC-012, TEST-001, TEST-002 -->

- [x] 1.1 [RED] TASK-001-RED: Write failing `Swift Testing` tests in `Tests/SwiftEditTests/NestedBracketAndBacktickEngineTests.swift` for `P1` (`BracketMatcher` assigns 0-based `nestingDepth` `0, 1, 2` and outer-to-inner `enclosingPairs` on `"scrivo{ho le graffe, le quadre[dentro le quadre ho le tonde(qua) e (pure qua)]}"`; `BacktickHighlightScanner` detects inline `` `token` `` and multiline `` ```swift\nlet x = 1\n``` `` spans) and `N1` (unclosed inline backticks, unclosed fences, and mismatched brackets `"{ [ ) }"` report deterministically without crashing); verify failure on assertions [Const: AR-004 (01-architecture/module-topology.md)]
  - paths: [P1, N1]
- [x] 1.2 [GREEN] TASK-001-GREEN: Extend `BracketPairSpan` (`nestingDepth: Int = 0`) and `BracketBalanceResult` (`enclosingPairs: [BracketPairSpan] = []`) in `Sources/SwiftEditCore/SearchDiffAndBracketEngine/BracketMatcher.swift` and implement `BacktickHighlightScanner` in `Sources/SwiftEditCore/SearchDiffAndBracketEngine/BacktickHighlightScanner.swift` so `P1` and `N1` pass [Const: AR-012 (01-architecture/host-and-sagas.md)]
  - paths: [P1, N1]
- [x] 1.3 [REFACTOR] TASK-001-REFACTOR: Share the UTF-16 line-length pre-scan helper across `BracketMatcher` and `BacktickHighlightScanner` while keeping `BracketBalancingEngineTests` and `NestedBracketAndBacktickEngineTests` green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [P1, N1]
- [x] 1.4 [DOC] TASK-001-DOC: Write concise English Swift Markup (`///`) documentation on `BracketPairSpan.nestingDepth`, `BracketBalanceResult.enclosingPairs`, `BacktickHighlightSpan`, and `BacktickHighlightScanner`
  - paths: [P1, N1]
- [x] 1.5 [RED] [SECURITY] TASK-002-RED: Write failing security tests in `Tests/SwiftEditTests/NestedBracketAndBacktickEngineTests.swift` for `N2` (a single `4097`-unit UTF-16 line and a binary read-only snapshot both return `.degradedOrTimedOut` in `BracketMatcher` and `BacktickHighlightScanner`); verify failure on assertions [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [P1, N2] · tags: security · priority: critical
- [x] 1.6 [GREEN] [SECURITY] TASK-002-GREEN: Enforce binary read-only refusal and `4096` UTF-16 single-line cap with linear $O(n)$ non-backtracking scans in `BacktickHighlightScanner` and `BracketMatcher` so `N2` passes [Const: BC-011 (02-domain/ubiquitous-language-and-policy.md)]
  - paths: [P1, N2] · tags: security · priority: critical
- [x] 1.7 [REFACTOR] [SECURITY] TASK-002-REFACTOR: Audit scanner bounds and UTF-16 offset arithmetic for zero integer overflow or quadratic edge cases while keeping all tests green [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [P1, N2] · tags: security
- [x] 1.8 [DOC] [SECURITY] TASK-002-DOC: Document `CWE-400` linear scan bounds and `4096` UTF-16 line-cap invariants in English Swift Markup (`///`) comments
  - paths: [P1, N2]

## 2. Unit: MarkdownSmartNewlineEngine
<!-- Governing rules: AR-002, BC-004, BC-006, BC-011, DATA-003, SEC-012, TEST-001 -->

- [x] 2.1 [RED] TASK-003-RED: Write failing `Swift Testing` tests in `Tests/SwiftEditTests/MarkdownSmartNewlineEngineTests.swift` for `P2` (Enter continues `"  - alpha"`, `"- [x] done"`, `"3. third"`, `"2) second"`, `"> quoted"` with consistent next prefix and strips empty markers like `"- "` to exit the list) and `N3` (inside fenced `` ``` `` code block, non-Markdown `.swift` buffer, or plain prose returns `nil`); verify failure on assertions [Const: BC-004 (02-domain/bounded-context-ownership.md)]
  - paths: [P2, N3]
- [x] 2.2 [GREEN] TASK-003-GREEN: Implement `SmartNewlineEdit` and `MarkdownSmartNewlineEngine` in `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownSmartNewlineEngine.swift` (pure value-type line/fence scanner returning a `TextEdit` and `newCaretLocation` compatible with `DocumentSession.applyTextEdits`) so `P2` and `N3` pass [Const: BC-006 (02-domain/negative-ownership-and-refs.md)]
  - paths: [P2, N3]
- [x] 2.3 [REFACTOR] TASK-003-REFACTOR: Extract list-marker parsing (`unordered`, `task`, `ordered`, `blockquote`) and fenced-block parity tracking into clean private helpers while keeping all Markdown tests green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [P2, N3]
- [x] 2.4 [DOC] TASK-003-DOC: Write concise English Swift Markup (`///`) documentation on `SmartNewlineEdit`, `MarkdownSmartNewlineEngine`, and `isMarkdownFilename(_:)`
  - paths: [P2, N3]
- [x] 2.5 [RED] [SECURITY] TASK-004-RED: Write failing security tests in `Tests/SwiftEditTests/MarkdownSmartNewlineEngineTests.swift` for `N4` (binary read-only snapshot, out-of-range caret `-1`/`9999`, and `4097`-unit line all return `nil` safely with zero edits); verify failure on assertions [Const: DATA-003 (04-data-persistence/storage-and-migrations.md)]
  - paths: [P2, N4] · tags: security · priority: critical
- [x] 2.6 [GREEN] [SECURITY] TASK-004-GREEN: Enforce `isBinaryReadOnly`, caret bounds, `4096` UTF-16 line length guard, and safe integer overflow check on ordered-list increment in `MarkdownSmartNewlineEngine` so `N4` passes [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [P2, N4] · tags: security · priority: critical
- [x] 2.7 [REFACTOR] [SECURITY] TASK-004-REFACTOR: Verify zero regex backtracking and single-pass line slicing across all `MarkdownSmartNewlineEngine` paths [Const: BC-011 (02-domain/ubiquitous-language-and-policy.md)]
  - paths: [P2, N4] · tags: security
- [x] 2.8 [DOC] [SECURITY] TASK-004-DOC: Document binary read-only refusal, line-length cap, and integer-overflow guards on ordered list increments in English Swift Markup (`///`) comments
  - paths: [P2, N4]

## 3. Unit: WorkspaceTabReordering
<!-- Governing rules: AR-004, BC-006, BC-008, TEST-001, TEST-002 -->

- [x] 3.1 [RED] TASK-005-RED: Write failing `Swift Testing` tests in `Tests/SwiftEditTests/TabReorderAndBinarySidebarTests.swift` for `P3` (`moveTabLeft`, `moveTabRight`, and `moveTab(id:toIndex:)` reorder pinned `[P1, P2]` and unpinned `[U1, U2, U3]` within their respective partitions preserving `activeTabID`) and `N5` (cross-partition boundary moves remain inert preserving pinned-first ordering; unknown `DocumentID` throws `DomainError.tabNotFound`); verify failure on assertions [Const: BC-008 (02-domain/negative-ownership-and-refs.md)]
  - paths: [P3, N5]
- [x] 3.2 [GREEN] TASK-005-GREEN: Implement `moveTab(id:toIndex:)`, `moveTabLeft(id:)`, and `moveTabRight(id:)` in `Sources/SwiftEditCore/WorkspaceAndTabSession/WorkspaceTabSession.swift` clamping target indices strictly within each tab's pinned or unpinned partition so `P3` and `N5` pass [Const: BC-006 (02-domain/negative-ownership-and-refs.md)]
  - paths: [P3, N5]
- [x] 3.3 [REFACTOR] TASK-005-REFACTOR: Extract partition bounds calculation (`pinnedCount`) shared by `moveTab*` methods while keeping `WorkspaceTabSessionTests` and `TabSessionFileSyncTests` green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [P3, N5]
- [x] 3.4 [DOC] TASK-005-DOC: Write concise English Swift Markup (`///`) documentation on `WorkspaceTabSession.moveTab(id:toIndex:)`, `moveTabLeft(id:)`, and `moveTabRight(id:)`
  - paths: [P3, N5]

## 4. Unit: DotfileBinaryEntryDetection
<!-- Governing rules: BC-007, DATA-003, DATA-007, SEC-002, SEC-003, TEST-003, TEST-004 -->

- [x] 4.1 [RED] TASK-006-RED: Write failing `Swift Testing` tests in `Tests/SwiftEditTests/TabReorderAndBinarySidebarTests.swift` for `P4` (`DotfileFolderNavigator.listEntries` marks NUL-bearing `"archive.bin"` as `isBinary == true` while UTF-8 `"notes.md"` and directories report `isBinary == false`, with balanced `startCount == stopCount`); verify failure on assertions [Const: DATA-003 (04-data-persistence/storage-and-migrations.md)]
  - paths: [P4]
- [x] 4.2 [GREEN] TASK-006-GREEN: Extend `FolderEntryDescriptor` with `isBinary: Bool = false` and perform a bounded `DocumentCodec.binaryProbeBytes` (`8 KiB`) prefix check via `DocumentCodec.isBinaryPrefix(_:)` on confined regular files in `Sources/SwiftEditCore/WorkspaceAndTabSession/DotfileFolderNavigator.swift` so `P4` passes [Const: DATA-007 (04-data-persistence/write-read-separation.md)]
  - paths: [P4]
- [x] 4.3 [REFACTOR] TASK-006-REFACTOR: Extract the `8 KiB` `FileHandle` bounded prefix reader helper so directories and unreadable special files are skipped safely without full-file reads while keeping `DotfileNavigatorAndPreferencesTests` green [Const: TEST-004 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [P4]
- [x] 4.4 [DOC] TASK-006-DOC: Write concise English Swift Markup (`///`) documentation on `FolderEntryDescriptor.isBinary` and bounded `8 KiB` probing
  - paths: [P4]
- [x] 4.5 [RED] [SECURITY] TASK-007-RED: Write failing security tests in `Tests/SwiftEditTests/TabReorderAndBinarySidebarTests.swift` for `N6` (escaping symlink targeting an external binary file throws `DomainError.securityScopeViolation` before any byte probing occurs with `startCount == stopCount`); verify failure on assertions [Const: SEC-003 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P4, N6] · tags: security · priority: critical
- [x] 4.6 [GREEN] [SECURITY] TASK-007-GREEN: Enforce `verifyConfinement` on resolved child paths strictly prior to `8 KiB` binary probing in `DotfileFolderNavigator.listEntries` so `N6` passes [Const: SEC-002 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P4, N6] · tags: security · priority: critical
- [x] 4.7 [REFACTOR] [SECURITY] TASK-007-REFACTOR: Verify `defer { stopAccessing }` runs on all normal and throwing exits across `listEntries` and `resolveParentDirectory` [Const: SEC-002 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P4, N6] · tags: security
- [x] 4.8 [DOC] [SECURITY] TASK-007-DOC: Document `CWE-22` symlink confinement before binary prefix probing and `CWE-400` `8 KiB` read cap in English Swift Markup (`///`) comments
  - paths: [P4, N6]

## 5. Unit: ThemeSelectorCurrentLineAndZoom
<!-- Governing rules: UI-001, UI-002, UI-003, UI-004, UI-005, UI-006, UI-008, UI-012, TEST-001 -->

- [x] 5.1 [RED] TASK-008-RED: Write failing `Swift Testing` tests in `Tests/SwiftEditTests/EditorUXLayoutThemeAndAboutTests.swift` for `P5` (live `updateSystemColorScheme(prefersDark:)` switches `.auto` dynamically between Light and Black without reloading buffers; `PurpleThemePalette` exposes current-line `#161224` Dark / `#F3F0FA` Light, nested bracket depth tokens, backtick tint tokens, and disabled binary `#9CA3AF` Dark / `#52525B` Light; `EditorZoomController.sidebarScaledFontSizePoints` scales `13.0pt` to `19.5pt` at `150%`; non-mutating visual highlight projection computes current-line, nested brackets, and backticks without incrementing `BufferRevision`) and `N7` (clicking binary `FolderEntryDescriptor` performs zero tab opens, binary smart newline returns `false`, and sidebar zoom clamps at `50%` = `6.5pt` and `300%` = `39.0pt`); verify failure on assertions [Const: UI-003 (03-ui-ux/design-system-and-tokens.md)]
  - paths: [P5, N7]
- [x] 5.2 [GREEN] TASK-008-GREEN: Extend `PurpleThemePalette` and `EditorZoomController` in `Sources/SwiftEditUI/Theme/PurpleThemeAndZoom.swift`, add `SwiftEditWorkbenchModel.updateSystemColorScheme(prefersDark:)`, `backtickSpans`, `handleSmartNewline(at:)`, and binary-click guard in `openFolderEntry`, replace the clipped segmented `Picker` with an always-visible 3-button `Light | Dark | Auto` selector synced to `@Environment(\.colorScheme)`, and upgrade `TextKit2EditorView` with `SwiftEditNSTextView` (full-width current-line background in `drawBackground(in:)`, non-mutating `NSTextLayoutManager` rendering attributes for nested brackets/active pair/unbalanced brackets/backticks, and `insertNewline:` Markdown continuation hook) in `Sources/SwiftEditUI/Views/SwiftEditRootView.swift` so `P5` and `N7` pass [Const: UI-002 (03-ui-ux/design-system-and-tokens.md)]
  - paths: [P5, N7]
- [x] 5.3 [REFACTOR] TASK-008-REFACTOR: Extract `EditorHighlightProjection` and `SwiftEditNSTextView` decoration application into dedicated clean helpers respecting `<= 16 ms` keystroke budget while keeping `PurpleThemeZoomAndSafetyBannerTests` and `TextKit2EditorAndDiffCoordinatorTests` green [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
  - paths: [P5, N7]
- [x] 5.4 [DOC] TASK-008-DOC: Write concise English Swift Markup (`///`) documentation on new `PurpleThemePalette` highlight/binary tokens, `EditorZoomController.sidebarScaledFontSizePoints`, `SwiftEditWorkbenchModel.updateSystemColorScheme`, and `SwiftEditNSTextView`
  - paths: [P5, N7]

## 6. Unit: PercentageSidebarPinHoverToolbarAndContextCreate
<!-- Governing rules: BC-012, SEC-003, SEC-012, UI-001, UI-004, UI-005, UI-010, UI-011 -->

- [x] 6.1 [RED] TASK-009-RED: Write failing `Swift Testing` tests in `Tests/SwiftEditTests/EditorUXLayoutThemeAndAboutTests.swift` for `P6` (`SidebarLayoutGeometry` computes width strictly as `containerWidth * clampedRatio` across `1200pt` and `2560pt` displays with zero fixed pixel caps; `toggleSidebarPinCollapse()` collapses/expands sidebar; `isToolbarHovered` controls middle command visibility while Logo/Zoom/Theme stay always visible; `resolveSidebarCreationDirectory(for:)` resolves current folder on empty background, directory on folder row, and parent on file row; `moveTabLeft`/`moveTabRight` reorder open tabs in `SwiftEditWorkbenchModel`) and `N8` (out-of-bounds ratios `0.02`/`0.95` clamp to `0.12`/`0.65`, zero container width resolves to `0`, and empty/dot prompted names fail without disk mutations); verify failure on assertions [Const: UI-001 (03-ui-ux/design-system-and-tokens.md)]
  - paths: [P6, N8]
- [x] 6.2 [GREEN] TASK-009-GREEN: Implement `SidebarLayoutGeometry` (`minRatio = 0.12`, `maxRatio = 0.65`, `defaultRatio = 0.22`), `isLeftSidebarPinned` / `toggleSidebarPinCollapse()`, `isToolbarHovered`, `resolveSidebarCreationDirectory(for:)`, and workbench tab reorder methods (`moveTabLeft`, `moveTabRight`, `moveTab`) in `Sources/SwiftEditUI/Views/SwiftEditRootView.swift`; wire `GeometryReader`-based percentage sidebar + draggable percentage divider, manual `pin` collapse button + left-edge reopen handle, zoomed sidebar fonts/icons, disabled gray binary rows (click disabled, right-click Finder/Trash active), right-click `New File…` / `New Folder…` modal name prompts on BOTH entry rows and empty sidebar background, drag-and-drop + Move Left/Right on `EditorTabStrip`, and hover-revealed top-bar command buttons honoring `Reduce Motion` so `P6` and `N8` pass [Const: UI-005 (03-ui-ux/component-state-and-forms.md)]
  - paths: [P6, N8]
- [x] 6.3 [REFACTOR] TASK-009-REFACTOR: Extract interactive single-segment name prompt helper shared by `New File…`, `New Folder…`, and `Rename…` and update `KeyboardShortcutsCheatSheetCatalog` in `Sources/SwiftEditUI/Views/KeyboardShortcutsCheatSheetView.swift` while keeping `MinimalLayoutGutterAndParentNavigationTests` and `SidebarActionsAndWorkspaceHandoffTests` green [Const: UI-010 (03-ui-ux/accessibility-and-cwv.md)]
  - paths: [P6, N8]
- [x] 6.4 [DOC] TASK-009-DOC: Write concise English Swift Markup (`///`) documentation on `SidebarLayoutGeometry`, `toggleSidebarPinCollapse()`, `resolveSidebarCreationDirectory(for:)`, and tab reorder workbench actions
  - paths: [P6, N8]
- [x] 6.5 [RED] [SECURITY] TASK-010-RED: Write failing security tests in `Tests/SwiftEditTests/EditorUXLayoutThemeAndAboutTests.swift` for `N9` (prompted right-click Create File/Folder names `"../escape.md"`, `"a/b.md"`, BiDi `"a\u{202E}b.md"`, and symlinked target directories outside scope fail closed with `DomainError.invalidItemName` or `DomainError.securityScopeViolation`); verify failure on assertions [Const: SEC-003 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P6, N9] · tags: security · priority: critical
- [x] 6.6 [GREEN] [SECURITY] TASK-010-GREEN: Route all prompted empty-area and row right-click Create File / Create Folder calls strictly through `SidebarItemNameValidator` and confined `FileSystemProviding` in `SwiftEditWorkbenchModel` so `N9` passes [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [P6, N9] · tags: security · priority: critical
- [x] 6.7 [REFACTOR] [SECURITY] TASK-010-REFACTOR: Verify zero direct `FileManager` bypasses in sidebar context-menu actions and confirm `ArchitectureFitnessTests` passes [Const: AR-003 (01-architecture/module-topology.md)]
  - paths: [P6, N9] · tags: security
- [x] 6.8 [DOC] [SECURITY] TASK-010-DOC: Document `CWE-22` single-segment validation and symlink confinement for empty-area and row right-click creation in English Swift Markup (`///`) comments
  - paths: [P6, N9]

## 7. Unit: BrandLogoAndHelpAboutDialog
<!-- Governing rules: AR-014, SEC-004, UI-001, UI-008, UI-010, TEST-001 -->

- [x] 7.1 [RED] TASK-011-RED: Write failing `Swift Testing` tests in `Tests/SwiftEditTests/EditorUXLayoutThemeAndAboutTests.swift` for `P7` (`SwiftEditBrandLogoGeometry` defines Concept E2 vector tokens `#0B0614`/`#A78BFA`/`#C4B5FD`/`#7C3AED`; `SwiftEditHelpMenuCatalog` exposes `"About PH.SwiftEdit"` in the Help menu; `AboutSheetDescriptor` resolves App Name `"PH.SwiftEdit"`, `nbgv` version, validated GitHub repo URL, and validated MIT License URL `"https://github.com/paoloinnocenti/PH.SwiftEdit/blob/main/LICENSE"`); verify failure on assertions [Const: AR-014 (01-architecture/host-and-sagas.md)]
  - paths: [P7]
- [x] 7.2 [GREEN] TASK-011-GREEN: Implement `SwiftEditBrandLogoGeometry` and `SwiftEditBrandLogoView` in `Sources/SwiftEditUI/Views/SwiftEditBrandLogoView.swift`, place the small logo beside `PH.SwiftEdit` in `SwiftEditRootView.toolbarBar`, add `Button("About PH.SwiftEdit")` inside `CommandGroup(replacing: .help)` in `SwiftEditCommands`, and update `AboutSheetDescriptor` + `AboutSheetView` in `Sources/SwiftEditUI/Views/AboutSheetView.swift` with large `SwiftEditBrandLogoView` and MIT License link button so `P7` passes [Const: UI-001 (03-ui-ux/design-system-and-tokens.md)]
  - paths: [P7]
- [x] 7.3 [REFACTOR] TASK-011-REFACTOR: Consolidate external link confirmation state in `AboutSheetView` across repository and license buttons while keeping `WorkbenchSearchLifecycleAndMenusTests` green [Const: UI-008 (03-ui-ux/component-state-and-forms.md)]
  - paths: [P7]
- [x] 7.4 [DOC] TASK-011-DOC: Write concise English Swift Markup (`///`) documentation on `SwiftEditBrandLogoGeometry`, `SwiftEditBrandLogoView`, `AboutSheetDescriptor.officialLicenseURL`, and `Help -> About PH.SwiftEdit`
  - paths: [P7]
- [x] 7.5 [RED] [SECURITY] TASK-012-RED: Write failing security tests in `Tests/SwiftEditTests/EditorUXLayoutThemeAndAboutTests.swift` for `N10` (non-HTTPS or tampered license/repository URIs `"http://github.com/paoloinnocenti/PH.SwiftEdit/blob/main/LICENSE"`, `"javascript:alert(1)"`, and `"file:///LICENSE"` return `nil` from `AboutSheetDescriptor.prepareExternalLinkConfirmation(rawURI:)`); verify failure on assertions [Const: SEC-004 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P7, N10] · tags: security · priority: critical
- [x] 7.6 [GREEN] [SECURITY] TASK-012-GREEN: Enforce `https`-only host validation (`prepareExternalLinkConfirmation`) and user confirmation alert on both repository and MIT License links in `AboutSheetDescriptor` and `AboutSheetView` so `N10` passes [Const: SEC-004 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P7, N10] · tags: security · priority: critical
- [x] 7.7 [REFACTOR] [SECURITY] TASK-012-REFACTOR: Preserve `prepareRepositoryLinkConfirmation(rawURI:)` forwarding to `prepareExternalLinkConfirmation(rawURI:)` for zero breaking API regressions and run full `swift test` suite [Const: TEST-001 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [P7, N10] · tags: security
- [x] 7.8 [DOC] [SECURITY] TASK-012-DOC: Document `SEC-004` `https`-only validation and explicit user confirmation for both repository and license links in English Swift Markup (`///`) comments
  - paths: [P7, N10]

## 8. Unit: LivingSpecificationReconciliation
<!-- Governing rules: SDD-001, SDD-002 -->

- [x] 8.1 [SYNC] TASK-013-SYNC: Execute `/myspec-sync 008-editor-ux-highlighting-sidebar-pin-tabs-and-about` to reconcile delta changes into `openspec/specs/markdown-lint-format-bracket-and-diff/spec.md`, `openspec/specs/notepadpp-tabs-session-recovery-and-dotfiles/spec.md`, `openspec/specs/swifteditui-purple-zed-layout-textkit2-and-appicons/spec.md`, `openspec/specs/ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions/spec.md`, and `openspec/specs/editor-ux-highlighting-sidebar-pin-tabs-and-about/spec.md` (automatically marked `[x]` by `myspec_sync.py`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]
