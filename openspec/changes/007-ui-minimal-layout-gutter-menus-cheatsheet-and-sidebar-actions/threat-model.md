# Threat Model: SwiftEditUI Minimalist Layout, Line Gutter, Classic Menus, CheatSheet, Parent ... Navigator and 11 Sidebar Actions

## 1. Asset Boundaries & Trust Zones
- **Left Sidebar Folder Navigator & Parent (`...`) Control (User-Permitted Filesystem Scope)**: Displays shallow directory entries and the `...` parent-folder navigation action. Symlinks, special filenames, and parent directory permissions are untrusted until verified via `resolvingSymlinksInPath()` and user-permission readability checks (`[SEC-002]`, `[SEC-003]`).
- **Desktop Handoff Seam (`DesktopWorkspaceIntegrating` / `NSWorkspace`)**: Crosses the process boundary to `Finder`, `iTerm2` (`com.googlecode.iterm2`), or `Terminal.app` (`com.apple.Terminal`). Passing an unverified file URL (such as `.command`, `.sh`, or `.term`) to a terminal or general launcher could trigger arbitrary command execution (`CWE-78`, `[SEC-004]`).
- **About & External URI Handoff (`AboutSheetDescriptor` / `InspectionSafetyBannerState`)**: Crosses from application UI to external browser handling (`https://github.com/paoloinnocenti/PH.SwiftEdit`) (`[SEC-004]`, `[UI-008]`).
- **Dirty Buffer & Tab Lifecycle State (`SwiftEditWorkbenchModel`)**: Unsaved user text buffers across `Close Document` (`Cmd+W`), `Quit` (`Cmd+Q`), and sidebar `Delete` (Trash) (`[BC-008]`, `[DATA-006]`).

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | A crafted or unverified terminal bundle identifier or tampered About URI impersonates `iTerm2`/`Terminal.app` or redirects the user to a `javascript:`/`file:` URI (`CWE-20`, `CWE-345`). | `DesktopWorkspaceIntegrating` restricts terminal handoff strictly to the allowlisted bundle IDs `com.googlecode.iterm2` and `com.apple.Terminal`; `AboutSheetDescriptor` gates external links through `InspectionSafetyBannerState.prepareExternalURIConfirmation(rawURI:)` (`[SEC-004]`, `[UI-008]`). |
| Tampering | Sidebar `Create`, `Rename`, `Paste`, or `Delete` mutates outside the active scope, or clicking `...` follows a symlinked parent to an unauthorized location (`CWE-22`, `CWE-59`). | Every sidebar CRUD/Paste/Trash action delegates to `FileSystemProviding` with `SidebarItemNameValidator` and `resolvingSymlinksInPath()` confinement; `navigateToParentFolder()` verifies canonical parent path confinement and readability under user permissions (`[SEC-002]`, `[SEC-003]`, `[BC-012]`). |
| Repudiation | Silent loss of unsaved edits on `Cmd+W` / `Cmd+Q`, or unconfirmed permanent deletion from the sidebar (`CWE-73`). | Closing a dirty tab or quitting with dirty tabs enters an explicit `Save / Don't Save / Cancel` confirmation state; sidebar Delete requires user confirmation, moves items to Trash via `ItemTrashing`, and detaches dirty tabs (`[BC-008]`, `[DATA-006]`). |
| Information Disclosure | Ascending via `...` into an unreadable or symlink-escaped directory or batch-opening `> 50` files / symlinks outside permitted directories (`CWE-200`). | `canNavigateToParentFolder` and `navigateToParentFolder()` check directory readability and symlink confinement before listing; `ShallowFolderBatchLoader` aborts on any escaping symlink (`[SEC-002]`, `[SEC-003]`, `[SEC-011]`). |
| Denial of Service | Opening a folder with hundreds of files via `Cmd+Shift+Option+O`, or whole-document layout recalculation on every keystroke in `LineNumberGutterView` and status bar (`CWE-400`). | `ShallowFolderBatchLoader` pauses behind a confirmation gate above `50` files (`<= 256 MiB` ceiling); `LineNumberGutterProjection` and `CursorMetricsCalculator` use O(N) scalar/UTF-16 value-type scans without whole-document TextKit layout (`[BC-011]`, `[UI-001]`, `[UI-012]`). |
| Elevation of Privilege | Invoking `Open Terminal` on an executable script file (`.sh`, `.command`) in the sidebar causes the terminal emulator to execute the script instead of opening a shell in its directory (`CWE-78`). | `DesktopWorkspaceIntegrating.openInTerminal` resolves any file URL to `targetURL.deletingLastPathComponent()`, verifies `resolvingSymlinksInPath()` confinement and `isDirectory == true`, and passes only the verified directory URL to `NSWorkspace` with zero subprocesses (`[SEC-003]`, `[SEC-004]`). |

## 3. Abuse Cases & Negative Scenarios
- **Abuse Scenario `N3` (Symlink Parent Escape on `...` Navigation — `Trait: security`)**: Ascending via `...` when the current folder or parent path traverses a symlink outside user-permitted readable scope throws `DomainError.securityScopeViolation` and leaves `selectedFolderURL` and `folderEntries` unchanged.
- **Abuse Scenario `N5` (Tampered or Non-HTTPS About/External URI — `Trait: security`)**: Evaluating `AboutSheetDescriptor` or external link handoff with `"javascript:alert(1)"`, `"file:///etc/passwd"`, or a hostless URI returns `nil` confirmation prompt and blocks external launch.
- **Abuse Scenario `N7` (Executable File Terminal Handoff, Escaping Symlink, or Unallowlisted Terminal Bundle — `Trait: security`)**: Invoking `openInTerminal` on `"deploy.command"` never passes the file URL to the terminal (it resolves to the verified parent directory), while an escaping symlink target or an unallowlisted terminal bundle ID (`"com.evil.term"`) fails closed with `DomainError.securityScopeViolation`.

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-19
- Verdict: approved
- Status: approved
- Open items: none
