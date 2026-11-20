# Capability: markdown-lint-format-bracket-and-diff

## Purpose
Extends `REQ-001` of `markdown-lint-format-bracket-and-diff` additively with the `.nonStandardOutlineMarker` diagnostic that flags pseudo-outline list prefixes CommonMark treats as plain paragraph text, preserving all existing lint and format behavior.

## Requirements

### Requirement: REQ-001 Offline Markdown AST Linting and Formatting Batch Generation
WHEN evaluating a non-degraded text `DocumentSnapshot`, the Markdown lint and format engine SHALL parse offline via `swift-markdown` to emit `MarkdownLintDiagnostic` values, including `.nonStandardOutlineMarker` for `a.`/`1.1` prefixes outside fences, and compute single-revision format batches [AR-011][BC-003][BC-004][BC-006][TEST-005].

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
WHEN evaluating `()`, `{}`, and `[]` delimiters in a `DocumentSnapshot`, the bracket matching engine SHALL return matched `BracketPairSpan` pairs with 0-based `nestingDepth`, identify `activePair` and `enclosingPairs` at the caret offset, report unbalanced brackets, and refuse lines exceeding `4096` UTF-16 code units [AR-004][AR-012][BC-011][SEC-012][TEST-005].

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

### Requirement: REQ-004 Stateless Two-Snapshot Myers File Compare Diff with Resource Caps
WHEN comparing two `DocumentSnapshot` values, the file compare diff engine SHALL compute line-level Myers `DiffHunk` sequences (`.unchanged`, `.inserted`, `.removed`) while returning a degraded or timed-out outcome if either input exceeds `10 MiB`, is binary read-only, or exceeds the `500` millisecond clock deadline [AR-004][AR-012][AR-013][BC-006][BC-011][SEC-012][TEST-005].

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
