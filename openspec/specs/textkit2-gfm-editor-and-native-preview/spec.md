# Capability: textkit2-gfm-editor-and-native-preview

## Purpose
Defines the two-speed viewport GFM highlighting, Markdown authoring commands with GFM table navigation, and the on-demand offline Zero-WebKit native preview with confined local images and mediated links, all without mutating binary buffers or opening sockets.

## Requirements

### Requirement: REQ-001 Viewport-Only GFM Highlighting Preserving 21:1 Prose
WHEN a visible text range of a non-degraded Markdown snapshot is laid out, the `MarkdownSyntaxHighlighter` SHALL return spans only for that range for the 12 GFM constructs using zero regex and a fence index, keep prose base colors, and return no spans for fenced interiors, non-Markdown, binary, degraded snapshots or lines over 4096 UTF-16 units [AR-002][BC-004][SEC-012].

#### Scenario: P1 Twelve GFM Constructs Tokenized for the Visible Range Only
- **Path**: P1
- **Trait**: positive
- **GIVEN** a Markdown snapshot with a heading, bold, italic, strike, inline code, a fence, a link, an image, a task item, a quote, a table row and a thematic break, and a visible range covering only lines `1..6`
- **WHEN** `MarkdownSyntaxHighlighter.spans(snapshot:visibleRange:)` runs
- **THEN** it returns construct spans only inside lines `1..6`, never spans for prose text colors, and keeps the base font size uniform

#### Scenario: N1 Fenced Interior Non-Markdown and Empty Range Yield No Construct Spans
- **Path**: N1
- **Trait**: negative
- **GIVEN** a fenced block containing `**not bold**`, a `.txt` snapshot, and an empty visible range
- **WHEN** `spans(snapshot:visibleRange:)` runs for each
- **THEN** the fenced interior receives only the code-block span, the non-Markdown snapshot receives none, and the empty range returns an empty list

#### Scenario: N2 Binary Degraded and Overlong Lines Return No Spans
- **Path**: N2
- **Trait**: security
- **GIVEN** a binary read-only snapshot, a degraded plain-text snapshot, and a Markdown line of `4097` UTF-16 units
- **WHEN** `spans(snapshot:visibleRange:)` runs for each
- **THEN** every call returns no spans within the bounded scan and no error escapes

### Requirement: REQ-002 Single-Batch Markdown Authoring Commands
WHEN the user invokes a `CommandMenu("Markdown")` shortcut on a text Markdown snapshot outside fenced code, the `MarkdownAuthoringCommands` SHALL return one `TextEdit` batch with a translated selection that wraps, toggles or inserts the construct, and SHALL return no edit for binary, degraded or non-Markdown snapshots [BC-004][BC-006][UI-007].

#### Scenario: P2 Bold Italic Link and Heading Commands Apply in One Edit Batch
- **Path**: P2
- **Trait**: positive
- **GIVEN** a snapshot `"word"` with `word` selected
- **WHEN** Bold, then Italic and Insert Link are evaluated, and Heading level `2` on a plain line
- **THEN** each yields exactly one batch producing `"**word**"`, `"*word*"`, `"[word](url)"` and `"## word"`, toggling off when already applied, with the selection translated by the inserted prefix length

#### Scenario: N3 Commands Inside Fences and Non-Markdown Documents Are Not Applied
- **Path**: N3
- **Trait**: negative
- **GIVEN** a selection inside a fenced block and a `.swift` snapshot
- **WHEN** Bold is evaluated for each
- **THEN** no edit is returned and the buffer stays unchanged

### Requirement: REQ-003 GFM Table Tab Navigation with Bounded Size
WHEN the user presses `Tab` or `Shift+Tab` inside a GFM pipe table of at most 64 columns and 2000 rows outside fences, the `GFMTableEditEngine` SHALL pad columns, select the next or previous cell, and append a row at the final cell in one batch, and otherwise SHALL return `notApplicable` [BC-004][BC-006][SEC-012].

#### Scenario: P3 Tab Pads Columns Moves Between Cells and Appends a Row
- **Path**: P3
- **Trait**: positive
- **GIVEN** a table `"| a | bb |\n|---|---|\n| 1 | 2 |"` with the caret in the last cell
- **WHEN** `Tab` is evaluated, then `Shift+Tab` on the first cell of the second row
- **THEN** `Tab` appends a padded empty row and selects its first cell, `Shift+Tab` selects the previous cell, each as one batch

#### Scenario: N4 Oversized Tables and Binary Snapshots Return No Edit
- **Path**: N4
- **Trait**: security
- **GIVEN** a table with `65` columns, a table with `2001` rows, and a binary snapshot
- **WHEN** `Tab` is evaluated for each
- **THEN** no edit is returned and the caller falls through to the next handler

