# Spec Delta: markdown-lint-format-bracket-and-diff

## Purpose
Extends `REQ-001` of `markdown-lint-format-bracket-and-diff` additively with the `.nonStandardOutlineMarker` diagnostic that flags pseudo-outline list prefixes CommonMark treats as plain paragraph text, preserving all existing lint and format behavior.

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-001 Offline Markdown AST Linting and Formatting Batch Generation
WHEN evaluating a non-degraded text `DocumentSnapshot`, the Markdown lint and format engine SHALL parse offline via `swift-markdown` to emit `MarkdownLintDiagnostic` values, including `.nonStandardOutlineMarker` for `a.`/`1.1` prefixes outside fences, and compute single-revision format batches [AR-011][BC-003][BC-004][BC-006][TEST-005].

Security-Waiver: additive extension of REQ-001 only; scenarios P1 and N1 stay intact while N3 adds the nonStandardOutlineMarker diagnostic without changing existing rules.

#### Scenario: N3 Non-Standard Outline Markers Are Flagged Outside Fences Only
- **Path**: N3
- **Trait**: negative
- **GIVEN** a snapshot `"1. ok\n    a. alpha\n    1.1 beta\n```\n    b. code\n```"`
- **WHEN** `lint(snapshot:)` runs
- **THEN** it reports `.nonStandardOutlineMarker` on lines `2` and `3` only, and reports none for the valid `1.` item or the fenced `b.` line

## REMOVED Requirements

## RENAMED Requirements
