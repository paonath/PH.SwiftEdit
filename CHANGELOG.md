# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased] - 2026-11-20 UTC
Branch: feature/FirstStub | Commit: eeac4fc

### Added
- Added `MarkdownSyntaxHighlighter` (`MarkdownLineIndex`, `MarkdownSyntaxSpan`, `MarkdownSyntaxKind`) in `SwiftEditCore` for zero-regex viewport-only GFM tokenization across 12 constructs with an `O(log F)` fenced-code index while preserving `#000000`/`#FFFFFF` (`21:1`) prose (`openspec/specs/textkit2-gfm-editor-and-native-preview/spec.md`, archived at `openspec/changes/archive/2026-11-20-012-textkit2-gfm-editor-and-native-preview/`).
- Added `MarkdownAuthoringCommands` and `GFMTableEditEngine` in `SwiftEditCore` for single-batch Markdown formatting commands (`CommandMenu("Markdown")`: Bold, Italic, Strikethrough, Inline Code, Code Fence, Link, Image, Task Toggle, Blockquote, Headings 1–6, Insert Table) and GFM pipe-table `Tab` / `Shift+Tab` column-padded cell navigation with automatic row append.
- Added `MarkdownPreviewProjector` (`GFMPreviewDocument`, `GFMPreviewBlock`) and `PreviewResourceAndLinkGate` in `SwiftEditCore`, plus extracted `TextKit2EditorView` (with `renderingAttributesValidator` and `Ctrl+Tab` > Fence > Table > List > default dispatch), `MarkdownNativePreviewView` (`Cmd+P` default-OFF Zero-WebKit native preview with `sourceLine` scroll sync), `LazyVStack` `LineNumberGutterView`, and `500 ms` debounced `SessionRecovery` persistence in `SwiftEditUI`.

### Security
- Enforced zero-socket offline preview (`AsyncImage`, `URLSession`, `WebKit` banned), 5-gate `FileSystemProviding`-confined local raster image admission (`png`/`jpg`/`jpeg`/`gif`/`webp`/`heic`, `<= 16 MiB`, `<= 8192 px`, `<= 16 MP`, downsampled `<= 2048 px`, max `64` images, SVG/PDF and symlink escapes blocked), `OpenURLAction` user confirmation (`https`/`http`/`mailto` only), inert monospaced rendering of raw HTML, `4096` UTF-16 line cap, `64x2000` table cap, and binary read-only lockouts.

## [Unreleased] - 2026-11-20 UTC
Branch: feature/FirstStub | Commit: e036b5b

### Added
- Added `MarkdownSmartListEngine` (`SmartListEdit`, `SmartListOutcome`, `MarkdownListLine`, `MarkdownListGrammar`) in `SwiftEditCore` for CommonMark-valid `4`-space `Tab` nesting and `Shift+Tab` outdenting across unordered (`-`, `*`, `+`), ordered (`N.`, `N)`), and task-list (`- [ ]`) items, with Parent-Ceiling validation, valid marker inheritance, sibling number resumption, and `coalescedEdit` single-replacement support (`openspec/specs/adaptive-markdown-lists-tab-indentation/spec.md`, archived at `openspec/changes/archive/2026-11-20-011-adaptive-markdown-lists-tab-indentation/`).
- Extended `MarkdownSmartNewlineEngine` with `a.` → `b.` and `1.1` → `1.2` pseudo-outline continuation plus two-stage empty nested ordered list exit, and added `MarkdownLintRuleID.nonStandardOutlineMarker` in `MarkdownLintAndFormatEngine` to flag pseudo-outline markers inside list context outside fenced code blocks (`openspec/specs/markdown-lint-format-bracket-and-diff/spec.md`).
- Wired `SwiftEditWorkbenchModel.listIndentationOutcome(outdent:)`, `applyListIndentation(outdent:)`, and `TextKit2EditorView.Coordinator.handleListIndent` (`insertTab:` / `insertBacktab:`) in `SwiftEditRootView` so single-line and multi-line list indentation updates in one `BufferRevision` with single-step `Cmd+Z` undo (`openspec/specs/editor-ux-highlighting-sidebar-pin-tabs-and-about/spec.md`).

