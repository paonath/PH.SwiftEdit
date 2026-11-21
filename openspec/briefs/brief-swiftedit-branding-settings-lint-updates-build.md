# Brief: SwiftEdit Branding, Dynamic Untitled Tabs, Prominent Lint, Redesigned Settings, Update Check & Local Release Build

- Date: `2026-11-21`
- Mode: `myspec-quick`
- Security Review: `approved` (human-approved `Constitution v1.5.0` amendment on `SEC-001` & `SEC-004` during Workflow 01)

## Disambiguated Prompt & `/qa` Decision Log

1. **App Name = `SwiftEdit` (Repo/Project/Scheme/Bundle ID kept `PH.SwiftEdit` / `it.ph.SwiftEdit`)**:
   - `XcodeApp/Info.plist` sets `CFBundleName`, `CFBundleDisplayName`, and `CFBundleExecutable` to `SwiftEdit` while preserving `CFBundleIdentifier = it.ph.SwiftEdit`.
   - `XcodeApp/PH.SwiftEdit.xcodeproj/project.pbxproj` sets `PRODUCT_NAME = SwiftEdit` and product reference `SwiftEdit.app`, keeping project, target, and scheme `PH.SwiftEdit`.
   - Top bar, `About SwiftEdit`, menus, cheat sheet, CI release workflow, and GitHub installer reference `SwiftEdit` / `SwiftEdit.app`.
2. **Dynamic Untitled Tab Title (First 4 Space-Separated Words)**:
   - Decision: First `4` non-empty words joined by single spaces (`maxCharacters: 36` with `"…"`, leading Markdown heading/list/task/blockquote markers stripped, fallback `"Untitled"` when empty).
   - `TabTitleDeriver` (`O(1)` bounded scan `<= 512` scalars) computes dynamic titles while preserving the tab's resolved `DocumentLanguage` via `WorkspaceTabSession.updateUntitledDisplayTitle`. Once saved (`fileURL != nil`), the tab title locks to `fileURL.lastPathComponent`.
3. **Prominent Markdown Lint Highlighting**:
   - Decision: Triple visual reinforcement — thick dotted amber underline + `0.18` tinted background (`warning`) and thick solid red underline + `0.24` tinted background (`error`) in `TextKit2EditorView`, 3 pt leading accent bar + 8×8 dot + tinted row in `LineNumberGutterView`, and high-visibility severity capsule pill in the status bar (`PurpleThemePalette` semantic tokens only).
4. **Redesigned Settings (`Fonts`, `Terminal`, `Updates`) & Installed Terminal Discovery**:
   - Decision: Sidebar navigation (`SettingsSection`: `Fonts`, `Terminal`, `Updates`), dynamic discovery across 8 allowlisted macOS terminal bundle IDs (`iTerm2`, `Terminal`, `Warp`, `Ghostty`, `WezTerm`, `Alacritty`, `Kitty`, `Hyper`), `Auto` defaulting to `iTerm2` when installed else `Terminal.app`, persisted in `EditorPreferencesStore` (`swiftedit.terminal.bundleID`) and honored by `sidebarOpenInTerminal`.
5. **Check for Updates in Main Menu (`SEC-001` / `SEC-004` Constitution `v1.5.0`)**:
   - Decision: Approved human amendment (`v1.5.0`) enabling `com.apple.security.network.client` on macOS strictly for manual `Check for Updates…` HTTPS GET requests via ephemeral `URLSession` (`GitHubReleaseUpdateChecker`) against `api.github.com/repos/paonath/PH.SwiftEdit/releases/latest` (with `/releases?per_page=10` fallback for alpha/prerelease tags).
   - If up to date or no releases exist, reports `"SwiftEdit <ver> is up to date."`; if newer, proposes `"Download Update…"` / `"Release Notes…"` opening strictly verified `https://` GitHub hosts via `NSWorkspace.shared.open`.
6. **Local Release Build Output (`build/<FULL_VERSION>/`)**:
   - Added `build/` to `.gitignore` and updated `Scripts/build-app.sh` to extract `<FULL_VERSION>` from `version.json` and stage the `Release` bundle into `build/<FULL_VERSION>/SwiftEdit.app`.

## 6-Category STRIDE Security Check

| Category | Threat | Mitigation Implemented | Trait |
| :--- | :--- | :--- | :--- |
| **Spoofing** | Phishing update links or renamed tab spoofing YAML/Markdown engine | `GitHubReleaseUpdateChecker.verifiedGitHubHTTPSURL` restricts links strictly to `https` + allowlisted GitHub hosts (`github.com`, `objects.githubusercontent.com`, etc.); `TabDescriptor.updateUntitledDisplayTitle` locks resolved language. | `security` |
| **Tampering** | Malicious bundle IDs in `UserDefaults` or path traversal in `version.json` | `setPreferredTerminalBundleID` and `TerminalLaunchResolution.allowedTerminalBundleIdentifiers` fail closed to allowlist/Auto (`Terminal.app`); `Scripts/build-app.sh` rejects `..`/`/` in version. | `security` |
| **Repudiation** | Silent background network polling or unacknowledged external navigation | Update network requests occur strictly on explicit user action (`Check for Updates…`); downloads launch via explicit user click and `NSWorkspace.shared.open`. | `security` |
| **Information Disclosure** | Leakage of local buffers, cookies, or tokens over HTTP | Update requests use `.ephemeral` `URLSessionConfiguration` with `GET`-only fixed GitHub API URL, sending no local files, telemetry, or cookies; document preview stays 100% offline. | `security` |
| **Denial of Service** | Per-keystroke untitled tab title derivation stalling on large buffers | `TabTitleDeriver.untitledTitle` stops scanning after 4 words or 512 Unicode scalars (`O(1)` time & memory); network checker uses 10s request timeout. | `security` |
| **Elevation of Privilege** | Over-privileged sandbox entitlements or shell execution on Terminal open | `EntitlementsFitnessValidator` forbids `network.server`, `files.all`, `temporary-exception`, and `disable-library-validation`; iOS keeps `app-sandbox` only; `NSWorkspace` launches verified directories with zero subprocesses (`CWE-78`). | `security` |

## Implemented Test Coverage (`SwiftEditBrandingSettingsUpdatesTests`)

- `P1`..`P3`, `N1`: `TabTitleDeriver` space-joined 4-word derivation, Markdown marker stripping, empty fallback `"Untitled"`, ellipsis clamping, workbench live updates, save-lock, and language preservation.
- `P4`, `P5`, `N2`: `TerminalCatalog` installed-app discovery, Auto-prefer-iTerm2, explicit terminal persistence in `EditorPreferencesStore`, `sidebarOpenInTerminal` routing, uninstalled fallback, and untrusted bundle ID rejection (`DomainError.securityScopeViolation`).
- `P6`, `P7`, `N3`: `GitHubReleaseUpdateChecker` newer SemVer detection, up-to-date & HTTP-404 no-release handling, and fail-closed rejection of non-HTTPS/untrusted hosts.
- `P8`: `XcodeApp/Info.plist` `SwiftEdit` branding + `it.ph.SwiftEdit` bundle ID verification alongside full `299/299` `swift test --parallel` pass and local `Release` build staging into `build/0.0.1-alpha5/SwiftEdit.app`.

## Metadata
- Branch: feature/FirstStub
