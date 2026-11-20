# Proposal: 26-Rule All-Construct Markdown Linter, Idempotent Quick-Fix and Fix All, Triple Diagnostics UI and Shift+Cmd+M Popover

## Why
The Markdown linter covers `5` rules, the status bar only prints a raw count (also on non-Markdown files), diagnostics are not located in the editor, and there is no safe automated repair. Authors need comprehensive, false-positive-free diagnostics with hardened URI/image safety and one-step repairs (`[BC-004]`, `[SEC-004]`, `[UI-007]`).

## What Changes
- Add `MarkdownLintProfile` with `.legacyBaseline` (default, unchanged behavior) and `.allConstructs` running `26` rules in one shared pass: headings, lists/tasks/outlines, GFM tables, links/images with hardened `.unsafeLinkScheme` / `.unsafeImagePath`, code fences, blockquotes and whitespace (`[BC-004]`, `[SEC-012]`).
- Add `YAMLFrontmatterScanner` (Line-1 mask, `<= 200` lines) and `MarkdownSourceLineTable` (UTF-8 to scalar-aligned UTF-16 ranges); cap `1000` diagnostics keeping `.error` before `.warning` with `isTruncated`.
- Add `MarkdownQuickFixResolver`: non-overlapping, idempotent, revision-pinned `Quick-Fix` and `Fix All` as one edit batch; `quickFix == nil` on security rules (`[BC-006]`, `[BC-011]`).
- Add `ActiveLintStatus` (`Lint: Off` / `Lint: Paused` / `Lint: N`) and `ActiveLineLintSuppressionPolicy` (`[DATA-003]`).
- Add UI surfaces in `SwiftEditUI`: TextKit 2 dotted underlines in `renderingAttributesValidator`, gutter severity badges with tooltips, status-bar `ActiveLintStatus`, `MarkdownDiagnosticsPopoverView` toggled by `⇧⌘M` with Jump-to-Range, per-item Quick-Fix and Fix All in one `Cmd+Z` step (`[UI-005]`, `[UI-012]`).

## Capabilities
- New Capabilities: `comprehensive-markdown-linter-and-diagnostics-ui`
- Modified Capabilities: `markdown-lint-format-bracket-and-diff`

## Domain Carrier & Decision Ownership (BC-###)
- **BC-001**: `MarkdownLintAndFormat` (`SwiftEditCore`, Core) owns rule classification, severity, fix generation and status; `SwiftEditUI` (Presentation) only renders attributes, badges and the popover and applies returned edits.
- **Owned Decisions**: Which rule fires, its severity, whether a fix exists, fix ordering and idempotence, and lint status classification.
- **Forbidden Responsibilities**: The linter MUST NEVER auto-fix security diagnostics, mutate binary or degraded buffers, apply a fix against a stale revision, or import `AppKit`/`UIKit`/`SwiftUI`/`WebKit` in `SwiftEditCore` (`[AR-002]`, `[BC-011]`, `[DATA-003]`).
- **External Decision References**: `DocumentID`, `BufferRevision`, `TextRange`.

## Impact
- **Production Modules (`SwiftEditCore`)**:
  - `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownLintAndFormatEngine.swift` (profiles, rules, cap)
  - `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownSourceLineTable.swift` (new, includes `YAMLFrontmatterScanner`)
  - `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownQuickFixResolver.swift` (new, includes `ActiveLintStatus` and suppression policy)
- **Production Modules (`SwiftEditUI`)**:
  - `Sources/SwiftEditUI/Views/MarkdownDiagnosticsPopoverView.swift` (new)
  - `Sources/SwiftEditUI/Views/TextKit2EditorView.swift`, `LineNumberGutterView.swift`, `SwiftEditRootView.swift`, `SwiftEditCommands.swift`, `KeyboardShortcutsCheatSheetView.swift`
- **Test Suites**: new `MarkdownAllConstructsLintTests`, `MarkdownQuickFixAndStatusTests`; updated `MarkdownLintAndFormatTests.swift`.
- **External Dependencies**: none (`swift-markdown` already present, `[AR-005]`).

## Security Impact
- **Hardened URI/Image Rules (`SEC-LINT-01`, `CWE-79`, `CWE-22`)**: percent/HTML-entity decoding, zero-width/BiDi stripping and protocol-relative detection before scheme checks; traversal and `.svg` images flagged as errors.
- **No Auto-Fix on Security Rules**: `quickFix == nil`; suppression never hides them.
- **Race Safety (`CWE-362`)**: fixes apply only when `expectedRevision == session.revision`.
- **Resource Bounds (`CWE-400`, `[SEC-012]`)**: `250 ms` budget, `1000` cap, `200`-line frontmatter mask.

## Metadata
- Owner: swift-macos-expert
- Domain: apple-swift-macos
- Reviewer: cyber-security-expert
- Branch: feature/FirstStub
- Manual-Steps: none
- Modifies-Specs: markdown-lint-format-bracket-and-diff (REQ-001)
- Constitutional-Rules: AR-002, AR-003, AR-005, BC-001, BC-004, BC-006, BC-011, DATA-003, SEC-004, SEC-009, SEC-012, TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, UI-002, UI-005, UI-007, UI-012, SDD-001, SDD-002, SDD-003
- Amends-Constitution: none

## Prerequisites
- `openspec/Constitution.md` (`v1.3.0`, active)
- `openspec/changes/archive/2026-11-20-012-textkit2-gfm-editor-and-native-preview` (archived; validator and gutter)
- `openspec/changes/archive/2026-11-20-011-adaptive-markdown-lists-tab-indentation` (archived; outline rule)
- `openspec/briefs/brief-comprehensive-markdown-linter-and-diagnostics-ui.md`