### Security
- Enforced bounded fail-closed guards in `MarkdownSmartListEngine` (`4096` UTF-16 line cap, `32` nesting level cap, `999_999_999` ordered number cap, `128` sibling lookback cap, and clamped UTF-16 range validation) alongside binary read-only quarantine and non-Markdown file lockouts in `SwiftEditWorkbenchModel.applyListIndentation`.

## [Unreleased] - 2026-11-20 UTC
Branch: feature/FirstStub | Commit: 084cbdf

### Added
- Added `HeaderSubmenuStateMachine` (`120 ms` hover dwell, `0 ms` click toggle, `180 ms` travel grace, active-drag lockout, `Escape` suppression latch) and translucent `HeaderBrandSubmenuView` (`312 pt` overlay at `.zIndex(100)` over `.zIndex(99)` outside-click shield with `0.0 pt` vertical layout shift) (`openspec/specs/translucent-header-brand-submenu/spec.md`, archived at `openspec/changes/archive/2026-11-20-010-translucent-header-brand-submenu/`).
- Added descriptive verb-noun `HeaderCommandCatalog` rows with monospaced shortcut badges (`Duplicate Line or Selection` `⌘D`, `Format Markdown Document` `⇧⌘F`, `Format Markdown Section` `⌥⇧⌘F`, `Show/Hide Markdown Preview` `⌘P` defaulting to `false`, `Show/Hide File Compare Diff`, `Keyboard Shortcuts CheatSheet` `⌘/`) and `SwiftEditWorkbenchModel.formatActiveSection()` / `toggleMarkdownPreview()`.
- Extracted single-source `SwiftEditCommands` (`Sources/SwiftEditUI/Views/SwiftEditCommands.swift`) and added `Cmd+P` (`Toggle Markdown Preview`) and `Cmd+Option+Shift+F` (`Format Markdown Section`) to `KeyboardShortcutsCheatSheetCatalog`.

### Changed
- Replaced the nine inline horizontal top-bar buttons in `SwiftEditRootView.toolbarBar` with the `PH.SwiftEdit` brand submenu trigger while keeping Zoom (`-`, `100%`, `+`) and `Light | Dark | Auto` controls isolated and always visible on the right (`[UI-001]`, `[UI-012]`), and removed duplicate `.keyboardShortcut` modifiers from `toolbarBar`.

### Security
- Replaced the system `.printItem` (`Cmd+P`) with in-memory Zero-WebKit Markdown Preview toggling (`SEC-004`, zero print-spooler IPC) and enforced synchronized binary read-only quarantine lockouts (`DATA-003`, `SEC-012`, `UI-008`) across `HeaderCommandCatalog`, `SwiftEditCommands`, and `SwiftEditWorkbenchModel` (`performCommandD`, `saveActiveDocument`, `saveActiveDocumentAsViaPanel`, `formatActiveDocument`, `formatActiveSection`) before any `NSSavePanel` construction.

## [Unreleased] - 2026-11-19 UTC
Branch: feature/FirstStub | Commit: c4340b5

