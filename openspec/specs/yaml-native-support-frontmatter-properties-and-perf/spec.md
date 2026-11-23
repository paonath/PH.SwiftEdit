# Capability: yaml-native-support-frontmatter-properties-and-perf

## Purpose
Delivers native `.yml`/`.yaml` editing (viewport key/value highlighting, structural lint, top-level outline, 2-space smart indentation) and integrated Markdown YAML frontmatter support (inline key/value styling plus a structured Properties panel), followed by a measured whole-codebase analysis and three benchmark-gated performance refactor passes.

## Requirements

### Requirement: REQ-001 Single-Resolution Document Language Classification
WHEN a tab is opened, renamed, or saved under a new name, the `DocumentLanguage` resolver SHALL classify it once from the final path extension as `.markdown` (untitled, `md`, `markdown`, `mdown`, `mkd`), `.yaml` (`yml`, `yaml`, case-insensitive) or `.plainText`, cache the value on the tab, and force `.plainText` for binary or degraded snapshots [BC-001][AR-009][SEC-012].

#### Scenario: P1 Extensions Map to Markdown YAML and Plain Text
- **Path**: P1
- **Trait**: positive
- **GIVEN** tabs titled `README.md`, `Untitled`, `config.yml`, `Deploy.YAML` and `notes.txt`
- **WHEN** `DocumentLanguage.resolve(filename:isBinary:isDegraded:)` runs for each
- **THEN** the results are `.markdown`, `.markdown`, `.yaml`, `.yaml` and `.plainText`, and the status bar shows `Markdown`, `Markdown`, `YAML`, `YAML` and `Plain Text`

#### Scenario: N1 Double Extensions Dotfiles and Binary Never Enable YAML Features
- **Path**: N1
- **Trait**: negative
- **GIVEN** tabs titled `config.yml.bak`, `.yamllint`, `yml`, `notes.yaml.md` and a binary `data.yml` containing `0x00`
- **WHEN** the resolver runs for each
- **THEN** the results are `.plainText`, `.plainText`, `.plainText`, `.markdown` and `.plainText`, and the binary tab receives zero YAML spans, diagnostics or outline entries

### Requirement: REQ-002 Zero-Regex Bounded YAML Line Tokenizer
The `YAMLLineTokenizer` SHALL classify each UTF-16 line into `key`, `colon`, `value`, `quotedString`, `comment`, `listDash`, `anchor`, `alias`, `tag`, `documentMarker` and `blockScalarIndicator` tokens in linear time without regular expressions, skip lines over `4096` UTF-16 units, and never expand aliases or resolve tags [AR-002][BC-004][SEC-012].

#### Scenario: P2 Keys Values Comments Lists and Quoted Strings Tokenized
- **Path**: P2
- **Trait**: positive
- **GIVEN** the lines `name: "a # not comment: x"  # real`, `  - item`, `url: http://x.y/z` and `tags: [a, b]`
- **WHEN** `YAMLLineTokenizer.tokens(line:)` runs for each
- **THEN** `name` is a `key`, the quoted string including `#` and `:` is one `quotedString`, `# real` is a `comment`, `-` is a `listDash`, `http://x.y/z` is one `value` and `[a, b]` is one `value`

#### Scenario: N2 Overlong Lines Unterminated Quotes and Alias Bombs Stay Bounded
- **Path**: N2
- **Trait**: security
- **GIVEN** a `4097`-unit line, the line `k: "unterminated`, and a document of ten nested `&lN [*lM, *lM, ...]` alias levels
- **WHEN** the tokenizer runs over the document
- **THEN** the overlong line yields no tokens, the unterminated quote yields one `quotedString` to end of line without error, aliases yield `alias` tokens only, and total work stays linear in the document length

### Requirement: REQ-003 Viewport-Only YAML Highlighting for YAML Files and Markdown Frontmatter
WHEN a visible text range of a non-degraded `.yaml` snapshot, or the frontmatter lines of a `.markdown` snapshot, is laid out, the `YAMLSyntaxHighlighter` SHALL return `yamlKey`, `yamlPunctuation`, `yamlComment` and `yamlValue` spans only for lines intersecting that range, reusing the per-revision `MarkdownLineIndex` [BC-004][UI-012][SEC-012].

