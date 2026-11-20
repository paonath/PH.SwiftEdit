# Spec Delta: textkit2-gfm-editor-and-native-preview

## Purpose
Enforces document-wide 64-image preview admission, ordered list numbering (`1., 2.`), HTML-before-table termination, CR-aware source lines, async `NSCache` thumbnails, `(DocumentID, BufferRevision)` line index invalidation, single-pass viewport attributes, and undo-safe TextKit 2 edits (`BUG-001`, `BUG-005`, `BUG-014..016`, `BUG-019`, `BUG-021`, `PERF-001`, `PERF-002`).

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-004 Hidden-By-Default Inert GFM Preview Projection
WHEN `showMarkdownPreview` toggles or `MarkdownPreviewProjector` evaluates a document, the preview projector SHALL perform zero projections while hidden, project ordered list numerals (`1., 2.`), break HTML before adjacent GFM tables, track CR/CRLF/LF `sourceLine` anchors, and keep raw HTML inert [BC-004][SEC-004][SEC-012].

Security-Waiver: fixes HTML-block boundary swallowing of adjacent GFM tables (`BUG-019`), ordered list numerals (`BUG-014`), and CR/CRLF `previewSourceLine` (`BUG-016`) while keeping HTML strictly inert (`N5`) and offline guarantees intact.

#### Scenario: P7 Ordered List Numerals Adjacent HTML-Before-Table and CR/CRLF Source Lines Project Accurately
- **Path**: P7
- **Trait**: positive
- **GIVEN** `showMarkdownPreview` true on `"<div>hi</div>\n| A | B |\n|---|---|\n| 1 | 2 |\n\n1. first\n2. second"` and a `CR`-separated snapshot `"# One\rTwo\rThree"`
- **WHEN** `MarkdownPreviewProjector.project` and `previewSourceLine` evaluate both documents
- **THEN** `<div>hi</div>` closes cleanly as inert HTML without absorbing the following GFM table (`table == true`), ordered list items render `"1."` and `"2."` instead of `"•"`, and `previewSourceLine` advances correctly across `\r` separators

#### Scenario: N9 Malicious HTML Script Immediately Preceding Table Remains Inert Without Rendering Tags
- **Path**: N9
- **Trait**: security
- **GIVEN** `"<script>alert(1)</script>\n| H |\n|---|\n| V |"` with `showMarkdownPreview` true
- **WHEN** `MarkdownPreviewProjector.project(snapshot:)` runs
- **THEN** the script block stays inert monospace plain text with zero WebKit evaluation while cleanly parsing the adjacent GFM table

### Requirement: REQ-005 Confined Image Admission and Mediated Links
IF a preview image or link resolves, THEN the preview resource gate SHALL admit local raster images via `FileSystemProviding` within `16 MiB`, `8192 px`, and `16 MP`, downsample off-`@MainActor` into a bounded `NSCache` up to `2048 px`, enforce an aggregate `64`-image document budget, open zero sockets, and confirm `https`/`http`/`mailto` links [SEC-002][SEC-003][SEC-004].

Security-Waiver: closes `CWE-400` 70/64 per-paragraph cap bypass (`BUG-014`) by enforcing a cumulative `64`-image document counter (`PERF-002` async bounded `NSCache` thumbnails) while keeping `P5` and `N6` confinement protections intact.

#### Scenario: P8 Valid Images Across Multiple Paragraphs Cache Downsampled Thumbnails Asynchronously
- **Path**: P8
- **Trait**: positive
- **GIVEN** a Markdown document with `10` valid local PNG images across distinct paragraphs
- **WHEN** `MarkdownNativePreviewView` renders images with document-wide image admission and bounded `NSCache` thumbnails
- **THEN** thumbnails decode off `@MainActor`, populate cached entries across re-renders without synchronous main-thread decoding spikes, and display all `10` admitted images

#### Scenario: N10 Document With 70 Valid Images Across Separate Paragraphs Strictly Enforces Aggregate 64-Image Cap
- **Path**: N10
- **Trait**: security
- **GIVEN** a Markdown snapshot placing `70` valid local images across `70` separate paragraphs
- **WHEN** `MarkdownNativePreviewView` renders the full preview using a shared cumulative document counter (`remainingImageBudget = 64`)
- **THEN** at most `64` images total decode and render while the `65th..70th` images are capped (`CWE-400`), never admitting `70/64`

### Requirement: REQ-006 Editor Pipeline Wiring With Dispatch Order and Binary Lockout
WHEN `TextKit2EditorView` and `SwiftEditUI` process keystrokes, `Cmd+P`, `Tab`, programmatic edits, or closing tabs, the shell SHALL route undo-safe edits preserving selection, assign one `NSUndoManager` per tab cleared in `dismantleNSView`, reset attributes only across dirty/visible ranges in one viewport pass, key `MarkdownLineIndex` by `(DocumentID, BufferRevision)`, and lock binary tabs [AR-003][DATA-003][UI-005][UI-007][UI-012].

Security-Waiver: strengthens isolation and eliminates stale line index (`BUG-015`), full-doc layout/attribute storms (`PERF-001`), undo loss (`BUG-005`), and missing `dismantleNSView` (`BUG-021`) while keeping `P6` and `N7` binary lockouts intact.

#### Scenario: P9 Revision-Keyed LineIndex Same-Length Edits and Single-Pass Viewport Styling Stay Coherent
- **Path**: P9
- **Trait**: positive
- **GIVEN** a document edited from `"# a\n**b**"` (`rev 1`) to `"* a\n__b__"` (`rev 2`, identical UTF-16 length) inside `TextKit2EditorView`
- **WHEN** `Coordinator` updates syntax/diagnostic styling across visible range and invokes `Cmd+Z` after `MarkdownAuthoringCommands` Bold
- **THEN** `cachedLineIndex` invalidates on `BufferRevision` (`rev 1 -> rev 2`) even when length is unchanged, styling updates dirty/visible range in a single viewport layout pass, and Bold toggles undo in one `Cmd+Z`

#### Scenario: N11 Degraded Binary or Dismantled Editor Performs Zero Full-Document Layout Sweeps
- **Path**: N11
- **Trait**: negative
- **GIVEN** a `12 MiB` degraded plain-text buffer or a closed tab triggering `dismantleNSView`
- **WHEN** `updateNSView` and teardown execute
- **THEN** degraded buffers bypass full-document `setRenderingAttributes([:], for: docRange)` sweeps and dismantled views clear delegates and validators immediately

## REMOVED Requirements

## RENAMED Requirements
