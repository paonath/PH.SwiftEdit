# Design: SwiftEditUI Minimalist Layout, Line Gutter, Classic Menus, CheatSheet, Parent ... Navigator and 11 Sidebar Actions

## Context
Change `006` delivered the `SwiftEditCore` foundation for `TASK-02`: 3-way `LineEnding` (`.lf`, `.crlf`, `.cr`), `CursorMetricsCalculator`, 10-entry `RecentFilesStore`, 50-file `ShallowFolderBatchLoader`, `DocumentSearchEngine`, confined `FileSystemProviding` CRUD/Paste/Trash operations, and `WorkspaceTabSession.applyRename`/`applyTrash`. Change `007` (`TASK-03`) completes the `SwiftEditUI` and `XcodeApp` shell according to Constitution `v1.3.0` (`UI-001`, `DATA-004`, `SEC-004`) and adds the user-requested `...` parent-folder up-navigation button in the left Folder Navigator sidebar whenever user permissions allow reading the parent directory.

## Goals / Non-Goals
- Goals:
  - Restructure `SwiftEditRootView` and `SwiftEditWorkbenchModel` so `isLeftSidebarCollapsed` starts `true` on empty launch or single-file open, auto-expands on `Open Folder` (`Cmd+Shift+O`) or `Open All Files in Folder` (`Cmd+Shift+Option+O`), and places `EditorTabStrip` strictly above the right editor column (`[UI-001]`).
  - Add a leading `...` parent-folder navigation entry/button in the left sidebar that ascends to the parent directory whenever not at `"/"` and user permissions allow reading the parent directory within symlink-verified scope (`[BC-007]`, `[DATA-007]`, `[SEC-002]`, `[SEC-003]`).
  - Render a synchronized left 1-based `LineNumberGutterView` (`LineNumberGutterProjection`) and bottom-right status bar (`Line`, `Column`, `Character count`, `UTF-8`, and `LF`/`CRLF`/`CR`) (`[UI-001]`, `[UI-002]`, `[DATA-004]`).
  - Implement `FindReplaceGoToLineBar` (`Cmd+F`, `Cmd+H`, `Cmd+G`), dirty close/quit confirmation (`Save / Don't Save / Cancel`), `@FocusedValue` classic macOS menus (`File`, `Edit`, `View`, `Help`, `About`), graphical `KeyboardShortcutsCheatSheetView`, and `AboutSheetView` (`[UI-008]`, `[UI-009]`, `[UI-010]`, `[SEC-004]`).
  - Wire all 11 sidebar actions (`Reveal in Finder`, `Open Folder in Finder`, `Open Terminal` preferring `com.googlecode.iterm2` else `com.apple.Terminal`, `New Folder`, `Rename Folder`, `New File`, `Cut File`, `Copy File`, `Paste File`, `Delete File` to Trash, `Rename File`) behind `FileSystemProviding` and `DesktopWorkspaceIntegrating` (`[AR-007]`, `[BC-012]`, `[SEC-004]`).
- Non-Goals:
  - Spawning shell subprocesses (`Process`, `posix_spawn`, `osascript`) or built-in terminal emulators (`[BC-005]`, `[SEC-004]`).
  - Multi-folder workspace trees or deep recursive file watchers (`[BC-005]`).

## Architecture Memory & Module Boundaries (AR-###)
- **AR-001**: Cross-platform `DotfileFolderNavigator` parent-resolution helpers live in `Sources/SwiftEditCore/WorkspaceAndTabSession/DotfileFolderNavigator.swift`; UI models, projections, views, and `DesktopWorkspaceIntegrating` live in `Sources/SwiftEditUI/`; app scene commands live in `XcodeApp/SwiftEditApp.swift` (`[AR-001]`).
- **AR-002**: `SwiftEditCore` continues to import only `Foundation` and `Markdown` (`[AR-002]`).
- **AR-003**: `SwiftEditUI` isolates `AppKit` (`NSWorkspace`, `NSPasteboard`, `NSOpenPanel`, `NSSavePanel`, `NSTextView`) behind `#if os(macOS)` while exposing platform-neutral value-type projections (`LineNumberGutterProjection`, `FindReplaceBarState`, `KeyboardShortcutsCheatSheetCatalog`, `AboutSheetDescriptor`, `SidebarFileClipboard`, `DirtyCloseDecision`) testable in parallel via `swift test` (`[AR-003]`, `[TEST-003]`).
- **AR-007**: Desktop handoffs (`Finder`, `iTerm2`, `Terminal.app`) use a narrow `1:1` `DesktopWorkspaceIntegrating` seam with `MacOSWorkspaceAdapter` in production and a recording fake in unit tests (`[AR-007]`, `[TEST-004]`).
- **Single-Reference Lock**: Loaded `openspec/Constitution.md` (`v1.3.0`) with `01-architecture/module-topology.md`, `03-ui-ux/design-system-and-tokens.md`, `06-testing-fitness/tdd-and-unit-testing.md`, `07-security-privacy/authn-authz-and-boundaries.md`, and `08-sdd-governance/artifact-traceability.md` (`[SDD-009]`).