#### Scenario: P3 YAML File and Markdown Frontmatter Receive Key and Value Spans in the Viewport
- **Path**: P3
- **Trait**: positive
- **GIVEN** a `.yml` snapshot of `200` lines with a visible range on lines `10..30`, and a `.md` snapshot `"---\ntitle: Hi\n---\n# Body **b**"`
- **WHEN** the highlighter runs for both visible ranges
- **THEN** only lines `10..30` of the YAML file receive spans, the Markdown line `title: Hi` receives a `yamlKey` span for `title` and a `yamlValue` span for `Hi`, and the body keeps its GFM heading and bold spans

#### Scenario: N3 Plain Binary Degraded and Out-of-Viewport Lines Receive No YAML Spans
- **Path**: N3
- **Trait**: negative
- **GIVEN** a `.txt` snapshot containing `key: value`, a binary `.yml` snapshot, a degraded `.yml` snapshot, and a `.md` snapshot whose `---` block starts on line `2`
- **WHEN** the highlighter runs for each visible range
- **THEN** every call returns zero YAML spans and the Markdown line-2 block is treated as GFM thematic breaks rather than frontmatter

### Requirement: REQ-004 Structural YAML Linter With Bounded Output
WHEN a `.yaml` snapshot or a Markdown frontmatter block is linted, the `YAMLStructureLinter` SHALL report `YML001` tab indentation, `YML002` duplicate key, `YML003` inconsistent indentation step, `YML004` unterminated frontmatter and `YML005` nesting beyond `32` levels as `MarkdownLintDiagnostic` values without YAML values in messages, capped at `1000` diagnostics [BC-004][SEC-006][SEC-012].

#### Scenario: P4 Four Structural Rules Reported on Their Lines
- **Path**: P4
- **Trait**: positive
- **GIVEN** a `.yml` snapshot with a tab-indented line `3`, `name` declared twice at top level, a child indented `3` spaces under a `2`-space sibling, and a `.md` snapshot opening `---` with no closing delimiter within `200` lines
- **WHEN** `YAMLStructureLinter.lint(snapshot:)` runs for both
- **THEN** it reports `YML001` on line `3`, `YML002` on the second `name`, `YML003` on the `3`-space child, and `YML004` on line `1` of the Markdown file

#### Scenario: N4 Valid Documents Are Clean and Pathological Input Is Capped
- **Path**: N4
- **Trait**: security
- **GIVEN** a valid `.yml` file, a file with `5000` duplicate keys, and a file nested `40` levels deep with a secret value `token: s3cr3t`
- **WHEN** the linter runs for each
- **THEN** the valid file yields zero diagnostics, the duplicate file yields exactly `1000` diagnostics, nesting beyond `32` stops descent with exactly one `YML005` diagnostic, and no diagnostic message contains `s3cr3t`

### Requirement: REQ-005 Top-Level YAML Key Outline in the Document Navigator
WHEN the Document Navigator opens on a `.yaml` tab, the `YAMLOutlineEngine` SHALL list top-level mapping keys with their UTF-16 offsets in document order, capped at `5000` entries, and the Navigator SHALL jump to the selected key using the existing confirm and clamp behavior [BC-004][UI-010][SEC-012].

#### Scenario: P5 Top-Level Keys Listed and Jump Lands on the Key Line
- **Path**: P5
- **Trait**: positive
- **GIVEN** a `.yml` snapshot `"version: 2\nservices:\n  web:\n    image: x\nvolumes: {}"`
- **WHEN** the Navigator opens and the user confirms `volumes`
- **THEN** the outline lists `version`, `services`, `volumes` and the selection moves to the start of line `5`

#### Scenario: N5 Nested Keys Comments List Items and Block Scalar Bodies Are Excluded
- **Path**: N5
- **Trait**: negative
- **GIVEN** a `.yml` snapshot with nested `web:`, a comment `# key: no`, a top-level list `- name: a`, and `script: |` followed by an indented `fake: key` line
- **WHEN** `YAMLOutlineEngine.outline(index:)` runs
- **THEN** only `script` is listed and a stale offset beyond the current length is clamped before jumping

### Requirement: REQ-006 Two-Space YAML Smart Enter and Tab
WHEN `Enter` or `Tab` is pressed in a `.yaml` tab or inside Markdown frontmatter, the `YAMLSmartIndentEngine` SHALL insert the parent indentation plus `2` spaces after a line ending with `key:`, continue `- ` after a non-empty list item, remove an empty `- ` marker, and insert `2` spaces for `Tab`, never a tab character, as one undoable edit [BC-003][BC-004].

