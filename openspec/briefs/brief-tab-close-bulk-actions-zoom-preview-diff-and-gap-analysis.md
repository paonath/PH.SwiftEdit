# Brief: Clean & Bulk Tab Operations, Zoomed Preview & Diff, Code Copy, Native Mermaid/Markmap, Disk Watcher, Folder Search, JSON & Editor Suite

- Branch: main
- Phase: draft
- Date: 2026-11-25
- Modifies-Specs: none (net-new capability `tab-close-bulk-actions-zoom-preview-diff-and-gap-analysis`)
- Security Review: approved

## Disambiguated Prompt & Expanded Scope

1. **Clean & Baseline-Reverted Tab Immediate Closure (`REQ-001`)**:
   - Newly created empty `Untitled` tabs (`newUntitledTab()`) start with `isDirty == false`, and edited tabs reverted back to their saved/initial baseline (`text` and `LineEnding` matching `savedBaselineByID[id]`, e.g. via `Cmd+Z`) reset `isDirty = false` and close immediately without confirmation.
2. **Tab Right-Click Bulk Actions, Reopen Closed Tab & Tab Shortcuts (`REQ-002`)**:
   - Right-click tab context menu adds **Close Tabs to the Right**, **Close Other Tabs**, **Close All Unpinned Tabs** (all preserving pinned tabs), and **Close All Tabs** (`forcePinned: true`), with sequential dirty prompts (`Cancel` halts remaining queue) and immediate `.recovery` unlink.
   - Adds middle-click tab close, **Reopen Closed Tab (`Shift+Cmd+T`, ring buffer <= 20)**, and keyboard tab navigation (`Ctrl+Tab` / `Shift+Cmd+]` next, `Ctrl+Shift+Tab` / `Shift+Cmd+[` previous, `Cmd+1..9` index jump).
3. **Zoom-Scaled Markdown Preview, Frontmatter Metadata Card & Mandatory Code-Fence Copy to Clipboard (`REQ-003`)**:
   - Scales all `MarkdownNativePreviewView` blocks linearly across `50%..300%` zoom via `AppTypography`, renders YAML frontmatter as a structured metadata card, and places a **Copy to Clipboard button in the top-right corner of every triple-backtick fenced block** (`>= 24 pt` target, copying raw fence contents via `clipboardWriter` with transient `"Copied"` feedback).
