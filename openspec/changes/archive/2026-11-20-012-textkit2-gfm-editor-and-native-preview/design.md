# Design: Two-Speed GFM TextKit 2 Editor, Markdown CommandMenu, GFM Table Tab and Cmd+P Zero-WebKit Native Preview

## Context
`SwiftEditRootView.swift` (about `2400` lines) hosts the `NSTextView` coordinator, eager gutter and session recovery calls. `MarkdownSmartListEngine` (change `011`) already handles list `Tab`, and `SwiftEditCommands` (change `010`) binds `Cmd+P` to `showMarkdownPreview` default `false`. There is no GFM highlighting, authoring menu, table navigation, or preview (`[BC-004]`, `[UI-005]`).

## Goals / Non-Goals
- Goals:
  - Pure `SwiftEditCore` engines returning typed outcomes for highlighting, authoring, table edits, projection and resource/link admission (`[AR-002]`, `[AR-009]`, `[BC-011]`).
  - Hot path `<= 2 ms`, `<= 16 ms` P99 typing; preview cost zero while hidden (`[UI-012]`).
  - Offline, inert, confined preview (`[SEC-002]`, `[SEC-003]`, `[SEC-004]`).
- Non-Goals:
  - 26-rule linter, diagnostics popover and Quick-Fix (`TASK-05`); remote images; WebKit; SVG.

## Architecture Memory & Module Boundaries (AR-###)
- **AR-001**: All engines live in `SwiftEditCore` (`Foundation` and `swift-markdown` only, `[AR-002]`); views, `NSTextLayoutManager.renderingAttributesValidator`, `ImageIO` decoding and `CommandMenu` live in `SwiftEditUI` (`[AR-003]`, `[AR-006]`).
- **AR-018**: `SwiftEditWorkbenchModel` coordinates via `DocumentID`, `BufferRevision` and `TextRange`, always editing through `DocumentSession.applyTextEdits` (`[AR-008]`, `[BC-006]`).

## Constitutional Alignment & Module Boundaries (AR-### / UI-### / DATA-### / API-###)
- **Single-Reference Lock**: Consulted `01-architecture/dependency-and-layering.md` (`AR-006..010`), `02-domain/bounded-context-ownership.md` (`BC-001..006`), `03-ui-ux/component-state-and-forms.md` (`UI-005..008`), `03-ui-ux/accessibility-and-cwv.md` (`UI-012`), `06-testing-fitness/tdd-and-unit-testing.md` (`TEST-001..004`) and `07-security-privacy/authn-authz-and-boundaries.md` (`SEC-002..004`) (`[SDD-001]`, `[SDD-002]`, `[SDD-003]`).

## Glossary & Conventions
- `MarkdownSyntaxSpan`: construct kind plus UTF-16 range, no color data.
- `TableEditOutcome`: `.edit(TextEditBatch)`, `.notApplicable`.
- `GFMPreviewDocument`: ordered blocks each holding `sourceLine`.
- `ImageAdmission`: `.admitted(url)`, `.blocked(reason)`.

## Decisions
- **D1 — Spans without colors in Core**: Core returns construct kinds; UI maps them to palette tokens, keeping Core free of `AppKit` and prose at `21:1` (`KISS`, `[AR-002]`, `[UI-002]`).
- **D2 — Viewport-only hot path, debounced cold path**: validator scans visible fragments with an `O(log F)` fence index; AST and projection run at `180 ms` off the main actor only when preview is on (`[UI-012]`).
- **D3 — One file per engine, no protocol hierarchy**: Rule of Three is not met, so concrete types extracted from the root view (`[AR-009]`, `KISS`).
- **D4 — Gate before decode**: `PreviewResourceAndLinkGate` checks scheme, scope, extension, size and header pixels before `CGImageSourceCreateThumbnailAtIndex`; SVG/PDF never decoded (`[SEC-003]`, `[SEC-004]`).
- **D5 — Tab chain in the Coordinator**: `Ctrl+Tab` > fence > table > list > default, each stage returning `notApplicable` to defer.

## Risks / Trade-offs
- Per-keystroke attribute work could exceed budget -> viewport-only scanning, line cap and fence index, measured by a timing test.
- `SwiftEditRootView.swift` extraction may conflict with uncommitted `011` follow-ups -> reconcile working tree before the first `[RED]` task.
- Programmatic text reset clears native undo -> apply through `shouldChangeText`/`didChangeText`.

## Migration Plan
1. Add `MarkdownSyntaxHighlighter` and tests.
2. Add `MarkdownAuthoringCommands` / `GFMTableEditEngine` and tests.
3. Add `MarkdownPreviewProjector` and `PreviewResourceAndLinkGate` and tests.
4. Extract `TextKit2EditorView`, add `MarkdownNativePreviewView`, menu and wiring.
5. Run `swift test --parallel`.

## Security Review
- Reviewer: cyber-security-expert
- Date: 2026-11-20
- Verdict: approved
- Open items: none
