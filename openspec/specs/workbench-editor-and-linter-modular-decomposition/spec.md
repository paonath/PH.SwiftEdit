# Capability: workbench-editor-and-linter-modular-decomposition

## Purpose
Decomposes `SwiftEditWorkbenchModel`, `SwiftEditRootView`, `TextKit2EditorView` (`Coordinator`), and `MarkdownAllConstructsLinter.diagnostics` into modular, independently testable, single-responsibility units guarded by an automated `CodeModularityFitnessScanner` architecture fitness gate.

## Requirements

### Requirement: REQ-001 Automated Code Modularity and Anti-God-Class Fitness Gate
WHEN evaluating production source directories under `Sources/SwiftEditCore` and `Sources/SwiftEditUI`, the code modularity fitness scanner SHALL verify that every `.swift` file contains at most `800` lines, every nominal declaration or extension block contains at most `600` lines, and every nominal declaration block declares at most `75` members while rejecting symlinked or out-of-root paths fail-closed [AR-006][TEST-006][SEC-003][SEC-012][SDD-001].

#### Scenario: P1 Live Production Sources Pass File Block and Member Modularity Budgets
- **Path**: P1
- **Trait**: positive
- **GIVEN** the live repository `Sources/SwiftEditCore` and `Sources/SwiftEditUI` directories after modular decomposition
- **WHEN** `CodeModularityFitnessScanner.scanDirectories(at:budgets:)` evaluates every `.swift` source file against `CodeModularityBudgets.default` (`maxFileLines: 800`, `maxNominalBlockLines: 600`, `maxNominalMembers: 75`)
- **THEN** the scan completes with zero `CodeModularityViolation` entries and confirms every scanned file and nominal block is within budget

#### Scenario: N1 Oversized Source File Nominal Block or Member Count Emits Typed Violations
- **Path**: N1
- **Trait**: negative
- **GIVEN** synthetic Swift source fixtures containing a file of `801` lines, a nominal class block of `601` lines, or a nominal type declaring `76` methods and properties
- **WHEN** `CodeModularityFitnessScanner.scanSource(content:filePath:budgets:)` analyzes each fixture
- **THEN** the scanner returns non-empty typed `CodeModularityViolation` diagnostics identifying the exact file path, type name, metric kind, observed count, and budget limit

#### Scenario: N2 Symlink Escape Parent Traversal or Oversized Source Payload Fails Closed
- **Path**: N2
- **Trait**: security
- **GIVEN** a scanned directory containing a symlinked `.swift` file pointing outside the canonical repository root, a relative `../` path segment, or a `.swift` payload exceeding `4_194_304` bytes
- **WHEN** `CodeModularityFitnessScanner.scanDirectory(at:budgets:)` enumerates the directory
- **THEN** the scanner rejects the entry fail-closed with a `CodeModularityViolation` of kind `.securityBoundaryViolation` without reading external files

### Requirement: REQ-002 Modular Workbench Sub-Controllers and Domain Extension Decomposition
WHEN `SwiftEditWorkbenchModel` coordinates word completion, find/replace and navigation, embedded terminal sessions, confined sidebar file operations, and GitHub update checks, the workbench model SHALL delegate domain state transitions to cohesive `@MainActor` sub-controllers and domain-scoped extension files under `Sources/SwiftEditUI/Workbench/` while preserving its existing public API signatures [AR-009][AR-010][UI-005][SEC-003][SEC-004].

#### Scenario: P2 Isolated Workbench Sub-Controllers Execute Domain Operations and Synchronize With Facade
- **Path**: P2
- **Trait**: positive
- **GIVEN** isolated instances of `WorkbenchWordCompletionController`, `WorkbenchFindAndNavigationController`, `WorkbenchTerminalSessionController`, `WorkbenchSidebarFileController`, and `WorkbenchUpdateController` wired into `SwiftEditWorkbenchModel`
- **WHEN** a caller invokes completion suffix lookup, find/replace or go-to-line navigation, terminal session queuing, confined sidebar file creation/rename, or update checks either directly on the sub-controller or via `SwiftEditWorkbenchModel`
- **THEN** each sub-controller deterministically updates its domain state and `SwiftEditWorkbenchModel` reflects identical observable state across all existing public properties and methods

#### Scenario: N3 Invalid Prefix Out-of-Scope Sidebar Path or Unconfirmed Multiline Terminal Payload Is Rejected
- **Path**: N3
- **Trait**: negative
- **GIVEN** a single-character completion prefix, a sidebar file operation targeting a path outside the workspace root, an out-of-range go-to-line query, or a multiline terminal selection before user confirmation
- **WHEN** the corresponding workbench sub-controller evaluates the request
- **THEN** the sub-controller rejects the operation without mutating active document buffer contents, filesystem entries outside scope, or active PTY stdin streams

### Requirement: REQ-003 SwiftEditRootView Structural Decomposition Preserving Static Chrome Anchors
WHEN rendering the main workbench window, the root workbench view SHALL partition sidebar and context menus, optional panels, compare/diff and status bar, and lifecycle/sheets/alerts/keyboard monitoring into dedicated view extension files under `Sources/SwiftEditUI/Views/` while retaining `toolbarBar` and `tabBar` anchors in `SwiftEditRootView.swift` [UI-001][UI-005][TEST-006].

