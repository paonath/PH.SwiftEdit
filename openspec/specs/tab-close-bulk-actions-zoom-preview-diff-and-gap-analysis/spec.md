# Capability: tab-close-bulk-actions-zoom-preview-diff-and-gap-analysis

## Purpose
Delivers confirmation-free closure for clean and baseline-reverted tabs, right-click bulk tab operations with closed-tab history and keyboard cycling, 50%..300% zoom across Markdown Preview and Side-by-Side Diff View (with line numbers and hunk jumps), top-right Copy to Clipboard on fenced blocks, native Zero-WebKit SwiftUI Canvas rendering for Markmap/Mindmaps and core Mermaid diagrams, confined external disk watching, Quick Open and Find in Folder, enhanced Find & Replace, line-manipulation tools, native JSON support, live log filtering, status-bar metrics/encoding/Git-branch indicators, and the complete application gap analysis.

## Requirements

### Requirement: REQ-001 Unmodified and Baseline-Reverted Tab Immediate Closure
WHEN a user creates an untitled tab, opens a clean file tab, or edits a tab back to its saved or initial baseline text and line ending, the workbench and document session SHALL mark isDirty false and close the tab immediately without confirmation [AR-004][BC-003][BC-008][DATA-004][DATA-006].

#### Scenario: P1 New Untitled Clean File and Baseline-Reverted Tabs Close Without Confirmation
- **Path**: P1
- **Trait**: positive
- **GIVEN** a newly created empty `Untitled` tab via `newUntitledTab()`, a freshly opened file-backed tab, and an edited tab whose text and `LineEnding` are restored to match `savedBaselineByID` via Undo or manual edit
- **WHEN** `requestCloseTab(id:)` or `requestCloseActiveTab()` is invoked on each tab
- **THEN** each tab reports `isDirty == false`, `pendingDirtyCloseTabID` remains `nil`, and all three tabs close immediately without presenting an alert

#### Scenario: N1 Modified Text or Line Ending Prompts Confirmation and Pinned Single Close Blocks
- **Path**: N1
- **Trait**: negative
- **GIVEN** an unpinned tab whose text or `LineEnding` differs from `savedBaselineByID` and a pinned clean tab
- **WHEN** `requestCloseTab(id:)` is invoked on the modified tab and on the pinned tab
- **THEN** the modified tab sets `pendingDirtyCloseTabID` keeping the tab open until user decision, and the pinned tab stays open with the status message `"Pinned tab cannot be closed. Unpin it first."`

### Requirement: REQ-002 Bulk Tab Context Menu Actions Reopen Closed Tab and Tab Cycling Shortcuts
WHEN a user triggers right-click bulk tab closure, middle-click close, Reopen Closed Tab, or tab cycling shortcuts, the workbench SHALL execute pinned-aware closure with sequential dirty prompts, unlink closed recovery snapshots, reopen up to 20 recently closed files, and switch tabs deterministically [BC-006][BC-008][DATA-005][DATA-006][SEC-007][SEC-011][UI-001][UI-009].

#### Scenario: P2 Bulk Close Actions Reopen Closed Tab Middle-Click and Tab Shortcuts Execute Cleanly
- **Path**: P2
- **Trait**: positive
- **GIVEN** pinned tabs `[P1, P2]` and unpinned file-backed tabs `[U1, U2_dirty, U3_clean]`
- **WHEN** `Close Tabs to the Right` on `U1` (`.dontSave`), `Close Other Tabs`, `Close All Unpinned Tabs`, `Reopen Closed Tab` (`Shift+Cmd+T`), keyboard cycling (`Shift+Cmd+]` / `Shift+Cmd+[` / `Cmd+1..9`), and `Close All Tabs` execute
- **THEN** right/other/unpinned actions preserve `[P1, P2]`, `Shift+Cmd+T` reopens the most recently closed file-backed tab in scope, shortcuts cycle active tabs deterministically, and `Close All Tabs` closes pinned and unpinned tabs leaving `tabs` empty

