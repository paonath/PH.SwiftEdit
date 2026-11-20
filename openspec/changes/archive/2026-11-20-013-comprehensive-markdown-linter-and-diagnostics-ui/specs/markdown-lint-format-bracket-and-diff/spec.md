# Spec Delta: markdown-lint-format-bracket-and-diff

## Purpose
Extends `REQ-001` of `markdown-lint-format-bracket-and-diff` additively so lint accepts an optional profile whose default preserves existing rules, enabling the all-construct catalog without changing prior behavior.

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-001 Offline Markdown AST Linting and Formatting Batch Generation
WHEN evaluating a non-degraded text `DocumentSnapshot`, the Markdown lint and format engine SHALL parse offline via `swift-markdown` to emit `MarkdownLintDiagnostic` values for the selected `MarkdownLintProfile` (default `.legacyBaseline`), including `.nonStandardOutlineMarker`, and compute single-revision format batches [AR-011][BC-003][BC-004][BC-006][TEST-005].

Security-Waiver: additive profile parameter only; existing scenarios and the default rule set stay intact while N7 asserts the unchanged legacy behavior.

#### Scenario: N7 Default Lint Call Keeps the Legacy Rule Set
- **Path**: N7
- **Trait**: negative
- **GIVEN** a snapshot `"#Heading\n[x](javascript:alert(1))"`
- **WHEN** `lint(snapshot:)` runs without a profile
- **THEN** it returns the same diagnostics as before this change and none of the all-construct-only rules

## REMOVED Requirements

## RENAMED Requirements
