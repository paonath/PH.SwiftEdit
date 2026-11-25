# Brief: Semantic Syntax Color Schemes & Native HTML Highlighting

- **Spec ID**: `030-semantic-syntax-color-schemes-and-html`
- **Mode**: `myspec-quick`
- **Branch**: `main` (`implemented`)
- **Date**: `2026-11-25`
- **Security Review**: approved

## 1. Disambiguated Prompt & `/qa` Decision Log
- User requested online research on open-source semantic color schemes for text editors and semantic syntax highlighting across **HTML**, **Markdown**, **YAML**, **JSON**, and **Log**.
- Research identified **Tinted Theming / Base16 (MIT)** palettes (**Catppuccin**, **GitHub**, **Tokyo Night**) as zero-dependency pure-Swift static tables respecting `AR-005` (no unratified SPM packages), `SEC-004` (zero WebKit/JS), `UI-002` (`#FFFFFF`/`#000000` canvas), and `UI-009` (WCAG AA `>= 4.5:1`).
- User approved the recommended scope: implement 4 selectable schemes (`SwiftEdit Default`, `Catppuccin`, `GitHub`, `Tokyo Night`), add `DocumentLanguage.html` + viewport-only zero-regex `HTMLSyntaxHighlighter`, wire semantic rendering slots across all 5 languages, persist in `EditorPreferencesStore`, and add Settings picker.

## 2. STRIDE Summary
| Category | Assessment & Mitigation |
| :--- | :--- |
| Spoofing | Final-extension-only `.html`/`.htm` resolution blocks double-extension smuggling (`page.html.bak` -> `.plainText`). |
| Tampering | Malformed `swiftedit.appearance.syntaxColorScheme` values fail closed to `.swiftEditDefault`; switching schemes never mutates open document buffers (`UI-003`). |
| Repudiation | Deterministic pure-Swift palette tables and viewport span emitters. |
| Information Disclosure | Pure offline static palettes with zero network or WebKit surface (`SEC-004`). |
| Denial of Service | Zero-regex `O(L)` `HTMLSyntaxHighlighter` skips lines `> 4096` UTF-16 units and degrades unclosed comments/quotes safely (`CWE-400`, `CWE-1333`, `SEC-012`). |
| Elevation of Privilege | HTML is highlighted as inert text only; zero HTML/JS execution (`SEC-004`). |

## 3. Implemented Paths (`Tests/SwiftEditTests/SemanticSyntaxColorSchemesAndHTMLTests.swift`)
- `P1`: All 4 schemes resolve distinct Light/Black palettes, persist round-trip in `EditorPreferencesStore`, switch live without buffer mutation, and emit semantic attributes across HTML, Markdown, YAML, JSON, and Log.
- `P2`: `DocumentLanguage.html` resolves `.html`/`.htm` (`"HTML"` label) and `HTMLSyntaxHighlighter` emits doctype, comment, tag, attribute, string, and entity spans in viewport.
- `N1` (`Trait: security`): All 64 scheme foreground tokens satisfy WCAG AA `>= 4.5:1` on `#FFFFFF`/`#000000`; malformed prefs fail closed; binary/degraded/double-extension `.html` force `.plainText`; overlong `> 4096` and unterminated HTML lines degrade safely.
