# Capability: swiftedit-branding-settings-lint-updates-build

## Purpose
Establishes SwiftEdit application display/bundle branding inside the PH.SwiftEdit repository, O(1) space-preserving first-4-word titles for unsaved tabs, high-contrast Markdown lint indicators, sidebar-categorized Settings with installed terminal discovery, manual GitHub Releases update checking (`SEC-001`/`SEC-004` v1.5.0), and local Release staging under gitignored `build/<FULL_VERSION>/`.

## Requirements

### Requirement: REQ-001 SwiftEdit App Display Branding and PH.SwiftEdit Project Identity
WHEN packaging or rendering user-facing application chrome, Xcode build configuration, Info.plist, About sheet, menus, and CI release packaging SHALL expose the app name `SwiftEdit` (`SwiftEdit.app`) while retaining repository, Xcode project/scheme (`PH.SwiftEdit`), and bundle identifier `it.ph.SwiftEdit` [AR-014][UI-001].

#### Scenario: P1 Info.plist and Release Bundle Use SwiftEdit Naming
- **Path**: P1
- **Trait**: positive
- **GIVEN** `XcodeApp/Info.plist` and the Xcode Release configuration
- **WHEN** `Scripts/build-app.sh` stamps version metadata and builds the bundle
- **THEN** `CFBundleName`, `CFBundleDisplayName`, `CFBundleExecutable`, and the `.app` directory name are `SwiftEdit` while `CFBundleIdentifier` stays `it.ph.SwiftEdit`

#### Scenario: N1 External Links Keep Official PH.SwiftEdit Repository Identity
- **Path**: N1
- **Trait**: negative
- **GIVEN** `AboutSheetDescriptor` and `GitHubReleaseUpdateChecker`
- **WHEN** repository or release URLs are resolved
- **THEN** GitHub URLs continue targeting `PH.SwiftEdit` without altering bundle identifiers

### Requirement: REQ-002 Dynamic First-Four-Word Titles for Unsaved Tabs
WHEN an unsaved tab (`fileURL == nil`) has its buffer created or modified, `TabTitleDeriver` SHALL compute its display title in `O(1)` bounded time from up to 4 space-separated words (stripping leading Markdown markers, clamping above 36 characters with `…`, defaulting to `"Untitled"`) while preserving the resolved `DocumentLanguage` [BC-008][PERF-001].

#### Scenario: P2 Untitled Tab Updates Title Dynamically With Spaces and Locks on Save
- **Path**: P2
- **Trait**: positive
- **GIVEN** a new unsaved tab starting at `"Untitled"`
- **WHEN** `"## Weekly Sync Agenda October 2026"` is entered and then saved to `notes.md`
- **THEN** the tab title updates to `"Weekly Sync Agenda October"` preserving Markdown highlighting, and locks to `"notes.md"` once saved

#### Scenario: N2 Empty or Oversized Unsaved Text Degrades Safely
- **Path**: N2
- **Trait**: negative
- **GIVEN** an unsaved tab containing only Markdown markers or words exceeding 36 characters
- **WHEN** `TabTitleDeriver.untitledTitle` derives the title
- **THEN** marker-only text resolves to `"Untitled"` and overlong text clamps with `"…"` within 512 inspected scalars

### Requirement: REQ-003 Prominent Markdown Lint Highlighting
WHEN Markdown or YAML lint diagnostics exist for visible text lines, `TextKit2EditorView`, `LineNumberGutterView`, and the status bar SHALL render thick color-coded underlines with semi-transparent tinted range backgrounds, leading 3 pt gutter accent bars with 8 pt severity dots, and a bordered status-bar severity pill using semantic `PurpleThemePalette` tokens [UI-001][UI-005].

#### Scenario: P3 Warnings and Errors Surface Triple Visual Indicators
- **Path**: P3
- **Trait**: positive
- **GIVEN** an active Markdown buffer containing lint errors and warnings
- **WHEN** TextKit 2 rendering attributes, gutter metrics, and the status bar evaluate diagnostics
- **THEN** errors receive thick solid red underlines with `0.24` background tint and warnings receive thick dotted amber underlines with `0.18` tint alongside gutter bars and a prominent status pill

#### Scenario: N3 Clean Documents Render Zero Lint Tints
- **Path**: N3
- **Trait**: negative
- **GIVEN** a Markdown document with zero lint diagnostics
- **WHEN** editor attributes and gutter rows render
- **THEN** no lint underlines, tinted spans, or severity badges appear

