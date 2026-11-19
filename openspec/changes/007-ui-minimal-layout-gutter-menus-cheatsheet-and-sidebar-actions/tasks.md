# Tasks: SwiftEditUI Minimalist Layout, Line Gutter, Classic Menus, CheatSheet, Parent ... Navigator and 11 Sidebar Actions

## 1. Unit: MinimalWorkspaceLayoutAndLineGutter
<!-- Governing rules: UI-001, UI-002, UI-004, UI-005, DATA-004, TEST-001, TEST-002 -->

- [ ] 1.1 [RED] TASK-001-RED: Write failing `Swift Testing` tests in `Tests/SwiftEditTests/MinimalLayoutGutterAndParentNavigationTests.swift` and `Tests/SwiftEditTests/PurpleThemeZoomAndSafetyBannerTests.swift` for `P1` (`isLeftSidebarCollapsed` defaults to `true`, stays `true` on single-file open, becomes `false` on `selectWorkspaceFolder`, `LineNumberGutterProjection` outputs `[1, 2, 3]` with active line `2`, and status metrics report line `2`, column `2`, `18` chars, `UTF-8`, `CRLF`) and `N1` (empty buffer `""` and out-of-range caret `99` clamp safely to `[1]` and line `1`, column `1`, `0` chars); verify failure on assertions [Const: UI-001 (03-ui-ux/design-system-and-tokens.md)]
  - paths: [P1, N1]
- [ ] 1.2 [GREEN] TASK-001-GREEN: Implement `LineNumberGutterProjection` and `LineNumberGutterView` in `Sources/SwiftEditUI/Views/LineNumberGutterView.swift` and update `SwiftEditWorkbenchModel` and `SwiftEditRootView` in `Sources/SwiftEditUI/Views/SwiftEditRootView.swift` (default `isLeftSidebarCollapsed = true`, auto-expand on folder open, right-column `EditorTabStrip`, left `LineNumberGutterView`, and live `CursorMetrics` status bar) so `P1` and `N1` pass [Const: UI-001 (03-ui-ux/design-system-and-tokens.md)]
  - paths: [P1, N1]
- [ ] 1.3 [REFACTOR] TASK-001-REFACTOR: Extract status-bar formatting and gutter line-break scanning helpers while keeping `PurpleThemeZoomAndSafetyBannerTests` and `TextKit2EditorAndDiffCoordinatorTests` green [Const: UI-002 (03-ui-ux/design-system-and-tokens.md)]
  - paths: [P1, N1]
- [ ] 1.4 [DOC] TASK-001-DOC: Write concise English Swift Markup (`///`) documentation on `LineNumberGutterProjection`, `LineNumberGutterView`, and `SwiftEditWorkbenchModel.isLeftSidebarCollapsed`
  - paths: [P1, N1]

## 2. Unit: SidebarParentFolderUpNavigation
<!-- Governing rules: BC-007, DATA-007, SEC-002, SEC-003, UI-001, TEST-003, TEST-004 -->

- [ ] 2.1 [RED] TASK-002-RED: Write failing tests in `Tests/SwiftEditTests/MinimalLayoutGutterAndParentNavigationTests.swift` for `P2` (entering `"/tmp/workspace/Sources"` sets `canNavigateToParentFolder == true`, first `navigateToParentFolder()` (`...`) ascends to `"/tmp/workspace"`, and second `navigateToParentFolder()` with parent read permission enabled ascends to `"/tmp"` and updates `grantedScopeRootURL`) and `N2` (at `"/"` or when `isParentReadable` is `false`, `canNavigateToParentFolder == false` and `navigateToParentFolder()` is a no-op keeping `selectedFolderURL` unchanged); verify failure on assertions [Const: BC-007 (02-domain/negative-ownership-and-refs.md)]
  - paths: [P2, N2]