### Added
- Added exhaustive semantic Light/Black/Auto role tokens (`topBarSurface`, `sheetSurface`, `sidebarSurface`, `tabBarSurface`, `tabActiveSurface`, `pinnedTabBadge`, `findBarSurface`, `submenuTranslucentSurface` with `1.0` alpha clamping under `reduceTransparency`/`increasedContrast`, `gutterSurface`, `gutterForeground`, `gutterActiveForeground`, `statusBarSurface`, `statusBarForeground`, `secondaryForeground`, `chromeAccent`, `activeControlFill`, `activeControlForeground`, `badgeSurface`, `hairlineBorder`, `selectionBackground`, `diffInsertedBackground`, `diffRemovedBackground`) and centralized `RGBAColorToken.swiftUIColor` / `nsColor` bridges in `PurpleThemeAndZoom.swift` (`openspec/specs/full-app-semantic-theming-and-window-sync/spec.md`, archived at `openspec/changes/archive/2026-11-19-009-full-app-semantic-theming-and-window-sync/`).
- Added `#if os(macOS)` `@MainActor` `MacOSAppearanceSynchronizer` (`NSApp.appearance` `.aqua`/`.darkAqua`/`nil` synchronization), injectable `systemDarkDetector` reading unmasked `AppleInterfaceStyle` + `DistributedNotificationCenter` `"AppleInterfaceThemeChangedNotification"`, and `O(viewport)` `TextKit2EditorView` scroller/selection/caret live restyling without incrementing `BufferRevision` (`[AR-003]`, `[BC-006]`, `[UI-003]`, `[UI-007]`, `[UI-012]`).
- Added static UI theme token fitness scanner `ArchitectureImportScanner.scanSwiftEditUIThemeTokens` and `scanSwiftEditUIViewsDirectory` in `SwiftEditCore` (`[AR-006]`, `[TEST-006]`).
- Added `Scripts/stamp-info-plist.sh`, Xcode `PBXShellScriptBuildPhase`, and `InfoPlistVersionStamper.synchronizeInfoPlistIfNeeded` so `XcodeApp/Info.plist` (`CFBundleShortVersionString` / `CFBundleVersion`) always stays synchronized with `version.json` during both builds and tests (`[AR-014]`, `[TEST-008]`).

### Changed
- Removed `public let brandGround` from `PurpleThemePalette` (preserving `#0B0614` in `SwiftEditBrandLogoGeometry.groundHex` and `.black` surfaces) and migrated all 12 workspace, gutter, find-bar, preview, diff, status-bar, banner, and modal sheet views to semantic `PurpleThemePalette` tokens (`[UI-001]`, `[UI-002]`, `[UI-009]`).

### Fixed
- Fixed Light-mode `1.10:1` dark-ground leaks across `AboutSheetView`, `KeyboardShortcutsCheatSheetView`, `FindReplaceGoToLineBar`, `LineNumberGutterView`, `toolbarBar`, `sidebarView`, `collapsedSidebarEdgeHandle`, and `statusBar`, and darkened Light-mode `nestedBracketPalette` colors to `>= 4.5:1` on `#FFFFFF` (`[UI-001]`, `[UI-009]`).
- Guarded `SwiftEditRootView.onChange(of: systemColorScheme)` behind `appearanceMode == .auto` so forced Light/Black `.preferredColorScheme` overrides cannot poison subsequent `.auto` restoration (`[UI-003]`).

### Security
- Enforced explicit `RGBAColorToken` foreground/background/border triples verified at `>= 4.5:1` text and `>= 3.0:1` border contrast for Trojan Source BiDi warnings (`CVE-2021-42574`), Binary Quarantine banners (`DATA-003`), Unbalanced Brackets (`#991B1B`/`#FEE2E2` Light, `#FCA5A5`/`#450A0A` Black), and Inert Raw HTML preview blocks (`CWE-451`, `[SEC-004]`, `[SEC-009]`, `[UI-008]`), alongside fail-closed static view token auditing (`scanSwiftEditUIThemeTokens`).

## [Unreleased] - 2026-11-19 UTC
Branch: feature/FirstStub | Commit: 6dbdc90

