---
id: "brief-textkit2-gfm-editor-and-native-preview"
change_id: "012-textkit2-gfm-editor-and-native-preview"
capability: "textkit2-gfm-editor-and-native-preview"
branch: "feature/FirstStub"
modifies_specs: "none"
status: "approved-via-qa"
date: "2026-11-20"
owners:
  - "swift-macos-expert"
  - "oop-architecture-expert"
  - "cyber-security-expert"
---

# TDD Specification Brief: `012-textkit2-gfm-editor-and-native-preview`

## 1. Context & Source Traceability

- **Originating Reasoning Session**: `reasoning/003_theming-header-menu-and-markdown-editor/README.ai.md` (`TASK-04`, `TOPIC-04`, human review approved in full).
- **Scope Resolution (QA)**: `TASK-04` also exists in `reasoning/001_project-constitution` (`WorkspaceAndTabSession`). Verified as **already implemented** (change `003-notepadpp-tabs-session-recovery-and-dotfiles`, status `implemented`, archived), so only the `003_theming...` `TASK-04` is specified here.
- **Core Problem**: Markdown authoring has no viewport GFM highlighting, no formatting commands, no GFM table `Tab` navigation, and no preview; per-keystroke stalls exist (eager gutter `VStack`, immediate `SessionRecovery` writes, transient coordinator allocation inside `body`).
- **Active Git Branch**: `feature/FirstStub` (baseline SHA `c808c98`; working tree holds uncommitted `TASK-03` follow-ups, so reconcile target files before implementation).
- **Approved Scope**: pure engines in `SwiftEditCore` (`MarkdownSyntaxHighlighter`, `MarkdownAuthoringCommands` incl. `GFMTableEditEngine`, `MarkdownPreviewProjector`, image/link gate); `SwiftEditUI` wiring (`TextKit2EditorView`, `MarkdownNativePreviewView`, `CommandMenu("Markdown")`, `Cmd+P` toggle, `sourceLine` scroll sync). Lint expansion is `TASK-05` (non-goal).
- **Consolidated Specs Modified**: none (new capability, additive only; existing `Cmd+P` default-OFF binding from change `010` is consumed, not altered).
- **Governing Rules (`v1.3.0`)**: `AR-002`, `AR-003`, `AR-006`, `AR-008`, `AR-009`, `BC-001`, `BC-004`, `BC-006`, `BC-011`, `DATA-003`, `SEC-002`, `SEC-003`, `SEC-004`, `SEC-009`, `SEC-012`, `TEST-001..005`, `UI-002`, `UI-005`, `UI-007`, `UI-012`, `SDD-001..003`.

## 2. Domain, Architecture & Security Expert Notes

- **Two-Speed Pipeline**: hot path `<= 2 ms` on `@MainActor` (`renderingAttributesValidator`, `O(log F)` fence index, zero-regex UTF-16 scanner, `4096` line cap); cold path debounced `180 ms`, `BufferRevision`-gated AST off the main actor, projected only while `showMarkdownPreview == true`.
- **21:1 Prose**: paragraph/list/quote/table-cell prose keeps `#000000`/`#FFFFFF` at uniform size; only traits and `>= 4.5:1` palette tokens apply to the 12 GFM constructs.
- **Shortcuts**: `⇧⌘B` Bold, `⌘I` Italic, `⇧⌘X` Strike, `⌘E` Code, `⇧⌘C` Fence, `⌘K` Link, `⇧⌘I` Image, `⇧⌘L` Task, `⇧⌘.` Quote, `⌃⌘1..6` Headings, `⌥⌘T` Table; no collision with `⌘B`/`⌘D`; each is one `shouldChangeText` Undo group.
- **Tab Chain**: `Ctrl+Tab` escape > fenced code (`nil`) > GFM table > list (`MarkdownSmartListEngine`) > default.
- **Preview Security**: zero sockets (`AsyncImage` banned), local images only through `FileSystemProviding` inside `grantedScopeRootURL`, allowlist `png/jpg/jpeg/gif/webp/heic`, `<= 16 MiB`, `<= 8192 px` / `<= 16 MP` header pre-check, thumbnail `<= 2048 px`, max `64` images, no SVG/PDF, no symlink escape; links only via `prepareExternalURIConfirmation` (`https`/`http`/`mailto`); raw HTML inert plain text.
- **Bounds (`CWE-400`)**: table `<= 64` columns x `<= 2000` rows; binary and degraded snapshots yield no edits and no projection.

## 3. Path Coverage Matrix

| Unit | Path ID | Trait | Scenario Summary |
| :--- | :--- | :--- | :--- |
| `MarkdownSyntaxHighlighter` | `P1` | `positive` | 12 GFM constructs tokenized for visible range only, prose keeps base colors |
| `MarkdownSyntaxHighlighter` | `N1` | `negative` | Fenced interior, non-Markdown, empty range produce no construct spans |
| `MarkdownSyntaxHighlighter` | `N2` | `security` | Binary, degraded, `4097`-unit line return no spans (bounded work) |
| `MarkdownAuthoringCommands` | `P2` | `positive` | Bold/Italic/Link/Heading wrap or toggle in one edit batch with translated selection |
| `GFMTableEditEngine` | `P3` | `positive` | `Tab` pads columns, moves to next/previous cell, appends row at last cell |
| `GFMTableEditEngine` | `N3` | `negative` | Outside table, inside fence, non-Markdown: `notApplicable`, no edit |
| `GFMTableEditEngine` | `N4` | `security` | `65` columns or `2001` rows, binary: no edit |
| `MarkdownPreviewProjector` | `P4` | `positive` | Table, task, quote, heading, inert HTML projected when preview is on |
| `MarkdownPreviewProjector` | `N5` | `security` | Preview hidden: zero projections; raw HTML never interpreted |
| `PreviewResourceAndLinkGate` | `P5` | `positive` | `./diagram.png` inside scope loads downsampled; `https` link needs confirmation |
| `PreviewResourceAndLinkGate` | `N6` | `security` | Remote, `data:`, traversal, SVG, oversize, symlink, `javascript:` blocked, zero sockets |
| `EditorPipelineWiring` | `P6` | `positive` | `Cmd+P` toggles default-OFF preview; Tab chain order; debounced recovery; `sourceLine` sync |
| `EditorPipelineWiring` | `N7` | `security` | Binary tab: Markdown menu disabled, preview unavailable, zero mutation |
