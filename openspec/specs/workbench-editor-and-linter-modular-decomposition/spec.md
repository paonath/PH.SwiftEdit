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

### Requirement: REQ-011 Core Search Filesystem Pre-Scan and Native Preview Block Complexity Decomposition
WHEN executing literal document searches (`DocumentSearchEngine.find`), copy-tree pre-scans (`LocalFileSystemAdapter.preScanCopySourceTree`), and native Markdown block rendering (`MarkdownNativePreviewView.blockView`), the runtime SHALL decompose each entrypoint into cohesive helpers satisfying `cognitive <= 12`, `cyclomatic <= 9`, and `max_nesting <= 3` (with `blockView` at `cognitive <= 8` and `max_nesting <= 3`) while preserving all symlink, confinement, batch-limit, and offline-preview security controls [AR-006][BC-004][SEC-003][SEC-004][SEC-010][SEC-012][TEST-006].

#### Scenario: P11 Decomposed Search Filesystem Pre-Scan and Preview Block Views Meet Complexity Targets With Passing Regression Tests
- **Path**: P11
- **Trait**: positive
- **GIVEN** the refactored `DocumentSearchEngine.find`, `LocalFileSystemAdapter.preScanCopySourceTree`, and `MarkdownNativePreviewView.blockView` implementations and their extracted helpers
- **WHEN** `swift test` and `tokensave_complexity` evaluate `Sources/SwiftEditCore` and `Sources/SwiftEditUI` after `tokensave sync`
- **THEN** all `472` tests across `130` suites pass, `tokensave_circular` reports `0` cycles, and `find`, `preScanCopySourceTree`, and `blockView` satisfy `cyclomatic <= 9`, `cognitive <= 12` (`<= 8` for `blockView`), and `max_nesting <= 3`

#### Scenario: N12 Symlink Copy Escape Oversized Batch Search Flood or Malicious Preview HTML Link Continues Failing Closed
- **Path**: N12
- **Trait**: security
- **GIVEN** a copy source tree containing a symbolic link or exceeding `maxCopyItems`/`maxCopyBytes`, a search query exceeding `1024` UTF-16 units or `maxMatches`, or Markdown containing raw HTML or untrusted external links
- **WHEN** the decomposed `preScanCopySourceTree`, `DocumentSearchEngine.find`, or `MarkdownNativePreviewView.blockView` evaluates the input
- **THEN** symbolic links and oversized batches throw `DomainError.securityScopeViolation` or `DomainError.batchLimitExceeded`, oversized or flooded searches return `.degradedOrTimedOut`, and raw HTML renders strictly as inert monospaced text

### Requirement: REQ-012 Shortcut Dispatcher and Rendering Attribute Table Complexity Decomposition
WHEN dispatching keyboard shortcuts (`SwiftEditShortcutDispatcher.dispatchNonCommandChord`, `SwiftEditShortcutDispatcher.dispatchCommandOption`) and resolving TextKit 2 rendering attributes (`EditorRenderingAttributeTable.lookupSemanticEntries`, `EditorRenderingAttributeTable.attributes`), the UI layer SHALL decompose each entrypoint into cohesive table-driven or role-group helpers satisfying `cognitive <= 10, cyclomatic <= 8` for shortcut dispatchers and `cognitive <= 8, cyclomatic <= 8` for rendering attribute lookups while preserving `<= 20` nominal members in `EditorRenderingAttributes.swift` and all malformed, BiDi, overlay, and quarantine guards [AR-006][UI-002][UI-005][UI-009][UI-010][SEC-012][TEST-006].

#### Scenario: P12 Decomposed Shortcut Dispatcher and Rendering Attribute Lookups Meet Complexity Targets With Passing Regression Tests
- **Path**: P12
- **Trait**: positive
- **GIVEN** the refactored `SwiftEditShortcutDispatcher` (`dispatchNonCommandChord`, `dispatchCommandOption`, `commandOptionTable`, `dispatchTableEntry`) and `EditorRenderingAttributeTable` (`attributes`, `lookupSemanticEntries`, `lookupHTMLEntries`, `lookupJSONEntries`, `lookupInlineEntries`, `lookupBlockAndYAMLEntries`)
- **WHEN** `swift test` and `tokensave_complexity` evaluate `Sources/SwiftEditUI/Views/SwiftEditShortcutDispatcher.swift` and `Sources/SwiftEditUI/Views/EditorRenderingAttributes.swift` after `tokensave sync`
- **THEN** all `472` tests across `130` suites pass (including `<= 20` nominal member budget in `EditorRenderingAttributes.swift`), `tokensave_circular` reports `0` cycles, `dispatchNonCommandChord` and `dispatchCommandOption` satisfy `cyclomatic <= 8` and `cognitive <= 10`, and `lookupSemanticEntries` and `attributes` satisfy `cyclomatic <= 8` and `cognitive <= 8`

