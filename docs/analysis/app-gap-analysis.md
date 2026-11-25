# SwiftEdit Application Gap Analysis & Architecture Feasibility Report

## 1. Executive Summary

This analysis audited the **SwiftEdit** macOS workspace across tab management, native Markdown preview, Side-by-Side Diff comparison, workspace navigation, search, editing ergonomics, log tailing, status-bar telemetry, and constitutional boundaries (`openspec/Constitution.md` v1.7.0).

Every prioritized functional gap selected for implementation (`REQ-001` through `REQ-012`) preserves SwiftEdit's core architectural invariants:
- **Zero WebKit & Zero Network Execution (`AR-002`, `SEC-004`)**: All Markdown, Markmap, and Mermaid rendering runs 100% offline in native SwiftUI + CoreGraphics `Canvas` without `WKWebView`, JavaScript engines, or external network sockets.
- **Strict Resource & Recursion Ceilings (`CWE-400`, `CWE-674`, `CWE-1333`)**: Every parser, crawler, and linter uses iterative stacks/queues, bounded memory caps, and literal-only matching.
- **Constitutional Non-Goals Preserved (`BC-005`)**: Language Server Protocol (LSP), git staging/commit orchestration, AI cloud assistants, multi-window splits, and third-party extension marketplaces remain out of scope by design.

---

## 2. Prioritized Functional Audit & Resolution Matrix

| # | Capability Area | Pre-028 Gap | Resolution in Spec 028 | Status |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **Clean & Reverted Tab Close** | Untouched `Cmd+N` tabs and `Cmd+Z`-reverted tabs prompted for save confirmation. | `newUntitledTab()` starts `isDirty == false`; `reconcileDirtyState(against:)` resets `isDirty` when text and `LineEnding` match `savedBaselineByID`. | **Implemented (`REQ-001`)** |
| **2** | **Bulk Tab Actions, Middle-Click & Reopen Closed Tab** | No right-click bulk close, middle-click close, tab cycling shortcuts, or `Shift+Cmd+T` reopen. | Added *Close Tabs to the Right*, *Close Other Tabs*, *Close All Unpinned Tabs*, *Close All Tabs*, middle-click close, `Shift+Cmd+T` (`<= 20` MRU), `Shift+Cmd+]`/`[`, `Ctrl+Tab`, and `Cmd+1..9`. | **Implemented (`REQ-002`)** |
| **3** | **Markdown Preview Zoom, Frontmatter Card & Code Copy** | Preview used fixed font sizes, rendered YAML frontmatter `---` as thematic breaks, and lacked code-block copy buttons. | Linear `50%..300%` zoom via `ZoomedChromeMetrics`, structured `PROPERTIES` frontmatter card, and mandatory top-right **Copy** button (`>= 24 pt`) on every fenced code block. | **Implemented (`REQ-003`)** |
| **4** | **Native Markmap & Mermaid Preview Diagrams** | Diagram fences rendered only as raw monospaced text. | Pure-Swift iterative parsers & tidy-tree / layered-DAG layouts (`DiagramSupport/`) rendered on SwiftUI `Canvas` with `Diagram / Code` toggle and Copy button. | **Implemented (`REQ-004`)** |
| **5** | **Zoomed Diff View, Line Numbers & Hunk Navigation** | Side-by-Side Diff lacked zoom scaling, line numbers, `F7` hunk jumping, and context folding. | Added `50%..300%` `.editor` font scaling, `lhsLineNumber`/`rhsLineNumber` gutters, `F7`/`Shift+F7` hunk navigation, and `Only Diff` (`±2` context lines). | **Implemented (`REQ-005`)** |
| **6** | **External Disk Change Watcher & Revert to Saved** | External edits (`git checkout`, formatters, CLI tools) were not detected on open tabs. | Confined `O_EVTONLY` `ExternalFileChangeMonitor` auto-reloads clean tabs, shows *Reload from Disk / Keep Mine / Compare* on dirty tabs, plus `File → Revert to Saved`. | **Implemented (`REQ-006`)** |
| **7** | **Quick Open (`Cmd+T`) & Find in Folder (`Ctrl+Shift+F`)** | Opening files in nested trees required manual folder stepping; search was single-tab only. | Confined iterative BFS indexer (`<= 10,000` files) powering `Cmd+T` Quick Open and `Ctrl+Shift+F` literal multi-file search (`<= 5,000` matches). | **Implemented (`REQ-007`)** |
| **8** | **Enhanced Find & Replace (`Ww`, `In Sel`, `1 of N`, `Opt+Cmd+E`)** | Find bar lacked Whole-Word, selection-scoped Replace All, active match index, and `Opt+Cmd+E`. | Added `Ww` Whole-Word boundary check, `In Sel` range clamping, `k of N` match indicator, and `Opt+Cmd+E` *Use Selection for Find*. | **Implemented (`REQ-008`)** |
| **9** | **Atomic Line Commands & Trim Trailing Whitespace on Save** | Common line manipulations (`Option+Up`/`Down`, `Ctrl+Shift+K`, `Ctrl+J`, Sort, Trim on Save) were missing. | Implemented single-revision `LineEditCommands` preserving `LineEnding` plus persisted `trimTrailingWhitespaceOnSave` setting. | **Implemented (`REQ-009`)** |
| **10** | **Native `.json` & `.jsonl` Support** | `.json` and `.jsonl` files opened as plain text without highlighting, linting, or formatting. | Added `DocumentLanguage.json`, viewport-only `JSONSyntaxHighlighter`, iterative `JSONStructureLinter` (`maxDepth = 128`), Pretty-Print, and Minify. | **Implemented (`REQ-010`)** |
| **11** | **Offline HTML / PDF Export** | Exporting rendered Markdown to standalone HTML or paginated PDF. | **Explicitly Excluded**: Excluded per user scope decision and `SEC-004` print-spooler / `WebKit` pagination isolation. | **Excluded by Scope** |
| **12** | **Log Tail Filtering, Enriched Status Bar & Git Branch Badge** | Live Log Tail lacked severity/substring filters; status bar lacked selection/word counts, encoding menu, and Git branch badge. | Added non-destructive `All / Info+ / Warn+ / Error` + `<= 256`-char filter, selection/word counters, Encoding menu, and zero-subprocess `.git/HEAD` badge. | **Implemented (`REQ-011`, `REQ-012`)** |

