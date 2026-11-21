# Design: Native YAML Files, Frontmatter Key/Value Properties & Post-Implementation 3-Pass Performance Refactor

## Context
- Language detection is `MarkdownSmartNewlineEngine.isMarkdownFilename(activeTabTitle)` re-evaluated with `NSString.pathExtension` at 6+ sites of `SwiftEditRootView` (smart newline, diagnostics refresh, list indent, Markdown menu gate, preview, editor prop) on every render/keystroke; `.yml`/`.yaml` fall into the non-Markdown branch (`Lint: Off`, no highlighting).
- Frontmatter is detected twice: `YAMLFrontmatterScanner.maskedLineCount` over `MarkdownLineIndex` (UTF-16) and `MarkdownAllConstructsLinter.detectYAMLFrontmatterMaskedLinesUTF8` (UTF-8), and only used for masking.
- Highlighting runs in `TextKit2EditorView.installGFMValidator` (`renderingAttributesValidator`, viewport fragments) via `MarkdownSyntaxHighlighter.spans(index:visibleRange:)` over a coordinator-cached `MarkdownLineIndex` keyed by `(DocumentID, BufferRevision)` but retagged on same-length local edits.
- `updateNSView` performs `textView.string != text` (`O(N)` bridge + compare) when the model revision changes without a pending local edit.

## Goals / Non-Goals
- Goals: native `.yml`/`.yaml` editing (highlight, lint, outline, smart indent); inline frontmatter key/value styling and a Properties panel for top-level scalars/lists; grey lighter keys vs full-color values; zero new dependencies; `UI-012` budgets preserved; 3 measured, benchmark-gated perf passes after implementation.
- Non-Goals: full YAML 1.2 compliance (anchors resolution, merge keys `<<`, multi-document streams beyond tokenizing `---`/`...`, flow mappings editing), JSON Schema validation, YAML formatting/re-serialization of whole documents, TOML (`+++`) frontmatter, Properties panel for `.yml` files, any Constitution amendment.

## Architecture Memory & Module Boundaries (AR-###)
- **AR-001**: All YAML engines live in `SwiftEditCore/MarkdownLintAndFormat/YAMLSupport/` (pure `Foundation`, `.macOS(.v26)`/`.iOS(.v26)`), `DocumentLanguage` in `SwiftEditCore/DocumentCore/`; `SwiftEditUI` consumes them inward only (`AR-006`); `PropertiesPanelView` and palette tokens live in `SwiftEditUI` (`AR-002`, `AR-010`).
- **AR-018**: `SwiftEditWorkbenchModel` coordinates (parse → present → writer `TextEdit` → `DocumentSession.applyTextEdits`) but never decides editability, quoting or YAML structure; those decisions belong to `FrontmatterPropertyParser`/`FrontmatterPropertyWriter` (`BC-001`).

## Constitutional Alignment & Module Boundaries (AR-### / UI-### / DATA-### / API-###)
- **Single-Reference Lock**: `constitution/01-architecture/dependency-and-layering.md`, `constitution/02-domain/bounded-context-ownership.md`, `constitution/03-ui-ux/design-system-and-tokens.md`, `constitution/03-ui-ux/accessibility-and-cwv.md`, `constitution/06-testing-fitness/tdd-and-unit-testing.md`, `constitution/07-security-privacy/stride-and-gdpr-privacy.md`, `constitution/08-sdd-governance/artifact-traceability.md` (one micro-file per active step).
- **Bounded Context Classification (`BC-002`)**: `MarkdownLintAndFormat` — Core (YAML engines, frontmatter properties); `DocumentCore` — Core (`DocumentLanguage`, single mutation path); `WorkspaceAndTabSession` — Supporting (per-tab cached language); `SearchDiffAndBracketEngine` — Supporting (unchanged, perf pass candidate only).