#### Scenario: N2 Canceling Dirty Prompt or Empty Bulk Scope Preserves Remaining Tabs
- **Path**: N2
- **Trait**: negative
- **GIVEN** tabs `[P1_pinned, U1_dirty, U2_dirty]` and an empty closed-tab history
- **WHEN** `Close Tabs to the Right` runs on `U2_dirty`, `Reopen Closed Tab` runs on empty history, and `Close All Unpinned Tabs` runs with `.cancel` chosen on `U1_dirty`
- **THEN** the first two operations perform safe no-ops and `.cancel` halts the bulk close queue keeping `P1_pinned`, `U1_dirty`, and `U2_dirty` open with unsaved text intact

#### Scenario: N3 Bulk Closure Immediately Unlinks Recovery Snapshots Stops Tails and Evicts Deleted Reopen Paths
- **Path**: N3
- **Trait**: security
- **GIVEN** open tabs with `<UUID>.recovery` snapshots in `SessionRecovery/`, active `LogTailController` descriptors, per-tab undo managers, and a closed-tab entry whose file was replaced by an external symlink
- **WHEN** `Close All Tabs` runs and `Reopen Closed Tab` attempts to reopen the symlinked path
- **THEN** every closed `.recovery` file is unlinked immediately, all vnode descriptors and undo managers are released, `PreviewThumbnailCache` and `diffCoordinator` clear, and the escaping symlink reopen fails closed (`SEC-003`)

### Requirement: REQ-003 Zoom-Scaled Markdown Preview YAML Frontmatter Card and Fenced Block Copy Button
WHEN Markdown preview is visible across 50 to 300 percent zoom, the Markdown native preview view SHALL scale all block and inline typography via AppTypography, project line-1 YAML frontmatter as a structured metadata card, and render a top-right Copy to Clipboard button on every fenced code block [UI-002][UI-004][UI-007][UI-009][SEC-004][SEC-012].

#### Scenario: P3 Preview Scales Linearly Renders Frontmatter Card and Copies Fenced Code via Top-Right Button
- **Path**: P3
- **Trait**: positive
- **GIVEN** a Markdown document starting with `---\ntitle: Spec\ntags: [a, b]\n---` followed by headings, tables, inline code, and a triple-backtick ```swift\nlet x = 42\n``` block at `100%` and `200%` zoom
- **WHEN** `MarkdownPreviewProjector` and `MarkdownNativePreviewView` render the preview and the user activates the top-right Copy to Clipboard button on the fenced block
- **THEN** the frontmatter renders as a structured key-value card instead of thematic breaks, all preview typography doubles at `200%` zoom, and `clipboardWriter` receives `"let x = 42"` with a minimum `24 pt` button hit target and transient `"Copied"` feedback

#### Scenario: N4 Clamped Zoom Transitions Keep Fonts Fresh Preserve Inert HTML and Guard Empty Code Copy
- **Path**: N4
- **Trait**: security
- **GIVEN** zoom inputs `20%` and `500%` on a Markdown document containing `<script>alert(1)</script>`, `javascript:evil()`, `70` local images, and an empty ```\n``` fenced block
- **WHEN** the preview renders across font/zoom changes and Copy to Clipboard runs on the empty fence
- **THEN** zoom clamps to `50%..300%` without stale fonts, `<script>` stays inert monospaced text without WebKit, `javascript:` links stay blocked, admitted images stay capped at `64`, and empty-fence copy writes `""` safely without crashing

### Requirement: REQ-004 Native Zero-WebKit Markmap Mindmap and Core Mermaid Preview Rendering
WHEN a Markdown preview contains a fenced markmap, mindmap, or mermaid block within structural bounds, the diagram engine and preview view SHALL render a zoom-scaled vector SwiftUI Canvas diagram with a top-right Diagram/Code toggle and Copy to Clipboard button while degrading unsupported or oversized diagrams to code blocks [AR-002][UI-004][UI-007][SEC-004][SEC-012].

