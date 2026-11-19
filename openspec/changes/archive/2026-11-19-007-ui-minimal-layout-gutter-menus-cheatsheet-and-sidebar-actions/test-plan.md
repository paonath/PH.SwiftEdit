# Test Plan: SwiftEditUI Minimalist Layout, Line Gutter, Classic Menus, CheatSheet, Parent ... Navigator and 11 Sidebar Actions

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `MinimalWorkspaceLayoutAndLineGutter` (`SwiftEditWorkbenchModel`, `LineNumberGutterProjection`) | `P1`: `isLeftSidebarCollapsed` starts `true`, stays `true` on single-file open, becomes `false` on folder open, `LineNumberGutterProjection` outputs `[1, 2, 3]` with active line `2`, and status metrics report `Line 2, Col 2, 18 chars, UTF-8, CRLF` (`[UI-001]`, `[UI-002]`, `[DATA-004]`). | `N1`: empty buffer `""` and out-of-range caret `99` clamp safely to line `[1]`, active line `1`, column `1`, `0` chars without throwing (`[UI-004]`, `[UI-012]`). |
| `SidebarParentFolderUpNavigation` (`DotfileFolderNavigator`, `SwiftEditWorkbenchModel.navigateToParentFolder`) | `P2`: entering subfolder `"/tmp/workspace/Sources"` enables `canNavigateToParentFolder == true`, clicking `...` ascends to `"/tmp/workspace"`, and clicking `...` again with readable parent permission ascends to `"/tmp"` while updating `grantedScopeRootURL` (`[BC-007]`, `[DATA-007]`, `[SEC-002]`). | `N2`: at filesystem root `"/"` or when parent directory lacks user read permission, `canNavigateToParentFolder` is `false` and `navigateToParentFolder()` leaves `selectedFolderURL` unchanged; `N3` (`security`): symlinked parent escaping permitted hierarchy throws `DomainError.securityScopeViolation` (`[SEC-002]`, `[SEC-003]`). |
| `FindReplaceGoToLineAndDirtyLifecycle` (`FindReplaceBarState`, `SwiftEditWorkbenchModel`) | `P3`: literal find/replace-all, go-to-line `2`, line-ending switch to `.cr`, 10-entry MRU reopen without duplicate, and dirty close with `.dontSave` closes tab and unlinks recovery snapshot (`[BC-004]`, `[DATA-004]`, `[DATA-008]`). | `N4`: `.cancel` on dirty tab close or app quit preserves open dirty tab and returns `false` for termination; batch folder open above `50` files waits for `confirmPendingBatchOpen()` (`[BC-008]`, `[BC-011]`). |
| `MenusCheatSheetAndAboutGuard` (`KeyboardShortcutsCheatSheetCatalog`, `AboutSheetDescriptor`) | `P4`: `KeyboardShortcutsCheatSheetCatalog` lists all `File`, `Edit`, `View`, `Navigation`, and `Sidebar` (including `...` parent navigation) shortcuts; `AboutSheetDescriptor` resolves `"0.0.1-alpha1"` and validates `"https://github.com/paoloinnocenti/PH.SwiftEdit"` (`[AR-014]`, `[UI-009]`, `[UI-010]`, `[SEC-004]`). | `N5` (`security`): tampered URIs (`"javascript:alert(1)"`, `"file:///etc/passwd"`, `"https://"`) return `nil` confirmation prompt and block external handoff (`[SEC-004]`, `[UI-008]`). |
| `SidebarCRUDAndDesktopWorkspaceHandoff` (`SwiftEditWorkbenchModel`, `DesktopWorkspaceIntegrating`, `MacOSWorkspaceAdapter`) | `P5`: all 11 sidebar actions execute inside scope (`createDirectory`, `createFile`, `renameItem` with tab sync, `cut`/`copy`/`pasteItem` with collision suffix, confirmed `trashItem` with tab sync, `revealInFinder`, `openFolderInFinder`, and `openInTerminal` resolving files to parent directory and launching `com.googlecode.iterm2` or fallback `com.apple.Terminal`) (`[BC-012]`, `[SEC-002]`, `[SEC-004]`). | `N6`: empty clipboard paste and canceled Trash confirmation perform zero mutations; `N7` (`security`): `openInTerminal` on `"deploy.command"` never passes the file URL to the terminal, while escaping symlink targets and unallowlisted terminal bundle IDs throw `DomainError.securityScopeViolation` (`[SEC-003]`, `[SEC-004]`). |

## 2. Test Automation Strategy & Commands
- Unit test runner command: `swift test --parallel`
- Targeted suites: `swift test --parallel --filter MinimalLayoutGutterAndParentNavigationTests`, `--filter WorkbenchSearchLifecycleAndMenusTests`, `--filter SidebarActionsAndWorkspaceHandoffTests`, `--filter PurpleThemeZoomAndSafetyBannerTests`
- Security trait filter command: `swift test --parallel --filter Security`
- Coverage and warnings gate: `swift test --parallel -Xswiftc -warnings-as-errors --enable-code-coverage`

## 3. Testability Seams & Test Doubles
- Real collaborators: `SwiftEditWorkbenchModel`, `DotfileFolderNavigator`, `DocumentSearchEngine`, `RecentFilesStore`, `ShallowFolderBatchLoader`, `LocalFileSystemAdapter`, and real temporary workspace directories under `.tmp/test-results/<UUID>/` cleaned via `defer`.
- Isolation seams: `DesktopWorkspaceIntegrating` recording fake (verifying `revealInFinder`, `openFolderInFinder`, and `openInTerminal` directory URLs and bundle IDs without launching macOS `Finder`/`Terminal`), `ItemTrashing` recording fake, injected `isParentReadable` closure, ephemeral `SessionRecoveryStore` directory, and unique `UserDefaults(suiteName:)` suites (`[TEST-003]`, `[TEST-004]`).

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | Given/When/Then scenarios defined across `REQ-001..REQ-005` in `ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions` and modified `REQ-001` in `swifteditui-purple-zed-layout-textkit2-and-appicons` |
| Path coverage completeness | Verified | All 5 units cover positive (`P1..P5`) and negative (`N1..N7`) paths |
| Security traits tagged | Verified | Abuse cases `N3`, `N5`, and `N7` tagged `- **Trait**: security` (`[SEC-002]`, `[SEC-003]`, `[SEC-004]`, `[UI-008]`) |