## Bounded Context Classification & Ubiquitous Language Glossary (`BC-002`, `BC-009`)

| Component / Type | Context (Tier) | Normative Definition |
| :--- | :--- | :--- |
| `DotfileFolderNavigator.resolveParentDirectory` | `WorkspaceAndTabSession` (`Supporting`) | Computes and validates the parent directory URL for `...` navigation: checks `currentURL.path != "/"`, verifies symlink confinement or readable user permissions on the parent directory, and updates the effective scope root when user permissions allow ascending (`[BC-007]`, `[SEC-002]`, `[SEC-003]`). |
| `LineNumberGutterProjection` / `LineNumberGutterView` | `SwiftEditUI` (`Presentation`) | Value-type projection `(lineNumbers: [Int], activeLine: Int, fontSizePoints: Double)` computing 1-based line numbers (`1..max(1, lineCount)`) across `LF`/`CRLF`/`CR` and rendering to the left of `TextKit2EditorView` (`[UI-001]`, `[UI-002]`, `[UI-004]`). |
| `FindReplaceBarState` / `FindReplaceGoToLineBar` | `SwiftEditUI` (`Presentation`) | State and bar supporting `find` (`Cmd+F`), `findAndReplace` (`Cmd+H`), and `goToLine` (`Cmd+G`) backed by `DocumentSearchEngine` (`[BC-004]`, `[UI-009]`). |
| `KeyboardShortcutsCheatSheetCatalog` / `KeyboardShortcutsCheatSheetView` | `SwiftEditUI` (`Presentation`) | Categorized shortcut catalog (`File`, `Edit`, `View`, `Navigation`, `Sidebar` including `...` parent navigation) presented via `Help` menu or toolbar button (`[UI-009]`, `[UI-010]`). |
| `AboutSheetDescriptor` / `AboutSheetView` | `SwiftEditUI` (`Presentation`) | Resolves `nbgv` version from `version.json` / `Info.plist` (`AR-014`) and gates `https://github.com/paoloinnocenti/PH.SwiftEdit` through `InspectionSafetyBannerState.prepareExternalURIConfirmation` (`[SEC-004]`, `[UI-008]`). |
| `DesktopWorkspaceIntegrating` / `MacOSWorkspaceAdapter` | `SwiftEditUI` (`Presentation`) | Port and adapter for `revealInFinder`, `openFolderInFinder`, and directory-only `openInTerminal` (`com.googlecode.iterm2` or `com.apple.Terminal`) with zero subprocesses (`[AR-007]`, `[SEC-004]`). |
| `SidebarFileClipboard` & `DirtyCloseDecision` | `SwiftEditUI` (`Presentation`) | Value types tracking sidebar `.cut(URL)` / `.copy(URL)` clipboard state and `Save / Don't Save / Cancel` decisions for dirty tab close or application quit (`[BC-008]`, `[BC-012]`). |

## Decisions
- **Decision 1 — Left Sidebar `...` Parent-Folder Navigation Within User Permissions (`KISS-First`)**:
  - `SwiftEditWorkbenchModel` stores both `selectedFolderURL: URL?` (currently browsed directory) and `grantedScopeRootURL: URL?` (highest directory root authorized by user permissions).
  - `DotfileFolderNavigator.resolveParentDirectory(from currentURL: URL, withinScope scopeURL: URL?, isParentReadable: (URL) -> Bool)` checks:
    1. `currentURL.standardizedFileURL.path != "/"` (cannot go above filesystem root `"/"`).
    2. Computes `rawParentURL = currentURL.standardizedFileURL.deletingLastPathComponent()` and `resolvedParentURL = rawParentURL.resolvingSymlinksInPath().standardizedFileURL`.
    3. If `rawParentURL` is a symbolic link whose resolved target escapes the expected canonical parent hierarchy (`resolvedParentURL != currentURL.resolvingSymlinksInPath().standardizedFileURL.deletingLastPathComponent()`), it throws `DomainError.securityScopeViolation` (`[SEC-003]`).
    4. If `resolvedParentURL` is already inside `scopeURL` (when the user navigated into a subfolder), or if `isParentReadable(resolvedParentURL)` returns `true` (user permissions allow reading the parent directory, e.g. under user-granted parent access or test/sandbox permission check), navigation succeeds and returns `(parentURL: resolvedParentURL, updatedScopeRootURL: effectiveScopeRoot)` so `listEntries` can enumerate the parent directory cleanly.
    5. Otherwise (parent not readable under user permissions), `canNavigateToParentFolder` is `false` and `navigateToParentFolder()` leaves `selectedFolderURL` unchanged with a non-destructive status message.
  - In `SwiftEditRootView`, when `model.selectedFolderURL != nil`, the sidebar renders a header row with a `...` button (`disabled(!model.canNavigateToParentFolder)`) above the directory entry list so the user can always click `...` to ascend one level when permissions allow.
