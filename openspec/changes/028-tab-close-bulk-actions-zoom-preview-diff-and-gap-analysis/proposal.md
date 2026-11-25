# Proposal: Clean & Bulk Tab Operations, Zoomed Preview & Diff, Code Copy, Native Mermaid/Markmap, Disk Watcher, Folder Search, JSON & Editor Suite

## Why
Daily authoring and log/config inspection in `PH.SwiftEdit` needs both immediate UX fixes and the 10 high-impact editor/workspace capabilities surfaced by our whole-app gap analysis (excluding standalone HTML/PDF export):
1. **Tab Lifecycle & Navigation Friction**: Empty `newUntitledTab()` buffers start with `isDirty: true` and reverted (`Cmd+Z`) buffers stay `isDirty: true`, causing false confirmation alerts on close; the tab bar lacks right-click bulk close (*Close Tabs to the Right*, *Close Other Tabs*, *Close All Unpinned Tabs*, *Close All Tabs*), middle-click close, *Reopen Closed Tab* (`Shift+Cmd+T`), and keyboard tab cycling.
2. **Markdown Preview & Diff View Capabilities**: `MarkdownNativePreviewView` and `diffPanel` ignore `50%..300%` editor zoom; Preview lacks YAML frontmatter card rendering, top-right **Copy to Clipboard** buttons on triple-backtick code blocks, and native offline diagram rendering for **Markmap/Mindmaps** and **Mermaid**; Diff View hides `lhsLineNumber`/`rhsLineNumber` and lacks hunk navigation (`F7`/`Shift+F7`) and a changes-only filter.
3. **Workspace Awareness, Search, Editing, JSON, Logs & Status Bar**: External terminal edits on disk go undetected (no watcher/reload/conflict banner); workspace-wide `Find in Folder` and `Quick Open` (`Cmd+T`) are absent; `Find & Replace` lacks Whole-Word, `3 of 12` index, and Selection scope; line-level Move/Delete/Join/Sort/Trim commands and native `.json`/`.jsonl` support are missing; `LogTailPanelView` lacks severity/text filters; and the status bar lacks selection/word metrics, an interactive Encoding menu, and a read-only `.git/HEAD` branch badge.

## What Changes
- **Clean/Reverted Tab Close & Bulk/Keyboard Tab Management (`ADDED REQ-001`, `REQ-002`)**:
  - Initialize `newUntitledTab()` with `isDirty: false` and add `DocumentSession.reconcileDirtyState(against:)` so clean or baseline-reverted tabs close immediately (`[BC-003]`, `[BC-008]`, `[DATA-006]`).
  - Add right-click *Close Tabs to the Right*, *Close Other Tabs*, *Close All Unpinned Tabs*, and *Close All Tabs* (`forcePinned: true`) with sequential dirty prompts and immediate `.recovery` unlink, plus middle-click close, `Shift+Cmd+T` reopen (`<= 20` entries), and `Ctrl+Tab` / `Shift+Cmd+]` / `Shift+Cmd+[` / `Cmd+1..9` tab shortcuts (`[BC-006]`, `[SEC-007]`, `[SEC-011]`, `[UI-001]`).
