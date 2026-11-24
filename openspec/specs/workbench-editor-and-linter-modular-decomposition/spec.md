# Capability: workbench-editor-and-linter-modular-decomposition

## Purpose
Flattens all remaining high-member nominal structures and classes across `Sources/SwiftEditCore` and `Sources/SwiftEditUI` to at most `25` declared members per nominal block (`maxNominalBlockLines <= 400`), eliminates all 8 remaining call-graph recursion cycles (`tokensave_recursion == 0` in `Sources/`), enforces per-method cyclomatic (`<= 15`) and cognitive (`<= 25`) complexity ceilings, reduces file dependency depth to at most `10` hops with zero dead private functions, and enforces at least `85%` line coverage across both `SwiftEditCore` and `SwiftEditUI` in an automated Refactor-Verify-Reanalyze loop.

## Requirements

### Requirement: REQ-001 Automated Code Modularity and Anti-God-Class Fitness Gate
WHEN evaluating production source directories under `Sources/SwiftEditCore` and `Sources/SwiftEditUI`, the code modularity fitness scanner SHALL verify that every `.swift` file contains at most `800` lines, every nominal declaration or extension block contains at most `400` lines, and every nominal declaration block declares at most `25` members while rejecting symlinked or out-of-root paths fail-closed [AR-006][TEST-006][SEC-003][SEC-012][SDD-001].

#### Scenario: P1 Live Production Sources Pass File Block and Member Modularity Budgets
- **Path**: P1
- **Trait**: positive
- **GIVEN** the live repository `Sources/SwiftEditCore` and `Sources/SwiftEditUI` directories after flattening all 9 high-member types (`EditorRenderingAttributeTable`, `PurpleThemePalette`, `SwiftEditNSTextView`, `SwiftEditWorkbenchModel`, `TextKit2EditorView`, `WorkspaceEditorCoordinator`, `ZoomedChromeMetrics`, `DocumentSession`, and `LogTailController`) to `<= 25` members each
- **WHEN** `CodeModularityFitnessScanner.scanDirectories(at:budgets:)` evaluates every `.swift` source file against `CodeModularityBudgets.default` (`maxFileLines: 800`, `maxNominalBlockLines: 400`, `maxNominalMembers: 25`)
- **THEN** the scan completes with zero `CodeModularityViolation` entries and confirms every scanned file and nominal block is within the `25`-member and `400`-line block budgets

#### Scenario: N1 Oversized Source File Nominal Block or Member Count Emits Typed Violations
- **Path**: N1
- **Trait**: negative
- **GIVEN** synthetic Swift source fixtures containing a file of `801` lines, a nominal class block of `401` lines, or a nominal type declaring `26` methods and properties (including `@ObservationIgnored` properties and `init`/`deinit`)
- **WHEN** `CodeModularityFitnessScanner.scanSource(content:filePath:budgets:)` analyzes each fixture
- **THEN** the scanner returns non-empty typed `CodeModularityViolation` diagnostics identifying the exact file path, type name, metric kind, observed count, and budget limit

#### Scenario: N2 Symlink Escape Parent Traversal or Oversized Source Payload Fails Closed
- **Path**: N2
- **Trait**: security
- **GIVEN** a scanned directory containing a symlinked `.swift` file pointing outside the canonical repository root, a relative `../` path segment, or a `.swift` payload exceeding `4_194_304` bytes
- **WHEN** `CodeModularityFitnessScanner.scanDirectory(at:budgets:)` enumerates the directory
- **THEN** the scanner rejects the entry fail-closed with a `CodeModularityViolation` of kind `.securityBoundaryViolation` without reading external files

### Requirement: REQ-002 Modular Workbench Sub-Controllers and Domain Extension Decomposition
WHEN `SwiftEditWorkbenchModel`, `WorkspaceEditorCoordinator`, `DocumentSession`, and `LogTailController` coordinate workbench state, editor sessions, document mutations, and live log tailing, each nominal block SHALL declare at most `25` members and delegate cohesive state groups to sub-structs and acyclic extensions while preserving public API signatures [AR-009][AR-010][UI-005][SEC-003][SEC-004].