- [ ] 2.2 [GREEN] TASK-002-GREEN: Implement `DotfileFolderNavigator.resolveParentDirectory(from:withinScope:isParentReadable:)` in `Sources/SwiftEditCore/WorkspaceAndTabSession/DotfileFolderNavigator.swift` and wire `canNavigateToParentFolder`, `navigateToParentFolder()`, and the leading `...` sidebar button in `Sources/SwiftEditUI/Views/SwiftEditRootView.swift` so `P2` and `N2` pass [Const: DATA-007 (04-data-persistence/write-read-separation.md)]
  - paths: [P2, N2]
- [ ] 2.3 [REFACTOR] TASK-002-REFACTOR: Consolidate active scope-root tracking (`grantedScopeRootURL`) and folder entry refresh on `...` navigation while keeping `DotfileNavigatorAndPreferencesTests` green [Const: TEST-004 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [P2, N2]
- [ ] 2.4 [DOC] TASK-002-DOC: Write concise English Swift Markup (`///`) documentation on `resolveParentDirectory`, `canNavigateToParentFolder`, and `navigateToParentFolder()`
  - paths: [P2, N2]
- [ ] 2.5 [RED] [SECURITY] TASK-003-RED: Write failing security test in `Tests/SwiftEditTests/MinimalLayoutGutterAndParentNavigationTests.swift` for `N3` (ascending via `...` when the current folder or parent path traverses a symlink escaping the permitted hierarchy throws `DomainError.securityScopeViolation` and leaves `selectedFolderURL` and `folderEntries` unchanged); verify failure on assertions [Const: SEC-003 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P2, N3] · tags: security · priority: critical
- [ ] 2.6 [GREEN] [SECURITY] TASK-003-GREEN: Enforce `resolvingSymlinksInPath()` canonical parent hierarchy validation and balanced security-scoped resource access in `DotfileFolderNavigator.resolveParentDirectory` and `SwiftEditWorkbenchModel.navigateToParentFolder()` so `N3` passes [Const: SEC-002 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P2, N3] · tags: security · priority: critical
- [ ] 2.7 [REFACTOR] [SECURITY] TASK-003-REFACTOR: Share canonical confinement checks between `listEntries` and `resolveParentDirectory` without weakening any security assertion [Const: SEC-003 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P2, N3] · tags: security
- [ ] 2.8 [DOC] [SECURITY] TASK-003-DOC: Document `CWE-22`/`CWE-59` symlink parent-escape prevention and user-permission checks in English Swift Markup (`///`) comments
  - paths: [P2, N3]

## 3. Unit: FindReplaceGoToLineAndDirtyLifecycle
<!-- Governing rules: BC-004, BC-006, BC-008, BC-011, DATA-004, DATA-006, DATA-008, UI-009 -->

- [ ] 3.1 [RED] TASK-004-RED: Write failing `@Suite("WorkbenchSearchLifecycleAndMenusTests")` tests in `Tests/SwiftEditTests/WorkbenchSearchLifecycleAndMenusTests.swift` for `P3` (Find `"one"`, Replace All with `"ONE"`, Go to Line `2`, switch active document `LineEnding` to `.cr`, record/reopen in `RecentFilesStore` without duplicate, and close dirty tab with `.dontSave` unlinking its recovery snapshot) and `N4` (`.cancel` on dirty tab close or `requestApplicationTermination` keeps dirty tab open and cancels quit, and `openAllFilesInFolder` with `> 50` files waits for `confirmPendingBatchOpen()`); verify failure on assertions [Const: DATA-004 (04-data-persistence/storage-and-migrations.md)]
  - paths: [P3, N4]
- [ ] 3.2 [GREEN] TASK-004-GREEN: Implement `FindReplaceBarState` and `FindReplaceGoToLineBar` in `Sources/SwiftEditUI/Views/FindReplaceGoToLineBar.swift`, `DirtyCloseDecision`, batch confirmation state, `RecentFilesStore` integration, and 3-way `LineEnding` switching in `Sources/SwiftEditUI/Views/SwiftEditRootView.swift` so `P3` and `N4` pass [Const: BC-008 (02-domain/negative-ownership-and-refs.md)]
  - paths: [P3, N4]
- [ ] 3.3 [REFACTOR] TASK-004-REFACTOR: Extract search/replace state transitions and dirty-tab close/quit reconciliation helpers while keeping all suites green [Const: DATA-008 (04-data-persistence/write-read-separation.md)]
  - paths: [P3, N4]
- [ ] 3.4 [DOC] TASK-004-DOC: Write concise English Swift Markup (`///`) documentation on `FindReplaceBarState`, `FindReplaceGoToLineBar`, `DirtyCloseDecision`, and batch-open confirmation methods
  - paths: [P3, N4]

## 4. Unit: MenusCheatSheetAndAboutGuard
<!-- Governing rules: AR-014, SEC-004, UI-008, UI-009, UI-010, TEST-002 -->

- [ ] 4.1 [RED] TASK-005-RED: Write failing tests in `Tests/SwiftEditTests/WorkbenchSearchLifecycleAndMenusTests.swift` for `P4` (`KeyboardShortcutsCheatSheetCatalog` covers all `File`, `Edit`, `View`, `Navigation`, and `Sidebar` shortcuts including `...` parent navigation, and `AboutSheetDescriptor` resolves `"0.0.1-alpha1"` and validates `"https://github.com/paoloinnocenti/PH.SwiftEdit"`) and `N5` (tampered URIs `"javascript:alert(1)"`, `"file:///etc/passwd"`, and `"https://"` return `nil` confirmation prompt); verify failure on assertions [Const: UI-010 (03-ui-ux/accessibility-and-cwv.md)]
  - paths: [P4, N5] · tags: security · priority: critical
- [ ] 4.2 [GREEN] [SECURITY] TASK-005-GREEN: Implement `KeyboardShortcutDescriptor`, `KeyboardShortcutsCheatSheetCatalog`, and `KeyboardShortcutsCheatSheetView` in `Sources/SwiftEditUI/Views/KeyboardShortcutsCheatSheetView.swift`, `AboutSheetDescriptor` and `AboutSheetView` in `Sources/SwiftEditUI/Views/AboutSheetView.swift`, and `@FocusedValue` `SwiftEditCommands` in `Sources/SwiftEditUI/Views/SwiftEditRootView.swift` and `XcodeApp/SwiftEditApp.swift` so `P4` and `N5` pass [Const: SEC-004 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P4, N5] · tags: security · priority: critical
- [ ] 4.3 [REFACTOR] [SECURITY] TASK-005-REFACTOR: Deduplicate external URI validation between `AboutSheetDescriptor` and `InspectionSafetyBannerState.prepareExternalURIConfirmation` while keeping the suite green [Const: UI-008 (03-ui-ux/component-state-and-forms.md)]
  - paths: [P4, N5] · tags: security
- [ ] 4.4 [DOC] [SECURITY] TASK-005-DOC: Write concise English Swift Markup (`///`) documentation on `KeyboardShortcutsCheatSheetCatalog`, `AboutSheetDescriptor`, and `SwiftEditCommands`
  - paths: [P4, N5]

## 5. Unit: SidebarCRUDAndDesktopWorkspaceHandoff
<!-- Governing rules: AR-003, AR-007, BC-012, SEC-002, SEC-003, SEC-004, TEST-003, TEST-004 -->

- [ ] 5.1 [RED] TASK-006-RED: Write failing `@Suite("SidebarActionsAndWorkspaceHandoffTests")` tests in `Tests/SwiftEditTests/SidebarActionsAndWorkspaceHandoffTests.swift` for `P5` (all 11 sidebar actions: `createDirectory`, `createFile`, `renameItem` updating open tab in place, `cut`/`copy`/`pasteItem` producing `"final copy.md"`, confirmed `trashItem` moving to Trash and syncing tabs, `revealInFinder`, `openFolderInFinder`, and `openInTerminal` resolving selected file `"final.md"` to its parent directory URL and launching `"com.googlecode.iterm2"` when installed/preferred or `"com.apple.Terminal"` fallback) and `N6` (empty sidebar clipboard paste and `cancelPendingTrashItem()` perform zero mutations); verify failure on assertions [Const: BC-012 (02-domain/ubiquitous-language-and-policy.md)]
  - paths: [P5, N6]
- [ ] 5.2 [GREEN] TASK-006-GREEN: Implement `DesktopWorkspaceIntegrating`, `TerminalAppPreference`, and `MacOSWorkspaceAdapter` in `Sources/SwiftEditUI/Workspace/DesktopWorkspaceIntegrating.swift` and wire the 11 sidebar actions and context menu in `Sources/SwiftEditUI/Views/SwiftEditRootView.swift` so `P5` and `N6` pass [Const: AR-007 (01-architecture/dependency-and-layering.md)]
  - paths: [P5, N6]
- [ ] 5.3 [REFACTOR] TASK-006-REFACTOR: Extract sidebar clipboard and target-directory resolution helpers while keeping `SidebarFileOperationsTests` and `TabSessionFileSyncTests` green [Const: AR-003 (01-architecture/module-topology.md)]
  - paths: [P5, N6]
- [ ] 5.4 [DOC] TASK-006-DOC: Write concise English Swift Markup (`///`) documentation on `DesktopWorkspaceIntegrating`, `TerminalAppPreference`, `MacOSWorkspaceAdapter`, and `SidebarFileClipboard`
  - paths: [P5, N6]
- [ ] 5.5 [RED] [SECURITY] TASK-007-RED: Write failing security tests in `Tests/SwiftEditTests/SidebarActionsAndWorkspaceHandoffTests.swift` for `N7` (`openInTerminal` on `"deploy.command"` never passes the file URL to the terminal and resolves only its verified parent directory, while calling `openInTerminal`, `revealInFinder`, or `openFolderInFinder` on a symlink escaping the workspace scope or with an unallowlisted terminal bundle ID `"com.evil.shell"` throws `DomainError.securityScopeViolation` with zero launches); verify failure on assertions [Const: SEC-004 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P5, N7] · tags: security · priority: critical
- [ ] 5.6 [GREEN] [SECURITY] TASK-007-GREEN: Enforce `resolvingSymlinksInPath()` workspace confinement, directory-only resolution (`isDirectory == true`), and the `["com.googlecode.iterm2", "com.apple.Terminal"]` bundle allowlist in `DesktopWorkspaceIntegrating` and `MacOSWorkspaceAdapter` so `N7` passes [Const: SEC-004 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P5, N7] · tags: security · priority: critical
- [ ] 5.7 [REFACTOR] [SECURITY] TASK-007-REFACTOR: Consolidate directory-only and scope-confinement guards across Finder and Terminal handoffs, clean `./.tmp/`, and run `swift test --parallel -Xswiftc -warnings-as-errors --enable-code-coverage` confirming all suites and fitness gates pass [Const: TEST-008 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P5, N7] · tags: security
- [ ] 5.8 [DOC] [SECURITY] TASK-007-DOC: Document `CWE-78` directory-only terminal handoff, zero-subprocess execution, and `SEC-003`/`SEC-004` confinement invariants in English Swift Markup (`///`) comments
  - paths: [P5, N7]

## 6. Unit: LivingSpecificationReconciliation
<!-- Required because the change includes a MODIFIED requirement -->

- [ ] 6.1 [SYNC] TASK-008-SYNC: Execute `/myspec-sync 007-ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions` to reconcile delta changes into `openspec/specs/swifteditui-purple-zed-layout-textkit2-and-appicons/spec.md` and `openspec/specs/ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions/spec.md` (automatically marked `[x]` by `myspec_sync.py`)