### Added
- Added `MarkdownSmartNewlineEngine` in `SwiftEditCore` and wired `NSTextViewDelegate` `insertNewline:` interception to continue Markdown unordered bullets (`-`, `*`, `+`), task checkboxes (`- [ ]`), incremented ordered lists (`N.`, `N)`), and blockquotes (`>`) while clearing empty list markers to exit lists and suppressing continuation inside fenced code blocks (`openspec/specs/editor-ux-highlighting-sidebar-pin-tabs-and-about/spec.md`, archived at `openspec/changes/archive/2026-11-19-008-editor-ux-highlighting-sidebar-pin-tabs-and-about/`).
- Added linear `BacktickHighlightScanner` (`inlineCode` and `fencedMultiline` spans) and extended `BracketMatcher` (`BracketPairSpan.nestingDepth`, `BracketBalanceResult.enclosingPairs`) with non-mutating TextKit 2 visual highlighting in `SwiftEditNSTextView` for full-width current-line background (`#161224` Dark / `#F3F0FA` Light), nested depth-colored brackets, active pair emphasis, unbalanced bracket highlights, and inline/multiline backtick spans (`[AR-012]`, `[UI-002]`, `[UI-005]`).
- Added `WorkspaceTabSession` partition-preserving tab reordering (`moveTab`, `moveTabLeft`, `moveTabRight`) wired to drag-and-drop and left/right controls in `EditorTabStrip` (`[BC-008]`).
- Added pure SwiftUI vector `SwiftEditBrandLogoView` (Concept E2 `logo-e2-refined.svg`) beside `PH.SwiftEdit` in the top bar and large inside `AboutSheetView`, added `About PH.SwiftEdit` to the `Help` menu, and added the MIT License link (`AboutSheetDescriptor.officialLicenseURL`) alongside the GitHub repository link (`[AR-014]`, `[UI-001]`).
- Added percentage-only `SidebarLayoutGeometry` (`12%..65%` of container width with draggable proportional divider across displays), manual sidebar `pin`/collapse control with left-edge reopen handle, sidebar typography zoom scaling (`EditorZoomController.sidebarScaledFontSizePoints`), disabled gray binary file entries (`FolderEntryDescriptor.isBinary`), and interactive right-click `New File…`/`New Folder…` name prompts on both sidebar entries and empty sidebar background (`[UI-001]`, `[UI-004]`).

### Changed
- Hid middle top-bar command buttons right of `PH.SwiftEdit` until mouse hover over the top bar area (honoring `Reduce Motion`) while keeping the Concept E2 logo, title, zoom controls, and appearance selector permanently visible (`[UI-001]`, `[UI-011]`).
- Synchronized `XcodeApp/Info.plist` (`CFBundleVersion`) with `version.json` (`0.0.1-alpha3`) and updated `XcodeAppShellAndPackagingFitnessTests` to validate dynamically against `version.json` as the `nbgv` source of truth (`[AR-014]`).

### Fixed
- Replaced the clipped segmented theme `Picker` stuck on `Auto` with an always-visible 3-way `Light | Dark | Auto` pill selector and synchronized `.auto` dynamically with live macOS `@Environment(\.colorScheme)` instead of hardcoded `systemPrefersDark: true` (`[UI-003]`).

### Security
- Enforced symlink confinement prior to bounded `8 KiB` binary probing in `DotfileFolderNavigator.listEntries` (`CWE-22`, `CWE-400`, `[SEC-002]`, `[SEC-003]`), `4096` UTF-16 line caps and binary guards across `BacktickHighlightScanner`, `BracketMatcher`, and `MarkdownSmartNewlineEngine` (`[BC-011]`, `[SEC-012]`), single-segment `SidebarItemNameValidator` validation on interactive right-click creation prompts, and `https`-only host validation with explicit confirmation on both GitHub repository and MIT License links in `AboutSheetDescriptor` (`[SEC-004]`, `[UI-008]`).

## [Unreleased] - 2026-11-19 UTC
Branch: feature/FirstStub | Commit: ec1cac8

### Added
- Implemented the minimalist `SwiftEditUI` workspace layout (`isLeftSidebarCollapsed = true` default, automatic expansion on `Open Folder` / `Open All Files in Folder`, right-column `EditorTabStrip`, left 1-based `LineNumberGutterView`, and live `Line`/`Column`/`Character count`/`UTF-8`/`LF|CRLF|CR` status bar) (`openspec/specs/ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions/spec.md` and `openspec/specs/swifteditui-purple-zed-layout-textkit2-and-appicons/spec.md`, archived at `openspec/changes/archive/2026-11-19-007-ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions/`).
- Added left-sidebar `...` parent-folder navigation (`DotfileFolderNavigator.resolveParentDirectory` and `SwiftEditWorkbenchModel.navigateToParentFolder`) ascending one directory level whenever not at `"/"` and user permissions permit reading the parent folder (`[BC-007]`, `[DATA-007]`, `[UI-001]`).
- Added `FindReplaceGoToLineBar` (`Cmd+F` Find, `Cmd+H` Find & Replace, `Cmd+G` Go to Line), 3-way `LineEnding` switching (`DocumentSession.setLineEnding`), 10-entry MRU `Open Recent` menu integration, `> 50`-file batch-open confirmation, and `Save / Don't Save / Cancel` prompts on dirty tab close (`Cmd+W`) and application termination (`Cmd+Q`).
- Added `@FocusedValue` `SwiftEditCommands` (`File`, `Edit`, `View`, `Help`, `About`) in `XcodeApp/SwiftEditApp.swift`, graphical `KeyboardShortcutsCheatSheetView` (`KeyboardShortcutsCheatSheetCatalog`), `AboutSheetView` (`AboutSheetDescriptor` reading `version.json` / `Info.plist`), and all 11 sidebar CRUD/Cut-Copy-Paste/Trash and `Finder`/`iTerm2`/`Terminal.app` actions via `DesktopWorkspaceIntegrating` (`MacOSWorkspaceAdapter`).