#### Scenario: P2 Isolated Workbench Sub-Controllers Execute Domain Operations and Synchronize With Facade
- **Path**: P2
- **Trait**: positive
- **GIVEN** isolated instances of `SwiftEditWorkbenchModel`, `WorkspaceEditorCoordinator`, `DocumentSession`, and `LogTailController` flattened to `<= 25` nominal members per declaration block via cohesive state sub-structs and domain extensions
- **WHEN** a caller invokes completion suffix lookup, find/replace, terminal session queuing, confined sidebar file CRUD, update checks, document session edits, or live log tailing
- **THEN** each component deterministically updates its domain state and preserves 100% source and behavioral compatibility across all existing public properties and methods

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
WHEN updating TextKit 2 typography, GFM syntax attributes, viewport highlights, per-tab undo managers, or zoomed chrome metrics, the TextKit 2 editor and theme layer SHALL declare at most `25` members per nominal block across `EditorRenderingAttributeTable`, `PurpleThemePalette`, `SwiftEditNSTextView`, `TextKit2EditorView`, `TextKit2EditorView.Coordinator`, and `ZoomedChromeMetrics` in acyclic files of at most `800` lines [AR-010][UI-001][UI-002][UI-006][UI-007].

#### Scenario: P4 TextKit2ViewportHighlightApplier Applies Scoped Highlight Passes Within Dirty or Visible Ranges
- **Path**: P4
- **Trait**: positive
- **GIVEN** a `TextKit2BufferAdapter` storage, a visible UTF-16 viewport range, an `EditorHighlightProjection`, search matches, lint diagnostics, and flattened `EditorRenderingAttributeTable`, `PurpleThemePalette`, `SwiftEditNSTextView`, `TextKit2EditorView`, `TextKit2EditorView.Coordinator`, and `ZoomedChromeMetrics` (`<= 25` nominal members each)
- **WHEN** `TextKit2ViewportHighlightApplier.applyNonMutatingHighlightsIfNeeded(...)` and theme/metric builders execute
- **THEN** each isolated highlight pass applies attributes strictly to ranges intersecting the visible viewport, updates `lastHighlightSnapshot`, and preserves all theme colors and zoom metrics with zero circular calls

#### Scenario: N5 Unchanged Highlight Render Signature or Out-of-Viewport Range Skips Redundant Storage Mutations
- **Path**: N5
- **Trait**: negative
- **GIVEN** an editor update where `HighlightRenderSignature` matches `coordinator.lastHighlightSnapshot` or where highlight spans lie completely outside the visible UTF-16 viewport window and clamp bounds
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

### Requirement: REQ-006 File-Level Dependency Acyclicity and Leaf Line-Index Isolation
WHEN evaluating cross-file symbol and call dependencies across `Sources/SwiftEditCore` and `Sources/SwiftEditUI`, the file dependency acyclicity verifier SHALL confirm zero circular file dependency cycles, zero upward call edges from `SwiftEditCore` to `SwiftEditUI`, and a maximum cross-file dependency depth of at most `10` hops [AR-006][AR-007][BC-001][BC-002][TEST-006].

#### Scenario: P6 Production File Graph Contains Zero Strongly Connected Components
- **Path**: P6
- **Trait**: positive
- **GIVEN** the production source files under `Sources/SwiftEditCore` and `Sources/SwiftEditUI` with `MarkdownLineIndex.swift` isolated as an acyclic leaf and `SwiftEditWorkbenchModel+*.swift` extensions decoupled from horizontal chaining
- **WHEN** `CodeModularityFitnessScanner.verifyAcyclicFileGraph(at:)` analyzes cross-file dependencies and symbol call edges across both targets
- **THEN** the verifier reports zero Strongly Connected Components (`cycleCount == 0`), zero upward edges from `SwiftEditCore` into `SwiftEditUI` or `Tests/`, and maximum file dependency chain depth `<= 10`

#### Scenario: N7 Cyclic File Dependency or Upward Core-to-UI Call Edge Emits Typed Cycle Violation
- **Path**: N7
- **Trait**: negative
- **GIVEN** synthetic Swift source fixtures containing a two-file mutual call cycle (`FileA.swift <-> FileB.swift`) or an upward symbol reference from `SwiftEditCore` into `SwiftEditUI`
- **WHEN** `CodeModularityFitnessScanner.verifyAcyclicFileGraph(sources:)` evaluates the dependency graph
- **THEN** the verifier rejects the graph and emits a `CodeModularityViolation` of kind `.circularFileDependency` listing the offending file cycle path

### Requirement: REQ-007 Call-Graph Recursion Elimination and Bounded Iterative View Traversal
WHEN resolving typography fonts, tailing rotated log files, moving workspace tabs, running all-construct Markdown lint passes, or invalidating `NSView` and `CALayer` display trees, the runtime SHALL execute disambiguated non-recursive call chains (`0` recursion cycles in `Sources/`) and bounded iterative worklist traversals capped at `4_096` visited nodes [AR-007][AR-010][UI-002][UI-007][SEC-001][SEC-004][SEC-012].