- **Decision 2 — Right-Column `EditorTabStrip`, Default-Collapsed Sidebar, and Left `LineNumberGutterView`**:
  - `isLeftSidebarCollapsed` defaults to `true` in `SwiftEditWorkbenchModel.init()`.
  - Opening a single file (`openFile`) preserves `isLeftSidebarCollapsed`; selecting a workspace folder (`selectWorkspaceFolder`, `openFolderViaPanel`, or `openAllFilesInFolder`) sets `isLeftSidebarCollapsed = false`.
  - `SwiftEditRootView` places `sidebarView` on the left of the outer `HSplitView` (only rendered when `!model.isLeftSidebarCollapsed`) and places `EditorTabStrip`, `safetyAndErrorBanners`, `FindReplaceGoToLineBar` (when visible), and `HStack(spacing: 0) { LineNumberGutterView; TextKit2EditorView }` inside the right column `VStack`.
- **Decision 3 — Directory-Only Zero-Subprocess Terminal Handoff (`SEC-004`, `CWE-78`)**:
  - `DesktopWorkspaceIntegrating.openInTerminal(targetURL:withinScope:preferredTerminal:)` resolves `targetURL`: if `targetURL` is a regular file (or not a directory), it takes `directoryURL = targetURL.deletingLastPathComponent()`.
  - It verifies `directoryURL.resolvingSymlinksInPath()` is confined within `withinScope` and is an existing directory (`isDirectory == true`). If `directoryURL` resolves outside `withinScope` or is not a directory, it throws `DomainError.securityScopeViolation`.
  - Terminal selection checks only the allowlist `["com.googlecode.iterm2", "com.apple.Terminal"]`. Any other bundle ID throws `DomainError.securityScopeViolation`. When `iTerm2` is installed and preferred/default, `"com.googlecode.iterm2"` is chosen; otherwise `"com.apple.Terminal"` is used.
- **Decision 4 — Testable `@MainActor` Workbench Actions without Modal UI Blocking**:
  - All panel-driven and alert-driven operations on `SwiftEditWorkbenchModel` have deterministic programmatic entry points (`selectWorkspaceFolder(_:isParentReadable:)`, `navigateToParentFolder()`, `openAllFilesInFolder(_:)`, `confirmPendingBatchOpen()`, `requestCloseTab(id:)`, `resolvePendingDirtyClose(_:)`, `requestApplicationTermination()`, `sidebarCreateFolder(named:in:)`, `sidebarCreateFile(named:in:)`, `sidebarRenameItem(at:to:)`, `sidebarCutItem(at:)`, `sidebarCopyItem(at:)`, `sidebarPasteItem(into:)`, `requestSidebarTrashItem(at:)`, `confirmPendingTrashItem()`, `cancelPendingTrashItem()`, `sidebarRevealInFinder(at:)`, `sidebarOpenFolderInFinder(at:)`, `sidebarOpenInTerminal(at:)`).

## Risks / Trade-offs
- **App Sandbox Parent Folder Permissions on macOS** -> Under strict macOS App Sandbox, a security-scoped bookmark granted via `NSOpenPanel` on `/A/B` grants kernel read access to `/A/B` and its descendants, whereas `/A` is readable only if `/A` (or an ancestor) is readable by the sandboxed process. By checking `isParentReadable` (`FileManager.default.isReadableFile(atPath:)` + `contentsOfDirectory` probe with `startAccessingSecurityScopedResource()`), `...` ascends seamlessly both across subfolders `/A/B/C -> /A/B` and up to `/A` whenever user permissions allow, and degrades gracefully without crashing when blocked by the OS sandbox.
- **Line Number Gutter Performance on Large Files** -> `LineNumberGutterProjection` counts line breaks in a single UTF-16/scalar pass (`<= 10 MiB` full mode, clamped viewport window) without forcing whole-document TextKit 2 layout (`[UI-012]`).

## Migration Plan
1. Execute the 5 behavioral units in `tasks.md` (`MinimalWorkspaceLayoutAndLineGutter`, `SidebarParentFolderUpNavigation`, `FindReplaceGoToLineAndDirtyLifecycle`, `MenusCheatSheetAndAboutGuard`, `SidebarCRUDAndDesktopWorkspaceHandoff`) following strict `[RED] -> [GREEN] -> [REFACTOR] -> [DOC]` triads.
2. Run `swift test --parallel -Xswiftc -warnings-as-errors --enable-code-coverage` and verify all existing and new tests pass with zero warnings (`[TEST-006]`, `[TEST-008]`).
3. Execute `/myspec-sync 007-ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions` (`[SYNC]` task) to merge the modified `REQ-001` into `openspec/specs/swifteditui-purple-zed-layout-textkit2-and-appicons/spec.md`.

## Security Review
- Reviewer: cyber-security-expert
- Date: 2026-11-19
- Verdict: approved
- Status: approved
- Open items: none