### Security
- Enforced symlink parent-escape blocking and balanced security-scoped resource bracketing on `...` parent-folder navigation (`DomainError.securityScopeViolation`, `CWE-22`, `CWE-59`, `[SEC-002]`, `[SEC-003]`).
- Enforced directory-only `NSWorkspace` terminal handoff (`DesktopWorkspaceValidator.resolveTerminalLaunch` resolving selected files such as `.command`/`.sh` strictly to their verified parent directory, allowlisting only `com.googlecode.iterm2` and `com.apple.Terminal` with zero subprocesses, `CWE-78`) and HTTPS-only `AboutSheetDescriptor` repository link confirmation (`[SEC-004]`, `[UI-008]`).

## [Unreleased] - 2026-11-19 UTC
Branch: feature/FirstStub | Commit: f6f700a

### Added
- Extended `LineEnding` in `DocumentCore` with Classic Mac `CR` (`\r`) using Unicode scalar scanning (`crlf > cr > lf` precedence) for byte-exact `LF`/`CRLF`/`CR` round-trips (`openspec/specs/document-core-and-spm-scaffold/spec.md`, archived at `openspec/changes/archive/2026-11-19-006-core-cr-lineending-mru-batch-search-and-sidebar-fs/`).
- Implemented `CursorMetricsCalculator` (`line`, UTF-16 `column`, Unicode scalar `characterCount`), `RecentFilesStore` (10-entry path-deduplicated MRU list with `SecurityScopedBookmarkCoding` and `clear()`), `ShallowFolderBatchLoader` (first-level regular non-binary files, `> 50` confirmation gate, `256 MiB` batch cap), `DocumentSearchEngine` (`find`, `replaceAll`, `goToLine` with literal-only matching), and `WorkspaceTabSession.applyRename`/`applyTrash` (`openspec/specs/core-cr-lineending-mru-batch-search-and-sidebar-fs/spec.md`).
- Extended `FileSystemProviding` (`LocalFileSystemAdapter`, `InMemoryFileSystemFake`) with confined sidebar `createDirectory`, `createFile`, `renameItem`, `pasteItem` (`cut`/`copy` with non-overwriting `copy` / `copy N` suffixes), and `trashItem` via `ItemTrashing` (`FileManager.trashItem`).

### Security
- Enforced single-segment `SidebarItemNameValidator` checks (rejecting `.`, `..`, `/`, `:`, NUL/control bytes, BiDi overrides, and `> 255` UTF-8 bytes), `resolvingSymlinksInPath()` confinement, scope-root mutation refusal, symlink-free `1000`-item / `256 MiB` copy pre-scans, and Trash-only deletion detaching dirty tabs without losing unsaved edits (`[SEC-002]`, `[SEC-003]`, `[SEC-012]`).
- Enforced `RecentFilesStore` binary-file exclusion, balanced `startAccessing`/`defer stopAccessing` bookmark resolution with path-parity checks and fail-closed `<= 1 MiB` decoding, `ShallowFolderBatchLoader` escaping-symlink abort, and `DocumentSearchEngine` `1024`-unit query / `100,000`-match caps (`[BC-011]`, `[SEC-011]`, `[SEC-012]`).

