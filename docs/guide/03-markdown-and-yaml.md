---
title: "Markdown Authoring, Linting, Native Preview, YAML & JSON Support"
summary: "Complete guide to GitHub Flavored Markdown editing, adaptive lists, table navigation, AST formatting, 26-rule linting with quick fixes, native offline preview with Copy buttons and Markmap/Mermaid diagrams, frontmatter Properties panel, and YAML/JSON support."
commit: "b6ee821"
date: "2026-11-25"
branch: "main"
review_date: "2026-12-25"
---

# Chapter 3: Markdown, YAML & JSON

## Functional: GitHub Flavored Markdown (GFM) Authoring

SwiftEdit automatically detects `.md`, `.markdown`, `.mdown`, `.mkd`, and `.mkdn` files (and new untitled tabs) as Markdown and provides viewport-only syntax highlighting (themed by your active **Syntax Color Scheme**) plus structured authoring commands:

| Command | Shortcut | Action |
| :--- | :--- | :--- |
| **Bold** | `Shift+Cmd+B` | Wraps or toggles `**bold**` emphasis |
| **Italic** | `Cmd+I` | Wraps or toggles `*italic*` emphasis |
| **Inline Code** | `Cmd+E` | Wraps or toggles `` `code` `` span |
| **Insert Link** | `Cmd+K` | Wraps selection as `[text](url)` |
| **Toggle Task Checkbox** | `Option+Cmd+L` | Toggles `- [ ]` ↔ `- [x]` on the current line |
| **Headings 1–6** | `Ctrl+Cmd+1` … `Ctrl+Cmd+6` | Applies ATX heading level `#` through `######` |
| **Format Document** | `Shift+Cmd+F` | Normalizes headings, list markers, and trailing spaces via AST while preserving fenced code blocks |
| **Format Section** | `Option+Shift+Cmd+F` | Formats only the lines intersecting the current selection |

### Adaptive Lists, Smart Enter & Table Navigation

- **Smart Enter**: pressing `Return` inside an unordered list (`-`, `*`, `+`), ordered list (`1.`), task list (`- [ ]`), or blockquote (`>`) automatically continues the prefix (incrementing ordered counters). Pressing `Return` on an empty marker exits the list cleanly.
- **Adaptive List Indentation (`Tab` / `Shift+Tab`)**: indents or outdents list items cleanly in a single undoable step.
- **GFM Table Navigation (`Tab` / `Shift+Tab`)**: moves forward or backward between cells in a Markdown table without intercepting `Ctrl+Tab`.

---

## Functional: 26-Rule Markdown Linter & Diagnostics UI

SwiftEdit runs a live 26-rule Markdown linter covering structure, style, and security (including unsafe link schemes such as `javascript:`, `file:`, and `data:`, entity/percent-encoded scheme obfuscation, and unsafe image traversal paths).

Diagnostics appear in three synchronized places:
1. **Inline Underlines**: dotted warnings and thick solid security errors directly in the editor. Transient warnings on the active editing line are suppressed while you type, whereas security errors are always shown.
2. **Gutter Severity Badges**: dedicated icon column in the line-number gutter; hovering over any badge shows the rule code, message, and explanation.
3. **Diagnostics Popover (`Shift+Cmd+M`)**: click the lint status indicator in the status bar or press `Shift+Cmd+M` to inspect every diagnostic, jump directly to its range, apply an individual **Quick Fix**, or run **Fix All** (idempotent, single `Cmd+Z` undo step; security diagnostics never auto-fix).

![Markdown Diagnostics Popover](images/markdown-diagnostics.png)

---

## Functional: Native Offline Markdown Preview (`Cmd+P`)

Press **`Cmd+P`** (or click the eye icon in the header bar) to toggle the side-by-side **Preview** pane:

- Rendered natively in SwiftUI with **zero WebKit and zero network access**, scaling linearly with global zoom (`50%–300%`).
- Renders line-1 YAML frontmatter as a structured **Properties** metadata card with a top-right **Copy** button, and displays a top-right **Copy** button on every fenced code block.
- Renders **`markmap` / `mindmap`** trees and core **`mermaid`** diagrams (`flowchart`/`graph`, `sequenceDiagram`, `stateDiagram`/`stateDiagram-v2`) natively on SwiftUI `Canvas` with a top-right **`Diagram / Code`** toggle and **Copy** button.
- Supports headings, paragraphs, emphasis, strikethrough, inline code, fenced code blocks, blockquotes, lists, task lists, tables, thematic breaks, and local images.
- Local image loading is strictly confined to the granted workspace folder scope (`PreviewResourceAndLinkGate`); external network images are never fetched.
- Synchronizes with the active source line as you navigate the document and releases preview/thumbnail caches immediately when closed.

