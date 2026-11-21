---
id: "brief-yaml-native-support-frontmatter-properties-and-perf"
change_id: "016-yaml-native-support-frontmatter-properties-and-perf"
capability: "yaml-native-support-frontmatter-properties-and-perf"
branch: "feature/FirstStub"
modifies_specs:
  - "textkit2-gfm-editor-and-native-preview (REQ-001 highlight: frontmatter lines receive YAML spans, not GFM spans)"
  - "comprehensive-markdown-linter-and-diagnostics-ui (lint policy: YAML tabs report YAML lint status instead of Lint: Off)"
status: "approved-via-qa"
date: "2026-11-21"
owners:
  - "swift-macos-expert"
  - "oop-architecture-expert"
  - "cyber-security-expert"
---

# TDD Specification Brief: `016-yaml-native-support-frontmatter-properties-and-perf`

## 1. Context & Scope

- **Request**: ONE spec covering (1) native `.yml`/`.yaml` file support, (2) native integrated YAML frontmatter support inside `.md` files with key/value editing and a visually separated key (lighter weight, grey) vs value (full canvas color) layout, (3) AFTER full implementation: whole-codebase analysis and 3 performance refactor passes eliminating at least 3 bottlenecks.
- **QA decisions** (4 answers + final confirmation):
  1. Frontmatter editing = inline styled text in the canvas **plus** a structured `Properties` panel that rewrites the YAML block with a single Undo.
  2. YAML file scope = highlight + structural lint + top-level outline in the Navigator + Smart Enter/Tab with 2-space indentation; zero new dependencies (own YAML subset scanner, no `Yams`).
  3. Perf phase = pre-registered candidates + automated benchmark RED tests (`>= 20%` gain or `UI-012` budget), analysis may confirm or replace candidates.
  4. Properties panel edits top-level scalars (string/number/bool/date) and simple lists (block `- x`, flow `[a, b]`); nested maps, block scalars `|`/`>`, anchors/aliases, `!!` tags and malformed frontmatter are read-only with a banner; automatic quoting of `:`, `#`, leading/trailing spaces, newlines; aliases never expanded.
- **Governing rules**: `AR-002`, `AR-006..AR-010`, `BC-001`, `BC-003`, `BC-004`, `BC-011`, `UI-002`, `UI-005`, `UI-009`, `UI-010`, `UI-012`, `DATA-003`, `TEST-001..TEST-005`, `SEC-009`, `SEC-010`, `SEC-012`, `SDD-001..SDD-003`.

## 2. Expert Notes

- **swift-macos-expert**: introduce `DocumentLanguage` (`.markdown`, `.yaml`, `.plainText`) resolved once per tab from the filename (`.md/.markdown/.mdown/.mkd` → markdown, untitled → markdown, `.yml/.yaml` case-insensitive → yaml, else plain). Replace the scattered `MarkdownSmartNewlineEngine.isMarkdownFilename(activeTabTitle)` calls (6 sites in `SwiftEditRootView`). New pure `SwiftEditCore` engines under a `YAMLSupport/` folder inside the `MarkdownLintAndFormat` context: `YAMLLineTokenizer` (zero-regex UTF-16 line scanner: key, colon, value scalar, quoted string, comment, list dash, anchor/alias/tag, document markers), `YAMLSyntaxHighlighter` (viewport-only, reuses the per-revision `MarkdownLineIndex`), `YAMLStructureLinter` (`YML001` tab indentation, `YML002` duplicate key in the same mapping, `YML003` inconsistent indentation step, `YML004` unterminated frontmatter in `.md`), `YAMLOutlineEngine` (top-level keys), `YAMLSmartIndentEngine` (Enter after `key:` → +2 spaces; Enter after `- x` → `- `; Tab inserts 2 spaces, never `\t`), `FrontmatterPropertyParser` and `FrontmatterPropertyWriter` (minimal single `TextEdit` rewrite preserving untouched lines and comments byte-for-byte).
- **UI**: TextKit 2 validator dispatches by language: YAML file → YAML spans for every visible line; Markdown → YAML spans for frontmatter lines (`YAMLFrontmatterScanner.maskedLineCount`) and GFM spans for the rest. Palette adds `yamlKeyForeground` (Light `#6B7280` = 4.83:1 on `#FFFFFF`, Black `#9CA3AF` = 8.6:1 on `#000000`) rendered with a lighter (`.light`) monospaced weight; values keep `editorCanvasText` (21:1); comments/punctuation use `secondaryForeground`. `PropertiesPanelView` (collapsible, above the editor, only on writable Markdown tabs with frontmatter) with keyboard navigation and VoiceOver labels.
- **oop-architecture-expert**: no protocol hierarchy for languages (2 variants < Rule of Three, `AR-009`): a plain `enum DocumentLanguage` switch. Writer returns an immutable `TextEdit`; `DocumentSession.applyTextEdits` remains the single mutation path (`BC-003`, `BC-004`).
- **cyber-security-expert**: YAML subset scanner never builds alias graphs (billion-laughs immune), caps lines at `4096` UTF-16 units, frontmatter at `200` lines, outline at `5000` keys, diagnostics at `1000`, properties at `500` entries, depth at `32`; writer rejects keys containing control characters or newlines, quotes risky values, refuses stale `BufferRevision`; binary/degraded snapshots get zero YAML work.
- **Perf candidates (pre-registered)**: `PERF-C1` repeated `DocumentLanguage` derivation via `NSString` bridging on every render/keystroke; `PERF-C2` duplicated per-revision text scans (`Array(text.utf16)` copies in `MarkdownLineIndex` per consumer + separate UTF-8 frontmatter detector in `MarkdownAllConstructsLinter`) → one shared per-revision `DocumentTextIndexCache`; `PERF-C3` `O(N)` `textView.string != text` comparison and `textView.string` bridging in `TextKit2EditorView.updateNSView`/validator, plus same-length line-index retag staleness risk; `PERF-C4` broad SwiftUI invalidation from the 2.8k-line `SwiftEditRootView` `@Observable` model (status bar/gutter/sidebar recomputed per keystroke). The analysis task confirms the top 3+ by measurement.