- **Zoomed Preview, Frontmatter Card, Mandatory Code-Block Copy & Native Mermaid/Markmap (`ADDED REQ-003`, `REQ-004`)**:
  - Scale `MarkdownNativePreviewView` across `50%..300%` zoom via `AppTypography`, render line-1 YAML frontmatter as a structured metadata card, and add a **top-right Copy to Clipboard button** (`>= 24 pt` target) on every fenced code block (`[UI-002]`, `[UI-004]`, `[UI-009]`, `[SEC-004]`).
  - Implement pure-`Foundation` bounded parsers (`<= 256` nodes, `maxDepth <= 12`, `<= 64 KiB`) and native Zero-WebKit SwiftUI `Canvas` renderers for **Markmap/Mindmap** (```` ```markmap ````, ```` ```mindmap ````, ```` ```mermaid\nmindmap ````) and core **Mermaid** (`flowchart`/`graph`, `sequenceDiagram`, `stateDiagram`/`stateDiagram-v2`) with `50%..300%` zoom, a top-right `Diagram / Code` toggle + Copy button, and graceful code fallback (`[AR-002]`, `[UI-007]`, `[SEC-004]`, `[SEC-012]`).
- **Zoomed Diff View With Line Numbers, Hunk Jumps & Changes-Only Filter (`ADDED REQ-005`)**:
  - Scale `diffPanel` (`.editor` role) and `compareHeader` (`>= 24 pt` targets) across `50%..300%` zoom, display `lhsLineNumber`/`rhsLineNumber` columns, add `F7`/`Shift+F7` hunk navigation, and add an *Only Differences* filter (`[UI-004]`, `[UI-007]`, `[UI-009]`).
- **External Disk File Watcher, Quick Open & Find in Folder (`ADDED REQ-006`, `REQ-007`)**:
  - Add confined `ExternalFileChangeMonitor`: auto-reload clean tabs modified externally, show *Reload / Keep Mine / Compare* conflict banner on dirty tabs, and add `Revert to Saved` (`[DATA-006]`, `[SEC-002]`, `[SEC-003]`).
  - Add `Cmd+T` Quick File Open (`<= 10,000` files) and `Ctrl+Shift+F` literal Find in Folder (`<= 5,000` matches, zero regex `CWE-1333`) (`[BC-004]`, `[SEC-003]`, `[SEC-012]`).
- **Enhanced Find Bar, Line Commands, Native JSON, Log Filters, Status Bar & Docs (`ADDED REQ-008`..`REQ-012`)**:
  - Add Whole-Word, `active of total` counter, Selection scope, and `Opt+Cmd+E` to Find & Replace (`[BC-004]`, `[UI-009]`).
  - Add `Option+Up`/`Down` Move Line, `Ctrl+Shift+K` Delete Line, `Ctrl+J` Join Lines, Sort Lines, and Trim Trailing Whitespace (command + `settings.json` option) (`[BC-003]`, `[DATA-008]`).
  - Add `DocumentLanguage.json` (`.json`/`.jsonl`), viewport `JSONSyntaxHighlighter`, bounded `JSONStructureLinter`, and JSON Pretty-Print / Minify (`[BC-001]`, `[SEC-012]`).
  - Add `LogTailPanelView` severity pills (`All / Info+ / Warn+ / Error`) and substring filter (`[UI-007]`).
  - Add status-bar selection/word counts, interactive Encoding menu (`UTF-8` / `UTF-16 LE` / `UTF-16 BE`), confined zero-subprocess `.git/HEAD` branch badge, `docs/analysis/app-gap-analysis.md` (with Mermaid/Markmap feasibility & deferred item #11), and synchronized `docs/guide/` + bundled Help (`[BC-005]`, `[SEC-004]`, `[SDD-001]`).

## Capabilities
- New Capabilities: `tab-close-bulk-actions-zoom-preview-diff-and-gap-analysis`
- Modified Capabilities: None

## Domain Carrier & Decision Ownership (BC-###)
- **BC-001**: `DocumentCore`, `MarkdownLintAndFormat` (+ `DiagramSupport` & `JSONSupport`), `SearchDiffAndBracketEngine`, `LogSupport`, and `WorkspaceAndTabSession` in pure `Foundation` `SwiftEditCore`, orchestrated by `@MainActor` `SwiftEditUI` sub-controllers and views (`[BC-001]`, `[BC-003]`, `[BC-004]`, `[AR-006]`).
- **Owned Decisions**: Baseline dirty equivalence, bulk tab closure & closed-tab history, native diagram AST/layout bounds, diff hunk indexing, disk-change auto-reload vs conflict state, confined folder search, whole-word/selection search, line edits, JSON highlighting/lint/format, log filtering, and `.git/HEAD` parsing (`[BC-006]`, `[BC-008]`, `[DATA-006]`, `[UI-004]`).
- **Forbidden Responsibilities**: Never overwrite dirty buffers on external disk changes or bulk close without user confirmation; never invoke `WebKit`, network sockets, regex engines (`CWE-1333`), external `git` subprocesses, or unratified SwiftPM packages (`Constitution.md` v1.7.0 remains unamended); never implement deferred item #11 (HTML/PDF export) or `BC-005` IDE/LSP/DB features; never breach `027` modularity gates (`<= 25` members/block, `<= 400` block lines, `cyclomatic <= 15`, `cognitive <= 25`, `depth <= 10`, `0` cycles, `>= 85%` coverage) (`[AR-002]`, `[AR-005]`, `[BC-005]`, `[SEC-004]`, `[TEST-006]`, `[TEST-008]`).
- **External Decision References**: `(DocumentID, BufferRevision)` value-type coordinates across all engines, monitors, and UI caches (`[AR-008]`).

## Impact
- `Sources/SwiftEditCore/DocumentCore/`: `DocumentSession.swift`, `DocumentLanguage.swift`, `CursorMetricsCalculator.swift`, new `LineEditCommands.swift`, new `GitHeadBranchReader.swift`
- `Sources/SwiftEditCore/MarkdownLintAndFormat/`: `MarkdownPreviewProjector.swift` (fence info string + frontmatter card), new `DiagramSupport/` (`MarkdownDiagramModels.swift`, `MarkmapParserAndLayout.swift`, `MermaidParserAndLayout.swift`), new `JSONSupport/` (`JSONSyntaxHighlighter.swift`, `JSONStructureLinter.swift`, `JSONFormatter.swift`)
- `Sources/SwiftEditCore/SearchDiffAndBracketEngine/`: `DocumentSearchEngine.swift` (whole-word & selection range), new `WorkspaceFolderSearchEngine.swift`
- `Sources/SwiftEditCore/LogSupport/`: `LogTail.swift` (non-destructive severity & substring projection)
- `Sources/SwiftEditCore/WorkspaceAndTabSession/`: `WorkspaceTabSession.swift`, `EditorPreferencesStore.swift` (`trimTrailingWhitespaceOnSave`)
- `Sources/SwiftEditUI/`: `ZoomedChromeMetrics.swift`, `WorkbenchBulkCloseAndHistoryController.swift`, `ExternalFileChangeMonitor.swift`, `MarkdownNativePreviewView.swift`, `MarkdownDiagramPreviewView.swift`, `QuickOpenAndFolderSearchView.swift`, `FindReplaceGoToLineBar.swift`, `LogTailPanelView.swift`, `SwiftEditRootView*.swift`, `SwiftEditCommands.swift`, `SwiftEditShortcutDispatcher.swift`
- `docs/analysis/app-gap-analysis.md`, `docs/guide/*.md`, `Sources/SwiftEditUI/Resources/Help/guide/*.md`, and `Tests/SwiftEditTests/`

## Security Impact
- Preserves `SEC-004` 100% offline Zero-WebKit & Zero-Subprocess isolation: Mermaid/Markmap diagrams render in SwiftUI `Canvas` with `<= 256` node / `maxDepth <= 12` caps (`CWE-400`, `CWE-674`), and `.git/HEAD` reads `<= 256` confined bytes without spawning `git`.
- Enforces `SEC-002`/`SEC-003` canonical symlink confinement across `ExternalFileChangeMonitor`, `QuickOpen`, `Find in Folder`, `Reopen Closed Tab`, and `.git/HEAD`, plus zero-regex `CWE-1333` safety across folder/whole-word search and JSON linting.
- Guarantees `DATA-006`, `SEC-007`, and `SEC-011`: dirty buffers are never silently overwritten or discarded, and bulk tab close immediately unlinks `<UUID>.recovery` snapshots and releases vnode descriptors.

## Metadata
- Owner: swift-macos-expert
- Domain: apple-swift-macos, ddd, cyber-security, test-quality
- Reviewer: cyber-security-expert, oop-architecture-expert, test-quality-auditor, spec-sdlc-expert
- Branch: main
- Manual-Steps: none
- Modifies-Specs: none
- Constitutional-Rules: AR-001, AR-002, AR-004, AR-005, AR-006, AR-008, AR-010, BC-001, BC-003, BC-004, BC-005, BC-006, BC-008, BC-011, UI-001, UI-002, UI-004, UI-005, UI-007, UI-009, UI-010, UI-012, DATA-003, DATA-004, DATA-005, DATA-006, DATA-008, TEST-001, TEST-004, TEST-005, TEST-006, TEST-008, SEC-002, SEC-003, SEC-004, SEC-007, SEC-009, SEC-011, SEC-012, SDD-001, SDD-002, SDD-003
- Amends-Constitution: none

## Prerequisites
- `027-tokensave-zero-cycles-complexity-and-coverage-convergence`
- `023-embedded-terminal-json-settings-log-highlights-and-onboard-docs`
- `022-two-tab-compare-gutter-theme-menu-and-dblclick`
- `017-deep-debug-zoom-fonts-opendyslexic-and-perf`
- `012-textkit2-gfm-editor-and-native-preview`
