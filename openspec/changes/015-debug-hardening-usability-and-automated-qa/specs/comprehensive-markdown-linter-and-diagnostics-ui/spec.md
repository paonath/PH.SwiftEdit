# Spec Delta: comprehensive-markdown-linter-and-diagnostics-ui

## Purpose
Moves full AST linting off `@MainActor` with debounced `BufferRevision` cancellation while preserving a bounded linear URI and image safety fast-path so P99 typing stays at or below `16 ms` up to `20,000` lines without silencing `.unsafeLinkScheme` or `.unsafeImagePath` XSS detection (`PERF-006`).

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-001 All-Construct Rule Catalog With Frontmatter Immunity and Bounded Output
WHEN `lint` runs with `.allConstructs` on a non-degraded Markdown snapshot or during live editing, the engine and workbench SHALL run full AST parsing off `@MainActor` debounced by `(DocumentID, BufferRevision)`, execute a bounded security URI/image pass preserving `.unsafeLinkScheme` and `.unsafeImagePath` errors even on `5kL`–`20kL` files, and keep keystrokes at or below `16 ms` P99 [BC-004][SEC-012][UI-012].

Security-Waiver: fixes `PERF-006` where main-thread `swift-markdown` timeouts (`250 ms` checked post-parse) froze UI up to `964 ms` and silently dropped `.unsafeLinkScheme`/`.unsafeImagePath` (`lint=0`), preserving `P1`, `N1`, and `N2` while ensuring security rules remain active on large non-degraded docs.

#### Scenario: P5 Large Non-Degraded Document Async Lint Sustains 16ms Typing While Detecting XSS Links
- **Path**: P5
- **Trait**: positive
- **GIVEN** non-degraded `5,000`-line and `20,000`-line Markdown snapshots containing `"[xss](javascript:alert(1))"` and `"![traversal](../../etc/passwd)"`
- **WHEN** `handleEditorTextChanged` executes rapid edits followed by async debounced AST linting and bounded security scanning
- **THEN** P99 synchronous typing latency stays `<= 16 ms` AND reported diagnostics include `.unsafeLinkScheme` and `.unsafeImagePath` errors (`lint > 0`, never `0` silently)

#### Scenario: N7 Stale Async Lint Task Discards Outdated Diagnostics After Newer BufferRevision
- **Path**: N7
- **Trait**: security
- **GIVEN** an in-flight background lint computation started at `BufferRevision(10)` containing `"[xss](javascript:alert(1))"` and superseded by user deletion at `BufferRevision(11)`
- **WHEN** the background worker for `BufferRevision(10)` completes after `BufferRevision(11)` commits
- **THEN** the stale completion cancels or drops without overwriting `BufferRevision(11)` diagnostics or triggering false `Quick-Fix` indices

### Requirement: REQ-003 Lint Status Classification and Active-Line Suppression
WHEN classifying document lint state or filtering active-line diagnostics, the workbench lint policy SHALL report Off for non-Markdown tabs, Paused for degraded buffers, Active retaining security error counts during background recomputation (`ActiveLintStatus`), and hide only non-security caret-line warnings via `ActiveLineLintSuppressionPolicy` [BC-004][DATA-003].

Security-Waiver: prevents status-bar `Lint: 0` flickering during async AST debouncing (`PERF-006`) while retaining `P3` and `N5` invariants intact.

#### Scenario: P6 Debounced Background AST Lint Retains Active Security Error Count Until Revision Settles
- **Path**: P6
- **Trait**: positive
- **GIVEN** a Markdown tab containing an active `.unsafeLinkScheme` diagnostic while async `26`-rule AST linting is pending for the new revision
- **WHEN** `ActiveLintStatus.classify` runs before the debounced AST worker completes
- **THEN** status remains `.active(count >= 1)` reflecting security fast-path errors rather than flashing `.active(count: 0)`

## REMOVED Requirements

## RENAMED Requirements