---

## 3. Feasibility Study: Native Markmap & Mermaid Rendering Without WebKit

### Why `WKWebView` + Bundled JS Was Rejected
Embedding `mermaid.min.js` or `markmap-view` inside `WKWebView` would:
1. Violate `AR-002` and `SEC-004` (which prohibit `WebKit` and HTML/JS execution surfaces in `SwiftEditCore` and `SwiftEditUI`).
2. Inflate idle RSS well beyond the `50 MB` constitutional budget (`UI-012`) by spawning WebContent XPC helper processes.
3. Re-introduce DOM/SVG XSS surfaces (`<img onerror=...>`, `foreignObject`, `javascript:` URIs) inside untrusted Markdown files.

### Native SwiftUI `Canvas` Solution (`DiagramSupport/`)
Instead, SwiftEdit implements a deterministic two-stage native pipeline:
1. **Pure-`Foundation` Parsing & Layout (`SwiftEditCore`)**:
   - **Markmap & Mindmap (`MarkmapParserAndLayout`)**: parses ATX headings (`#`..`######`), nested Markdown lists, and Mermaid `mindmap` indentation into a bounded tree (`maxNodes = 256`, `maxDepth = 12`) and computes an `O(N)` horizontal tidy-tree layout.
   - **Core Mermaid (`MermaidParserAndLayout`)**: parses `flowchart` / `graph` (`TD`, `TB`, `LR`, `RL`, `BT`, shapes, edge styles, edge labels, `subgraph`), `sequenceDiagram` (participants, solid/dashed arrows, self-messages), and `stateDiagram` / `stateDiagram-v2`, using bounded Bellman-Ford rank relaxation (`<= 12` passes) so cyclic graphs (`A --> B --> A`) lay out deterministically with **zero recursion** (`CWE-674`).
2. **Vector Rendering (`MarkdownDiagramPreviewView` in `SwiftEditUI`)**:
   - Draws crisp vector curves, shapes, lifelines, arrowheads, and `Text(verbatim:)` labels via SwiftUI `Canvas` scaled linearly by `ZoomedChromeMetrics.factor` (`50%..300%`).
   - Exposes a top-right **`Diagram / Code`** toggle and **Copy** button (`>= 24 pt`), degrading unsupported diagram types (e.g., `gantt`, `pie`) or oversized inputs (`> 64 KiB`, `> 256` nodes, `> 512` edges, `> 12` depth) gracefully to the standard fenced code block view.
