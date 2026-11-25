# Capability: semantic-syntax-color-schemes-and-html

## Purpose
Provides four zero-dependency, WCAG-AA-verified (`>= 4.5:1`) Base16/Tinted-Theming-inspired semantic syntax color schemes (`SwiftEdit Default`, `Catppuccin`, `GitHub`, `Tokyo Night`) across Light (`#FFFFFF`) and Black (`#000000`) modes, persisted in `EditorPreferencesStore` and selectable live in Settings, alongside native zero-regex viewport `.html`/`.htm` highlighting (`HTMLSyntaxHighlighter`) and unified semantic token styling for HTML, Markdown, YAML, JSON, and Log documents.

## Requirements

### Requirement: REQ-001 Selectable WCAG-AA Semantic Syntax Color Schemes Across Five Languages
WHEN the user selects a SyntaxColorScheme in Settings or loads persisted EditorPreferences, SwiftEditUI SHALL resolve WCAG-AA-compliant semantic syntax colors for HTML, Markdown, YAML, JSON, and Log on `#FFFFFF` and `#000000` canvases without reloading open buffers [AR-005][DATA-008][UI-002][UI-003][UI-009].

#### Scenario: P1 Four Color Schemes Resolve Persist and Style HTML Markdown YAML JSON and Log
- **Path**: P1
- **Trait**: positive
- **GIVEN** the four schemes `swiftEditDefault`, `catppuccin`, `github`, and `tokyoNight` in `EditorPreferencesStore` and an open buffer
- **WHEN** the user switches `syntaxColorScheme` live in `SwiftEditWorkbenchModel` and evaluates `EditorRenderingAttributeTable`
- **THEN** preferences round-trip cleanly, the buffer revision stays unmutated, and all five languages receive scheme-specific semantic attributes

### Requirement: REQ-002 Zero-Regex Viewport-Only HTML Syntax Highlighting
WHEN a writable non-degraded `.html` or `.htm` document is laid out, DocumentLanguage and HTMLSyntaxHighlighter SHALL classify the tab as `.html` and emit bounded viewport spans for doctypes, comments, tags, attributes, strings, and entities while skipping lines over 4096 UTF-16 units [AR-002][BC-004][DATA-003][SEC-004][SEC-012].

#### Scenario: P2 HTML Files Emit Doctype Comment Tag Attribute String and Entity Spans
- **Path**: P2
- **Trait**: positive
- **GIVEN** an `index.html` document containing `<!DOCTYPE html>`, `<!-- comment -->`, `<section class="hero">&copy;</section>`, and `<br/>`
- **WHEN** `DocumentLanguage.resolve` and `DocumentSyntaxHighlighter.spans` execute
- **THEN** the language resolves `.html` (`"HTML"`) and emits `.htmlDoctype`, `.htmlComment`, `.htmlTag`, `.htmlAttribute`, `.htmlString`, and `.htmlEntity` spans

#### Scenario: N1 WCAG Contrast Malformed Preferences and Adversarial HTML Degrade Fail-Closed
- **Path**: N1
- **Trait**: security
- **GIVEN** all 4 schemes across `#FFFFFF`/`#000000`, an unknown persisted scheme key, binary/degraded/double-extension `.html` filenames, a `> 4096`-unit HTML line, and unterminated comments/quotes
- **WHEN** palette resolution, preference loading, language classification, and `HTMLSyntaxHighlighter` execute
- **THEN** every scheme token meets WCAG AA `>= 4.5:1`, unknown prefs fall back to `.swiftEditDefault`, binary/degraded/`index.html.bak` resolve `.plainText`, and overlong/unterminated HTML degrades without trapping (`SEC-012`)
