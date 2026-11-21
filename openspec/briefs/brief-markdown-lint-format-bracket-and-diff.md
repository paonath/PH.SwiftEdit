---
id: "brief-markdown-lint-format-bracket-and-diff"
change_id: "002-markdown-lint-format-bracket-and-diff"
capability: "markdown-lint-format-bracket-and-diff"
branch: "feature/FirstStub"
modifies_specs: "none"
status: "approved-via-qa"
date: "2026-11-17"
owners:
  - "swift-macos-expert"
  - "ddd-expert"
  - "cyber-security-expert"
---

# TDD Specification Brief: `MarkdownLintAndFormat` (`swift-markdown` AST) & `SearchDiffAndBracketEngine` (`(){}[]` & Myers Diff) (`TASK-03`)

## 1. Context & Source Traceability

- **Originating Roadmap Task**: `TASK-03` in `reasoning/001_project-constitution/README.ai.md`.
- **Active Git Branch**: `feature/FirstStub` (`Nerdbank.GitVersioning` `0.0.1-alpha1`).
- **Consolidated Specs Modified (`modifies_specs`)**: `none` (existing living specs `design-assets-promotion` and `document-core-and-spm-scaffold` are untouched; all requirements in `markdown-lint-format-bracket-and-diff` are `ADDED`).
- **Governing Constitutional Rules**: `[AR-002]`, `[AR-004]`, `[AR-007]`, `[AR-008]`, `[AR-011]`, `[AR-012]`, `[AR-013]`, `[BC-001]`, `[BC-002]`, `[BC-003]`, `[BC-004]`, `[BC-005]`, `[BC-006]`, `[BC-009]`, `[BC-011]`, `[BC-012]`, `[TEST-001]`, `[TEST-002]`, `[TEST-003]`, `[TEST-004]`, `[TEST-005]`, `[TEST-008]`, `[SEC-004]`, `[SEC-009]`, `[SEC-010]`, `[SEC-012]`, `[SDD-001]`, `[SDD-002]`, `[SDD-003]`.

## 2. Domain, Architecture & Security Expert Notes

- **`swift-macos-expert` (`openspec/agents/swift-macos-expert.agent.md` v1.2.0)**:
  - `MarkdownLintAndFormat` imports `Foundation` and `Markdown` (`swiftlang/swift-markdown`) to parse CommonMark / GFM AST trees 100% offline (`AR-011`, `SEC-004`).
  - Both `MarkdownLintAndFormatEngine` and `SearchDiffAndBracketEngine` accept an injected `ElapsedTimeProviding` / Swift `Clock` seam (`AR-007`, `AR-013`, `TEST-004`) so deterministic timeout tests (`> 250 ms` for Markdown lint/format, `> 500 ms` for Myers diff per `BC-011`) execute in microseconds without `Task.sleep` wall-clock delays.
- **`ddd-expert` (`02-domain/bounded-context-ownership.md` & `ubiquitous-language-and-policy.md`)**:
  - `MarkdownLintAndFormat` (`Core` subdomain) and `SearchDiffAndBracketEngine` (`Supporting` subdomain) consume immutable `DocumentSnapshot` values (`(DocumentID, BufferRevision)`) and NEVER mutate `DocumentSession` directly (`BC-001`, `BC-004`, `BC-006`).
  - Formatting (`formatDocument` and `formatSection(range:)`) returns an ordered `[TextEdit]` batch tagged with the source `BufferRevision`. `DocumentSession.applyTextEdits(_:expectedRevision:)` applies the batch in a single synchronous `BufferRevision` increment (`BC-004`), throwing `DomainError.staleBufferRevision` if `expectedRevision != session.revision`.
