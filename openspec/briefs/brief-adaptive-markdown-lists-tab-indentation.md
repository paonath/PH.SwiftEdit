---
id: "brief-adaptive-markdown-lists-tab-indentation"
change_id: "011-adaptive-markdown-lists-tab-indentation"
capability: "adaptive-markdown-lists-tab-indentation"
branch: "feature/FirstStub"
modifies_specs: "editor-ux-highlighting-sidebar-pin-tabs-and-about (REQ-002), markdown-lint-format-bracket-and-diff (REQ-001)"
status: "approved-via-qa"
date: "2026-11-20"
owners:
  - "swift-macos-expert"
  - "oop-architecture-expert"
  - "cyber-security-expert"
---

# TDD Specification Brief: `011-adaptive-markdown-lists-tab-indentation`

## 1. Context & Source Traceability

- **Originating Reasoning Session**: `reasoning/003_theming-header-menu-and-markdown-editor/README.ai.md` (`TASK-03`, `TOPIC-03`, `ADR-03`).
- **Core Problem**: Pressing `Tab` in a Markdown list inserts a raw tab (or nothing useful), `Shift+Tab` does not outdent, `Return` on nested ordered items loses the parent numbering context, and manually typed pseudo-outline markers (`a.`, `1.1`) are neither continued nor flagged although CommonMark 0.31.2 parses them as plain paragraph text.
- **Active Git Branch**: `feature/FirstStub` (baseline SHA `d559cf8`).
- **Approved Scope (QA)**: pure `MarkdownSmartListEngine` in `SwiftEditCore`; `Tab`/`Shift+Tab`/`Return` wiring in `SwiftEditUI`; new lint rule `.nonStandardOutlineMarker` (detection only). The clickable Quick-Fix and diagnostics UI are deferred to `TASK-05`.
- **Consolidated Specs Modified**: `editor-ux-highlighting-sidebar-pin-tabs-and-about` (`REQ-002` smart Enter), `markdown-lint-format-bracket-and-diff` (`REQ-001` lint diagnostics).
- **New Capability**: `adaptive-markdown-lists-tab-indentation`.
- **Governing Rules (`v1.3.0`)**: `AR-002`, `AR-006`, `AR-008`, `AR-009`, `BC-004`, `BC-006`, `BC-011`, `DATA-003`, `SEC-012`, `TEST-001..006`, `UI-005`, `UI-007`, `UI-010`, `UI-012`, `SDD-001..003`.

## 2. Domain, Architecture & Security Expert Notes

- **Three-Tier Contract**: Tier 1 `Tab`/`Shift+Tab` emits only CommonMark-valid markers with a `4`-space step; Tier 2 inherits valid user overrides (`*`, `+`, `1)`, `- [ ]`); Tier 3 continues manual `a.`/`1.1` on `Return` while the linter flags `.nonStandardOutlineMarker`.
- **Parent-Ceiling**: `Tab` is rejected (consumed as a safe no-op) when `targetIndent > precedingSiblingIndent + 4`, so a root item never becomes a 4-space indented code block; max nesting `32` levels, ordered numbers `1...999_999_999`, sibling lookback `<= 128` lines.
- **Complexity & Security Floor**: zero regex, UTF-16 slices, lines `<= 4096` units, binary and degraded snapshots return no edit, fenced code blocks are never touched (`CWE-400`, `DATA-003`, `SEC-012`).
- **Atomicity**: one `TextEdit` batch per keystroke (one `BufferRevision`), caret translated by the prefix delta; multi-line selection handled in a single batch.

## 3. Path Coverage Matrix

| Unit | Path ID | Trait | Scenario Summary |
| :--- | :--- | :--- | :--- |
| `MarkdownSmartListEngine` | `P1` | `positive` | `Tab` nests ordered/unordered/task items by 4 spaces; `Shift+Tab` outdents and resumes parent numbering |
| `MarkdownSmartListEngine` | `P2` | `positive` | Multi-line selection indents all list lines in one edit batch; valid override markers are inherited |
| `MarkdownSmartListEngine` | `N1` | `negative` | Root first item, non-list line, non-Markdown, fenced code: no-op or not applicable |
| `MarkdownSmartListEngine` | `N2` | `security` | Binary, degraded, overlong line, level 32 cap, number overflow return no edit |
| `MarkdownSmartNewlineEngine` | `P3` | `positive` | `Return` continues `b.` / `1.2` and exits nested empty items in two stages |
| `MarkdownLintAndFormatEngine` | `N3` | `negative` | `.nonStandardOutlineMarker` flags `a.` / `1.1` outside fences and never valid markers |
| `SwiftEditWorkbenchModel` | `P5` | `positive` | `applyListIndentation` produces `+1` `BufferRevision` with translated caret |
| `SwiftEditWorkbenchModel` | `N4` | `security` | Binary tab or non-Markdown file: zero mutation and zero revision change |
