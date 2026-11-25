---
title: "Text Editing, Highlighting, Completion & Search"
summary: "Guide to the TextKit 2 editor canvas, zoom, word wrap, atomic line commands, double-click selection cycle, semantic syntax color schemes, HTML highlighting, ghost-text completion, contextual actions, Find & Replace, and File Compare."
commit: "b6ee821"
date: "2026-11-25"
branch: "main"
review_date: "2026-12-25"
---

# Chapter 2: Editing, Highlighting, Completion & Search

## Functional: TextKit 2 Editor Canvas

SwiftEdit renders text through a native **TextKit 2** (`NSTextLayoutManager`) view configured for predictable plain-text and source editing:

- **No Automatic Substitutions**: smart quotes, smart dashes, spelling auto-correction, and automatic text replacement are disabled so code, Markdown, YAML, JSON, and HTML are never altered unexpectedly.
- **Per-Tab Undo & Redo (`Cmd+Z` / `Shift+Cmd+Z`)**: each open tab owns an isolated `UndoManager` so switching tabs or closing another tab never mixes or corrupts undo history.
- **Word Wrap (`Cmd+W`)**: toggles soft line wrapping against the viewport width versus horizontal scrolling. The setting is persisted in `~/.SwiftEdit/settings.json`.
- **Proportional Zoom (`Cmd++`, `Cmd+-`, `Cmd+0`)**: scales the editor font from `50%` to `300%` in `10%` increments and proportionally scales the header, tab strip, Folder Navigator, Markdown preview, File Compare pane, and line-number gutter while keeping minimum hit targets accessible.
- **Duplicate Line or Selection (`Cmd+D`)**: with no selection, duplicates the current line onto a new line below; with an active selection, duplicates the selected range immediately after it as a single undoable edit.
- **Encoding, Line Endings, Selection & Git Branch**: preserves `UTF-8` and `UTF-16` encodings and `LF` (Unix/macOS), `CRLF` (Windows), or `CR` (Classic Mac) line endings. Click the encoding or line-ending menus in the status bar to convert or reopen encodings and switch line endings; the status bar also displays selection character/line counts, Markdown word counts, and the current `.git/HEAD` branch name.
- **Atomic Line Commands**: move lines up or down (`Option+Up` / `Option+Down`), delete lines (`Ctrl+Shift+K`), join lines (`Ctrl+J`), sort lines ascending or descending, or trim trailing whitespace manually or automatically on save (`Settings`).

---

## Functional: Selection, Semantic Color Schemes & Multi-Level Highlighting

### Selectable Semantic Syntax Color Schemes

SwiftEdit includes four zero-dependency, WCAG-AA-verified (`>= 4.5:1`) semantic syntax color schemes — **SwiftEdit Default**, **Catppuccin**, **GitHub**, and **Tokyo Night** — across both Light (`#FFFFFF`) and Black (`#000000`) modes. Switch schemes live in **Settings → Fonts (Editor) → Syntax Scheme** (`Cmd+,`).

### Repeated Double-Click Cycle

Double-clicking text cycles through three states:
1. **First double-click**: selects the word under the pointer.
2. **Second double-click**: expands to the full whitespace-free token (for example `contextual-menu` or `https://example.com/path`).
3. **Third double-click**: clears the selection back to a caret.

### Secondary Word & Token Occurrence Highlighting

Whenever you select any word or token of at least 2 characters — using a mouse double-click, mouse drag, or keyboard `Shift + Arrow` keys — SwiftEdit immediately highlights **all other occurrences** of that selection across the active document:

- **Primary Selection**: high-contrast deep purple (`#6D28D9` in Light, `#A78BFA` in Dark).
- **Secondary Occurrences**: soft purple pill (`#DDD6FE` in Light, `#3B1D6E` in Dark) paired with a `1.5 pt` bottom underline (`#7C3AED` / `#C4B5FD`) so matches remain distinguishable without relying on color alone.
- Works for whole words, partial words, symbol sequences (such as `->`), tokens inside backticks, and across the integrated Log Viewer (Plain, Live Direct, and Live Inverse modes).

![Secondary Word Occurrence Highlighting](images/word-occurrences.png)

### Backtick Code, Nested Brackets & Native HTML Highlighting

- **Backtick Spans**: inline `` `code` `` and fenced multiline code blocks receive an antique parchment-yellow highlight with WCAG AAA contrast in both Light and Dark modes.
- **Nested Brackets**: `()`, `[]`, and `{}` pairs are depth-colored; placing the caret on a bracket highlights its matching partner. Unbalanced brackets are highlighted in red and counted in the status bar.
- **HTML / HTM (`HTMLSyntaxHighlighter`)**: `.html` and `.htm` files receive viewport-only highlighting for doctypes, comments, tag names, attribute names, quoted attribute values, and HTML character entities (with double-extension smuggling such as `.html.bak` classified safely as plain text).

---

## Functional: Inline Ghost-Text Word Completion

As you type a word prefix of 2 or more characters, SwiftEdit suggests a muted inline grey completion derived from words (longer than 3 characters) already present in the current document:

- Press **`Tab`** to accept the suggestion as a single undoable edit.
- Press **`Esc`** (or keep typing/moving the caret) to dismiss it.
- When no suggestion is visible, `Tab` retains its normal Markdown list/table indentation or tab insertion behavior.
- The word cache lives strictly in memory per document, is rebuilt off the main thread after a `350 ms` debounce, and is discarded when the tab closes.

