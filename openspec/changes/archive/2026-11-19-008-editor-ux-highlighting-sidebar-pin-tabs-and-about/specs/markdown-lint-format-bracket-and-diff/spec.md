# Spec Delta: Nested Bracket Depth Metadata in SearchDiffAndBracketEngine

## Purpose
Extends `REQ-003` of `markdown-lint-format-bracket-and-diff` additively so every matched `BracketPairSpan` carries its 0-based `nestingDepth` and `BracketBalanceResult` exposes `enclosingPairs` for visual nested bracket highlighting while preserving the `4096` UTF-16 line-length and binary guards.

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-003 Deterministic Bracket Balancing and Line-Length Guard
WHEN evaluating `()`, `{}`, and `[]` delimiters in a `DocumentSnapshot`, the bracket matching engine SHALL return matched `BracketPairSpan` pairs with 0-based `nestingDepth`, identify `activePair` and `enclosingPairs` at the caret offset, report unbalanced brackets, and refuse lines exceeding `4096` UTF-16 code units [AR-004][AR-012][BC-011][SEC-012][TEST-005].

Security-Waiver: additive modification only; existing scenarios P2, N3, and N4 and all AR-004, AR-012, BC-011, SEC-012, and TEST-005 invariants are preserved intact while adding nestingDepth and enclosingPairs metadata.

#### Scenario: P4 Nested Depth Indexing Across Braces Brackets and Parentheses
- **Path**: P4
- **Trait**: positive
- **GIVEN** a `DocumentSnapshot` containing `"scrivo{ho le graffe, le quadre[dentro le quadre ho le tonde(qua) e (pure qua)]}"` with caret inside `"(qua)"`
- **WHEN** `SearchDiffAndBracketEngine.evaluateBrackets` inspects the snapshot
- **THEN** `{}` has `nestingDepth == 0`, `[]` has `nestingDepth == 1`, both `()` pairs have `nestingDepth == 2`, and `enclosingPairs` contains the outer-to-inner chain `[{}, [], ()]`

#### Scenario: N7 Unbalanced Deeply Nested Delimiters Retain Depth of Valid Pairs Without Overflow
- **Path**: N7
- **Trait**: negative
- **GIVEN** a `DocumentSnapshot` containing `"{[ ( ] }"` with a stray unmatched `"("`
- **WHEN** `SearchDiffAndBracketEngine.evaluateBrackets` inspects the snapshot
- **THEN** unmatched delimiters are reported in `unbalancedBrackets` with exact UTF-16 offsets and matched pairs retain non-negative `nestingDepth`

## REMOVED Requirements

## RENAMED Requirements
