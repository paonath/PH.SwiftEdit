# Spec Delta: editor-ux-highlighting-sidebar-pin-tabs-and-about

## Purpose
Extends `REQ-002` of `editor-ux-highlighting-sidebar-pin-tabs-and-about` additively so `Return` also continues manual pseudo-outline markers (`a.`, `1.1`) and exits empty nested ordered items in two stages while preserving every existing continuation and security scenario.

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-002 Markdown Smart Enter List and Blockquote Continuation
WHEN the user presses Enter in a Markdown or untitled buffer outside fenced code, the smart newline engine SHALL continue bullets, tasks, numbered items, pseudo-outline markers (`a.`, `1.1`), and blockquotes, and clear empty markers, exiting nested empty items in two stages [BC-004][BC-006][BC-011][DATA-003][SEC-012].

Security-Waiver: additive extension of REQ-002 only; scenarios P2, N3, and N4 stay intact while P3 adds pseudo-outline continuation and the two-stage nested exit.

#### Scenario: P3 Pseudo-Outline Continuation and Two-Stage Nested Empty Exit
- **Path**: P3
- **Trait**: positive
- **GIVEN** Markdown buffers `"    a. alpha"`, `"    1.1 uno"`, and a nested empty item `"2. due\n    1. "`
- **WHEN** `MarkdownSmartNewlineEngine.evaluateNewline` runs at the end of each
- **THEN** it proposes `"\n    b. "` and `"\n    1.2 "`, and on the nested empty item it first outdents it to `"3. "` and on a second Enter clears the marker

## REMOVED Requirements

## RENAMED Requirements
