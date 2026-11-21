# Proposal: Native YAML Files, Frontmatter Key/Value Properties & Post-Implementation 3-Pass Performance Refactor

## Why
PH.SwiftEdit treats `.yml`/`.yaml` files as undifferentiated plain text and only *masks* Markdown YAML frontmatter (linter `REQ-001`, heading outline) without any visual structure or structured editing. Document language is re-derived from the tab title through `NSString` bridging in at least 6 call sites of `SwiftEditRootView` on every render/keystroke, and every consumer re-copies the buffer into its own `[UInt16]`/UTF-8 scan per revision. Users editing configuration files and Obsidian-style notes need key/value separation (grey, lighter keys; full-color values), structural YAML diagnostics, a key outline, and a Properties panel, while the editor must stay inside the `UI-012` budgets (`<= 16 ms` P99 keystroke) [UI-002][UI-012][BC-004].

## What Changes
- **Wave 1 — Language Resolution**: add `DocumentLanguage` (`.markdown`, `.yaml`, `.plainText`) in `SwiftEditCore`, resolved once per tab from its filename (`.yml`/`.yaml` case-insensitive → `.yaml`; untitled and `.md`/`.markdown`/`.mdown`/`.mkd` → `.markdown`) and cached on the tab; status bar shows `Markdown`/`YAML`/`Plain Text` [BC-001][AR-009].
- **Wave 2 — YAML Engines (pure `SwiftEditCore`, zero new dependencies)**: `YAMLLineTokenizer` (zero-regex UTF-16 subset scanner), viewport-only `YAMLSyntaxHighlighter`, `YAMLStructureLinter` (`YML001` tab indentation, `YML002` duplicate key, `YML003` inconsistent indentation step, `YML004` unterminated frontmatter), `YAMLOutlineEngine` (top-level keys in the existing Navigator), `YAMLSmartIndentEngine` (2-space Enter/Tab continuation) [AR-002][BC-004][SEC-012].
- **Wave 3 — Markdown Frontmatter Integration**: frontmatter lines in `.md` receive YAML key/value spans instead of GFM spans; new `FrontmatterPropertyParser`/`FrontmatterPropertyWriter` and a collapsible `PropertiesPanelView` editing top-level scalars and simple lists through one minimal `TextEdit` (single Undo, new `BufferRevision`); nested maps, block scalars, anchors/aliases, tags and malformed blocks are read-only [BC-003][UI-005][UI-010].
- **Wave 4 — Visual Tokens**: `PurpleThemePalette.yamlKeyForeground` (Light `#6B7280` 4.83:1, Black `#9CA3AF` 8.6:1) with a lighter monospaced weight for keys; values keep `editorCanvasText` (21:1); comments/punctuation use `secondaryForeground` [UI-002][UI-009].
- **Wave 5 — Whole-Codebase Analysis & 3 Performance Refactor Passes (after Waves 1–4 are green)**: a measured analysis report (`docs/qa/perf-analysis-016.md`) ranks bottlenecks; pre-registered candidates `PERF-C1` (language re-derivation), `PERF-C2` (duplicated per-revision text scans → shared `DocumentTextIndexCache`), `PERF-C3` (`O(N)` `textView.string != text` compare and same-length index retag in `TextKit2EditorView`), `PERF-C4` (broad `@Observable` invalidation in the 2.8k-line `SwiftEditRootView` model). Three passes each start from a RED benchmark (`>= 20%` gain or `UI-012` budget) and a golden behavioral-equivalence test [UI-012][TEST-001].

## Capabilities
- New Capabilities: `yaml-native-support-frontmatter-properties-and-perf`
- Modified Capabilities: `textkit2-gfm-editor-and-native-preview`, `comprehensive-markdown-linter-and-diagnostics-ui`

