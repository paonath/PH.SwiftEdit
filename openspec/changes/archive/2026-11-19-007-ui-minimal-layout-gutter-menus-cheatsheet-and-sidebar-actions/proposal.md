# Proposal: SwiftEditUI Minimalist Layout, Line Gutter, Classic Menus, CheatSheet, Parent ... Navigator and 11 Sidebar Actions

## Why
Guided reasoning session `002_minimal-ui-menus-and-editor-features` (`TASK-03` in `README.ai.md`) and user requirement #1 (*"Nel navigatore a SX DEVO poter salire di livello (pulsante `...` per andare alla folder precedente) SE i permessi utente me lo concedono"*) complete the user-facing workspace shell over the `SwiftEditCore` engine delivered in change `006`. Constitution `v1.3.0` (`UI-001`, `DATA-004`, `SEC-004`) mandates a default-collapsed left sidebar that auto-expands on `Open Folder`, a right-column `EditorTabStrip`, a left 1-based `LineNumberGutterView`, a bottom-right `Line`/`Column`/`Character count`/`UTF-8`/`LF`/`CRLF`/`CR` status bar, classic macOS menus (`File`, `Edit`, `View`, `Help`, `About`), a graphical keyboard-shortcut `CheatSheet`, `Find`/`Replace`/`Go to Line`, dirty close/quit prompts, parent-folder (`...`) navigation when permitted by user permissions, and all 11 confined sidebar file/folder and `Finder`/`Terminal`/`iTerm2` actions.

## What Changes
- `Sources/SwiftEditCore/WorkspaceAndTabSession/DotfileFolderNavigator.swift`: add `parentDirectoryURL(for:withinScope:isReadableDirectory:)` / `canNavigateToParent(from:withinScope:isReadableDirectory:)` supporting parent-folder (`...`) up-navigation whenever `currentDirectoryURL.path != "/"` and the resolved parent directory is within the user-granted scope or readable under active user permissions, while rejecting symlink escapes (`[BC-007]`, `[DATA-007]`, `[SEC-002]`, `[SEC-003]`).
- `Sources/SwiftEditUI/Views/LineNumberGutterView.swift`: add `LineNumberGutterProjection` (`1..max(1, lineCount)`, 1-based active line highlight, monospaced font scaled by `EditorZoomController.scaledFontSizePoints`) and `LineNumberGutterView` rendered immediately to the left of `TextKit2EditorView` (`[UI-001]`, `[UI-002]`, `[UI-004]`).
- `Sources/SwiftEditUI/Views/FindReplaceGoToLineBar.swift`: add `FindReplaceBarState` and `FindReplaceGoToLineBar` (`Cmd+F` Find, `Cmd+H` Find & Replace, `Cmd+G` Go to Line) wired to `DocumentSearchEngine` (`[BC-004]`, `[UI-009]`).
- `Sources/SwiftEditUI/Views/KeyboardShortcutsCheatSheetView.swift` and `Sources/SwiftEditUI/Views/AboutSheetView.swift`: add `KeyboardShortcutDescriptor`, `KeyboardShortcutsCheatSheetCatalog` (covering `File`, `Edit`, `View`, `Navigation`, and `Sidebar` including `...` parent navigation, triggerable from `Help` menu and toolbar button), `AboutSheetDescriptor` (`nbgv` version + `https://github.com/paoloinnocenti/PH.SwiftEdit` gated by `InspectionSafetyBannerState.prepareExternalURIConfirmation`), and their SwiftUI sheet views (`[AR-014]`, `[SEC-004]`, `[UI-008]`, `[UI-010]`).
- `Sources/SwiftEditUI/Workspace/DesktopWorkspaceIntegrating.swift`: add `@MainActor` `DesktopWorkspaceIntegrating` protocol (`revealInFinder`, `openFolderInFinder`, `openInTerminal`), `TerminalAppPreference` (`com.googlecode.iterm2` preferred when installed/default, fallback `com.apple.Terminal`), and `MacOSWorkspaceAdapter` enforcing directory-only resolution (resolving any selected file URL to its parent directory URL) and symlink confinement with zero subprocesses (`[AR-003]`, `[AR-007]`, `[SEC-003]`, `[SEC-004]`).
- `Sources/SwiftEditUI/Views/SwiftEditRootView.swift` & `XcodeApp/SwiftEditApp.swift`: update `SwiftEditWorkbenchModel` and `SwiftEditRootView` so `isLeftSidebarCollapsed` defaults to `true`, auto-expands on `Open Folder` / `Open All Files in Folder`, renders `EditorTabStrip` strictly above the right editor column, renders the leading `...` parent-folder button in the left sidebar, wires the 10-entry `RecentFilesStore`, 50-file `ShallowFolderBatchLoader` confirmation prompt, 3-way `LineEnding` (`LF`, `CRLF`, `CR`) picker, live `CursorMetrics` status bar, dirty `Close`/`Quit` confirmation (`Save / Don't Save / Cancel`), all 11 sidebar context/toolbar actions, and `@FocusedValue` macOS menu `Commands` (`[UI-001]`, `[UI-005]`, `[DATA-004]`, `[DATA-008]`).

## Capabilities
- New Capabilities: `ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions`
- Modified Capabilities: `swifteditui-purple-zed-layout-textkit2-and-appicons` (`REQ-001`)

