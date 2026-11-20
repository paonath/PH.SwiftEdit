# Proposal: Linter-Governed Adaptive Markdown List Indentation (Tab / Shift+Tab / Return)

## Why
Editing Markdown outlines in `PH.SwiftEdit` is clumsy: `Tab` does not nest list items, `Shift+Tab` does not outdent, `Return` on a nested ordered item loses the parent numbering, and manually typed outline markers (`a.`, `1.1`) are silently treated by CommonMark 0.31.2 as paragraph text without any warning (`[BC-004]`, `[UI-009]`).

## What Changes
- Add pure `MarkdownSmartListEngine` in `SwiftEditCore`: `Tab`/`Shift+Tab` on a list line or multi-line selection emit `4`-space CommonMark-valid nesting (`1.` -> `    1. `, `- ` -> `    - `, task items preserved), resume parent numbering on outdent, inherit valid user markers (`*`, `+`, `1)`, `- [ ]`), and consume `Tab` on the root first item as a safe no-op (Parent-Ceiling) (`[AR-002]`, `[BC-004]`, `[BC-011]`).
- Extend `MarkdownSmartNewlineEngine` so `Return` continues manual pseudo-outline markers (`a.` -> `b.`, `A.` -> `B.`, `1.1` -> `1.2`) and exits empty nested items in two stages (`    2. ` -> `3. ` -> empty).
- Add lint rule `.nonStandardOutlineMarker` to `MarkdownLintAndFormatEngine` flagging `a.`/`A.`/`1.1` list-like prefixes outside fenced code blocks (detection only; Quick-Fix UI deferred to `TASK-05`).
- Wire `insertTab:` / `insertBacktab:` in `TextKit2EditorView.Coordinator` to `SwiftEditWorkbenchModel.applyListIndentation(outdent:)` applying one `TextEdit` batch (`+1` `BufferRevision`) and translating the caret (`[UI-005]`, `[UI-007]`, `[UI-012]`).

## Capabilities
- New Capabilities: `adaptive-markdown-lists-tab-indentation`
- Modified Capabilities: `editor-ux-highlighting-sidebar-pin-tabs-and-about`, `markdown-lint-format-bracket-and-diff`

## Domain Carrier & Decision Ownership (BC-###)
- **BC-001**: `MarkdownLintAndFormat` (`SwiftEditCore`, Core) owns list grammar, indentation edits, and the new lint rule; `SwiftEditUI` (Presentation) only routes keystrokes and applies the returned edits.
- **Owned Decisions**: Which marker a nested/outdented item receives, Parent-Ceiling rejection, two-stage empty exit, and `.nonStandardOutlineMarker` classification.
- **Forbidden Responsibilities**: The engine MUST NEVER touch fenced code, binary or degraded buffers, lines over `4096` UTF-16 units, or emit non-CommonMark markers on `Tab`/`Shift+Tab`; `SwiftEditCore` MUST NEVER import `AppKit`/`UIKit`/`SwiftUI`/`WebKit` (`[AR-002]`, `[BC-011]`, `[DATA-003]`).
- **External Decision References**: `DocumentID`, `BufferRevision`, `TextRange`.

## Impact
- **Production Modules (`SwiftEditCore`)**:
  - `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownSmartListEngine.swift` (new)
  - `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownSmartNewlineEngine.swift` (pseudo-outline continuation, two-stage exit)
  - `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownLintAndFormatEngine.swift` (`.nonStandardOutlineMarker`)
- **Production Modules (`SwiftEditUI`)**:
  - `Sources/SwiftEditUI/Views/SwiftEditRootView.swift` (`Coordinator.doCommandBy`, `applyListIndentation(outdent:)`)
- **Test Suites**: new `MarkdownSmartListEngineTests.swift`; updated `MarkdownSmartNewlineEngineTests.swift` and `MarkdownLintAndFormatTests.swift` where needed.
- **External Dependencies**: none (`[AR-005]`).

## Security Impact
- **Orphan Code-Block Defense (`CWE-451`)**: Parent-Ceiling prevents `Tab` from converting a root item into a 4-space indented code block that would change rendering semantics.
- **Resource Bounds (`CWE-400`, `[SEC-012]`)**: zero-regex linear scans, `4096` UTF-16 line cap, `32` nesting levels, `128` sibling lookback, ordered-number overflow guard.
- **Quarantine (`[DATA-003]`)**: binary read-only and degraded buffers never produce edits.

## Metadata
- Owner: swift-macos-expert
- Domain: apple-swift-macos
- Reviewer: cyber-security-expert
- Branch: feature/FirstStub
- Manual-Steps: none
- Modifies-Specs: editor-ux-highlighting-sidebar-pin-tabs-and-about (REQ-002), markdown-lint-format-bracket-and-diff (REQ-001)
- Constitutional-Rules: AR-002, AR-005, AR-006, AR-008, AR-009, BC-001, BC-004, BC-006, BC-011, DATA-003, SEC-004, SEC-009, SEC-012, TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, TEST-006, UI-005, UI-007, UI-009, UI-010, UI-012, SDD-001, SDD-002, SDD-003
- Amends-Constitution: none

## Prerequisites
- `openspec/Constitution.md` (`v1.3.0`, active)
- `openspec/changes/archive/2026-11-20-010-translucent-header-brand-submenu` (archived)
- `openspec/briefs/brief-adaptive-markdown-lists-tab-indentation.md`
