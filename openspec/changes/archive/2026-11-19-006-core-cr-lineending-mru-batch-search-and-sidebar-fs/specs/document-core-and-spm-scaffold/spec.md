# Spec Delta: Document Core Classic Mac CR Line-Ending Preservation

## Purpose
Extends the `DocumentCore` lossless line-ending contract from `LF` and `CRLF` to the three-way set `LF`, `CRLF`, and Classic Mac `CR`, evaluating `\r\n` before bare `\r` so no document is misclassified or rewritten on save.

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-002 Lossless Encoding BOM and Line-Ending Round-Trip with Size Gates
WHEN loading or saving a text document through `FileSystemProviding`, the document codec and loader SHALL preserve `UTF-8`, `UTF-8 BOM`, `UTF-16LE BOM`, and `UTF-16BE BOM` encodings alongside `LF`, `CRLF`, and Classic Mac `CR` line endings, evaluating `\r\n` before bare `\r`, while activating degraded plain-text mode above `10 MiB` and throwing `DomainError.fileTooLarge` above `64 MiB` [BC-007][BC-011][BC-012][DATA-002][DATA-004][TEST-005].

Security-Waiver: additive change only; the existing P2 and N2 scenarios, the size gates, and every BC-, DATA-, and TEST- citation are preserved unchanged, and the new CR path adds a negative scenario that protects byte fidelity.

#### Scenario: P1 Three-Way LF CRLF and CR Detection with Byte-Exact Round-Trip
- **Path**: P1
- **Trait**: positive
- **GIVEN** three UTF-8 files in `InMemoryFileSystemFake` whose lines are separated by `\n`, `\r\n`, and `\r` respectively
- **WHEN** `DocumentLoader` loads each file, applies one text edit, and saves it atomically
- **THEN** the sessions report `LineEnding.lf`, `LineEnding.crlf`, and `LineEnding.cr`, and each saved byte buffer uses only its own separator without introducing either of the other two

#### Scenario: N1 CRLF Is Never Misclassified as CR and Mixed Endings Resolve Deterministically
- **Path**: N1
- **Trait**: negative
- **GIVEN** the texts `"x\r\ny\r\nz"` and `"a\nb\r\nc\rd"`
- **WHEN** `LineEnding.detect(in:)` and `LineEnding.normalizeToLF(_:)` evaluate them using unicode-scalar scanning
- **THEN** both texts are classified `LineEnding.crlf` rather than `LineEnding.cr`, and normalization yields `"x\ny\nz"` and `"a\nb\nc\nd"` without duplicated blank lines

## REMOVED Requirements
<!-- When removing a requirement, provide ### Requirement: <Title> and **Reason**: <justification> -->

## RENAMED Requirements
<!-- When renaming a requirement, provide bullet pairs:
     - FROM: `### Requirement: <Old Title>`
     - TO: `### Requirement: <New Title>` -->
