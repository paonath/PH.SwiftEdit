# Capability: markdown-lint-format-bracket-and-diff

## Purpose
Caches bracket-pair topology per `(DocumentID, BufferRevision)` and eliminates full-buffer allocations on caret moves so `10,000`-line navigation meets `<= 16 ms` (`PERF-007`), and preserves distinct `.modified` LHS/RHS highlighting in `SideBySideDiffRow` (`BUG-020`).

## Requirements

### Requirement: REQ-001 Offline Markdown AST Linting and Formatting Batch Generation
WHEN evaluating a non-degraded text `DocumentSnapshot`, the Markdown lint and format engine SHALL parse offline via `swift-markdown` to emit `MarkdownLintDiagnostic` values for the selected `MarkdownLintProfile` (default `.legacyBaseline`), including `.nonStandardOutlineMarker`, and compute single-revision format batches [AR-011][BC-003][BC-004][BC-006][TEST-005].

#### Scenario: P1 AST Linting and Format Document or Format Section Batch Application
- **Path**: P1
- **Trait**: positive
- **GIVEN** a `DocumentSnapshot` at `BufferRevision(1)` containing malformed Markdown lines (`"#Heading without space"`, `"*   item   "`, `"[]()"`, and a fenced code block `"```swift\nlet  x = 1\n```"`)
- **WHEN** `MarkdownLintAndFormatEngine` runs `lint(snapshot:)`, `formatDocument(snapshot:)`, and `formatSection(snapshot:range:)`, and `DocumentSession.applyTextEdits` applies the returned `[TextEdit]` batch with `expectedRevision: BufferRevision(1)`
- **THEN** `lint` reports `missingHeadingSpace` and `emptyLinkTarget`, `formatDocument` normalizes `"# Heading without space"` and `"- item"` without altering the fenced code block body, and `applyTextEdits` updates `DocumentSession` in a single transition to `BufferRevision(2)`

#### Scenario: N1 Stale BufferRevision or Invalid TextEdit Range Rejection
- **Path**: N1
- **Trait**: negative
- **GIVEN** a `DocumentSession` at `BufferRevision(2)` and a `[TextEdit]` batch computed for stale `BufferRevision(1)` or containing an overlapping/out-of-bounds `TextRange`
- **WHEN** `DocumentSession.applyTextEdits` is called with the stale revision or invalid range batch
- **THEN** the call throws `DomainError.staleBufferRevision` or `DomainError.invalidTextRange` and leaves `DocumentSession.text` and `BufferRevision(2)` unchanged

#### Scenario: N3 Non-Standard Outline Markers Are Flagged Outside Fences Only
- **Path**: N3
- **Trait**: negative
- **GIVEN** a snapshot `"1. ok\n    a. alpha\n    1.1 beta\n```\n    b. code\n```"`
- **WHEN** `lint(snapshot:)` runs
- **THEN** it reports `.nonStandardOutlineMarker` on lines `2` and `3` only, and reports none for the valid `1.` item or the fenced `b.` line

#### Scenario: N7 Default Lint Call Keeps the Legacy Rule Set
- **Path**: N7
- **Trait**: negative
- **GIVEN** a snapshot `"#Heading\n[x](javascript:alert(1))"`
- **WHEN** `lint(snapshot:)` runs without a profile
- **THEN** it returns the same diagnostics as before this change and none of the all-construct-only rules

### Requirement: REQ-002 Markdown URI Safety Diagnostics and AST Complexity Deadlines
IF a `DocumentSnapshot` contains a link outside `https`, `http`, `mailto`, fragment, or relative paths, exceeds `128` AST nesting levels, is marked degraded or binary read-only, or exceeds the `250` millisecond clock budget, THEN the Markdown lint and format engine SHALL flag unsafe URI schemes and return a degraded or timed-out outcome [AR-013][BC-011][BC-012][SEC-004][SEC-012].

#### Scenario: P1 Safe Relative and HTTPS Markdown Links Produce Zero Security Diagnostics
- **Path**: P1
- **Trait**: positive
- **GIVEN** a `DocumentSnapshot` containing `[Docs](docs/design/color-schemes-and-zed-layout.md)` and `[Swift](https://swift.org)` within `128` AST levels and `250` milliseconds
- **WHEN** `MarkdownLintAndFormatEngine.lint` evaluates the snapshot
- **THEN** the engine returns `.completed` with zero `unsafeLinkScheme` diagnostics

