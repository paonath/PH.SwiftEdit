# Spec Delta: textkit2-gfm-editor-and-native-preview

## Purpose
Extends viewport-only GFM highlighting so Markdown YAML frontmatter lines receive YAML key/value spans instead of GFM construct spans, while the Markdown body, fenced interiors, binary and degraded guarantees and the 21:1 prose contrast stay unchanged.

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-001 Viewport-Only GFM Highlighting Preserving 21:1 Prose
WHEN a visible text range of a non-degraded Markdown snapshot is laid out, the `MarkdownSyntaxHighlighter` SHALL return spans only for that range for the 12 GFM constructs using zero regex and a fence index, delegate line-1 YAML frontmatter lines to the `YAMLSyntaxHighlighter`, keep prose base colors, and return no spans for fenced interiors, non-Markdown, binary, degraded snapshots or lines over 4096 UTF-16 units [AR-002][BC-004][SEC-012].

Security-Waiver: additive narrowing only — frontmatter lines previously received GFM spans (e.g. `---` styled as thematic breaks); they now receive bounded YAML spans from the same viewport, line-cap and binary/degraded guards, so existing scenarios `P1`, `N1` and `N2` are preserved unchanged and no security guarantee is relaxed.

#### Scenario: P10 Frontmatter Lines Receive YAML Spans While the Body Keeps GFM Spans
- **Path**: P10
- **Trait**: positive
- **GIVEN** a Markdown snapshot `"---\ntitle: Hi\ntags: [a]\n---\n# Heading\n**bold**"` with a visible range covering all lines
- **WHEN** the editor pipeline computes spans for the visible range
- **THEN** lines `1..4` receive only YAML spans (`yamlKey` for `title` and `tags`, no `thematicBreak` for the delimiters) and lines `5..6` receive the GFM `heading` and `bold` spans

#### Scenario: N12 Non-Line-1 Delimiters and Overlong Frontmatter Stay GFM
- **Path**: N12
- **Trait**: negative
- **GIVEN** a Markdown snapshot whose first `---` is on line `3`, and one whose line-1 `---` is not closed within `200` lines
- **WHEN** the editor pipeline computes spans for the visible range
- **THEN** both snapshots receive no YAML spans and their `---` lines keep GFM `thematicBreak` spans

## REMOVED Requirements

## RENAMED Requirements
