# Spec Delta: document-core-and-spm-scaffold

## Purpose
Fixes `DocumentSession.activeSeparator` on single-line Classic Mac `CR` documents so `Cmd+D` never leaks raw `\r` bytes into the normalized in-memory LF buffer while preserving exact `LineEnding.cr` serialization on save (`BUG-016`), and removes per-keystroke full-buffer `Array(text.utf16)` copies (`PERF-007`).

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-004 Deterministic Command-D Line and Selection Duplication on DocumentSession
WHEN `duplicateLineOrSelection` or `applyEdit` executes on a mutable `DocumentSession`, the document core engine SHALL normalize in-memory insertions to `"\n"` regardless of raw `\r` separators on single-line `CR`-only documents, preserve `LineEnding.cr` serialization on save, increment `BufferRevision`, and emit an immutable `DomainEvent` [AR-004][AR-008][AR-012][BC-003][BC-004][BC-006].

Security-Waiver: fixes `BUG-016` raw `\r` leakage on single-line CR `Cmd+D` inside normalized buffers without modifying binary quarantine (`N6`) or out-of-bounds range rejection (`N5`).

#### Scenario: P4 Single-Line CR-Only Document Cmd+D Preserves Clean Normalized Newlines and CR Save
- **Path**: P4
- **Trait**: positive
- **GIVEN** a single-line Classic Mac `CR` file decoded into `DocumentSession` with `LineEnding.cr` and normalized text `"alpha"` (zero `\r` inside buffer)
- **WHEN** `duplicateLineOrSelection` (`Cmd+D`) duplicates line `1` and `DocumentCodec.encode` serializes the session back to disk
- **THEN** the in-memory `snapshot.text` becomes `"alpha\nalpha"` with zero raw `\r` characters (`hasRawCR == false`), `BufferRevision` increments, and encoded save bytes equal `"alpha\ralpha"`

#### Scenario: N7 Mixed Raw Carriage Return Injection Is Normalized Safely Without Corrupting Line Counts
- **Path**: N7
- **Trait**: negative
- **GIVEN** a single-line `LineEnding.cr` session receiving a programmatic edit containing `\r\n` or `\r`
- **WHEN** `DocumentSession.applyEdit` validates and applies the edit and `CursorMetricsCalculator` computes metrics
- **THEN** in-memory storage normalizes separators deterministically without dangling raw `\r` artifacts and cursor line metrics count every line accurately

## REMOVED Requirements

## RENAMED Requirements