#### Scenario: P6 Mapping Indentation List Continuation and Tab Spaces
- **Path**: P6
- **Trait**: positive
- **GIVEN** a `.yml` caret at the end of `  services:`, another at the end of `  - web`, and a caret at column `0` of an empty line
- **WHEN** `Enter`, `Enter` and `Tab` are pressed respectively
- **THEN** the new lines start with `4` spaces and `  - ` respectively, and `Tab` inserts exactly two spaces

#### Scenario: N6 Non-YAML Context Empty Marker and Quoted Colon Fall Back
- **Path**: N6
- **Trait**: negative
- **GIVEN** a `.txt` tab ending in `key:`, a `.md` body line `key:` outside frontmatter, a `.yml` line `  - ` with an empty marker, and a `.yml` line `k: "a:"`
- **WHEN** `Enter` is pressed at each line end
- **THEN** the first two yield `.notApplicable`, the empty marker is removed leaving the indentation, and the quoted colon line receives only the current indentation

### Requirement: REQ-007 Fail-Closed Frontmatter Property Parsing
WHEN a `.markdown` snapshot contains a line-1 frontmatter block, the `FrontmatterPropertyParser` SHALL return up to `500` top-level entries (a defense-in-depth bound below the `200`-line frontmatter scan) classified as editable `scalar` or `list` (block `- x` or flow `[a, b]`) or read-only `nestedMap`, `blockScalar`, `aliased` or `tagged`, and SHALL mark the whole model read-only when the block is malformed or unterminated [BC-004][SEC-012].

#### Scenario: P7 Scalars and Simple Lists Parsed as Editable Entries
- **Path**: P7
- **Trait**: positive
- **GIVEN** frontmatter `title: Hello`, `draft: false`, `date: 2026-11-21`, `tags: [a, b]` and `aliases:\n  - x\n  - y`
- **WHEN** `FrontmatterPropertyParser.parse(snapshot:)` runs
- **THEN** it returns five editable entries with kinds `scalar`, `scalar`, `scalar`, `list(["a","b"])` and `list(["x","y"])` and their exact line ranges

#### Scenario: N7 Nested Maps Block Scalars Aliases Tags and Malformed Blocks Are Read-Only
- **Path**: N7
- **Trait**: security
- **GIVEN** frontmatter entries `meta:\n  a: 1`, `body: |\n  text`, `base: &b x`, `ref: *b`, `obj: !!python/object x`, and a separate snapshot with an unterminated `---` block
- **WHEN** the parser runs
- **THEN** those entries are read-only with kinds `nestedMap`, `blockScalar`, `aliased`, `aliased` and `tagged`, no alias is expanded, and the unterminated snapshot yields a fully read-only model

### Requirement: REQ-008 Minimal Injection-Safe Frontmatter Property Writer
WHEN the user edits, renames, adds or removes an editable property, the `FrontmatterPropertyWriter` SHALL return one `TextEdit` touching only that entry's lines, double-quote and escape values containing `:`, `#`, quotes, newlines or edge spaces, reject keys with control characters, newlines, a leading `-`, `?` or `#`, or duplicates, and refuse a stale `BufferRevision` [BC-003][BC-004][SEC-012].

#### Scenario: P8 Edit Rename Add and Remove Produce Minimal Round-Trip-Stable Edits
- **Path**: P8
- **Trait**: positive
- **GIVEN** frontmatter `# note\ntitle: Hello\ntags: [a, b]` at revision `7`
- **WHEN** the writer sets `title` to `Hi: there`, renames `tags` to `labels`, adds `draft: true` and removes `labels` in successive revisions
- **THEN** each result is a single `TextEdit` producing `title: "Hi: there"`, `labels: [a, b]`, an appended `draft: true` before the closing `---`, and a removed line, while `# note` and the body stay byte-identical and re-parsing returns the edited model

#### Scenario: N8 Injection Duplicate and Stale Revision Writes Are Rejected or Neutralized
- **Path**: N8
- **Trait**: security
- **GIVEN** a frontmatter at revision `7` containing `title` and `tags`
- **WHEN** the writer receives value `x\n---\nmalicious: true`, key `a: b`, key `k\u{7}`, rename `tags` to `title`, and a valid edit tagged with revision `6`
- **THEN** the value is written as one escaped quoted scalar keeping exactly two `---` delimiters, the three invalid key operations return `.rejected` with no edit, and the stale edit returns `.staleRevision` with no edit