## 3. Path Coverage Matrix

| Unit | Path | Trait | Summary |
| :--- | :--- | :--- | :--- |
| `DocumentLanguage` | P1 | positive | `.md`/untitled → markdown, `.yml`/`.YAML` → yaml, `.txt` → plain |
| `DocumentLanguage` | N1 | negative | `.yml.bak`, `.yamllint`, `yml` without dot, binary → never yaml/markdown features |
| `YAMLLineTokenizer` | P1 | positive | key/value/comment/list/quoted with inner `#`/`:` tokenized correctly |
| `YAMLLineTokenizer` | N1 | negative, security | `> 4096` line skipped, unterminated quote, anchors/aliases tokenized but never expanded |
| `YAMLSyntaxHighlighter` | P1 | positive | viewport-only key/value spans in `.yml` and in `.md` frontmatter; GFM body unchanged |
| `YAMLSyntaxHighlighter` | N1 | negative | binary/degraded/plain → zero spans; lines outside viewport → zero spans |
| `YAMLStructureLinter` | P1 | positive | `YML001..YML004` reported with correct line ranges |
| `YAMLStructureLinter` | N1 | negative, security | valid doc → zero diagnostics; 1000-diagnostic cap; 200-line frontmatter cap |
| `YAMLOutlineEngine` | P1 | positive | top-level keys with UTF-16 offsets listed in Navigator |
| `YAMLOutlineEngine` | N1 | negative | nested keys, comments, list items, keys inside block scalars ignored; 5000 cap |
| `YAMLSmartIndentEngine` | P1 | positive | Enter after `key:` +2 spaces; Enter after `- x` continues; Tab → 2 spaces |
| `YAMLSmartIndentEngine` | N1 | negative | non-YAML / outside frontmatter / empty `- ` exits list / never inserts `\t` |
| `FrontmatterPropertyParser` | P1 | positive | scalars and simple lists parsed with kind and editability |
| `FrontmatterPropertyParser` | N1 | negative, security | nested map/block scalar/alias/tag → read-only entry; malformed/unterminated → read-only panel |
| `FrontmatterPropertyWriter` | P1 | positive | edit/rename/add/remove produce one minimal `TextEdit`, comments preserved, round-trip stable |
| `FrontmatterPropertyWriter` | N1 | negative, security | newline/control-char key rejected, duplicate rename rejected, stale revision rejected, risky values quoted |
| `PropertiesPanel` | P1 | positive | shown for `.md` with frontmatter, edit applied as single Undo + new `BufferRevision` |
| `PropertiesPanel` | N1 | negative | hidden for plain/YAML/binary tabs; read-only rows not editable; VoiceOver labels present |
| `YAMLPaletteTokens` | P1 | positive | key token `>= 4.5:1` in Light and Black, lighter font weight |
| `YAMLPaletteTokens` | N1 | negative | values never tinted (canvas text `21:1`) |
| `PerfPass1..3` | P1 | positive | each benchmark improves `>= 20%` (or meets `UI-012` budget) |
| `PerfPass1..3` | N1 | negative | golden equivalence: identical spans/diagnostics/outline; no stale cache after same-length edit |

## 4. Behavior Contracts (GIVEN-WHEN-THEN)

- GIVEN a tab named `config.yml` WHEN it is opened THEN the editor shows grey light-weight keys and full-color values, the status bar shows `YAML` and `Lint: N issues` from `YAMLStructureLinter`.
- GIVEN a `.md` file with `---\ntitle: Hello\ntags: [a, b]\n---` WHEN the Properties panel edits `title` to `Hi: there` THEN the frontmatter line becomes `title: "Hi: there"` via one Undo-able `TextEdit` and all other bytes are unchanged.
- GIVEN a frontmatter with `base: &b {x: 1}` WHEN the panel renders THEN `base` is read-only and no alias expansion occurs.