#### Scenario: N8 Tab Outside Tables Is Not Applicable
- **Path**: N8
- **Trait**: negative
- **GIVEN** a caret in a paragraph and a caret inside a fenced block
- **WHEN** `Tab` is evaluated by the table engine
- **THEN** the result is `notApplicable` and the dispatch chain continues to list then default handling

### Requirement: REQ-004 Hidden-By-Default Inert GFM Preview Projection
WHILE `showMarkdownPreview` is false, the `MarkdownPreviewProjector` SHALL perform zero projections, and WHEN it is true SHALL project headings, paragraphs, tasks, quotes, tables within caps and thematic breaks with `sourceLine` anchors, rendering raw HTML block and inline as inert monospaced text [BC-004][SEC-004][SEC-012].

#### Scenario: P4 Preview On Projects Table Task Quote and Inert HTML With Source Lines
- **Path**: P4
- **Trait**: positive
- **GIVEN** `showMarkdownPreview` true and a snapshot with a heading, a table, `- [x] done`, a quote and `<b>x</b>`
- **WHEN** `project(snapshot:)` runs
- **THEN** it returns a `GFMPreviewDocument` whose blocks carry `sourceLine` and where the HTML appears as inert plain text

#### Scenario: N5 Preview Hidden Yields Zero Projections and Raw HTML Never Interpreted
- **Path**: N5
- **Trait**: security
- **GIVEN** `showMarkdownPreview` false and a snapshot containing `<script>x()</script>`
- **WHEN** the editor edits the document and `project` is requested
- **THEN** zero projections run, and a later projection renders the script text inertly

### Requirement: REQ-005 Confined Image Admission and Mediated Links
IF a preview image or link target is resolved, THEN the `PreviewResourceAndLinkGate` SHALL admit only local `png`/`jpg`/`jpeg`/`gif`/`webp`/`heic` files inside the granted scope via `FileSystemProviding` within 16 MiB, 8192 px and 16 MP, downsampled to 2048 px, at most 64 per document, SHALL open zero sockets, and SHALL allow links only after `https`/`http`/`mailto` confirmation [SEC-002][SEC-003][SEC-004].

#### Scenario: P5 In-Scope Raster Image Loads Downsampled and Https Link Requires Confirmation
- **Path**: P5
- **Trait**: positive
- **GIVEN** a workspace containing `./diagram.png` of `4000 x 3000` px under `10 MiB` and a link `https://example.com`
- **WHEN** the gate evaluates the image and the link
- **THEN** the image is admitted and downsampled to at most `2048` px, and the link yields a confirmation request showing the canonical URI

#### Scenario: N6 Remote Data Traversal SVG Oversize Symlink and Unsafe Links Are Blocked
- **Path**: N6
- **Trait**: security
- **GIVEN** images `https://tracker.example/p.png`, `data:image/png;base64,AA`, `../../etc/passwd`, `./x.svg`, a `20000 px` PNG, a symlink escaping the scope, and links `javascript:x()` and `file:///etc/hosts`
- **WHEN** the gate evaluates each
- **THEN** each is blocked with a placeholder or rejection, zero sockets open, zero out-of-scope reads occur, and escapes raise `securityScopeViolation`

### Requirement: REQ-006 Editor Pipeline Wiring With Dispatch Order and Binary Lockout
WHEN the editor handles keystrokes, `Cmd+P` and `Tab`, the `SwiftEditUI` SHALL toggle a default-OFF preview, dispatch `Tab` as `Ctrl+Tab` escape, fence, GFM table, list, then default, debounce `SessionRecovery` writes by 500 ms, sync preview scrolling by `sourceLine`, and SHALL disable Markdown commands and preview on binary tabs without mutation [AR-003][UI-005][UI-007][UI-012][DATA-003].

#### Scenario: P6 Cmd+P Toggles Preview and Tab Chain Honors Precedence
- **Path**: P6
- **Trait**: positive
- **GIVEN** a Markdown tab with `showMarkdownPreview` false, a table caret and a list caret
- **WHEN** `Cmd+P` is pressed and `Tab` is pressed at each caret
- **THEN** the preview toggles on and off, the table caret navigates cells, the list caret nests, and recovery writes coalesce within 500 ms

#### Scenario: N7 Binary Tab Disables Markdown Menu and Preview Without Mutation
- **Path**: N7
- **Trait**: security
- **GIVEN** a quarantined binary tab
- **WHEN** a Markdown command or `Cmd+P` is triggered
- **THEN** the command is disabled, no preview is mounted, and `BufferRevision` is unchanged