#### Scenario: P4 Markmap Mindmap Flowchart Sequence and State Diagrams Render Natively With Toggle and Copy
- **Path**: P4
- **Trait**: positive
- **GIVEN** Markdown fenced blocks for ```markmap (headings/lists), ```mindmap, ```mermaid `flowchart LR`, ```mermaid `sequenceDiagram`, and ```mermaid `stateDiagram-v2` at `100%` and `150%` zoom
- **WHEN** `MarkdownPreviewProjector` and `MarkdownDiagramPreviewView` evaluate each block, toggle `Diagram / Code`, and click the top-right Copy button
- **THEN** each block parses into a bounded `MarkdownDiagramModel`, renders scaled vector nodes and edges on SwiftUI `Canvas` using `PurpleThemePalette` tokens, switches cleanly to monospaced source on toggle, and copies the exact raw diagram source to the clipboard

#### Scenario: N5 Oversized Deep Cyclic or Unsupported Diagram Blocks Fall Back Safely Without WebKit or Recursion
- **Path**: N5
- **Trait**: security
- **GIVEN** diagram fences exceeding `256` nodes, `12` nesting levels, or `64 KiB`, a cyclic `flowchart` (`A --> B --> A`), and an unsupported `gantt` or malformed Mermaid block containing `<img src=x onerror=alert(1)>`
- **WHEN** `MarkdownDiagramParser` evaluates each block
- **THEN** cyclic flowcharts lay out iteratively without stack recursion (`CWE-674`), oversized or unsupported blocks fall back deterministically to the inert monospaced code block with Copy button (`CWE-400`), and zero WebKit or HTML/JS execution occurs (`SEC-004`)

### Requirement: REQ-005 Zoom-Scaled Diff View With Line Numbers Hunk Navigation and Changes-Only Filter
WHEN File Compare is visible across 50 to 300 percent zoom, the diff panel and compare header SHALL scale rows in the editor typography role and header labels with 24-point minimum targets, display left and right line numbers, jump across hunks via Previous and Next Change, and filter unchanged context rows [UI-002][UI-004][UI-007][UI-009].

#### Scenario: P5 Diff View Scales With Zoom Renders Line Numbers Jumps Hunks and Filters Unchanged Rows
- **Path**: P5
- **Trait**: positive
- **GIVEN** a multi-hunk `DiffPaneCoordinator` comparison at `100%` and `200%` zoom
- **WHEN** `diffPanel` renders line numbers and rows, `Next Change` (`F7`) and `Previous Change` (`Shift+F7`) run, and `Only Differences` toggles on
- **THEN** diff row fonts double at `200%` in `.editor` role, `lhsLineNumber` and `rhsLineNumber` align beside each pane, hunk navigation advances/rewinds active hunk indices deterministically, and `Only Differences` hides distant unchanged rows

#### Scenario: N6 Fifty Percent Zoom Preserves 24-Point Compare Targets and Identical Files Disable Hunk Jumps
- **Path**: N6
- **Trait**: negative
- **GIVEN** File Compare at `50%` zoom on two identical snapshots (`hasDifferences == false`) or a degraded comparison
- **WHEN** `compareHeader` controls and hunk navigation commands execute
- **THEN** interactive buttons retain `>= 24 pt` hit targets, `Next/Previous Change` perform safe no-ops without out-of-range indexing, and buffers remain unmutated

### Requirement: REQ-006 Confined External Disk File Watcher Auto-Reload and Dirty Conflict Banner
WHEN an open file-backed document is modified or replaced on disk outside the editor, the external file change monitor SHALL auto-reload clean text tabs within scope, present a Reload Keep Mine or Compare conflict banner on dirty tabs without overwriting edits, and support manual Revert to Saved [BC-008][DATA-003][DATA-006][SEC-002][SEC-003][SEC-012].

#### Scenario: P6 Clean Tab Auto-Reloads on External Write While Dirty Tab Surfaces Conflict Banner and Manual Revert
- **Path**: P6
- **Trait**: positive
- **GIVEN** an open clean file tab `a.md` and an open dirty file tab `b.md` modified on disk by an external process
- **WHEN** `ExternalFileChangeMonitor` detects both disk updates and the user chooses `Compare` then `Revert to Saved` on `b.md`
- **THEN** `a.md` reloads the updated disk text keeping `isDirty == false`, `b.md` preserves its unsaved buffer while surfacing the conflict banner, `Compare` opens File Compare against the disk snapshot, and confirmed `Revert to Saved` reloads `b.md` cleanly

#### Scenario: N7 External Binary Replacement Symlink Escape or Unsaved Tab Never Overwrites Dirty State
- **Path**: N7
- **Trait**: security
- **GIVEN** an open file overwritten externally with NUL-bearing binary bytes or replaced by a symlink escaping workspace scope, plus an unbacked `Untitled` tab
- **WHEN** `ExternalFileChangeMonitor` or `Revert to Saved` evaluates each tab
- **THEN** dirty text is never overwritten silently, binary replacement transitions/blocks writable auto-reload fail-closed (`DATA-003`), escaping symlinks abort with `securityScopeViolation` (`SEC-003`), and `Untitled` ignores `Revert to Saved`

### Requirement: REQ-007 Confined Quick File Open Overlay and Multi-File Literal Find in Folder
WHEN a user invokes Quick Open or Find in Folder with an active workspace folder, the workspace search engine SHALL index up to 10000 confined non-binary text files and execute literal substring or whole-word multi-file searches capped at 5000 matches with direct file-and-line navigation [BC-004][BC-007][SEC-002][SEC-003][SEC-012][UI-009].

#### Scenario: P7 Quick Open Filters Workspace Files and Find in Folder Jumps to Matching File and Line
- **Path**: P7
- **Trait**: positive
- **GIVEN** a mounted workspace folder containing nested subdirectories, Markdown/Swift/JSON text files, and binary assets
- **WHEN** the user opens `Quick Open` (`Cmd+T`) querying `"readme"` and runs `Find in Folder` (`Ctrl+Shift+F`) for a literal token then activates a match
- **THEN** `Quick Open` ranks matching non-binary relative paths and opens the chosen tab, and `Find in Folder` returns grouped file/line previews and jumps the editor caret to the exact match line

#### Scenario: N8 Escaping Symlinks Binary Files and Match Floods Are Excluded Safely With Zero Regex
- **Path**: N8
- **Trait**: security
- **GIVEN** a workspace folder containing a child symlink pointing to `/etc/passwd`, NUL-bearing binary files, regex metacharacters `"(a+)+$"`, and over `5000` occurrences
- **WHEN** `WorkspaceFolderSearchEngine` indexes and searches the folder
- **THEN** escaping symlinks are skipped prior to byte probing (`SEC-003`), binary files are skipped, metacharacters match strictly literally (`CWE-1333`), and results cap cleanly at `5000` matches with a truncation indicator (`CWE-400`)

### Requirement: REQ-008 Find and Replace Whole-Word Toggle Active Match Counter and Selection Scope
WHEN a user searches or replaces text in the active document, the document search engine and find bar SHALL support whole-word boundary matching, display 1-based active-of-total match position, restrict search or replace-all to a captured selection range when enabled, and populate the query via Use Selection for Find [BC-004][BC-011][SEC-012][UI-009].

#### Scenario: P8 Whole-Word Active Index Selection Replace and Opt+Cmd+E Operate Deterministically
- **Path**: P8
- **Trait**: positive
- **GIVEN** a buffer `"cat scatter cat\ncat"` with `"cat scatter cat"` selected
- **WHEN** `Opt+Cmd+E` populates `"cat"`, `Whole Word` and `In Selection` are enabled, `Next Match` steps through matches, and `Replace All` replaces with `"dog"`
- **THEN** `"scatter"` is excluded, the counter advances `"1 of 2"` -> `"2 of 2"`, and `Replace All` produces `"dog scatter dog\ncat"` leaving line 2 untouched

#### Scenario: N9 Empty Selection Zero Matches or Oversized Query Degrades Safely
- **Path**: N9
- **Trait**: negative
- **GIVEN** `In Selection` enabled with a zero-length caret, a query with zero matches, or a query exceeding `1024` UTF-16 units
- **WHEN** `executeFind()` and `executeReplaceAll()` run
- **THEN** zero matches display `"0 of 0"`, `Replace` / `Replace All` perform zero mutations, and oversized queries degrade safely without error

### Requirement: REQ-009 Atomic Line Manipulation Commands and Trim Trailing Whitespace
WHEN a user invokes Move Line Up, Move Line Down, Delete Line, Join Lines, Sort Lines, or Trim Trailing Whitespace on a writable text tab, the line edit engine SHALL apply the transformation as a single BufferRevision preserving selection and wire line endings, and optionally trim trailing whitespace on save [BC-003][DATA-004][DATA-008][UI-009].

#### Scenario: P9 Move Delete Join Sort and Trim Trailing Whitespace Execute in Single Revisions
- **Path**: P9
- **Trait**: positive
- **GIVEN** a writable buffer `"b  \na\t\nc"` and `trimTrailingWhitespaceOnSave` enabled in `EditorPreferences`
- **WHEN** `Sort Lines Ascending`, `Move Line Down` (`Option+Down`), `Join Lines` (`Ctrl+J`), `Delete Line` (`Ctrl+Shift+K`), and `saveActiveDocument()` execute
- **THEN** each command commits in a single undoable `BufferRevision` preserving `LineEnding`, and saving strips trailing spaces/tabs per line before writing to disk

#### Scenario: N10 Boundary Line Moves Stay In-Bounds and Read-Only or Binary Tabs Reject Edits
- **Path**: N10
- **Trait**: negative
- **GIVEN** the caret on line 1 during `Move Line Up`, on the last line during `Move Line Down`, and a binary read-only or live-tail tab
- **WHEN** line manipulation commands execute
- **THEN** boundary moves perform safe no-ops without corrupting text, and binary/tail tabs block mutations with a status message

### Requirement: REQ-010 Native JSON and JSONL Language Highlighting Linting and Formatting
WHEN a `.json` or `.jsonl` document is opened, laid out, linted, or formatted, the JSON support engines SHALL resolve DocumentLanguage.json, apply zero-regex viewport token spans, report bounded structural diagnostics up to nesting depth 128, and execute single-batch Pretty-Print or Minify formatting [AR-002][BC-001][BC-004][SEC-012][UI-009].

#### Scenario: P10 JSON and JSONL Highlight Validate and Format or Minify Atomically
- **Path**: P10
- **Trait**: positive
- **GIVEN** `"{\"b\":1,\"a\":[true,null,\"ok\"]}"` opened as `config.json` and a multi-line `.jsonl` log stream
- **WHEN** `DocumentLanguage.resolve`, `JSONSyntaxHighlighter`, `JSONStructureLinter`, `Format JSON`, and `Minify JSON` run
- **THEN** both resolve `.json` (`"JSON"` status label), viewport keys/strings/numbers/literals receive WCAG-compliant tokens, valid payloads report zero lint errors, and Pretty-Print / Minify round-trip deterministically in one `BufferRevision`

#### Scenario: N11 Deeply Nested Malformed Overlong or Binary JSON Payloads Degrade Safely
- **Path**: N11
- **Trait**: security
- **GIVEN** a `.json` payload nested `130` levels deep (`> 128`), malformed JSON with trailing comma `{"a":1,}`, a `4097`-UTF-16-unit line, and a binary `bad.json` containing `0x00`
- **WHEN** resolution, highlighting, linting, and formatting execute
- **THEN** `bad.json` resolves `.plainText`, `130`-level nesting halts iteratively at depth `128` without stack overflow (`CWE-674`), malformed syntax emits a line/column diagnostic while refusing destructive formatting, and overlong lines skip highlighting safely

### Requirement: REQ-011 Non-Destructive Live Log Tail Severity Pills and Substring Filter
WHEN viewing a live or tail-only log panel, the log tail controller and panel view SHALL filter projected lines non-destructively by minimum severity pill (`All`, `Info+`, `Warn+`, `Error`) and case-insensitive literal substring while continuing background ingestion into the bounded tail buffer [BC-004][SEC-012][UI-007][UI-012].

#### Scenario: P11 Severity Pills and Substring Query Filter Live Log Tail Non-Destructively
- **Path**: P11
- **Trait**: positive
- **GIVEN** an active `LogTailController` holding `DEBUG`, `INFO`, `WARN`, and `ERROR` lines across correlation IDs
- **WHEN** the user selects `Error` pill, enters a correlation substring filter, and then resets back to `All` and empty query
- **THEN** only matching `ERROR` lines project while active, newly appended matching lines appear live, and resetting immediately restores all retained `INFO`/`DEBUG`/`WARN` lines from `LogTailBuffer`

#### Scenario: N12 Unmatched Filter or Overlong Filter Query Never Drops Underlying Buffer or Stalls Ingestion
- **Path**: N12
- **Trait**: negative
- **GIVEN** a filter substring matching zero lines or exceeding `256` characters during rapid log appends
- **WHEN** `LogTailBuffer` ingests new chunks and projects filtered text
- **THEN** the view displays `0 shown` cleanly, queries clamp to `256` characters, and underlying `maxLines` ring retention remains intact

### Requirement: REQ-012 Status Bar Selection and Word Metrics Encoding Menu Git Branch Badge and Documentation Sync
WHEN rendering the status bar or auditing project documentation, the workbench SHALL display selection character/line counts and Markdown word counts, provide an interactive UTF-8 and UTF-16 encoding menu, read the confined `.git/HEAD` branch name with zero subprocesses, and publish `docs/analysis/app-gap-analysis.md` alongside synchronized User Guide chapters [BC-005][DATA-004][SDD-001][SEC-003][SEC-004][UI-001][UI-010].

#### Scenario: P12 Status Bar Shows Selection Word Count Encoding Menu Git Branch and Docs Pass Fitness
- **Path**: P12
- **Trait**: positive
- **GIVEN** a workspace folder containing `.git/HEAD` (`ref: refs/heads/feature/028\n`), a Markdown tab with `"hello world"` selected, and clean encoding reopen/save actions
- **WHEN** `activeStatusBarMetrics`, `GitHeadBranchReader`, encoding switch (`UTF-8` <-> `UTF-16 LE`), and documentation fitness tests run
- **THEN** the status bar shows selection counts, word count, `"feature/028"`, and the interactive Encoding menu, while `docs/analysis/app-gap-analysis.md` (recording Mermaid/Markmap feasibility and deferred item #11) and `docs/guide/` <-> `Resources/Help/guide/` pass all checks

#### Scenario: N13 Escaping Symlinked Git HEAD Malformed Refs or Dirty Encoding Reopen Are Guarded
- **Path**: N13
- **Trait**: security
- **GIVEN** a `.git/HEAD` symlink resolving outside workspace scope, an oversized `> 256`-byte or credential-bearing `HEAD` payload, and a dirty tab requesting `Reopen with Encoding`
- **WHEN** `GitHeadBranchReader` and encoding reopen evaluate each case
- **THEN** escaping symlinks and malformed payloads return `nil` with zero subprocesses or external reads (`SEC-003`, `SEC-004`), and dirty tabs block unconfirmed `Reopen with Encoding` so unsaved edits are never lost (`DATA-006`)