#### Scenario: P3 Decomposed SwiftEditRootView Compiles Under MainActor and Passes Static Theme and Hit-Target Audits
- **Path**: P3
- **Trait**: positive
- **GIVEN** `Sources/SwiftEditUI/Views/SwiftEditRootView.swift` and its extracted `SwiftEditRootView+*.swift` extension files under `Sources/SwiftEditUI/Views/`
- **WHEN** `SwiftEditRootView` is rendered in Light and Black appearances and scanned by static theme token, accessibility label, header order, and tab strip hit-target fitness tests
- **THEN** every extracted view file contains at most `800` lines, preserves `private var toolbarBar: some View` and `private var tabBar: some View` in `SwiftEditRootView.swift`, and passes all static UI audits with zero violations

#### Scenario: N4 Hardcoded Non-Palette Tokens Unlabeled Icon Buttons or Polling Regressions Are Rejected
- **Path**: N4
- **Trait**: negative
- **GIVEN** a view source fixture introducing a forbidden system color, an icon-only button missing `.accessibilityLabel`, or a `.milliseconds(20)` submenu polling loop
- **WHEN** the view static audit suite evaluates the view sources
- **THEN** validation fails and reports the offending view file and line number

### Requirement: REQ-004 TextKit 2 Editor View Coordinator and Viewport Highlight Applier Decomposition
WHEN updating TextKit 2 editor typography, GFM syntax attributes, viewport highlights, per-tab undo managers, or ghost-text completion, the TextKit 2 editor view SHALL delegate to dedicated single-responsibility types (`SwiftEditNSTextView`, `PerTabUndoManagerRegistry`, `EditorRenderingAttributes`, `TextKit2ViewportHighlightApplier`, and `TextKit2EditorView.Coordinator`) across files of at most `800` lines [AR-010][UI-006][UI-007].

#### Scenario: P4 TextKit2ViewportHighlightApplier Applies Scoped Highlight Passes Within Dirty or Visible Ranges
- **Path**: P4
- **Trait**: positive
- **GIVEN** a `TextKit2BufferAdapter` storage, a visible UTF-16 viewport range, an `EditorHighlightProjection` (active line, word occurrences, bracket pairs, backticks), search matches, and lint diagnostics
- **WHEN** `TextKit2ViewportHighlightApplier.applyNonMutatingHighlightsIfNeeded(...)` runs inside `NSTextContentStorage.performEditingTransaction`
- **THEN** each isolated highlight pass applies attributes strictly to ranges intersecting the visible viewport and updates `lastHighlightRenderSignature` on the coordinator

#### Scenario: N5 Unchanged Highlight Render Signature or Out-of-Viewport Range Skips Redundant Storage Mutations
- **Path**: N5
- **Trait**: negative
- **GIVEN** an editor update where `HighlightRenderSignature` matches `coordinator.lastHighlightRenderSignature` or where highlight spans lie completely outside the visible UTF-16 viewport window and clamp bounds
- **WHEN** `TextKit2ViewportHighlightApplier.applyNonMutatingHighlightsIfNeeded(...)` evaluates the request
- **THEN** the applier returns immediately without opening an `NSTextContentStorage` editing transaction or mutating layout attributes

### Requirement: REQ-005 Modular Rule-Family Passes for MarkdownAllConstructsLinter
WHEN evaluating `.allConstructs` or security-only Markdown diagnostics, the Markdown all-constructs linter SHALL execute pure rule-family evaluator passes (headings and frontmatter, fenced code and math blocks, lists and blockquotes, tables/thematic-breaks/whitespace, and inline link/image security) where each pass method maintains cyclomatic complexity at most `15` [BC-001][BC-002][TEST-005][SEC-012].

#### Scenario: P5 Modular Rule-Family Passes Emit Identical 26-Rule Diagnostics and Quick-Fixes Within Complexity Budget
- **Path**: P5
- **Trait**: positive
- **GIVEN** a `MarkdownLineIndex` containing GFM headings, YAML frontmatter, fenced code/math blocks, nested lists, blockquotes, pipe tables, whitespace anomalies, and inline links/images
- **WHEN** `MarkdownAllConstructsLinter.diagnostics(index:deadlineExceeded:)` executes the decomposed rule-family passes
- **THEN** the linter produces identical 26-rule diagnostics and `TextEdit` quick-fixes to the baseline engine while every method in `MarkdownAllConstructsLinter.swift` and `MarkdownLinterRuleFamilyPasses.swift` has cyclomatic complexity `<= 15`

#### Scenario: N6 Exceeded Linter Deadline or Malicious Link and Image Traversal Fails Closed in Modular Passes
- **Path**: N6
- **Trait**: security
- **GIVEN** a Markdown document where `deadlineExceeded()` returns `true` mid-pass or where inline links/images contain `javascript:`, `vbscript:`, `data:text/html`, `file:`, or `../` path traversal
- **WHEN** `MarkdownAllConstructsLinter` runs full or `securityOnlyDiagnostics` passes
- **THEN** an exceeded deadline aborts the pass with `timedOut == true` and unsafe link/image constructs emit `.unsafeLinkScheme` or `.unsafeImagePath` security diagnostics without false negatives