#### Scenario: P7 Disambiguated Update Check Preferences Store and Iterative Display Invalidation Execute Without Recursion Cycles
- **Path**: P7
- **Trait**: positive
- **GIVEN** `AppTypography` resolving system and OpenDyslexic faces via non-colliding helper names, `LogTailWorker` polling and re-arming vnode sources via a leaf `readAndDeliverSnapshotLocked(force:)` helper, `WorkspaceTabSession` moving tabs via `moveTabAtIndices`, `MarkdownAllConstructsLinter` running `evaluateConstructPasses`, and `SwiftEditNSTextView` iteratively invalidating subviews and sublayers
- **WHEN** each operation executes and `CodeModularityFitnessScanner.verifyZeroCallGraphRecursion(at:)` (and `tokensave_recursion`) inspects `Sources/SwiftEditCore` and `Sources/SwiftEditUI`
- **THEN** the call graph in `Sources/` contains `0` self-loops and `0` mutual recursion cycles while preserving identical typography resolution, live log rotation tailing, tab reordering, lint diagnostics, and view redraw behavior

#### Scenario: N8 Pathological Deep or Cyclic Layer Hierarchy Terminates at Visitation Cap Without Stack Overflow
- **Path**: N8
- **Trait**: security
- **GIVEN** a deep or synthetic `CALayer` / `NSView` hierarchy containing more than `4_096` nested child nodes or a rapidly rotated log file triggering delete/rename vnode events
- **WHEN** `SwiftEditNSTextView.markLayerTreeNeedsDisplay(_:maxVisitedNodes:)` or `LogTailWorker` processes the events
- **THEN** the iterative worklist halts deterministically at `4_096` visited nodes without stack recursion (`CWE-674`) and `LogTailWorker` closes the old file descriptor and re-arms once without recursive re-entrancy (`CWE-400`)

### Requirement: REQ-008 Method Cyclomatic and Cognitive Complexity Ceiling and Table-Driven Shortcut Dispatch
WHEN evaluating production method complexity across `Sources/SwiftEditCore` and `Sources/SwiftEditUI`, the complexity fitness scanner SHALL verify that every production method maintains cyclomatic complexity at most `15` and cognitive complexity at most `25` [AR-010][BC-001][BC-002][UI-005][TEST-006][SEC-012].

#### Scenario: P8 Decomposed Core Engines and Table-Driven UI Command Dispatchers Preserve Identical Behavior Within Complexity Ceilings
- **Path**: P8
- **Trait**: positive
- **GIVEN** the production implementations of `MarkdownLinterInlineSecurityPass.scanInline`, `CursorMetricsCalculator.metrics`, `MarkdownPreviewProjector.project`, `LogSyntaxHighlighter.scan`, `MarkdownAuthoringCommands.evaluateTab`, `MarkdownLintAndFormatEngine.lint`, `DocumentSession.applyTextEdits`, `TextKit2EditorCoordinator.applyProgrammaticTextUpdate`, `SwiftEditWorkbenchModel.refreshDiagnosticsForActiveDocument`, and table-driven `performCheatSheetCommand`, `dispatchCommandOnly`, and `attachKeyDownMonitor`
- **WHEN** `CodeModularityFitnessScanner.verifyMethodComplexityBudgets(at:maxCyclomatic:maxCognitive:)` evaluates all methods in `Sources/SwiftEditCore` and `Sources/SwiftEditUI` with `maxCyclomatic: 15` and `maxCognitive: 25` and the functional regression suites run
- **THEN** every method reports cyclomatic complexity `<= 15` and cognitive complexity `<= 25` while producing identical Markdown diagnostics, preview blocks, log spans, cursor metrics, buffer edits, and shortcut actions

#### Scenario: N9 Malicious Inline Markdown Schemes Traversal Payloads or Unmapped Shortcut Chords Fail Closed in Decomposed Sub-Passes
- **Path**: N9
- **Trait**: security
- **GIVEN** a Markdown payload containing `javascript:`, `vbscript:`, `data:text/html`, `file:`, `../` relative traversal, or disallowed control/BiDi scalars (`U+202A..U+202E`, `U+2066..U+2069`) or an unmapped/malformed keyboard shortcut event
- **WHEN** the decomposed `MarkdownLinterInlineSecurityPass` sub-passes or table-driven `SwiftEditShortcutDispatcher` evaluate the input
- **THEN** the inline security sub-passes emit the corresponding `.unsafeLinkScheme`, `.unsafeImagePath`, or `.disallowedControlCharacter` security diagnostic without false negatives and the shortcut dispatcher rejects the unmapped chord without mutating workbench state