#### Scenario: N2 Unsafe URI Scheme Deep AST Nesting Degraded Binary or Timeout Rejection
- **Path**: N2
- **Trait**: security
- **GIVEN** a `DocumentSnapshot` containing `[XSS](javascript:alert(1))` or `[Local](file:///etc/passwd)`, or a snapshot with `> 128` nested blockquotes, `isDegradedPlainText == true`, `isBinaryReadOnly == true`, or an injected clock advancing past `250` milliseconds
- **WHEN** `MarkdownLintAndFormatEngine` executes `lint` or `formatDocument`
- **THEN** dangerous links produce `.unsafeLinkScheme` diagnostics and depth, degraded, binary, or clock-exceeded inputs return `.degradedOrTimedOut` without mutating state

### Requirement: REQ-003 Deterministic Bracket Balancing and Line-Length Guard
WHEN evaluating delimiters or moving the caret, the bracket matching engine SHALL cache `SearchDiffAndBracketEngine` bracket topology by `(DocumentID, BufferRevision)`, resolve `activePair` and `enclosingPairs` via binary lookup within `16 ms` at `10,000` lines, and refuse lines over `4096` UTF-16 units [AR-004][AR-012][BC-011][SEC-012][TEST-005][UI-012].

#### Scenario: P2 Nested Balanced Brackets and Active Caret Pair Resolution
- **Path**: P2
- **Trait**: positive
- **GIVEN** a `DocumentSnapshot` containing `"func demo(a: [Int]) { return (a[0]) }"` and a caret offset positioned adjacent to `"{"` or `"]"`
- **WHEN** `SearchDiffAndBracketEngine.evaluateBrackets` inspects the snapshot
- **THEN** all four `()`, `[]`, and `{}` pairs are returned as matched `BracketPairSpan` values, `unbalancedBrackets` is empty, and `activePair` matches the delimiter at the caret

#### Scenario: N3 Mismatched or Unclosed Bracket Detection
- **Path**: N3
- **Trait**: negative
- **GIVEN** a `DocumentSnapshot` containing `"let broken = [(1 + 2)] } ({ unclosed"`
- **WHEN** `SearchDiffAndBracketEngine.evaluateBrackets` inspects the snapshot
- **THEN** the stray `"}"`, `"("`, and `"{"` delimiters are reported in `unbalancedBrackets` with their exact UTF-16 offsets and characters

#### Scenario: N4 Overlong Line Exceeding 4096 UTF-16 Code Units or Binary Snapshot Guard
- **Path**: N4
- **Trait**: security
- **GIVEN** a `DocumentSnapshot` containing a single line of `4097` UTF-16 code units or `isBinaryReadOnly == true`
- **WHEN** `SearchDiffAndBracketEngine.evaluateBrackets` inspects the snapshot
- **THEN** the engine aborts full-line delimiter scanning and returns `.degradedOrTimedOut`

#### Scenario: P4 Nested Depth Indexing Across Braces Brackets and Parentheses
- **Path**: P4
- **Trait**: positive
- **GIVEN** a `DocumentSnapshot` containing `"scrivo{ho le graffe, le quadre[dentro le quadre ho le tonde(qua) e (pure qua)]}"` with caret inside `"(qua)"`
- **WHEN** `SearchDiffAndBracketEngine.evaluateBrackets` inspects the snapshot
- **THEN** `{}` has `nestingDepth == 0`, `[]` has `nestingDepth == 1`, both `()` pairs have `nestingDepth == 2`, and `enclosingPairs` contains the outer-to-inner chain `[{}, [], ()]`

#### Scenario: N7 Unbalanced Deeply Nested Delimiters Retain Depth of Valid Pairs Without Overflow
- **Path**: N7
- **Trait**: negative
- **GIVEN** a `DocumentSnapshot` containing `"{[ ( ] }"` with a stray unmatched `"("`
- **WHEN** `SearchDiffAndBracketEngine.evaluateBrackets` inspects the snapshot
- **THEN** unmatched delimiters are reported in `unbalancedBrackets` with exact UTF-16 offsets and matched pairs retain non-negative `nestingDepth`

