# Threat Model: Clean & Bulk Tab Operations, Zoomed Preview & Diff, Code Copy, Native Mermaid/Markmap, Disk Watcher, Folder Search, JSON & Editor Suite

## 1. Asset Boundaries & Trust Zones
- **Trust Zone 1 — Pure Domain & Parser Engines (`SwiftEditCore`)**: `DocumentSession`, `WorkspaceTabSession`, `LineEditCommands`, `DocumentSearchEngine`, `WorkspaceFolderSearchEngine`, `MarkdownPreviewProjector`, `MarkdownDiagramParser` (`Markmap` / `Mermaid`), `JSONSyntaxHighlighter` / `JSONStructureLinter` / `JSONFormatter`, `LogTailBuffer`, and `GitHeadBranchReader` operating purely on `Foundation` value types with zero regex, zero subprocesses, and zero network (`[AR-001]`, `[AR-002]`, `[AR-004]`).
- **Trust Zone 2 — `@MainActor` Workbench, File Watchers & SwiftUI/Canvas Views (`SwiftEditUI`)**: `SwiftEditWorkbenchModel`, `WorkbenchBulkCloseAndHistoryController`, `ExternalFileChangeMonitor`, `MarkdownNativePreviewView`, `MarkdownDiagramPreviewView` (SwiftUI `Canvas`), `QuickOpenAndFolderSearchView`, `diffPanel`, and `LogTailPanelView` (`[UI-005]`, `[UI-007]`, `[SEC-002]`, `[SEC-004]`).
- **Protected Assets**: Unsaved user buffer edits and `LineEnding`/`TextEncoding` wire fidelity (`[DATA-004]`, `[DATA-006]`), `0700`/`0600` `SessionRecovery/` snapshots (`[SEC-007]`, `[SEC-011]`), canonical workspace filesystem scope (`[SEC-003]`), vnode file descriptors (`CWE-400`), main-thread CPU/stack budgets (`CWE-674`, `CWE-1333`), and system clipboard/IPC boundaries (`[SEC-004]`).

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | Symlinked child files, swapped paths in `Reopen Closed Tab` / `ExternalFileChangeMonitor`, or symlinked `.git/HEAD` escaping the user-granted workspace scope (`CWE-59`, `CWE-22`). | `REQ-002` (`N3`), `REQ-006` (`N7`), `REQ-007` (`N8`), and `REQ-012` (`N13`) validate canonical confinement via `resolvingSymlinksInPath()` prior to reading bytes or opening vnode descriptors (`[SEC-002]`, `[SEC-003]`). |
| Tampering | Silent loss of unsaved edits via false-clean dirty reconciliation (`LineEnding` change), unconfirmed `Reopen with Encoding`, or external disk modification auto-overwriting a dirty buffer. | `REQ-001` (`N1`), `REQ-006` (`P6`, `N7`), and `REQ-012` (`N13`) verify both `text` and `LineEnding` against `savedBaselineByID` and never overwrite `isDirty == true` buffers without explicit user confirmation (`[DATA-004]`, `[DATA-006]`). |
| Repudiation | Multi-tab bulk closures or external disk conflicts occurring without clear per-file attribution or user decision tracking. | `REQ-002` (`P2`, `N2`) and `REQ-006` (`P6`) surface explicit file-named confirmation prompts / banners (`Save / Don't Save / Cancel` and `Reload / Keep Mine / Compare`) (`[DATA-006]`). |
| Information Disclosure | Residual `<UUID>.recovery` files or undo history retained after bulk close (`CWE-212`), out-of-scope file probing during `Find in Folder`, or credential leakage from `.git/HEAD`. | `REQ-002` (`N3`) immediately unlinks closed `.recovery` files and clears undo/thumbnail/diff caches; `REQ-007` (`N8`) skips escaping symlinks prior to probing; `REQ-012` (`N13`) reads `<= 256` bytes from `.git/HEAD` extracting only sanitized branch ref names (`[SEC-007]`, `[SEC-011]`). |
| Denial of Service | Algorithmic/stack exhaustion from cyclic or giant Mermaid/Markmap diagrams, deep JSON payloads (`> 128` levels), regex backtracking (`CWE-1333`), or `Find in Folder` match floods (`CWE-400`, `CWE-674`). | `REQ-004` (`N5`) caps diagrams at `256` nodes, `maxDepth <= 12`, `64 KiB`, and iterative cycle-safe layout; `REQ-010` (`N11`) caps JSON depth iteratively at `128`; `REQ-007`/`REQ-008` use zero regex and cap folder scan at `10,000` files / `5,000` matches (`[SEC-012]`). |
| Elevation of Privilege | Malicious HTML/JS inside `mermaid`/`markmap` blocks (`<img onerror=...>`, `click A "javascript:..."`) executing scripts, or Git integration spawning shell subprocesses (`CWE-78`, `CWE-79`). | `REQ-003` (`N4`), `REQ-004` (`N5`), and `REQ-012` (`N13`) render diagrams exclusively as inert SwiftUI `Canvas` primitives/text (zero `WebKit`, zero Mermaid `click` URI handlers) and read `.git/HEAD` via pure file I/O with zero subprocesses (`[AR-002]`, `[SEC-004]`). |

## 3. Abuse Cases & Negative Scenarios
- **Abuse Case 1 — Residual Recovery Snapshot Retention & Symlink Reopen (`N3`, `Trait: security`)**:
  - Bulk closing dirty and tailing tabs immediately unlinks `<UUID>.recovery` files and stops descriptors; attempting `Shift+Cmd+T` on a path replaced by an out-of-scope symlink aborts fail-closed (`[SEC-003]`, `[SEC-007]`, `[SEC-011]`).
- **Abuse Case 2 — Malicious, Cyclic, or Oversized Mermaid / Markmap / HTML Payloads in Preview (`N4`, `N5`, `Trait: security`)**:
  - Diagram blocks with `> 256` nodes, `> 12` nesting depth, cyclic `A --> B --> A` edges, or `<script>` / `javascript:` payloads execute iteratively without recursion (`CWE-674`), never invoke `WebKit` or external links (`SEC-004`), and degrade safely to inert monospaced source with Copy button.
- **Abuse Case 3 — External Binary Overwrite or Symlink Swap on Watched Open File (`N7`, `Trait: security`)**:
  - When a watched file is replaced externally by binary bytes or an escaping symlink while dirty or clean, `ExternalFileChangeMonitor` never overwrites dirty text and blocks/quarantines binary or escaping targets fail-closed (`[DATA-003]`, `[SEC-003]`).
- **Abuse Case 4 — Symlink Escape & Match Flood in Folder Search and Deep JSON Bomb (`N8`, `N11`, `N13`, `Trait: security`)**:
  - `WorkspaceFolderSearchEngine` skips escaping symlinks before `8 KiB` probing and caps matches at `5,000` (`CWE-400`); `JSONStructureLinter` halts iteratively at depth `128` (`CWE-674`); `GitHeadBranchReader` rejects escaping/oversized `.git/HEAD` files with zero subprocesses (`[SEC-003]`, `[SEC-004]`, `[SEC-012]`).

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-25
- Verdict: approved
- Open items: none
