# Test Plan: Implement MarkdownLintAndFormat (swift-markdown AST) and SearchDiffAndBracketEngine (() {} [] & Myers Diff)

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `MarkdownAstLintAndFormatEngine` (`MarkdownLintAndFormatEngine` & `DocumentSession.applyTextEdits`) | `P1`: Parses Markdown via `swift-markdown` AST, reports `missingHeadingSpace`, `emptyLinkTarget`, and `unbalancedFencedCodeBlock`, computes `[TextEdit]` batches for `formatDocument` and `formatSection` (preserving fenced code blocks), and applies them atomically via `DocumentSession.applyTextEdits` in one `BufferRevision` step (`[AR-011]`, `[BC-004]`). | `N1`: Rejects stale `BufferRevision` (`DomainError.staleBufferRevision`) or overlapping/out-of-bounds `TextEdit` ranges (`DomainError.invalidTextRange`) without mutating `DocumentSession`; `N2` (`security`): Emits `.unsafeLinkScheme` on `javascript:`/`file:`/`data:` links and returns `.degradedOrTimedOut` on AST depth `> 128`, `isDegradedPlainText`, `isBinaryReadOnly`, or `> 250 ms` clock timeout (`[AR-013]`, `[BC-011]`, `[BC-012]`, `[SEC-004]`, `[SEC-012]`). |
| `BracketBalancingEngine` (`SearchDiffAndBracketEngine.evaluateBrackets`) | `P2`: Evaluates nested `()`, `{}`, and `[]` delimiters in `DocumentSnapshot`, returning matched `BracketPairSpan` pairs and resolving `activePair` at the caret offset (`[AR-004]`, `[AR-012]`, `[TEST-005]`). | `N3`: Reports mismatched or unclosed brackets (`(]`, stray `}`, unclosed `{`) in `unbalancedBrackets`; `N4` (`security`): Aborts delimiter scanning and returns `.degradedOrTimedOut` when any line exceeds `4096` UTF-16 code units or `isBinaryReadOnly == true` (`[BC-011]`, `[SEC-012]`). |
| `MyersFileCompareDiffEngine` (`SearchDiffAndBracketEngine.computeMyersDiff`) | `P3`: Computes minimal line-level Myers `DiffHunk` sequences (`.unchanged`, `.removed`, `.inserted`) with 1-based `lhsLineNumber` / `rhsLineNumber` tracking between two `DocumentSnapshot` values (`[AR-012]`, `[BC-006]`, `[TEST-005]`). | `N5`: Returns `hasDifferences == false` and all `.unchanged` hunks on identical snapshots; `N6` (`security`): Returns `.degradedOrTimedOut` when either snapshot exceeds `10 MiB`, is degraded/binary read-only, or exceeds the `500 ms` injected clock budget (`[AR-013]`, `[BC-011]`, `[SEC-012]`). |

## 2. Test Automation Strategy & Commands
- Unit test runner command: `swift test --parallel`
- Security trait / suite filter command: `swift test --parallel --filter Security`
- Coverage verification command: `swift test --parallel --enable-code-coverage`

## 3. Testability Seams & Test Doubles
- Real collaborators: Real `swiftlang/swift-markdown` AST parser (`Document`), real `DocumentSnapshot` / `DocumentSession` value types, and real Myers diff / bracket algorithms.
- Isolation seams: `DeterministicClockFake` conforming to `ElapsedTimeProviding` (`AR-007`, `AR-013`, `TEST-004`) advancing simulated elapsed milliseconds deterministically without `Task.sleep`.

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | Given/When/Then scenarios defined in `specs/markdown-lint-format-bracket-and-diff/spec.md` (`REQ-001..REQ-004`) |
| Path coverage completeness | Verified | All 3 units cover positive (`P1..P3`) and negative (`N1..N6`) paths |
| Security traits tagged | Verified | Abuse cases `N2`, `N4`, and `N6` tagged `- **Trait**: security` (`[BC-011]`, `[BC-012]`, `[SEC-004]`, `[SEC-012]`) |