#### Scenario: N13 Malformed BiDi Chord Overlay Text Field Quarantine or Unmapped Attribute Fails Closed
- **Path**: N13
- **Trait**: security
- **GIVEN** a malformed, oversized, NUL-embedded, or BiDi-tainted keyboard chord, an editing shortcut dispatched while `isEditingOverlayTextField` is `true`, a quarantined binary tab, or an unstyled `.yamlValue` syntax kind
- **WHEN** `SwiftEditShortcutDispatcher.dispatch` or `EditorRenderingAttributeTable.attributes(for:)` evaluates the input
- **THEN** `SwiftEditShortcutDispatcher` rejects malformed, unmapped, or overlay-blocked chords fail-closed (`false`) without mutating workbench state and `EditorRenderingAttributeTable.attributes(for: .yamlValue)` returns `[]` preserving `21:1` canvas text contrast

### Requirement: REQ-013 Core Markdown Engines and Strict UTF-16 Codec Complexity Decomposition
WHEN evaluating Markdown smart newlines (`MarkdownSmartNewlineEngine.evaluateNewline`), decoding strict UTF-16 streams (`DocumentCodec.decodeStrictUTF16`), and indenting Markdown list selections (`MarkdownSmartListEngine.evaluateIndent`), the core domain layer SHALL decompose each entrypoint into cohesive helpers satisfying `cognitive <= 10` and `cyclomatic <= 8` while preserving `<= 25` nominal members per type and all line-bounds, overflow, nesting-cap, and strict surrogate-pair validation controls [AR-006][BC-004][BC-006][BC-007][DATA-003][DATA-004][SEC-012][TEST-006].

#### Scenario: P13 Decomposed Markdown Smart Newline Smart List and Strict UTF-16 Codec Meet Complexity Targets With Passing Regression Tests
- **Path**: P13
- **Trait**: positive
- **GIVEN** the refactored `MarkdownSmartNewlineEngine.evaluateNewline`, `DocumentCodec.decodeStrictUTF16`, and `MarkdownSmartListEngine.evaluateIndent` implementations and their extracted cohesive helpers (`resolveCaretLine`, `emptyMarkerNewlineEdit`, `decodeNextUTF16Scalar`, `appendUTF8Bytes`, and `collectIndentEdits`)
- **WHEN** `swift test` and `tokensave_complexity` evaluate `Sources/SwiftEditCore` after `tokensave sync`
- **THEN** all `473` tests across `130` suites pass, `tokensave_circular` reports `0` cycles, and `evaluateNewline`, `decodeStrictUTF16`, and `evaluateIndent` each satisfy `cyclomatic <= 8` and `cognitive <= 10`

#### Scenario: N14 Unpaired UTF-16 Surrogates Odd Byte Payloads Overlong Lines and Level-32 or Overflowing Lists Fail Closed
- **Path**: N14
- **Trait**: security
- **GIVEN** a UTF-16LE/BE payload with unpaired high/low surrogates, truncated high surrogate, or odd byte length, a binary/degraded snapshot or `> 4096` UTF-16 line, or a level-32 or `999_999_999`-overflowing ordered list
- **WHEN** the decomposed `DocumentCodec.decode`, `MarkdownSmartNewlineEngine.evaluateNewline`, or `MarkdownSmartListEngine.evaluateIndent` evaluates the input
- **THEN** `DocumentCodec.decode` throws `DomainError.unsupportedEncoding` and `MarkdownSmartNewlineEngine` and `MarkdownSmartListEngine` fail closed without out-of-bounds access or buffer mutations

### Requirement: REQ-014 Diagram Parser JSON Linter Syntax Highlighter and Release Update Checker Complexity Decomposition
WHEN parsing Mermaid and Markmap diagrams (`MarkdownDiagramParser.parse`), advancing JSON tokens (`JSONStructureLinter.advanceJSONToken`), matching inline GFM syntax constructs (`MarkdownSyntaxHighlighter.matchInlineSyntaxConstruct`), and comparing or evaluating GitHub release versions (`SemanticVersion.<`, `GitHubReleaseUpdateChecker.evaluate`), each entrypoint SHALL delegate to cohesive helpers satisfying `cognitive <= 10, cyclomatic <= 8` (`cognitive <= 8, cyclomatic <= 7` for `SemanticVersion.<` and `evaluate`) while preserving `<= 25` nominal members per type and all size, depth, linear-scan, and HTTPS host-allowlist security controls [AR-006][BC-004][SEC-001][SEC-004][SEC-012][TEST-006].