## Domain Carrier & Decision Ownership (BC-###)
- **BC-001**: `SwiftEditUI` presentation and coordination layer (`SwiftEditWorkbenchModel`, `LineNumberGutterProjection`, `FindReplaceBarState`, `KeyboardShortcutsCheatSheetCatalog`, `AboutSheetDescriptor`, `DesktopWorkspaceIntegrating`) consuming `SwiftEditCore` bounded contexts (`DocumentCore`, `WorkspaceAndTabSession`, `SearchDiffAndBracketEngine`, `MarkdownLintAndFormat`) (`[BC-001]`, `[BC-004]`, `[BC-007]`).
- **Owned Decisions**: Default-collapsed sidebar state (`isLeftSidebarCollapsed`), parent-folder `...` availability and upward folder transition under user permissions, right-column tab strip placement, 1-based line gutter projection, dirty close/quit confirmation state machine, `CheatSheet` shortcut catalog, `About` metadata projection, and directory-only `Finder`/`Terminal`/`iTerm2` `NSWorkspace` handoff.
- **Forbidden Responsibilities**: `SwiftEditUI` MUST NEVER spawn shell subprocesses (`Process`, `posix_spawn`, `osascript`), pass a file URL (e.g. `.sh`, `.command`, `.term`) as a Terminal execution target, permanently delete user files instead of moving them to Trash, or open unvalidated non-HTTPS external links (`[AR-002]`, `[BC-005]`, `[SEC-004]`).
- **External Decision References**: Consumes `DocumentID`, `BufferRevision`, `TabDescriptor`, `CursorMetrics`, `RecentFileEntry`, `BatchOpenPlan`, `FolderEntryDescriptor`, and `PasteMode` (`[BC-006]`).

## Impact
- **Source Modules**: modifies `Sources/SwiftEditCore/WorkspaceAndTabSession/DotfileFolderNavigator.swift`, `Sources/SwiftEditUI/Views/SwiftEditRootView.swift`, and `XcodeApp/SwiftEditApp.swift`; adds `Sources/SwiftEditUI/Views/LineNumberGutterView.swift`, `Sources/SwiftEditUI/Views/FindReplaceGoToLineBar.swift`, `Sources/SwiftEditUI/Views/KeyboardShortcutsCheatSheetView.swift`, `Sources/SwiftEditUI/Views/AboutSheetView.swift`, and `Sources/SwiftEditUI/Workspace/DesktopWorkspaceIntegrating.swift`.
- **Test Suites**: updates `Tests/SwiftEditTests/PurpleThemeZoomAndSafetyBannerTests.swift`; adds `Tests/SwiftEditTests/MinimalLayoutGutterAndParentNavigationTests.swift`, `Tests/SwiftEditTests/WorkbenchSearchLifecycleAndMenusTests.swift`, and `Tests/SwiftEditTests/SidebarActionsAndWorkspaceHandoffTests.swift`.

## Security Impact
- **Parent-Folder (`...`) Confinement & Permission Check (`CWE-22`, `CWE-59`)**: Ascending via `...` resolves symlinks via `resolvingSymlinksInPath()`, blocks filesystem root `"/"` underflow, verifies user directory read permissions, and aborts with `DomainError.securityScopeViolation` if a symlink points outside permitted paths (`[SEC-002]`, `[SEC-003]`).
- **Directory-Only Terminal Handoff (`CWE-78`)**: `openInTerminal` resolves any selected file to its verified parent directory URL, confirms `isDirectory == true` inside the active workspace scope, and opens only allowlisted `com.googlecode.iterm2` or `com.apple.Terminal` via `NSWorkspace` with zero subprocesses (`[SEC-004]`).
- **External Link Guard (`CWE-20`, `SEC-004`)**: `AboutSheetDescriptor` gates `https://github.com/paoloinnocenti/PH.SwiftEdit` through `InspectionSafetyBannerState.prepareExternalURIConfirmation(rawURI:)`.
- **Non-Destructive File Lifecycle (`CWE-73`)**: Dirty close/quit requires explicit `Save / Don't Save / Cancel`; sidebar Delete requires user confirmation and delegates exclusively to `FileSystemProviding.trashItem`.

## Metadata
- Owner: PH.SwiftEdit Team
- Domain: SwiftEditUI Minimalist Layout, Line Gutter, Classic Menus, CheatSheet, Parent Navigator and 11 Sidebar Actions
- Reviewer: swift-macos-expert, cyber-security-expert
- Branch: feature/FirstStub
- Manual-Steps: none
- Modifies-Specs: swifteditui-purple-zed-layout-textkit2-and-appicons (REQ-001)
- Constitutional-Rules: [AR-001, AR-002, AR-003, AR-007, AR-014, BC-004, BC-006, BC-007, BC-008, BC-011, BC-012, DATA-003, DATA-004, DATA-006, DATA-007, DATA-008, SEC-002, SEC-003, SEC-004, SEC-011, SEC-012, TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, UI-001, UI-002, UI-003, UI-004, UI-005, UI-008, UI-009, UI-010, UI-012, SDD-001, SDD-002]
- Amends-Constitution: none

## Prerequisites
- Archived `005-constitution-v1-3-lineending-cr-and-workspace-handoff` and `006-core-cr-lineending-mru-batch-search-and-sidebar-fs`.
