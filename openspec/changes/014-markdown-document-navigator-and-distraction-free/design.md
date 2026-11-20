# Design: Markdown Document Navigator and Distraction-Free Mode

## Context
`SwiftEditWorkbenchModel` (`@MainActor @Observable`) owns UI flags such as `showMarkdownPreview` and `isLeftSidebarCollapsed`. `SwiftEditCommands` is the single source of key equivalents. `MarkdownLineIndex` already provides UTF-16 safe line ranges. `SwiftEditNSTextView` wraps TextKit 2.

## Goals / Non-Goals
- Goals: instant heading navigation for the active Markdown tab; zero cost when closed; one-key chrome-free full-screen writing.
- Non-Goals: setext headings, cross-document or workspace outline, outline editing/reordering, fuzzy ranking, persisting mode across launches.

## Constitutional Alignment & Module Boundaries (UI-002 / AR-002 / AR-003)
- **Single-Reference Lock**: `constitution/03-ui-ux/index.md` and `constitution/01-architecture/index.md` consulted.
- **AR-002**: `SwiftEditCore` ring holds `MarkdownHeadingOutlineEngine`; `SwiftEditUI` depends inward only.
- **AR-003**: parsing engine is pure in `SwiftEditCore` (no AppKit/SwiftUI); overlay, window and responder code stay in `SwiftEditUI`.

## Decisions
- **Pure engine plus thin UI**: `MarkdownHeadingOutlineEngine.outline(for:) -> [MarkdownHeading]` (`level`, `title`, `utf16Offset`). Testable without UI (KISS, TEST-001).
- **ATX only, fence and frontmatter aware**: avoids false positives such as `# comment` in code; setext rejected to match the requested `#..######` notation.
- **On-the-fly, not cached**: parse on open from the active snapshot (O(n), single pass); no background indexer, no memory held while closed.
- **`DocumentNavigatorState` value type**: `query`, `filtered`, `selectedIndex`, wrap-around `moveUp/moveDown`, `confirm() -> utf16Offset?`; keeps the SwiftUI view dumb.
- **Menu key equivalents for `⌥\` and `⌥1`**: macOS delivers key equivalents before `keyDown`, so the glyph (`«`, `¡`) is never inserted and no NSEvent monitor is needed.
- **ESC**: overlay uses `onExitCommand`; `SwiftEditNSTextView.cancelOperation` calls a model closure to exit distraction-free.
- **Distraction-free**: `isDistractionFree` plus `wasFullScreenBeforeDistractionFree`; root view conditionally omits header, sidebar, tab strip, gutter, status bar, diagnostics and borders; `NSWindow.toggleFullScreen` only when state differs; `NSWindow.didExitFullScreenNotification` resets the flag.
- **Layering**: while navigator is open, first `ESC` closes it; with distraction-free active a second `ESC` exits.

## Risks / Trade-offs
- Keyboard layouts where `\` needs Shift (Italian) -> menu shortcut registered on the logical character `\` with Option; verified manually, fallback documented in cheat sheet.
- Full-screen animation delay -> flag flips first, window follows; exit is idempotent.
- Large documents -> bounded by caps, measured by a performance test (`<= 16 ms` for 5000 lines).

## Migration Plan
- Additive; no data migration. Update `KeyboardShortcutsCheatSheetView` and CHANGELOG.

## Security Review
- Reviewer: cyber-security-expert
- Date: 2026-11-20
- Verdict: approved
- Open items: none