#### Scenario: P14 Decomposed Parsers Linters Highlighter and Update Checker Meet Complexity Targets With Passing Regression Tests
- **Path**: P14
- **Trait**: positive
- **GIVEN** the refactored `MarkdownDiagramParser.parse`, `JSONStructureLinter.advanceJSONToken`, `MarkdownSyntaxHighlighter.matchInlineSyntaxConstruct`, `SemanticVersion.<`, and `GitHubReleaseUpdateChecker.evaluate` implementations and their extracted helpers (`parseMermaidDiagram`, `consumeStructuralDelimiter`, `consumeColon`, `matchLinkOrTagConstruct`, `matchDelimitedInlineConstruct`, `comparePrereleaseLists`, `newestRelease`)
- **WHEN** `swift test` and `tokensave_complexity` evaluate all four source files after `tokensave sync`
- **THEN** all `473` tests across `130` suites pass, `tokensave_circular` reports `0` cycles, `MarkdownDiagramParser.parse`, `advanceJSONToken`, and `matchInlineSyntaxConstruct` satisfy `cyclomatic <= 8` and `cognitive <= 10`, and `SemanticVersion.<` and `evaluate` satisfy `cyclomatic <= 7` and `cognitive <= 8`

#### Scenario: N15 Oversized Diagrams Deep JSON Unclosed Inline Delimiters and Untrusted Release URLs Fail Closed
- **Path**: N15
- **Trait**: security
- **GIVEN** a Mermaid block exceeding `65_536` UTF-8 bytes or `12` subgraph nesting levels, a JSON payload with trailing tokens or nesting exceeding `128` levels, a GFM line exceeding `4096` UTF-16 units, or a GitHub release payload containing an HTTP or non-allowlisted release or download URL
- **WHEN** the decomposed `MarkdownDiagramParser.parse`, `JSONStructureLinter.lint`, `MarkdownSyntaxHighlighter.spans`, or `GitHubReleaseUpdateChecker.evaluateReleaseUpdate` evaluates the input
- **THEN** oversized diagrams return `.unsupportedOrOversized`, invalid or over-deep JSON emits `JSN003`/syntax diagnostics, overlong GFM lines yield no spans, and untrusted release URLs fail closed via `verifiedGitHubHTTPSURL`

### Requirement: REQ-015 Automation Scripts and Design Asset Verifier Complexity Decomposition
WHEN executing GitHub release installation (`Scripts/install-from-github.sh` `main`), macOS app bundle staging (`Scripts/build-app.sh` `main`), and Xcode `AppIcon.appiconset` validation (`Scripts/verify-design-assets.swift` `verifySingleAppIconSet`), each entrypoint SHALL delegate to cohesive helpers satisfying `cognitive <= 12, cyclomatic <= 10` for Bash scripts and `cognitive <= 8, cyclomatic <= 8` for Swift asset verification while preserving `set -euo pipefail`, `"$var"` quoting (`CWE-78`), SHA-256 checksum/HTTPS verification, build/packaging flags, and AppIcon symlink/confinement/size/alpha controls [AR-001][AR-006][UI-001][SEC-001][SEC-003][SEC-004][SEC-012][TEST-006][TEST-007].

#### Scenario: P15 Decomposed Release Installer Build Script and AppIcon Verifier Meet Complexity Targets With Passing Checks
- **Path**: P15
- **Trait**: positive
- **GIVEN** the refactored `Scripts/install-from-github.sh`, `Scripts/build-app.sh`, and `Scripts/verify-design-assets.swift` implementations and their extracted cohesive helpers (`apply_cli_option`, `parse_args`, `resolve_release_tag`, `determine_quarantine_plan`, `download_and_verify_archive`, `install_verified_app`, `prepare_xcodebuild_args`, `stage_built_product`, `loadAppIconManifest`, `validateAppIconSlot`, `validateAppIconFile`, `validatePngRaster`, `verifyStrayAppIconEntries`)
- **WHEN** `bash -n`, dry-run CLI checks, `swift Scripts/verify-design-assets.swift --self-test`, `swift Scripts/verify-design-assets.swift --root .`, `swift test`, and `tokensave_complexity(path="Scripts")` execute after `tokensave sync`
- **THEN** all `14` asset verifier self-tests, live workspace asset checks, and `473` Swift tests across `130` suites pass (`exit 0`), `tokensave_circular(path="Sources")` reports `0` cycles, Bash `main` and helpers satisfy `cyclomatic <= 10` and `cognitive <= 12`, and `verifySingleAppIconSet` and its helpers satisfy `cyclomatic <= 8` and `cognitive <= 8`

#### Scenario: N16 Invalid Tags Unquoted Traversal Filenames Symlinks Oversized Payloads and Alpha Mismatches Fail Closed
- **Path**: N16
- **Trait**: security
- **GIVEN** a release tag containing `..` or whitespace, an unknown or invalid `-c` build configuration, or an `AppIcon.appiconset` containing a path-traversal filename, symlink, out-of-root path, `> 16 MiB` PNG payload, or platform alpha mismatch (`ITMS-90717`)
- **WHEN** `Scripts/install-from-github.sh`, `Scripts/build-app.sh`, or `DesignAssetsVerifier.verifySingleAppIconSet` evaluates the input
- **THEN** invalid CLI tags or build configurations fail closed with exit code `1` without downloading or building, and `AppIcon.appiconset` traversal, symlink, `> 16 MiB`, and alpha violations fail closed with `VerificationReport.exitCode == 2`