## [Unreleased] - 2026-11-18 UTC
Branch: feature/FirstStub | Commit: a227d9a

### Added
- Amended `openspec/Constitution.md` (`v1.2.0` -> `v1.3.0`, `MINOR`) and area micro-files (`UI-001`, `DATA-004`, `SEC-004`) for default-collapsed left sidebar (`Open Folder` auto-expand), right-column `EditorTabStrip`, left 1-based `LineNumberGutterView`, bottom-right `Ln`/`Col`/`Chars`/`UTF-8`/`LF|CRLF|CR` status bar, 3-way `LF`/`CRLF`/`CR` line-ending preservation, and `10`-entry deduplicated MRU bookmarks (`openspec/specs/constitution-v1-3-governance-and-fitness/spec.md`, archived at `openspec/changes/archive/2026-11-18-005-constitution-v1-3-lineending-cr-and-workspace-handoff/`).
- Added pure `Foundation` `ConstitutionGovernanceValidator` in `SwiftEditCore` and `ConstitutionFitnessTests` (`Swift Testing`) enforcing SemVer `1.3.0`, Bare-Bones line caps (`<= 45` / `<= 25` / `<= 40` lines, zero blockquotes), and `v1.3.0` rule invariants (`[SDD-004..009]`, `[TEST-006]`).
- Implemented `SwiftEditUI` Concept E2 Purple (`Viola`: `#0B0614`, `#7C3AED`, `#A78BFA`, `#C4B5FD`) chrome palette (`PurpleThemePalette`, `RGBAColorToken` with WCAG 2.2 `21:1` `#FFFFFF`/`#000000` inverted editor canvas), `50%..300%` `EditorZoomController`, and `@MainActor @Observable` `WorkspaceEditorCoordinator` / `TextKit2BufferAdapter` (`NSTextContentStorage` scoped `performEditingTransaction`) + `DiffPaneCoordinator` (`SideBySideDiffRow`) (`openspec/specs/swifteditui-purple-zed-layout-textkit2-and-appicons/spec.md`, archived at `openspec/changes/archive/2026-11-18-004-swifteditui-purple-zed-layout-textkit2-and-appicons/`).
- Added `XcodeApp/` bundle resources (`Assets.xcassets/AppIcon.appiconset` 10 macOS PNGs, `iOSAssets.xcassets/AppIcon.appiconset` 8 iOS PNGs, `PH.SwiftEdit.macOS.entitlements`, `PH.SwiftEdit.iOS.entitlements`, `Info.plist`) alongside `EntitlementsFitnessValidator` and `InfoPlistVersionStamper` (`0.0.1-alpha1` from `version.json`) (`[AR-001]`, `[AR-014]`, `[TEST-007]`, `[TEST-008]`).
- Implemented `WorkspaceTabSession` (`TabDescriptor`) in `SwiftEditCore` with Notepad++ pinned-first tab ordering, active tab fallback, and pinned-tab close protection (`DomainError.pinnedTabCloseForbidden`, `DomainError.tabNotFound`) (`openspec/specs/notepadpp-tabs-session-recovery-and-dotfiles/spec.md`, archived at `openspec/changes/archive/2026-11-18-003-notepadpp-tabs-session-recovery-and-dotfiles/`).
- Implemented `SessionRecoveryStore` (`SessionRecoveryManifest`, `RecoveredDocumentSnapshot`) for atomic `session-manifest.json` and `<UUID>.recovery` persistence with immediate unlink on tab closure and deterministic startup orphan garbage collection (`[DATA-005]`, `[DATA-006]`).
- Implemented `DotfileFolderNavigator` (`SecurityScopedResourceAccessing`, `FolderEntryDescriptor`) for shallow directory enumeration including hidden dotfiles (`.env`, `.gitignore`) sorted directories-first, alongside `EditorPreferencesStore` (`AppearanceMode`, `50%..300%` clamped zoom) on isolated `UserDefaults` suites (`[DATA-007]`, `[DATA-008]`).
- Implemented `MarkdownLintAndFormatEngine` (`lint`, `formatDocument`, `formatSection`) using `swiftlang/swift-markdown` 100% offline in `SwiftEditCore` to detect `missingHeadingSpace`, `emptyLinkTarget`, `unsafeLinkScheme`, and `unbalancedFencedCodeBlock` and emit `TextEdit` batches preserving fenced code blocks (`openspec/specs/markdown-lint-format-bracket-and-diff/spec.md`, archived at `openspec/changes/archive/2026-11-18-002-markdown-lint-format-bracket-and-diff/`).
- Added atomic `DocumentSession.applyTextEdits(_:expectedRevision:)` advancing `BufferRevision` once per batch (`DomainEvent.formatBatchApplied`) and rejecting stale revisions (`DomainError.staleBufferRevision`) or overlapping/out-of-bounds ranges (`DomainError.invalidTextRange`) without buffer mutation (`[BC-003]`, `[BC-004]`).
- Implemented `SearchDiffAndBracketEngine.evaluateBrackets(in:caretLocation:)` for nested `()`, `{}`, and `[]` matching, active caret pair resolution, and unbalanced delimiter reporting, alongside `computeMyersDiff(lhs:rhs:clock:)` for stateless line-level Myers shortest-edit-script diffs (`DiffHunk`, `FileCompareDiffResult`) (`[AR-012]`, `[BC-006]`).