---

## Functional: Contextual Action Palette (`Cmd+Return`) & Right-Click Menu

Press **`Cmd+Return`** anywhere in the editor (or right-click) to access contextual actions tailored to the active selection and tab state:

![Contextual Action Palette](images/contextual-palette.png)

- **Surround With…** *(when text is selected)*: wraps the active selection in inline backticks (`` `…` ``), a fenced code block (```` ```\n…\n``` ````), or parentheses (`(…)`).
- **Terminal → Send to Terminal** *(when text is selected; also available via right-click in both the editor and the Log Viewer)*: opens the embedded terminal (`Cmd+J`) if closed, writes the sanitized selection into the active shell **without pressing Return**, and moves keyboard focus to the terminal. Multiline selections display an explicit confirmation warning first and are delivered using ANSI Bracketed Paste so intermediate lines are not executed automatically.
- **Reveal in Folder Navigator** *(when the active tab is backed by a file on disk)*: expands the left Folder Navigator, navigates to the file's canonical containing directory (preserving any ancestor workspace root), refreshes the listing, and highlights the file.
- **Start Dictation Here** *(when the active tab is writable and not binary or tail-only)*: focuses the active editor text view and starts native macOS dictation at the current caret or selection.
- **Duplicate Document** *(always available on non-binary, non-tail-only tabs)*: creates a non-overwriting copy of the active document (`name copy.ext`, `name copy 2.ext`, …).
- Filter rows in the `Cmd+Return` palette by typing, navigate with `Up`/`Down` arrows, expand/collapse groups with `Right`/`Left` arrows, confirm with `Return`, or dismiss with `Esc` or any outside click.

---

## Functional: Find, Replace & Go to Line

- **Find (`Cmd+F`)**: opens the inline literal search bar with case-sensitivity (`Aa`), Whole-Word (`Ww`), Search in Selection (`In Sel`), `1 of N` active match counter, Previous/Next navigation, and **`Option+Cmd+E`** (*Use Selection for Find*).
- **Find & Replace (`Option+Cmd+F`)**: adds replacement input with **Replace** (single match, advances to next) and **Replace All** (single atomic `BufferRevision` / Undo step). `Cmd+H` remains reserved for macOS Hide.
- **Go to Line (`Cmd+G`)**: jumps directly to any 1-based line number and scrolls the target line into view.

---

## Functional: File Compare (`Shift+Cmd+D`)

Toggle the side-by-side **File Compare** pane with **`Shift+Cmd+D`** or the diff icon in the header bar:

![Find Bar and File Compare Side-by-Side Diff](images/find-and-compare.png)

- **Saved vs. Current**: by default, compares the active tab's last saved baseline (left) against its current unsaved buffer (right), highlighting removed lines in red and inserted lines in green.
- **Two-Tab Compare, Zoom & Hunk Navigation**: use the **Compare with:** picker in the diff header to compare the source tab against any other open text tab. The diff view scales proportionally with global zoom (`50%–300%`), shows left/right line numbers, jumps across hunks with **`F7` / `Shift+F7`**, and folds unchanged context via **Only Diff**.

---

## Technical: Editor & Highlighting Engines

| Engine | Source File | Complexity & Design |
| :--- | :--- | :--- |
| `SwiftEditNSTextView` & `TextKit2EditorView` | `Sources/SwiftEditUI/Views/SwiftEditNSTextViewAndUndoRegistry.swift` | Synchronous selection scanning (`updateLiveWordOccurrencesAndInvalidate`), `drawBackground(in:)` pill + underline rendering, bounded iterative sublayer invalidation, right-click `NSMenu` |
| `SyntaxColorSchemePalette` & `EditorRenderingAttributes` | `Sources/SwiftEditUI/Theme/SyntaxColorSchemePalette.swift` | Four WCAG-AA semantic syntax color schemes across Light and Black modes |
| `HTMLSyntaxHighlighter` | `Sources/SwiftEditCore/MarkdownLintAndFormat/HTMLSupport/HTMLSyntaxHighlighter.swift` | Zero-regex viewport-only HTML tokenizer with `4,096` UTF-16 line cap |
| `WordOccurrenceScanner` | `Sources/SwiftEditCore/SearchDiffAndBracketEngine/WordOccurrenceScanner.swift` | Linear $O(N)$ UTF-8 byte scan with UTF-16 offset tracking, capped at `2_000` occurrences and `2...128` UTF-16 selection length |
| `WordCompletionIndex` | `Sources/SwiftEditCore/SearchDiffAndBracketEngine/WordCompletionIndex.swift` | Sorted prefix table with $O(\log n)$ lookup, rebuilt asynchronously off `@MainActor` |
| `BracketMatcher` & `BacktickHighlightScanner` | `Sources/SwiftEditCore/SearchDiffAndBracketEngine/` | Linear scans with 4,096 UTF-16 line-length degradation guard |
| `MyersDiffEngine` | `Sources/SwiftEditCore/SearchDiffAndBracketEngine/MyersDiffEngine.swift` | Packed-arena Myers diff with `10 MiB` size cap and `500 ms` clock deadline |
| `ElementContextualActions` & `LineEditCommands` | `Sources/SwiftEditCore/MarkdownLintAndFormat/` | Surrogate-pair-safe selection wrapping, sanitized terminal payloads, and atomic single-revision line commands |