### Requirement: REQ-004 Sidebar Settings Redesign and Installed Terminal Discovery
WHEN opening Settings (`Cmd+,`), `SwiftEditSettingsView` SHALL present sidebar sections (`Fonts`, `Terminal`, `Updates`), dynamically probe allowlisted macOS terminal bundle identifiers (`iTerm2`, `Terminal`, `Warp`, `Ghostty`, `WezTerm`, `Alacritty`, `Kitty`, `Hyper`), persist `preferredTerminalBundleID` in `EditorPreferencesStore`, and route `sidebarOpenInTerminal` directory-only through the chosen installed terminal (`Auto` preferring `iTerm2` when installed) [SEC-004][UI-001][UI-010].

#### Scenario: P4 Selected Installed Terminal Persists and Launches via Sidebar
- **Path**: P4
- **Trait**: positive
- **GIVEN** a host with `iTerm2`, `Terminal`, and `Warp` installed
- **WHEN** the user selects `Warp` in Settings and triggers `Open Terminal` in the sidebar
- **THEN** `EditorPreferencesStore` persists `"dev.warp.Warp-Stable"` and `sidebarOpenInTerminal` launches `Warp` on the verified directory

#### Scenario: N4 Unallowlisted or Uninstalled Terminal Bundle Fails Safe
- **Path**: N4
- **Trait**: security
- **GIVEN** a non-allowlisted bundle ID or a saved terminal subsequently uninstalled
- **WHEN** `DesktopWorkspaceValidator` or `TerminalCatalog.resolveBundleID` runs
- **THEN** unallowlisted IDs throw `DomainError.securityScopeViolation` and uninstalled preferences fall back safely to `iTerm2` or `Terminal.app`

### Requirement: REQ-005 Manual GitHub Releases Check for Updates (`SEC-001`, `SEC-004` v1.5.0)
WHEN the user selects `SwiftEdit -> Check for Updates…` or clicks `Check for Updates…` in Settings, `GitHubReleaseUpdateChecker` SHALL execute an ephemeral HTTPS `GET` against `api.github.com/repos/paonath/PH.SwiftEdit/releases/latest` (with `/releases?per_page=10` fallback), inform the user when current or missing, and offer `NSWorkspace` browser download only after verifying `https://` GitHub hosts [SEC-001][SEC-004].

#### Scenario: P5 Newer GitHub Release Offers Verified Download and Up-to-Date Informs User
- **Path**: P5
- **Trait**: positive
- **GIVEN** a running version `0.0.1-alpha5` and GitHub Release API responses
- **WHEN** release `v0.0.1-alpha6` exists versus matching `v0.0.1-alpha5` or HTTP 404
- **THEN** `v0.0.1-alpha6` proposes a verified HTTPS download whereas matching/404 reports `SwiftEdit 0.0.1-alpha5 is up to date`

#### Scenario: N5 Untrusted Update Hosts and Non-HTTPS Schemes Fail Closed
- **Path**: N5
- **Trait**: security
- **GIVEN** a release payload with an `http://` asset URL or non-GitHub `html_url`
- **WHEN** `GitHubReleaseUpdateChecker` validates the payload
- **THEN** validation fails closed and never opens untrusted URLs

### Requirement: REQ-006 Gitignored Local Release Build Staging
WHEN `./Scripts/build-app.sh` executes with default `Release` configuration, the script SHALL read `<FULL_VERSION>` from `version.json`, build `SwiftEdit.app`, and stage it under gitignored `build/<FULL_VERSION>/SwiftEdit.app` [AR-014][SEC-003].

#### Scenario: P6 Release Build Stages Under build/<FULL_VERSION>/ Excluded From Git
- **Path**: P6
- **Trait**: positive
- **GIVEN** `version.json` declaring `0.0.1-alpha5` and `.gitignore` containing `build/`
- **WHEN** `./Scripts/build-app.sh` runs
- **THEN** `build/0.0.1-alpha5/SwiftEdit.app` is created in Release configuration and remains ignored by `git status`

#### Scenario: N6 Path Traversal in Version Manifest Is Rejected
- **Path**: N6
- **Trait**: security
- **GIVEN** a `version.json` containing `..` or `/` path separators
- **WHEN** `resolve_full_version` validates the version string
- **THEN** the build script aborts non-zero before creating any staging directory