### Requirement: REQ-009 Collapsible Accessible Properties Panel With Single Undo
WHILE the active tab is a writable `.markdown` document with a line-1 frontmatter block, `SwiftEditUI` SHALL show a collapsible `PropertiesPanelView`, collapsed by default (spec 020), above the editor listing entries with grey key labels and full-color values, apply edits through `DocumentSession.applyTextEdits` as one undo step, show read-only entries as non-editable with a banner, and expose VoiceOver labels and keyboard navigation [UI-005][UI-009][UI-010][DATA-003].

#### Scenario: P9 Panel Edit Applies One Undo Step and Advances the Revision
- **Path**: P9
- **Trait**: positive
- **GIVEN** a writable `post.md` with frontmatter `title: Hello` at revision `3`
- **WHEN** the user changes `title` to `World` in the Properties panel and then presses `Cmd+Z`
- **THEN** the buffer shows `title: World` at revision `4` with the tab dirty, and a single `Cmd+Z` restores `title: Hello`

#### Scenario: N9 Panel Hidden for Non-Markdown Binary and Frontmatter-Less Tabs and Read-Only Rows Locked
- **Path**: N9
- **Trait**: negative
- **GIVEN** a `.yml` tab, a `.txt` tab, a binary `.md` tab, a `.md` tab without frontmatter, and a `.md` tab whose `meta` entry is a nested map
- **WHEN** the workbench evaluates `isPropertiesPanelVisible` and renders rows
- **THEN** the panel is hidden for the first four, and the `meta` row is non-editable with the accessibility label `meta, read-only nested mapping`

### Requirement: REQ-010 Visually Separated YAML Key and Value Tokens
The `PurpleThemePalette` SHALL provide `yamlKeyForeground` (`#6B7280` Light, `#9CA3AF` Black) rendered with a lighter monospaced font weight for YAML keys, keep YAML values on `editorCanvasText`, and render comments and punctuation with `secondaryForeground`, meeting `>= 4.5:1` contrast on the editor canvas [UI-002][UI-003][UI-009].

#### Scenario: P10 Key Token Meets Contrast in Light and Black With Lighter Weight
- **Path**: P10
- **Trait**: positive
- **GIVEN** the Light and Black palettes and the cached YAML key font at `100%` zoom
- **WHEN** contrast ratios and font weights are computed
- **THEN** `yamlKeyForeground` is `>= 4.5:1` against `#FFFFFF` and `#000000` respectively and the key font weight is lighter than the regular editor font

#### Scenario: N10 Values Are Never Tinted and Appearance Switch Keeps Buffers Intact
- **Path**: N10
- **Trait**: negative
- **GIVEN** an open `.yml` tab with an unsaved edit at revision `5`
- **WHEN** rendering attributes are applied and the appearance switches from `Light` to `Black`
- **THEN** no `foregroundColor` attribute is added for `yamlValue` spans, values stay `21:1`, and the buffer text and revision `5` are unchanged

### Requirement: REQ-011 Post-Implementation Measured Analysis and Three Benchmark-Gated Performance Passes
WHEN REQ-001 through REQ-010 are implemented with a green suite, the performance refactor workflow SHALL produce `docs/qa/perf-analysis-016.md` ranking at least `3` measured bottlenecks across `Sources/` and execute `3` refactor passes, each starting from a failing benchmark requiring `>= 20%` improvement or the `UI-012` budget and a golden equivalence test proving identical spans, diagnostics, outlines and edits [UI-012][TEST-001][TEST-005].

#### Scenario: P11 Each Pass Turns Its Benchmark Green Without Behavioral Change
- **Path**: P11
- **Trait**: positive
- **GIVEN** the analysis report ranking `PERF-C1..PERF-C4` (or measured replacements) with baseline timings on a `20,000`-line Markdown fixture and a `20,000`-line YAML fixture
- **WHEN** pass `1`, `2` and `3` are applied
- **THEN** each targeted benchmark improves by `>= 20%` or meets the `UI-012` budget and the full `swift test` suite stays green

#### Scenario: N11 Golden Equivalence Rejects Behavior-Changing Optimizations
- **Path**: N11
- **Trait**: negative
- **GIVEN** golden snapshots of spans, diagnostics, outline entries and smart-edit results captured before pass `1`
- **WHEN** an optimization alters any of those outputs
- **THEN** the golden equivalence test fails and the pass is not accepted

#### Scenario: N12 Shared Caches Never Serve Stale Data After Same-Length Edits
- **Path**: N12
- **Trait**: security
- **GIVEN** a shared per-revision text index cached at revision `9` for a `1000`-unit buffer
- **WHEN** a same-length replacement produces revision `10`
- **THEN** every consumer receives an index built for revision `10` and no span or diagnostic derived from revision `9` is rendered
