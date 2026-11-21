# Proposal: Markdown Document Navigator and Distraction-Free Mode

## Why
Long Markdown documents have no way to jump between sections, and the editor always shows chrome (header, sidebar, tabs, gutter) that distracts from writing. An Alfred-style heading palette and a one-key distraction-free mode close both gaps.

## What Changes
- Add `document-navigator`: centered Alfred-style palette listing ALL ATX headings (H1..H6) of the active Markdown tab, indented by level, grey `H<n>` badge instead of `#`, `↑`/`↓` navigation, `⏎`/click jumps the caret to the heading and closes it. Toggle with `⌥\`, close with `ESC`.
- Add `distraction-free` mode: `⌥1` sends the active tab to native full screen with only the editor visible; `ESC` or `⌥1` restores everything.
- Add pure `MarkdownHeadingOutlineEngine` in `SwiftEditCore` (on-the-fly parsing, fence/frontmatter aware).
- Out of scope: build scan and performance passes (executed afterwards via `/myspec-quick`).

## Capabilities
- New Capabilities: `markdown-document-navigator-and-distraction-free`
- Modified Capabilities: None

## Impact
- `Sources/SwiftEditCore/MarkdownLintAndFormat/`: new `MarkdownHeadingOutlineEngine`.
- `Sources/SwiftEditUI/Views/`: new `DocumentNavigatorOverlayView`; edits to `SwiftEditRootView` (model flags, overlay, chrome hiding), `SwiftEditCommands` (`⌥\`, `⌥1`), `TextKit2EditorView` (`cancelOperation`, caret jump), `KeyboardShortcutsCheatSheetView`.
- Tests: new Swift Testing suite for the engine, navigator state and workbench flags.

## Security Impact
Pure in-memory text processing; no I/O, network or subprocess. Bounded heading count and line length (CWE-400); caret offsets clamped (CWE-129). No change to sandbox or persistence.

## Metadata
- Owner: swift-macos-expert
- Domain: Markdown editor navigation and window chrome
- Reviewer: cyber-security-expert
- Branch: feature/FirstStub
- Manual-Steps: none
- Modifies-Specs: none
- Constitutional-Rules: UI-002, UI-005, UI-009, UI-012, AR-002, AR-003, BC-004, TEST-001, SEC-012, SDD-001
- Amends-Constitution: none

## Prerequisites
- Archived changes `012-textkit2-gfm-editor-and-native-preview` and `013-comprehensive-markdown-linter-and-diagnostics-ui`.
