# Spec Delta: markdown-lint-format-bracket-and-diff

## Purpose
Caches bracket-pair topology per `(DocumentID, BufferRevision)` and eliminates full-buffer allocations on caret moves so `10,000`-line navigation meets `<= 16 ms` (`PERF-007`), and preserves distinct `.modified` LHS/RHS highlighting in `SideBySideDiffRow` (`BUG-020`).

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-003 Deterministic Bracket Balancing and Line-Length Guard
WHEN evaluating delimiters or moving the caret, the bracket matching engine SHALL cache `SearchDiffAndBracketEngine` bracket topology by `(DocumentID, BufferRevision)`, resolve `activePair` and `enclosingPairs` via binary lookup within `16 ms` at `10,000` lines, and refuse lines over `4096` UTF-16 units [AR-004][AR-012][BC-011][SEC-012][TEST-005][UI-012].

Security-Waiver: adds `(DocumentID, BufferRevision)` bracket caching eliminating `70–78 ms` caret lags (`PERF-007`) while preserving `P2`, `N3`, `N4` (`> 4096` UTF-16 guard), `P4`, and `N7` verbatim.

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

Security-Waiver: fixes `BUG-020` where `alignSideBySideRows` collapsed paired `.removed + .inserted` hunks into `.inserted` losing red LHS highlights, while keeping `P3`, `N5`, and `N6` `10 MiB`/`500 ms` DoS caps unchanged.

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

## REMOVED Requirements

## RENAMED Requirements
