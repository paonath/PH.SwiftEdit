# Design: 26-Rule All-Construct Markdown Linter, Idempotent Quick-Fix and Fix All, Triple Diagnostics UI and Shift+Cmd+M Popover

## Context
`MarkdownLintRuleID` has `5` cases and `lint(snapshot:)` runs a fixed rule set. `SwiftEditWorkbenchModel` stores `lintDiagnostics` and the status bar prints `Lint: <count>` for every tab. `012` added the viewport validator, `LazyVStack` gutter and `MarkdownLineIndex` that this change reuses (`[BC-004]`, `[UI-005]`).

## Goals / Non-Goals
- Goals:
  - Additive profiles with a default that preserves existing behavior (`[BC-004]`).
  - Idempotent revision-pinned fixes in one edit batch (`[BC-006]`, `[BC-011]`).
  - Non-invasive triple surfacing and accessible popover (`[UI-007]`, `[UI-012]`).
- Non-Goals:
  - New parsers, remote lint services, auto-fix of security diagnostics, user-configurable rule sets.

## Architecture Memory & Module Boundaries (AR-###)
- **AR-001**: Rules, scanner, line table, resolver and status live in `SwiftEditCore` (`Foundation` and `swift-markdown` only, `[AR-002]`); underline attributes, gutter badges, popover and `⇧⌘M` live in `SwiftEditUI` (`[AR-003]`).
- **AR-018**: `SwiftEditWorkbenchModel` coordinates via `DocumentID`, `BufferRevision` and `TextRange` and applies fixes only through `DocumentSession.applyTextEdits` (`[AR-008]`, `[BC-006]`).

## Constitutional Alignment & Module Boundaries (AR-### / UI-### / DATA-### / API-###)
- **Single-Reference Lock**: Consulted `01-architecture/dependency-and-layering.md` (`AR-006..010`), `02-domain/bounded-context-ownership.md` (`BC-001..006`), `03-ui-ux/component-state-and-forms.md` (`UI-005..008`), `03-ui-ux/accessibility-and-cwv.md` (`UI-012`), `06-testing-fitness/tdd-and-unit-testing.md` (`TEST-001..004`) and `07-security-privacy/stride-and-gdpr-privacy.md` (`SEC-009..012`) (`[SDD-001]`, `[SDD-002]`, `[SDD-003]`).

## Glossary & Conventions
- `MarkdownLintProfile`: `.legacyBaseline` (default) or `.allConstructs`.
- `MarkdownLintSeverity`: `.error` or `.warning`.
- `ActiveLintStatus`: `.off`, `.paused`, `.active(count:)`.
- `QuickFixOutcome`: `.edit(MarkdownAuthoringEdit)`, `.stale`, `.noFix`.

## Decisions
- **D1 — Profile parameter, no rule class hierarchy**: one pass with line scanner functions; Rule of Three for `ILintRule` is not justified (`KISS`, `[AR-009]`).
- **D2 — Reuse `MarkdownLineIndex`**: fence and line lookups shared with the highlighter avoid a second scan.
- **D3 — Anchored blank-line fixes**: inserts at the lower block start prevent `MD012` loops; two bounded passes give idempotence.
- **D4 — Severity-first cap**: errors fill the `1000` budget before warnings (`CWE-400`).
- **D5 — Suppression in Core**: `ActiveLineLintSuppressionPolicy` is pure so it is unit-testable without AppKit.

## Risks / Trade-offs
- `26` rules may exceed `250 ms` on large files -> single pass, line cap, degraded `Lint: Paused` above `10 MiB`.
- False positives on frontmatter or tight sublists -> mask and root-only `MD032` scenarios.
- Fix interactions -> bounded passes plus idempotence tests.

## Migration Plan
1. Extend lint engine with profiles and rules (tests first).
2. Add line table, frontmatter scanner and cap.
3. Add resolver, status and suppression.
4. Wire UI surfaces and `⇧⌘M`.
5. Run `swift test --parallel`.

## Security Review
- Reviewer: cyber-security-expert
- Date: 2026-11-20
- Verdict: approved
- Open items: none