- **`cyber-security-expert` (`02-domain/ubiquitous-language-and-policy.md` & `07-security-privacy/stride-and-gdpr-privacy.md`)**:
  - Complexity & DoS caps (`BC-011`, `SEC-012`):
    - AST depth `> 128`, `snapshot.isDegradedPlainText == true`, `snapshot.isBinaryReadOnly == true`, or elapsed time `> 250 ms` returns `.degradedOrTimedOut(reason:)` (`CWE-400`).
    - Bracket scanner skips lines exceeding `4096` UTF-16 code units (`BC-011`).
    - Myers diff rejects or degrades inputs exceeding `10 MiB` (`10_485_760` UTF-8 bytes) or `500 ms` elapsed deadline (`BC-011`).
  - Markdown URI scheme guard (`BC-012`, `SEC-004`): links or image destinations using `javascript:`, `data:`, `vbscript:`, or `file:` schemes emit `.unsafeLinkScheme` diagnostics so the UI never hands off unsafe URIs to `NSWorkspace`/`UIApplication`.

## 3. 4-Pillar Breakdown & Path Coverage Matrix

| Unit | Path ID | Trait | Summary |
| :--- | :--- | :--- | :--- |
| `MarkdownAstLintAndFormatEngine` | `P1` | `positive` | Parses Markdown via `swift-markdown` AST emitting `MarkdownLintDiagnostic` items (`missingHeadingSpace`, `emptyLinkTarget`, `unbalancedFencedCodeBlock`), produces `[TextEdit]` batches for `formatDocument` and `formatSection` (preserving fenced code blocks), and applies them atomically via `DocumentSession.applyTextEdits` (`[AR-011]`, `[BC-004]`, `[BC-006]`). |
| `MarkdownAstLintAndFormatEngine` | `N1` | `negative` | Stale `BufferRevision` or out-of-bounds `TextRange` passed to `applyTextEdits` or `formatSection` throws `DomainError.staleBufferRevision` or `DomainError.invalidTextRange` without mutating `DocumentSession` (`[BC-003]`, `[BC-004]`). |
| `MarkdownAstLintAndFormatEngine` | `N2` | `security` | Markdown links with `javascript:`/`file:`/`data:` schemes emit `unsafeLinkScheme` diagnostics, and snapshots with AST nesting depth `> 128`, `isDegradedPlainText == true`, `isBinaryReadOnly == true`, or elapsed clock `> 250 ms` return `.degradedOrTimedOut` (`[AR-013]`, `[BC-011]`, `[BC-012]`, `[SEC-004]`, `[SEC-012]`). |
| `BracketBalancingEngine` | `P2` | `positive` | Evaluates nested `()`, `{}`, and `[]` delimiters in `DocumentSnapshot`, returning matched `BracketPairSpan` pairs and identifying the active enclosing/adjacent pair at the cursor (`[AR-004]`, `[AR-012]`, `[TEST-005]`). |
| `BracketBalancingEngine` | `N3` | `negative` | Detects unbalanced/mismatched opening or closing brackets (`(]`, unclosed `{`, stray `)`) as `.unbalanced(offset:symbol:)` (`[AR-012]`, `[TEST-005]`). |
| `BracketBalancingEngine` | `N4` | `security` | Lines exceeding `4096` UTF-16 code units or binary/degraded snapshots return a bounded `.lineLengthExceeded` / degraded result without scanning unbounded lines (`[BC-011]`, `[SEC-012]`). |
| `MyersFileCompareDiffEngine` | `P3` | `positive` | Computes stateless line-level Myers shortest-edit-script `DiffHunk` sequences (`.unchanged`, `.inserted`, `.removed`) between two `DocumentSnapshot` values (`[AR-004]`, `[AR-012]`, `[BC-006]`, `[TEST-005]`). |
| `MyersFileCompareDiffEngine` | `N5` | `negative` | Identical snapshots produce solely `.unchanged` hunks with `hasDifferences == false`, and empty-vs-non-empty snapshots produce single `.inserted` or `.removed` hunks (`[AR-012]`). |
| `MyersFileCompareDiffEngine` | `N6` | `security` | Diff inputs exceeding `10 MiB`, binary read-only snapshots, or runs exceeding the `500 ms` injected clock deadline abort fail-closed with `.degradedOrTimedOut` (`[AR-013]`, `[BC-011]`, `[SEC-012]`). |