![Markdown Native Preview and Frontmatter Properties Panel](images/markdown-preview-properties.png)

---

## Functional: Frontmatter Properties Panel

When a writable Markdown file begins with a YAML frontmatter block (`---` … `---` or `...`), SwiftEdit displays a compact **Properties** disclosure bar above the editor (collapsed by default):

- Shows a summary preview of top-level keys when collapsed.
- Expands to let you edit scalar values, edit list items, add new properties (`+`), or remove existing ones (`−`).
- Each property operation commits as a single `BufferRevision` and a single native `Cmd+Z` undo step.

---

## Functional: Native YAML Support

Opening a `.yml` or `.yaml` file enables native YAML tooling:

- **Syntax Highlighting**: distinguishes keys, values, punctuation, comments, quoted strings, anchors, aliases, tags, block scalars, and document markers (`---`, `...`).
- **Structural Linter (`YML001`–`YML005`)**: detects tabs in indentation, inconsistent indentation, duplicate keys within the same mapping (including quoted equivalents), malformed mappings, and unterminated quotes — also runs on Markdown frontmatter blocks.
- **Document Navigator (`Option+\`)**: lists top-level YAML keys for instant keyboard jump across `LF`, `CRLF`, and `CR` files (including files with blank lines).
- **Smart Indentation**: `Tab` / `Shift+Tab` and `Return` apply two-space YAML indentation automatically.

---

## Functional: Native JSON & JSON Lines Support

Opening a `.json` or `.jsonl` file enables native JSON tooling:

- **Viewport Syntax Highlighting**: distinguishes object keys, string values, numeric literals, `true`/`false`/`null` keywords, and structural punctuation on lines up to `4,096` UTF-16 units.
- **Iterative Structural Linter (`JSN001`–`JSN003`)**: validates braces, brackets, strings, trailing commas, and per-line JSON Lines records up to `128` nesting levels with zero recursion.
- **Pretty-Print & Minify**: press `Shift+Cmd+F` (*Format JSON Document*) for deterministic 2-space sorted-key formatting or choose *Minify JSON Document* from the Edit menu.

---

## Technical: Markdown, YAML & JSON Architecture

| Component | Source File | Key Details |
| :--- | :--- | :--- |
| `DocumentSyntaxHighlighter` & `MarkdownSyntaxHighlighter` | `Sources/SwiftEditCore/MarkdownLintAndFormat/` | Viewport-only token projection driven by `NSTextLayoutManager.renderingAttributesValidator` |
| `MarkdownAllConstructsLinter` & `MarkdownLinterRuleFamilyPasses` | `Sources/SwiftEditCore/MarkdownLintAndFormat/` | 26 rules, `250 ms` deadline with security fast-path fallback, AST depth cap (`128`) |
| `MarkdownQuickFixResolver` | `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownQuickFixResolver.swift` | Revision-pinned single quick fix and idempotent batch Fix All |
| `MarkdownPreviewProjector` & `MarkdownDiagramPreviewView` | `Sources/SwiftEditCore/MarkdownLintAndFormat/` & `Sources/SwiftEditUI/Views/` | Off-main-thread projection above `64 KiB`, zero WebKit, native SwiftUI `Canvas` diagrams |
| `FrontmatterPropertyParser` / `Writer` | `Sources/SwiftEditCore/MarkdownLintAndFormat/YAMLSupport/FrontmatterProperties.swift` | Parses and mutates YAML frontmatter into single atomic `TextEdit` operations |
| `YAMLStructureLinter` & `YAMLOutlineEngine` | `Sources/SwiftEditCore/MarkdownLintAndFormat/YAMLSupport/` | Linear `YML001`–`YML005` validation and bounds-safe key outline extraction |
| `JSONSyntaxHighlighter`, `JSONStructureLinter` & `JSONFormatter` | `Sources/SwiftEditCore/MarkdownLintAndFormat/JSONSupport/` | Viewport JSON/JSONL highlighting, iterative `128`-depth linter, and sorted-key formatting |
