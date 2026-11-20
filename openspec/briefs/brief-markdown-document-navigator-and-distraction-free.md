---
id: "brief-markdown-document-navigator-and-distraction-free"
change_id: "014-markdown-document-navigator-and-distraction-free"
capability: "markdown-document-navigator-and-distraction-free"
branch: "feature/FirstStub"
modifies_specs: "none"
status: "approved-via-qa"
date: "2026-11-20"
owners:
  - "swift-macos-expert"
  - "oop-architecture-expert"
  - "cyber-security-expert"
---

# TDD Specification Brief: `014-markdown-document-navigator-and-distraction-free`

## 1. Context & Scope

- **Request**: ONE spec covering (1) Markdown `document-navigator` (`⌥\`) and (2) `distraction-free` mode (`⌥1`). Item 3 (build scan, bug hunt, 3-pass performance optimization) is OUT of this spec and runs afterwards via `/myspec-quick`, asking the user before each fix.
- **QA**: scope confirmed by the user (option 1).
- **Consolidated specs modified**: none (additive; shortcuts registered in `SwiftEditCommands`, the single source of key equivalents).
- **Governing rules**: `UI-002`, `UI-005`, `UI-009`, `UI-012`, `AR-002`, `AR-003`, `BC-001`, `BC-004`, `TEST-001`, `SEC-012`, `SDD-001..003`.

## 2. Expert Notes

- **Parsing on the fly**: pure `SwiftEditCore` engine `MarkdownHeadingOutlineEngine` over `MarkdownLineIndex` (UTF-16 safe). ATX headings `#`..`######` only (0-3 leading spaces, mandatory space or EOL after the marker, optional closing `#` run stripped). Lines inside fenced code (` ``` ` / `~~~`) and YAML frontmatter are NOT headings. Setext headings are a non-goal. Computed only while the navigator is open (zero cost otherwise), snapshot of the active tab only, O(n) single pass, cap 5000 headings and the `MarkdownLineIndex.maxLineUTF16` line cap.
- **Alfred-style palette**: centered translucent overlay, query field (case-insensitive substring filter, empty = ALL headings), result list with `↑`/`↓` selection (wraps), `⏎` or click confirms, row = grey disabled `H<level>` badge (no `#` shown) + title indented `(level-1) * 16 pt` with font size decreasing from H1 to H6.
- **Jump**: confirm sets the editor selection to the heading line start (UTF-16 offset), scrolls it into view, closes the navigator and returns first responder to the editor.
- **Keys**: `⌥\` and `⌥1` produce glyphs on macOS, so they are bound as menu key equivalents in `SwiftEditCommands` (consumed before `keyDown`, no text inserted). `ESC` handled by the overlay (`onExitCommand`) and by `SwiftEditNSTextView.cancelOperation` for distraction-free.
- **Distraction-free**: model flag `isDistractionFree`; root view hides header, sidebar, tab strip, gutter, status bar, diagnostics and borders (edge-to-edge editor); the window enters native full screen (`NSWindow.toggleFullScreen`) only if not already full screen and restores the prior state on exit; leaving full screen via the system keeps state in sync. Navigator stays available over the editor (first `ESC` closes it, next `ESC` exits).
- **Security/DoS**: pure text processing, no I/O, no sockets; bounded heading count and line length; selection offsets clamped to the snapshot length; stale heading offsets re-validated against the current revision before jumping.

## 3. Path Coverage Matrix

| Unit | Path | Trait | Summary |
| :--- | :--- | :--- | :--- |
| `MarkdownHeadingOutlineEngine` | P1 | positive | H1..H6 extracted with level, title, UTF-16 offset |
| `MarkdownHeadingOutlineEngine` | N1 | negative | `#` in fences/frontmatter, `#hashtag`, 7 hashes and 4-space indent ignored |
| `DocumentNavigatorState` | P1 | positive | filter and wrap-around selection |
| `DocumentNavigatorState` | N1 | negative | empty outline / no match yields no selection and no jump |
| `DocumentNavigatorOverlay` | P1 | positive | `⌥\` opens in markdown tab, confirm jumps and closes, ESC/`⌥\` close |
| `DocumentNavigatorOverlay` | N1 | negative | non-markdown tab or binary tab never opens; stale offset clamped |
| `DistractionFreeMode` | P1 | positive | `⌥1` hides all chrome and goes full screen; ESC/`⌥1` restores |
| `DistractionFreeMode` | N1 | negative | no leaked chrome state; system full-screen exit resyncs; no `¡`/`«` inserted |