## Decisions
- **D1 `enum DocumentLanguage` over a language-plugin protocol**: only 3 variants and 2 with behavior (< Rule of Three for polymorphism, `AR-009`); a `switch` keeps dispatch explicit and allocation-free. Alternative `protocol LanguageSupport` rejected as speculative generality.
- **D2 Own zero-regex YAML subset tokenizer over `Yams`/libyaml**: keeps `AR-005` (single external dependency), avoids C parser attack surface and alias expansion entirely; the editor needs token boundaries and top-level structure, not a full object graph. Alternative `Yams` rejected (supply chain + `Constitution` amendment + billion-laughs exposure).
- **D3 Line-oriented engines over a shared `MarkdownLineIndex`**: YAML engines consume the same per-revision UTF-16 line table (line starts + slices) so highlighting stays `O(viewport)` and no extra buffer copy is created; frontmatter range comes from `YAMLFrontmatterScanner.maskedLineCount` (single source; the UTF-8 duplicate is removed in a perf pass).
- **D4 Span kinds**: add `MarkdownSyntaxKind.yamlKey`, `.yamlValue`, `.yamlPunctuation`, `.yamlComment` (Core returns kinds, never colors, `AR-002`); the TextKit 2 validator maps `yamlKey` → `yamlKeyForeground` + cached light-weight font, `yamlValue` → no attribute (canvas text 21:1), punctuation/comment → `secondaryForeground`.
- **D5 Properties writer emits one minimal `TextEdit`**: replace only the owned entry's line range (or insert before the closing delimiter), never re-serialize the block; preserves comments and ordering; round-trip property: `parse(apply(write(model, op))) == op(model)`. Quoting: plain scalar when safe, else double-quoted with `\\`, `\"`, `\n`, `\t` escapes.
- **D6 Panel placement**: collapsible strip above the editor column inside the right column (under `EditorTabStrip`), collapsed state per tab in memory only; hidden in distraction-free mode; keyboard: `Tab` between fields, `Return` commits, `Escape` reverts field.
- **D7 Lint wiring**: `refreshDiagnosticsForActiveDocument` dispatches by `DocumentLanguage`; YAML lint follows the same `4096`-byte sync/async threshold and `(DocumentID, BufferRevision)` race guard; Markdown tabs append frontmatter `YML00x` diagnostics to the 26-rule output.
- **D8 Perf pass protocol**: (1) `docs/qa/perf-analysis-016.md` from `swift test` microbenchmarks (`ContinuousClock`, median of 15 runs, 20k-line MD and YAML fixtures) plus a read-only scan of `Sources/` for `O(N)` per-keystroke work; (2) each pass = RED benchmark with threshold + golden equivalence test → GREEN refactor → REFACTOR; (3) candidates `PERF-C1` cached `DocumentLanguage`, `PERF-C2` shared `DocumentTextIndexCache` (one UTF-16 index per revision consumed by highlighter, outline, linter frontmatter mask, preview, YAML engines; UTF-8 duplicate detector removed), `PERF-C3` revision/identity-based text sync in `updateNSView` (no full-string compare) and strict `(DocumentID, BufferRevision)` index invalidation (no same-length retag), `PERF-C4` split `@Observable` sub-models (status bar metrics, diagnostics, properties) to narrow SwiftUI invalidation; analysis may replace any candidate with a higher-ranked measured bottleneck.

## Risks / Trade-offs
- YAML subset mis-tokenizes exotic syntax (multi-line plain scalars, complex keys `? `) → tokens degrade to `value`, never crash; outline/lint only rely on simple top-level structure; documented Non-Goals.
- Light font weight may reduce legibility at `50%` zoom → weight `.light` (not `.ultraLight`) and contrast `>= 4.5:1` verified by palette fitness test.
- Panel and inline edits racing → writer requires current `BufferRevision`; panel re-parses on every revision (debounced with the existing `180 ms` AST cadence).
- Perf pass `PERF-C4` (model split) is invasive in a 2.8k-line file → restricted to observation boundaries, behind golden tests; may be swapped for a cheaper measured bottleneck by the analysis.
- Same-length retag removal (`PERF-C3`) could increase index rebuilds → rebuild is `O(N)` once per revision off the hot fragment path; measured by benchmark.

## Migration Plan
- No persisted data changes; no `SessionRecovery` manifest schema changes; existing tabs re-resolve language on restore.
- Delivery order: Wave 1 → 2 → 3 → 4 with green suite; then Wave 5 (analysis report, 3 passes); then `/myspec-sync` for the two modified living specs.

## Security Review
- Reviewer: cyber-security-expert
- Date: 2026-11-21
- Verdict: approved # approved | changes-required
- Open items: none
