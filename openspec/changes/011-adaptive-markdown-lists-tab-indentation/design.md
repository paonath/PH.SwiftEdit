# Design: Linter-Governed Adaptive Markdown List Indentation (Tab / Shift+Tab / Return)

## Context
`MarkdownSmartNewlineEngine` already continues bullets, tasks, ordered items, and blockquotes on `Return`, but `Tab` and `Shift+Tab` fall through to AppKit defaults, nested ordered numbering is lost on outdent, and `a.`/`1.1` prefixes are neither continued nor diagnosed even though CommonMark 0.31.2 treats them as paragraph text (`[BC-004]`, `[UI-009]`).

## Goals / Non-Goals
- Goals:
  - Pure, zero-regex `MarkdownSmartListEngine` in `SwiftEditCore` returning a typed outcome (`edit`, `consumedNoOp`, `notApplicable`) for `Tab`/`Shift+Tab` (`[AR-002]`, `[AR-009]`, `[BC-011]`).
  - Extend `Return` continuation for pseudo-outline markers and two-stage nested empty exit.
  - Add `.nonStandardOutlineMarker` lint detection.
  - Route `insertTab:`/`insertBacktab:` through `SwiftEditWorkbenchModel.applyListIndentation(outdent:)` for one `BufferRevision` per keystroke (`[UI-005]`, `[UI-007]`).
- Non-Goals:
  - Quick-Fix UI and diagnostics surfaces (`TASK-05`), GFM table `Tab` navigation (`TASK-04`).

## Architecture Memory & Module Boundaries (AR-###)
- **AR-001**: The engine and the lint rule live in `SwiftEditCore` (`Foundation` only, `[AR-002]`); only the keystroke routing and caret handling live in `SwiftEditUI` (`[AR-003]`, `[AR-006]`).
- **AR-018**: `SwiftEditWorkbenchModel` coordinates via `DocumentID`, `BufferRevision`, and `TextRange` snapshots and never bypasses `DocumentSession.applyTextEdits` (`[AR-008]`, `[BC-006]`).

## Constitutional Alignment & Module Boundaries (AR-### / UI-### / DATA-### / API-###)
- **Single-Reference Lock**: Consulted `01-architecture/dependency-and-layering.md` (`AR-006..010`), `02-domain/index.md` (`BC-001..012`), `03-ui-ux/component-state-and-forms.md` (`UI-005..008`), `06-testing-fitness/tdd-and-unit-testing.md` (`TEST-001..004`), and `07-security-privacy/stride-and-gdpr-privacy.md` (`SEC-009..012`) (`[SDD-001]`, `[SDD-002]`, `[SDD-003]`).

## Glossario & Convenzioni
- `SmartListOutcome`: enum `.edit(SmartListEdit)`, `.consumedNoOp`, `.notApplicable`.
- `SmartListEdit`: value type holding `edits: [TextEdit]` and `newSelection: TextRange`.
- Parent-Ceiling: rejects nesting when `targetIndent > precedingSiblingIndent + 4`.

## Decisions
- **D1 — Typed outcome instead of optional**: `.consumedNoOp` lets the UI swallow `Tab` on a root item (so it never becomes a code block) while `.notApplicable` lets AppKit insert its default tab (`KISS`, `[BC-004]`).
- **D2 — Extend the existing newline engine, no new class hierarchy**: pseudo-outline continuation and two-stage exit are small additions to `MarkdownSmartNewlineEngine`; sharing line helpers with the list engine avoids duplication (`Rule of Three` not met for a protocol hierarchy, `[AR-009]`).
- **D3 — Edit through the model**: the Coordinator calls `applyListIndentation`, reusing `DocumentSession.applyTextEdits` for one revision and the existing programmatic-update path (`pendingProgrammaticCaret`).

## Risks / Trade-offs
- Programmatic text reset in `NSTextView` clears its native undo stack -> keep one `BufferRevision` per keystroke and, where headless `NSUndoManager` testing is feasible, apply via `shouldChangeText`/`didChangeText`; otherwise document the limitation and ask before weakening it.
- Existing `P2` smart-newline expectations for flat lists -> unchanged; two-stage exit only applies to nested ordered items (indent > 0).

## Migration Plan
1. Add `MarkdownSmartListEngine.swift` with tests.
2. Extend `MarkdownSmartNewlineEngine` and the lint rule.
3. Add `applyListIndentation(outdent:)` and the Coordinator hooks.
4. Run `swift test --parallel`.

## Security Review
- Reviewer: cyber-security-expert
- Date: 2026-11-20
- Verdict: approved
- Open items: none