## Domain Carrier & Decision Ownership (BC-###)
- **BC-001**: `MarkdownLintAndFormat` (Core) owns YAML tokenization, highlighting spans, structural lint, outline, smart indent and frontmatter property parsing/serialization; `DocumentCore` (Core) owns the single mutation path (`DocumentSession.applyTextEdits`) and `BufferRevision`; `WorkspaceAndTabSession` (Supporting) owns the cached per-tab `DocumentLanguage`; `SwiftEditUI` owns the Properties panel view state and TextKit 2 rendering.
- **Owned Decisions**: language classification by extension, YAML token boundaries, `YML001..YML004` severity, frontmatter editability per entry, quoting policy for written values, benchmark acceptance thresholds.
- **Forbidden Responsibilities**: the YAML scanner MUST NEVER expand anchors/aliases, evaluate tags, or perform type coercion beyond display classification; the Properties writer MUST NEVER rewrite lines it does not own or apply edits against a stale `BufferRevision`; perf passes MUST NEVER change observable spans, diagnostics, outline entries or edits; `SwiftEditCore` MUST NEVER import `AppKit`, `UIKit`, `SwiftUI` or `WebKit` [AR-002][BC-011].
- **External Decision References**: `DocumentID`, `BufferRevision`, `TextRange`.

## Impact
- **Sources**: `Sources/SwiftEditCore/MarkdownLintAndFormat/YAMLSupport/` (new), `MarkdownSourceLineTable.swift`, `MarkdownAllConstructsLinter.swift`, `MarkdownQuickFixResolver.swift` (`ActiveLintStatus`), `MarkdownSmartNewlineEngine.swift`, `WorkspaceAndTabSession/WorkspaceTabSession.swift`; `Sources/SwiftEditUI/Views/TextKit2EditorView.swift`, `SwiftEditRootView.swift`, `DocumentNavigatorOverlayView.swift`, new `PropertiesPanelView.swift`, `Theme/PurpleThemeAndZoom.swift`.
- **Tests**: new suites under `Tests/SwiftEditTests/` (`YAML*Tests.swift`, `FrontmatterProperty*Tests.swift`, `PerfPass*BenchmarkTests.swift`).
- **Dependencies**: none added (`swift-markdown` only) [AR-005].

## Security Impact
- New untrusted-input parser surface (YAML text from opened files): bounded `4096` UTF-16 line cap, `200`-line frontmatter cap, `32` depth cap, `500` properties, `1000` diagnostics, `5000` outline entries, no alias expansion (billion-laughs `CWE-776`), no tag evaluation, no `Codable`/`NSKeyedUnarchiver` decoding [SEC-012].
- Writer injection hardening: keys with control characters/newlines rejected, values containing `:`, `#`, quotes, leading/trailing spaces or newlines are double-quoted with escaping (`CWE-74`); stale revision edits refused [BC-004].
- Binary and degraded snapshots receive zero YAML work and no Properties panel [DATA-003].

## Metadata
- Owner: swift-macos-expert
- Domain: YAML Language Support, Markdown Frontmatter Properties & Editor Performance
- Reviewer: cyber-security-expert
- Branch: feature/FirstStub
- Manual-Steps: none
- Modifies-Specs: textkit2-gfm-editor-and-native-preview (REQ-001), comprehensive-markdown-linter-and-diagnostics-ui (REQ-003)
- Constitutional-Rules: AR-002, AR-005, AR-006, AR-008, AR-009, AR-010, BC-001, BC-003, BC-004, BC-011, DATA-003, UI-002, UI-005, UI-009, UI-010, UI-012, TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, SEC-009, SEC-010, SEC-012, SDD-001, SDD-002, SDD-003
- Amends-Constitution: none

## Prerequisites
- `openspec/Constitution.md` (`v1.3.0`)
- `openspec/briefs/brief-yaml-native-support-frontmatter-properties-and-perf.md`
- Implemented specs `012-textkit2-gfm-editor-and-native-preview`, `013-comprehensive-markdown-linter-and-diagnostics-ui`, `014-markdown-document-navigator-and-distraction-free` (Navigator overlay reused for YAML outline)