4. **Feasibility Verification & Native Zero-WebKit Markmap/Mindmap + Core Mermaid Preview (`REQ-004`)**:
   - **Feasibility Conclusion**: `Constitution.md` (`AR-002`, `AR-005`, `SEC-004`) forbids `WebKit`, network sockets, and unratified external packages. Both **Markmap / Mindmaps** (```` ```markmap ````, ```` ```mindmap ````, ```` ```mermaid\nmindmap ````) and core **Mermaid** diagrams (`flowchart`/`graph`, `sequenceDiagram`, `stateDiagram`/`stateDiagram-v2`) are 100% feasible natively via deterministic pure-`Foundation` parsers in `SwiftEditCore` (`<= 256` nodes, `maxDepth <= 12`, `<= 64 KiB` cap) + vector SwiftUI `Canvas` rendering in `SwiftEditUI`, with `50%..300%` zoom scaling, a top-right `Diagram / Code` toggle + **Copy to Clipboard** button, and graceful code-block fallback for unsupported diagram types.
5. **Zoom-Scaled Side-by-Side Diff View With Line Numbers, Hunk Navigation & Changes-Only Toggle (`REQ-005`)**:
   - Scales `diffPanel` (`role: .editor`) and `compareHeader` (`>= 24 pt` targets) across `50%..300%` zoom, renders `lhsLineNumber` / `rhsLineNumber` columns, adds **Previous / Next Change (`F7` / `Shift+F7`)** hunk jumps, and adds an **Only Differences** filter.
6. **External Disk File Watcher & Reload / Conflict Banner (`REQ-006`)**:
   - Confined `DispatchSource` vnode + activation watcher: auto-reloads clean (`!isDirty`) file-backed tabs modified externally (quarantining if binary), shows a **Reload from Disk / Keep Mine / Compare** banner on dirty (`isDirty`) tabs without overwriting edits, and adds manual **Revert to Saved (`Reload from Disk`)**.
7. **Workspace-Wide Literal Find in Folder & Quick File Open (`REQ-007`)**:
   - **Quick Open (`Cmd+T`)** fuzzy/substring file switcher (`<= 10,000` confined text files) and **Find in Folder (`Ctrl+Shift+F`)** bounded literal multi-file search (`<= 5,000` matches, zero regex `CWE-1333`, click/Enter jump to file & line).
8. **Find & Replace Bar Upgrades (`REQ-008`)**:
   - Adds **Whole Word** boundary matching, **`active of total` (`3 of 12`)** live match counter, **Find / Replace in Selection**, and **Use Selection for Find (`Opt+Cmd+E`)**.
9. **Atomic Line Manipulation & Trim Trailing Whitespace (`REQ-009`)**:
   - Adds **Move Line Up / Down (`Option+Up` / `Option+Down`)**, **Delete Line (`Ctrl+Shift+K`)**, **Join Lines (`Ctrl+J`)**, **Sort Selected Lines (Asc/Desc)**, and **Trim Trailing Whitespace** (command + optional `trimTrailingWhitespaceOnSave` JSON preference).
10. **Native JSON / JSONL Support (`REQ-010`)**:
    - Extends `DocumentLanguage` with `.json` (`json`, `jsonl`), viewport zero-regex `JSONSyntaxHighlighter`, bounded `JSONStructureLinter` (`depth <= 128`), and single-batch **Format JSON (Pretty-Print)** / **Minify JSON**.
11. **Live Log Tail Severity Pills & Substring Filter (`REQ-011`)**:
    - Adds non-destructive `All / Info+ / Warn+ / Error` severity pills and live literal filter text to `LogTailPanelView`.
12. **Status Bar Metrics, Interactive Encoding Menu, Read-Only Git Branch Badge & Gap Analysis Doc (`REQ-012`)**:
    - Adds selection char/line counts + Markdown word count, interactive **Encoding menu** (`UTF-8`, `UTF-16 LE`, `UTF-16 BE`), read-only confined `.git/HEAD` branch badge (zero subprocesses), `docs/analysis/app-gap-analysis.md` (documenting the full audit, Mermaid/Markmap feasibility, and deferred item #11 HTML/PDF export), and synchronized `docs/guide/` + bundled Help chapters.

## `/qa` Decision Log

| # | Question | Decision |
| :--- | :--- | :--- |
| 1 | Clean/reverted tab close & bulk close behavior on pinned and dirty tabs | Clean + revert-aware (`isDirty = false`, closes immediately); right/other/unpinned preserve pinned; `Close All Tabs` closes pinned too; sequential dirty prompts (`Cancel` halts remaining) |
| 2 | Preview/Diff zoom mode & gap analysis deliverable | Synchronized global zoom (`50%..300%`) via `AppTypography` with `>= 24 pt` targets + `docs/analysis/app-gap-analysis.md` |
| 3 | Expanded scope (Gap Analysis 1–10 excluding 11 + Preview Code Copy + Mermaid/Markmap feasibility) | Include items 1–10 (exclude 11 HTML/PDF export), mandatory top-right Copy to Clipboard on all fenced blocks in Preview, and **Native SwiftUI `Canvas` Zero-WebKit** renderer for Markmap/Mindmaps and core Mermaid (`flowchart`/`graph`, `sequenceDiagram`, `stateDiagram`, `mindmap`) with `Diagram / Code` toggle and code fallback (`Constitution.md` unchanged) |

## 6-Category STRIDE Security Check

| Threat | Mitigation |
| :--- | :--- |
| **Spoofing** | Queued bulk-close `DocumentID`s, `Reopen Closed Tab` paths, Quick Open entries, and `.git/HEAD` resolution verify canonical path confinement via `resolvingSymlinksInPath` inside granted scope (`SEC-002`, `SEC-003`). |
| **Tampering** | Baseline dirty check verifies both `text` and `LineEnding`; external disk changes on dirty buffers never overwrite unsaved edits without explicit user confirmation (`DATA-004`, `DATA-006`). |
| **Repudiation** | Sequential dirty tab prompts and external-modification conflict banners name the exact affected file and require explicit user choice (`DATA-006`). |
| **Information Disclosure** | Bulk close immediately unlinks `<UUID>.recovery` snapshots (`0700`/`0600`), stops vnode descriptors, and clears undo/thumbnail/diff caches; `.git/HEAD` parser reads at most `256` UTF-8 bytes and strips credentials/paths (`SEC-007`, `SEC-011`). |
| **Denial of Service** | Diagram parsers enforce `<= 256` nodes, `maxDepth <= 12`, and `<= 64 KiB` source (`CWE-400`, `CWE-674`); JSON linter caps depth at `128`; folder search caps at `10,000` files / `5,000` matches with zero regex (`CWE-1333`); zoom clamps to `50%..300%` (`SEC-012`). |
| **Elevation of Privilege** | Preview diagrams and code copy run 100% in SwiftUI/`Canvas` with zero `WebKit`, zero JS eval, zero subprocesses (`.git/HEAD` is pure file I/O), inert raw HTML, and confirmed links (`SEC-004`). |

## Path Coverage Matrix (`P1..P12`, `N1..N13`)

- `REQ-001`: `P1` (clean/reverted tab instant close) / `N1` (dirty text or `LineEnding` prompts; pinned single close blocks)
- `REQ-002`: `P2` (bulk close actions, `Shift+Cmd+T` reopen, tab shortcuts & middle-click) / `N2` (`Cancel` halts queue; empty scopes no-op) / `N3 [security]` (immediate `.recovery` unlink, vnode stop & cache purge)
- `REQ-003`: `P3` (`50%..300%` Preview zoom, YAML frontmatter card & top-right Copy to Clipboard on fenced blocks) / `N4 [security]` (clamped zoom, non-stale fonts, inert `<script>`, blocked `javascript:`, `64`-image cap)
- `REQ-004`: `P4` (native SwiftUI `Canvas` Markmap/Mindmap & core Mermaid rendering, zoom scaling, `Diagram / Code` toggle & Copy button) / `N5 [security]` (`> 256` nodes, `> 12` depth, cyclic graphs, or unsupported syntax degrade safely to code view without recursion or WebKit)
- `REQ-005`: `P5` (`50%..300%` Diff zoom, line numbers, `F7`/`Shift+F7` hunk jumps & Only Differences filter) / `N6` (`>= 24 pt` targets at `50%` zoom & safe degraded diffs)
- `REQ-006`: `P6` (external disk watcher auto-reloads clean tab & shows conflict banner on dirty tab + manual Revert) / `N7 [security]` (external binary replacement or symlink escape quarantines or aborts fail-closed without overwriting dirty edits)
- `REQ-007`: `P7` (`Cmd+T` Quick Open & `Ctrl+Shift+F` literal Find in Folder jump to file and line) / `N8 [security]` (escaping symlinks, binary files, and `> 5,000` match floods are skipped/capped without reading external targets)
- `REQ-008`: `P8` (Whole-Word, `3 of 12` counter, Find/Replace in Selection & `Opt+Cmd+E`) / `N9` (empty selection, out-of-bounds query, or zero matches handled safely)
- `REQ-009`: `P9` (Move Line Up/Down, Delete Line, Join Lines, Sort Lines & Trim Trailing Whitespace) / `N10` (top/bottom boundary moves stay in-bounds and binary/tail-only tabs reject mutations)
- `REQ-010`: `P10` (`.json`/`.jsonl` resolution, viewport highlighting, diagnostics & Pretty-Print/Minify) / `N11 [security]` (`> 128` JSON nesting depth, binary `.json`, or `> 4096` UTF-16 lines degrade safely without stack overflow)
- `REQ-011`: `P11` (live Log Tail severity filter pills & substring filter) / `N12` (clearing filter restores full bounded tail window; invalid/empty matches never corrupt incoming stream)
- `REQ-012`: `P12` (status bar selection/word counts, Encoding menu, `.git/HEAD` badge, `app-gap-analysis.md` & synced guides) / `N13 [security]` (symlinked `.git/HEAD` outside scope, oversized/malformed `HEAD`, or dirty reopen-encoding attempt fails closed or requires confirmation)
