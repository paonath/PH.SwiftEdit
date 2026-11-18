# Design: Implement MarkdownLintAndFormat (swift-markdown AST) and SearchDiffAndBracketEngine (() {} [] & Myers Diff)

## Context
With `DocumentCore` (`001-swifteditcore-document-and-binary-guard`, `TASK-02`) providing immutable `DocumentSnapshot` projections (`(DocumentID, BufferRevision)`), `TASK-03` implements the two analytical engines of `SwiftEditCore`:
1. **`MarkdownLintAndFormat`** (`Core` subdomain): 100% offline CommonMark / GitHub Flavored Markdown AST linting (`swiftlang/swift-markdown`) and deterministic `Format Document` / `Format Section` `TextEdit` generation (`[AR-011]`, `[BC-004]`).
2. **`SearchDiffAndBracketEngine`** (`Supporting` subdomain): live `(){}[]` bracket balancing (`BracketPairSpan`) and stateless two-snapshot Myers File Compare diffing (`DiffHunk`) (`[AR-012]`, `[BC-006]`).

## Goals / Non-Goals
- Goals:
  - Keep both engines 100% pure, `Sendable`, stateless, and free of `AppKit`/`UIKit`/`SwiftUI`/`WebKit` imports (`[AR-002]`, `[AR-004]`, `[BC-002]`).
  - Enforce cooperative deadline and complexity guardrails (`<= 250 ms` / `<= 128` AST depth for Markdown lint/format; `<= 4096` UTF-16 code units per line for bracket scanning; `<= 10 MiB` / `<= 500 ms` for Myers diff) via the `ElapsedTimeProviding` seam (`[AR-007]`, `[AR-013]`, `[BC-011]`, `[TEST-004]`).
  - Provide single-revision atomic batch mutation `DocumentSession.applyTextEdits(_:expectedRevision:)` (`[BC-003]`, `[BC-004]`).
- Non-Goals:
  - `WorkspaceAndTabSession`, Notepad++ tab pinning, and `SessionRecovery` GC (`TASK-04`).
  - `SwiftEditUI` TextKit 2 visual highlights and Side-by-Side diff views (`TASK-05`).

## Architecture Memory & Module Boundaries (AR-###)
- **AR-011**: `MarkdownLintAndFormatEngine` parses CommonMark and GitHub Flavored Markdown AST nodes exclusively offline via `swiftlang/swift-markdown` (`import Markdown`) inside `SwiftEditCore`.
- **AR-012**: `SearchDiffAndBracketEngine` implements `(){}[]` bracket balancing and Myers shortest-edit-script line diffing as pure deterministic functions over `DocumentSnapshot`.
- **AR-013**: Both engines accept an injected `ElapsedTimeProviding` clock seam (`ContinuousClockElapsedTimer` in production, `DeterministicClockFake` in unit tests) to enforce `250 ms` and `500 ms` deadlines deterministically.
- **Single-Reference Lock**: Loaded `openspec/Constitution.md` alongside `01-architecture/module-topology.md`, `01-architecture/dependency-and-layering.md`, `01-architecture/host-and-sagas.md`, `02-domain/bounded-context-ownership.md`, `02-domain/negative-ownership-and-refs.md`, `02-domain/ubiquitous-language-and-policy.md`, `06-testing-fitness/tdd-and-unit-testing.md`, `06-testing-fitness/architecture-fitness-and-quality.md`, `07-security-privacy/authn-authz-and-boundaries.md`, `07-security-privacy/stride-and-gdpr-privacy.md`, and `08-sdd-governance/artifact-traceability.md`.

## Bounded Context Classification & Ubiquitous Language Glossary (`BC-002`, `BC-009`)