### Security
- Enforced `SDD-007`/`SDD-009` active security-floor validation, `resolvingSymlinksInPath()` confinement inside `openspec/`, and `SEC-004` (`CWE-78`) offline zero-socket, zero-subprocess, and directory-only `NSWorkspace` Terminal (`com.googlecode.iterm2`, `com.apple.Terminal`) / `Finder` invariants in `ConstitutionGovernanceValidator` (`[SEC-003]`, `[SEC-004]`, `[SDD-007]`).
- Enforced UI-level binary read-only lockout (`canSave`/`canFormat`/`canPinTab == false`), Unicode Trojan Source bidirectional scalar badges (`U+202A..U+202E`, `U+2066..U+2069`, `U+061C`, `CWE-1007`), inert plain-text HTML Markdown preview projection (`isInertPlainTextHTML == true`), external URI confirmation (`https`/`http`/`mailto` only), and App Sandbox least-privilege `.entitlements` validation (`EntitlementsFitnessValidator`) (`[SEC-001]`, `[SEC-004]`, `[SEC-008]`, `[UI-006]`, `[UI-008]`).
- Enforced `0700`/`0600` POSIX permissions, iOS `FileProtectionType.complete`, `isExcludedFromBackup = true`, `64 MiB` (`67_108_864` bytes) aggregate quota (`DomainError.sessionRecoveryQuotaExceeded`), binary buffer non-retention (`DomainError.binaryFileSaveForbidden`), and symlink rejection across `WorkspaceTabSession` and `SessionRecoveryStore` (`[BC-008]`, `[DATA-003]`, `[SEC-007]`, `[SEC-011]`).
- Enforced balanced `startAccessing`/`defer { stopAccessing }` security-scoped resource bracketing and `resolvingSymlinksInPath()` confinement (`DomainError.securityScopeViolation`, `CWE-22`) in `DotfileFolderNavigator` (`[SEC-002]`, `[SEC-003]`, `[SEC-012]`).
- Enforced Markdown link URI scheme allowlisting (`https`, `http`, `mailto`, relative/fragment paths) flagging `javascript:`, `file:`, and `data:` links as `.unsafeLinkScheme`, iterative `128`-level AST depth caps, and `250 ms` `ElapsedTimeProviding` cooperative deadlines returning `.degradedOrTimedOut` (`[AR-013]`, `[BC-011]`, `[SEC-004]`, `[SEC-012]`).
- Enforced `4096` UTF-16 code-unit per-line caps in `evaluateBrackets`, `10 MiB` (`10_485_760` UTF-8 bytes) and `500 ms` cooperative deadlines in `computeMyersDiff`, and fail-closed binary/degraded snapshot rejection across both engines (`[BC-011]`, `[SEC-012]`).

## [Unreleased] - 2026-11-17 UTC
Branch: feature/FirstStub | Commit: bca0e90

