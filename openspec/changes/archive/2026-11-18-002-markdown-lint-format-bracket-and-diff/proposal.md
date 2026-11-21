# Proposal: Implement MarkdownLintAndFormat (swift-markdown AST) and SearchDiffAndBracketEngine (() {} [] & Myers Diff)

## Why
With `DocumentCore` (`001-swifteditcore-document-and-binary-guard`, `TASK-02`) archived, `PH.SwiftEdit` needs the two pure value-semantic engines defined in `TASK-03` (`reasoning/001_project-constitution/README.ai.md`): **`MarkdownLintAndFormat`** (`Core` subdomain powered by `swiftlang/swift-markdown` AST) and **`SearchDiffAndBracketEngine`** (`Supporting` subdomain providing live `(){}[]` bracket balancing and two-snapshot Myers File Compare diffing). Both engines consume immutable `DocumentSnapshot` projections (`(DocumentID, BufferRevision)`) off `@MainActor` under cooperative deadlines (`250 ms` for Markdown lint/format, `500 ms` / `10 MiB` for Myers diff, `4096` UTF-16 code units per line for bracket scanning, `128` AST nesting levels) and return immutable `Sendable` results (`MarkdownLintDiagnostic`, `TextEdit`, `BracketPairSpan`, `DiffHunk`) ready for `SwiftEditUI` (`TASK-05`).

## What Changes
- Implement `Sources/SwiftEditCore/MarkdownLintAndFormat/`:
  - `MarkdownLintDiagnostic` (`missingHeadingSpace`, `emptyLinkTarget`, `unsafeLinkScheme`, `excessiveHeadingDepth`, `unbalancedFencedCodeBlock`), `TextEdit`, and `EngineEvaluationOutcome<T>` (`.completed(T)` vs `.degradedOrTimedOut(DegradedEvaluationReason)`) (`[AR-004]`, `[AR-011]`, `[BC-011]`, `[BC-012]`).
  - `MarkdownLintAndFormatEngine` using `swiftlang/swift-markdown` (`Document`, `MarkupWalker`) 100% offline to inspect AST depth (`<= 128`), validate link schemes (`https`, `http`, `mailto`, `#`, or relative paths), emit lint diagnostics, and compute `formatDocument` / `formatSection` `[TextEdit]` batches preserving fenced code blocks while enforcing a `250 ms` `ElapsedTimeProviding` deadline (`[AR-011]`, `[AR-013]`, `[BC-004]`, `[BC-006]`, `[BC-011]`).
- Extend `DocumentSession` in `Sources/SwiftEditCore/DocumentCore/` with `applyTextEdits(_:expectedRevision:)` to apply formatting batches atomically in a single `BufferRevision` increment while rejecting stale revisions (`DomainError.staleBufferRevision`) or binary read-only buffers (`DomainError.binaryFileSaveForbidden`) (`[BC-003]`, `[BC-004]`, `[BC-012]`).
- Implement `Sources/SwiftEditCore/SearchDiffAndBracketEngine/`:
  - `BracketPairSpan`, `BracketMatchStatus` (`.matched(BracketPairSpan)` vs `.unbalanced(offset: Int, symbol: Character)`), and `BracketBalanceResult` scanning `()`, `{}`, and `[]` while skipping or flagging lines exceeding `4096` UTF-16 code units (`[AR-012]`, `[BC-011]`).
  - `DiffHunk` (`.unchanged`, `.inserted`, `.removed`), `FileCompareDiffResult`, and `SearchDiffAndBracketEngine.computeMyersDiff(lhs:rhs:clock:)` enforcing the `<= 10 MiB` size ceiling and `<= 500 ms` deadline (`[AR-012]`, `[AR-013]`, `[BC-006]`, `[BC-011]`).

## Capabilities
- New Capabilities: `markdown-lint-format-bracket-and-diff`
- Modified Capabilities: None

## Domain Carrier & Decision Ownership (BC-###)
- **BC-001**: `MarkdownLintAndFormat` (`Core` subdomain) owns offline `swift-markdown` AST linting and `Format Section` / `Format Document` `TextEdit` generation; `SearchDiffAndBracketEngine` (`Supporting` subdomain) owns stateless `(){}[]` bracket matching and two-file Myers diff calculation (`[BC-002]`, `[BC-004]`, `[BC-006]`).
- **Owned Decisions**: AST lint diagnostic classification, Markdown formatting `TextEdit` calculation, `128`-level AST depth guard, `250 ms` lint/format timeout, `4096` UTF-16 line-length bracket cap, and `10 MiB` / `500 ms` Myers diff execution (`[BC-011]`, `[BC-012]`).
- **Forbidden Responsibilities**: Neither `MarkdownLintAndFormat` nor `SearchDiffAndBracketEngine` may mutate `DocumentSession` directly (`[BC-003]`, `[BC-004]`), perform network I/O or load remote Markdown assets (`[AR-011]`, `[SEC-004]`), or implement Git/SCM repository parsing, blame gutters, or 3-way merge tools (`[BC-005]`).
- **External Decision References**: Both contexts reference documents exclusively via immutable `DocumentSnapshot` (`(DocumentID, BufferRevision)`) values (`[BC-006]`).

## Impact
- **Source Modules**: Adds `Sources/SwiftEditCore/MarkdownLintAndFormat/**` and `Sources/SwiftEditCore/SearchDiffAndBracketEngine/**`, and adds `applyTextEdits` + `DomainError.staleBufferRevision` in `Sources/SwiftEditCore/DocumentCore/`.
- **Test Suites**: Adds `MarkdownLintAndFormatTests.swift`, `BracketBalancingEngineTests.swift`, and `MyersFileCompareDiffTests.swift` under `Tests/SwiftEditTests/`.

## Security Impact
- Prevents CPU/stack exhaustion DoS (`CWE-400`, `[BC-011]`, `[SEC-012]`) via hard limits on AST nesting (`<= 128`), bracket scan line length (`<= 4096` UTF-16 code units), Myers diff input size (`<= 10 MiB`), and injected clock deadlines (`250 ms` / `500 ms`).
- Detects unsafe Markdown URI schemes (`javascript:`, `vbscript:`, `data:`, `file:`) during linting (`[BC-012]`, `[SEC-004]`).
- Rejects binary read-only snapshots (`isBinaryReadOnly == true`) and stale `BufferRevision` edits fail-closed (`[BC-004]`, `[SEC-012]`).

## Metadata
- Owner: PH.SwiftEdit Team
- Domain: Swift 6 Markdown AST Engine, Bracket Matcher & Myers Diff
- Reviewer: swift-macos-expert, ddd-expert, cyber-security-expert
- Branch: feature/FirstStub
- Manual-Steps: none
- Modifies-Specs: none
- Constitutional-Rules: [AR-002, AR-004, AR-007, AR-008, AR-011, AR-012, AR-013, BC-001, BC-002, BC-003, BC-004, BC-005, BC-006, BC-009, BC-011, BC-012, TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, TEST-008, SEC-004, SEC-009, SEC-010, SEC-012, SDD-001, SDD-002, SDD-003]
- Amends-Constitution: none

## Prerequisites
- Completed `001-swifteditcore-document-and-binary-guard` (`TASK-02`) and ratified `openspec/Constitution.md` (`v1.2.0`).