| Bounded Context / Type | Classification / Kind | Normative Definition (`BC-009`) |
| :--- | :--- | :--- |
| `MarkdownLintAndFormat` | `Core` Subdomain | Authoritative context owning offline `swift-markdown` AST linting and `Format Section` / `Format Document` `TextEdit` computation. |
| `SearchDiffAndBracketEngine` | `Supporting` Subdomain | Stateless analytical context owning `(){}[]` bracket matching and two-snapshot Myers File Compare diffing. |
| `ElapsedTimeProviding` | Clock Seam Protocol (`Sendable`) | Narrow clock port returning elapsed milliseconds (`elapsedMilliseconds() -> Int`) for cooperative `250 ms` / `500 ms` deadline enforcement (`[AR-007]`, `[AR-013]`, `[TEST-004]`). |
| `EngineEvaluationOutcome<T>` | Value Object (`enum`, `Sendable`) | Outcome wrapper: `.completed(T)` or `.degradedOrTimedOut(DegradedEvaluationReason)` (`[BC-011]`). |
| `DegradedEvaluationReason` | Value Object (`enum`, `Sendable`) | Typed degradation cause: `.binarySnapshot`, `.degradedPlainTextSnapshot`, `.astDepthExceeded(maxDepth: Int)`, `.lineLengthExceeded(line: Int, utf16Length: Int)`, `.inputTooLarge(byteCount: Int)`, `.deadlineExceeded(limitMilliseconds: Int)`. |
| `MarkdownLintRuleID` | Value Object (`enum`, `Sendable`) | Canonical lint rules: `.missingHeadingSpace`, `.emptyLinkTarget`, `.unsafeLinkScheme`, `.unbalancedFencedCodeBlock`. |
| `MarkdownLintDiagnostic` | Value Object (`struct`, `Sendable`) | Immutable AST lint finding `(rule: MarkdownLintRuleID, line: Int, message: String)`. |
| `TextEdit` | Value Object (`struct`, `Sendable`) | Single UTF-16 replacement `(range: TextRange, replacement: String)` produced by `Format Document` or `Format Section`. |
| `BracketPairSpan` | Value Object (`struct`, `Sendable`) | Matched opening and closing delimiter offsets `(openOffset: Int, closeOffset: Int, openSymbol: Character, closeSymbol: Character)`. |
| `UnbalancedBracket` | Value Object (`struct`, `Sendable`) | Unmatched delimiter diagnostic `(offset: Int, symbol: Character)`. |
| `BracketBalanceResult` | Value Object (`struct`, `Sendable`) | Aggregate bracket scan output `(documentID: DocumentID, revision: BufferRevision, matchedPairs: [BracketPairSpan], unbalancedBrackets: [UnbalancedBracket], activePair: BracketPairSpan?)`. |
| `DiffHunkKind` | Value Object (`enum`, `Sendable`) | Line diff classification: `.unchanged`, `.inserted`, `.removed`. |
| `DiffHunk` | Value Object (`struct`, `Sendable`) | Single line-level diff entry `(kind: DiffHunkKind, lineText: String, lhsLineNumber: Int?, rhsLineNumber: Int?)`. |
| `FileCompareDiffResult` | Value Object (`struct`, `Sendable`) | Two-snapshot Myers diff output `(lhsID: DocumentID, lhsRevision: BufferRevision, rhsID: DocumentID, rhsRevision: BufferRevision, hunks: [DiffHunk], hasDifferences: Bool)`. |

## Decisions
- **Decision 1 — Hybrid `swift-markdown` AST Walker + Lexical Line Canonicalizer (`KISS-First`)**:
  - *Rationale*: `swiftlang/swift-markdown` (`Document(parsing:)`) parses the CommonMark/GFM tree to measure exact AST nesting depth (`<= 128`) and inspect `Link` / `Image` AST nodes (`emptyLinkTarget`, `unsafeLinkScheme` for non-`https`/`http`/`mailto` schemes). Simultaneously, line-aware structural checks detect `#Heading` missing spaces (`missingHeadingSpace`) and unclosed ` ``` ` fences (`unbalancedFencedCodeBlock`), and generate minimal per-line `TextEdit` replacements for `formatDocument` / `formatSection` (normalizing `#Heading` -> `# Heading`, `*  item` -> `- item`, and stripping trailing spaces outside fenced code blocks).
- **Decision 2 — Single-Revision Atomic Batch Application (`DocumentSession.applyTextEdits`)**:
  - *Rationale*: Per `[BC-004]`, a formatting pass must advance `BufferRevision` at most once and never leave a half-formatted buffer if any `TextEdit` is invalid or stale. `applyTextEdits` verifies `expectedRevision == revision`, checks non-overlapping UTF-16 ranges, applies edits from highest to lowest `location` on a copy, and increments `revision` once (emitting `DomainEvent.formatBatchApplied(id, revision, count)`).
- **Decision 3 — Stateless Myers Shortest-Edit-Script (`O(ND)`) Line Diff**:
  - *Rationale*: Standard Eugene Myers `O(ND)` forward/backtrack algorithm over line slices (`\n`-split) computes minimal `.unchanged`, `.removed`, and `.inserted` hunks while checking `clock.elapsedMilliseconds() <= 500` on each `d`-step (`[AR-012]`, `[AR-013]`, `[BC-011]`).

## Risks / Trade-offs
- **Formatting Corrupting Fenced Code Blocks** -> Mitigated by tracking fenced code block state (` ``` ` / `~~~`) so indentation, list markers, and `#` comments inside code fences are never modified by `formatDocument` or `formatSection`.
- **Pathological Diff Inputs (`O(N^2)` Worst Case)** -> Mitigated by the `10 MiB` pre-check and per-iteration `500 ms` `ElapsedTimeProviding` deadline returning `.degradedOrTimedOut(.deadlineExceeded(limitMilliseconds: 500))`.

## Migration Plan
1. Create `Sources/SwiftEditCore/MarkdownLintAndFormat/` and `Sources/SwiftEditCore/SearchDiffAndBracketEngine/` directories in `1.0 [SETUP]`.
2. Execute TDD quads (`[RED] -> [GREEN] -> [REFACTOR] -> [DOC]`) across the 3 units (`MarkdownAstLintAndFormatEngine`, `BracketBalancingEngine`, `MyersFileCompareDiffEngine`).
3. Verify `swift test --parallel -Xswiftc -warnings-as-errors` passes with `>= 85%` `SwiftEditCore` line coverage.

## Security Review
- Reviewer: cyber-security-expert
- Date: 2026-11-17
- Verdict: approved
- Status: approved
- Open items: none