### Added
- Scaffolded cross-platform Swift 6 `Package.swift` (`.macOS(.v26)`, `.iOS(.v26)`, `-strict-concurrency=complete`) declaring `SwiftEditCore` (`swiftlang/swift-markdown` `0.9.0`), `SwiftEditUI` (`#if os(macOS)` / `#if os(iOS)`), and `SwiftEditTests` (`Swift Testing`), alongside `ArchitectureImportScanner` and `PackageManifestDumpValidator` (`openspec/specs/document-core-and-spm-scaffold/spec.md`, archived at `openspec/changes/archive/2026-11-17-001-swifteditcore-document-and-binary-guard/`).
- Implemented `DocumentCore` (`DocumentSession`, `DocumentLoader`, `DocumentCodec`, `FileSystemProviding`, `LocalFileSystemAdapter`, `InMemoryFileSystemFake`) with lossless `UTF-8`/`UTF-8 BOM`/`UTF-16LE BOM`/`UTF-16BE BOM` and `LF`/`CRLF` round-trip encoding, `10 MiB` plain-text degraded mode, and deterministic `Cmd+D` (`duplicateLineOrSelection`) line and selection duplication (`[AR-012]`, `[BC-003]`, `[DATA-004]`).
- Promoted Concept E2 brand icons (`logo-e2-refined.svg`, `logo-e2-refined-512.png`), macOS (`10` PNGs `16..1024 px`) and iOS (`8` PNGs across `9` slots `40..1024 px`) `AppIcon.appiconset` catalogs, Zed-minimal Purple (`Viola`) chrome and inverted `#FFFFFF`/`#000000` editor canvas specification (`color-schemes-and-zed-layout.md`), and three UI preview mockups to `docs/design/` (`openspec/specs/design-assets-promotion/spec.md`, archived at `openspec/changes/archive/2026-11-17-000-promote-design-and-app-icons-to-docs/`).
- Updated root `README.md` with relative links to `docs/design/color-schemes-and-zed-layout.md`, `docs/design/assets/app-icons-riepilogo.md`, and `openspec/Constitution.md`.
- Added pure Swift 6 CLI asset verifier and 14-test `--self-test` harness (`Scripts/verify-design-assets.swift`) using `Foundation`, `ImageIO`, and `CoreGraphics` to validate file completeness, brand tokens, `Contents.json` slots, and PNG pixel dimensions (`[AR-001]`, `[UI-001]`, `[TEST-007]`).
- Configured Nerdbank.GitVersioning (`version.json` at `0.0.0`, `feature/FirstStub` `0.0.1-alpha1`) and ratified the Bare-Bones `openspec/Constitution.md` (`v1.2.0`) alongside the `swift-macos-expert` agent profile (`e2af960`, `9008090`, `0a74b1f`).

### Security
- Enforced pre-allocation `64 MiB` ceiling (`DomainError.fileTooLarge`), `8 KiB` `0x00` NUL binary-file quarantine (`isBinaryReadOnly`, `1 MiB` inspection preview cap, `DomainError.binaryFileSaveForbidden` on edits/`Cmd+D`/saves), strict UTF-8/UTF-16 decoding (`DomainError.unsupportedEncoding`), and `resolvingSymlinksInPath()` workspace scope confinement (`DomainError.securityScopeViolation`, `CWE-22`) in `DocumentCore` (`[DATA-002]`, `[DATA-003]`, `[SEC-003]`, `[SEC-011]`, `[SEC-012]`).
- Scrubbed workstation-local `file://` and `/Users/` URIs (`CWE-200`) from promoted documentation and enforced symlink/parent-traversal confinement inside `docs/design/` (`CWE-22`, `[SEC-003]`, `[SEC-005]`).
- Enforced SVG active-content rejection (`<script>`, `<foreignObject>`, `javascript:`, `<!ENTITY`, `CWE-79`/`CWE-611`), `16 MiB` per-asset size caps (`CWE-400`), and platform alpha-channel invariants (`hasAlpha == false` on iOS App Store icons for `ITMS-90717`, `hasAlpha == true` on macOS icons).