#### Scenario: P5 Cached Bracket Topology Resolves 10000-Line Caret Moves Within 16ms Budget
- **Path**: P5
- **Trait**: positive
- **GIVEN** a `10,000`-line Markdown document with nested delimiters parsed once at `(docID, rev 1)`
- **WHEN** `handleSelectionChanged` moves the caret `100` consecutive times within `rev 1`
- **THEN** cached `BracketPairSpan` lookup runs without re-scanning full UTF-16 buffers, resolving `activePair` and `enclosingPairs` accurately with P99 latency `<= 16 ms`

#### Scenario: N8 Same-Revision Text Edit Invalidates Bracket Cache via BufferRevision Increment
- **Path**: N8
- **Trait**: negative
- **GIVEN** a cached bracket parse at `(docID, rev 1)` followed by editing `"("` to `")"` incrementing to `(docID, rev 2)`
- **WHEN** `evaluateBrackets` runs at `rev 2`
- **THEN** the cache misses cleanly on `rev 2` and returns updated `unbalancedBrackets` instead of serving stale `rev 1` spans

### Requirement: REQ-004 Stateless Two-Snapshot Myers File Compare Diff with Resource Caps
WHEN comparing two `DocumentSnapshot` values and aligning side-by-side rows, the diff engine SHALL emit `DiffHunk` sequences classifying modified line pairs so LHS renders `.removed` red highlights and RHS renders `.inserted` green highlights while enforcing `10 MiB` and `500 ms` caps [AR-004][AR-012][AR-013][BC-006][BC-011][SEC-012][TEST-005].

#### Scenario: P3 Line-Level Myers Diff Produces Minimal Inserted Removed and Unchanged Hunks
- **Path**: P3
- **Trait**: positive
- **GIVEN** a baseline `DocumentSnapshot` `"alpha\nbeta\ngamma"` and a modified `DocumentSnapshot` `"alpha\nbeta-updated\ngamma\ndelta"`
- **WHEN** `SearchDiffAndBracketEngine.computeMyersDiff` compares the two snapshots
- **THEN** the result is `.completed` with `hasDifferences == true` and ordered `DiffHunk` entries marking `"alpha"` unchanged, `"beta"` removed, `"beta-updated"` inserted, `"gamma"` unchanged, and `"delta"` inserted

#### Scenario: N5 Identical Snapshots Report Zero Differences
- **Path**: N5
- **Trait**: negative
- **GIVEN** two `DocumentSnapshot` instances containing identical text `"same\ncontent"`
- **WHEN** `SearchDiffAndBracketEngine.computeMyersDiff` compares the two snapshots
- **THEN** the result is `.completed` with `hasDifferences == false` and all lines classified as `.unchanged`

#### Scenario: N6 Diff Input Above 10 MiB Binary Snapshot or Clock Timeout Rejection
- **Path**: N6
- **Trait**: security
- **GIVEN** a comparison where either `DocumentSnapshot` has `isDegradedPlainText == true` (`> 10 MiB`), `isBinaryReadOnly == true`, UTF-8 byte length `> 10_485_760`, or an injected clock exceeding `500` milliseconds
- **WHEN** `SearchDiffAndBracketEngine.computeMyersDiff` evaluates the pair
- **THEN** the engine aborts diff matrix expansion and returns `.degradedOrTimedOut`

#### Scenario: P6 Modified Line Pairs Highlight Removed LHS Text Red and Inserted RHS Text Green
- **Path**: P6
- **Trait**: positive
- **GIVEN** baseline `"alpha\nbeta\ngamma"` and modified `"alpha\nbeta-updated\ngamma"` passed to `alignSideBySideRows`
- **WHEN** `DiffPaneCoordinator` builds side-by-side rows for row `2`
- **THEN** row `2` exposes distinct left `.removed` (`lhsKind == .removed`) and right `.inserted` (`rhsKind == .inserted`) or `.modified` state so LHS highlights `"beta"` red and RHS highlights `"beta-updated"` green

#### Scenario: N9 Binary or Over-10-MiB Diff Pair Yields Zero Misclassified Modified Highlights
- **Path**: N9
- **Trait**: negative
- **GIVEN** identical snapshots or a diff input marked `isBinaryReadOnly == true` or `isDegradedPlainText == true`
- **WHEN** `alignSideBySideRows` evaluates the diff outcome
- **THEN** zero `.removed`, `.inserted`, or `.modified` highlight states are emitted