### Requirement: REQ-009 Dead Private Symbol Elimination and Shallow Extension Dependency Layering
WHEN analyzing symbol reachability and cross-file dependency chains across `Sources/SwiftEditCore` and `Sources/SwiftEditUI`, the codebase SHALL contain zero unreferenced private functions or methods and maintain a maximum file dependency chain depth of at most `10` hops [AR-006][AR-007][TEST-006][SDD-001].

#### Scenario: P9 Production Sources Contain Zero Unreferenced Private Helpers and Dependency Chain Depth At Most 10
- **Path**: P9
- **Trait**: positive
- **GIVEN** all production `.swift` source files under `Sources/SwiftEditCore` and `Sources/SwiftEditUI` after dead-symbol cleanup and horizontal `SwiftEditWorkbenchModel+*.swift` decoupling
- **WHEN** `CodeModularityFitnessScanner.verifyDeadPrivateSymbolsAndDependencyDepth(at:maxDepth:)` inspects private symbol references and shortest/longest acyclic dependency paths with `maxDepth: 10`
- **THEN** the scanner reports zero unreferenced private functions or methods and confirms the longest file dependency chain across `Sources/` is `<= 10` hops

#### Scenario: N10 Unreferenced Private Helper or Deep Extension Chain Exceeding 10 Hops Emits Typed Fitness Violation
- **Path**: N10
- **Trait**: negative
- **GIVEN** synthetic Swift source fixtures containing an uncalled `private func unusedHelper()` or a linear file dependency chain of `11` files (`F1 -> F2 -> ... -> F11`)
- **WHEN** `CodeModularityFitnessScanner.verifyDeadPrivateSymbolsAndDependencyDepth(sources:maxDepth:)` evaluates the fixtures with `maxDepth: 10`
- **THEN** the scanner rejects the fixtures and emits typed `CodeModularityViolation` diagnostics identifying the unreferenced private symbol name and the `11`-hop dependency chain

### Requirement: REQ-010 Full-Codebase 85 Percent Line Coverage and TokenSave Convergence Gate
WHEN executing the continuous verification and TokenSave re-analysis pipeline across `PH.SwiftEdit`, the verification suite SHALL confirm at least `85.0%` line coverage in `SwiftEditCore`, at least `85.0%` line coverage in `SwiftEditUI`, and at least `85.0%` aggregate line coverage alongside zero file cycles, zero recursion cycles, and zero nominal blocks exceeding `25` members [AR-006][TEST-001][TEST-005][TEST-006][TEST-008][SDD-001].

#### Scenario: P10 Full Test Suite Achieves At Least 85 Percent Coverage Across Both Targets and Converges TokenSave Metrics
- **Path**: P10
- **Trait**: positive
- **GIVEN** the refactored `SwiftEditCore` and `SwiftEditUI` targets and the expanded `SwiftEditTests` suite covering `LogSyntaxHighlighter`, `MarkdownAuthoringCommands`, `MarkdownLinterInlineSecurityPass`, `SwiftEditShortcutDispatcher`, `SwiftEditRootView` key monitor, `UpdateCheckSheetView`, `PropertiesPanelView`, and `LogTailController`
- **WHEN** `swift test --parallel --enable-code-coverage` and the coverage and graph convergence evaluator inspect the exported `llvm-cov` JSON summary and `CodeModularityFitnessScanner` report
- **THEN** `SwiftEditCore` line coverage is `>= 85.0%`, `SwiftEditUI` line coverage is `>= 85.0%`, aggregate line coverage is `>= 85.0%`, and all modularity, acyclicity, recursion (`0`), and complexity (`<= 15` / `<= 25`) gates pass with zero violations

#### Scenario: N11 Sub-Threshold Target Coverage or Residual Graph Violation Fails Verification Gate
- **Path**: N11
- **Trait**: negative
- **GIVEN** a synthetic coverage report where `SwiftEditCore` is `92.0%` but `SwiftEditUI` is `84.9%` (or aggregate coverage is `< 85.0%`) or where a residual recursion cycle remains in `Sources/`
- **WHEN** the coverage and convergence fitness evaluator validates the report against the `85.0%` per-target floor
- **THEN** validation fails closed and reports the exact target name, observed line coverage percentage, and failing threshold
