# Threat Model: Linter-Governed Adaptive Markdown List Indentation (Tab / Shift+Tab / Return)

## 1. Asset Boundaries & Trust Zones
- **Trusted Core (`SwiftEditCore`)**: Pure `Foundation` value types (`DocumentSnapshot`, `TextEdit`, `MarkdownSmartListEngine`, `MarkdownSmartNewlineEngine`, `MarkdownLintAndFormatEngine`) computing edits against an immutable `BufferRevision` (`[AR-002]`, `[BC-006]`).
- **Presentation (`SwiftEditUI`, `@MainActor`)**: `TextKit2EditorView.Coordinator` intercepting `insertTab:` / `insertBacktab:` / `insertNewline:` and `SwiftEditWorkbenchModel` applying the returned batch (`[UI-005]`, `[UI-007]`).
- **Untrusted Inputs**: arbitrary document text (huge lines, deeply nested lists, numeric markers near `Int.max`, fenced code, BiDi scalars) and binary or degraded buffers (`[DATA-003]`, `[SEC-012]`).

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | A nested marker such as `a.` or `1.1` looks like a list but renders as plain paragraph text, misleading the author about document structure. | Flag `.nonStandardOutlineMarker` diagnostics outside fenced code and emit only CommonMark-valid markers on `Tab`/`Shift+Tab` (`[BC-004]`, `[UI-009]`). |
| Tampering | `Tab` on a root item inserts 4 spaces and silently turns the line into an indented code block, or edits land inside a fenced code block. | Parent-Ceiling rejects over-indent as a consumed no-op; fenced code lines are never edited (`[BC-004]`, `[SEC-012]`). |
| Repudiation | Multi-step indentation produces several revisions so an edit cannot be reverted atomically. | One `TextEdit` batch per keystroke producing exactly one `BufferRevision` (`[BC-006]`, `[UI-007]`). |
| Information Disclosure | Diagnostics or edit descriptions echo document content into logs or status text. | Engines return pure edits and rule IDs only; no content logging (`[SEC-011]`, `[SEC-012]`). |
| Denial of Service | Giant lines, thousands of siblings, or deep nesting make indentation quadratic; ordered numbers near `Int.max` overflow. | Zero regex, UTF-16 linear scans, `4096` line cap, `128` sibling lookback, `32` level cap, `addingReportingOverflow` and `999_999_999` cap (`CWE-400`, `[BC-011]`, `[SEC-012]`). |
| Elevation of Privilege | Indentation or `Return` continuation mutates a binary read-only or degraded buffer. | Snapshots with `isBinaryReadOnly` or `isDegradedPlainText` return no edit and the workbench rejects the call (`[DATA-003]`, `[SEC-012]`). |

## 3. Abuse Cases & Negative Scenarios
- **Abuse Case 1 — Binary Mutation via Tab**: `Tab` or `Return` on a quarantined binary buffer produces no edit and no `BufferRevision` change (`[DATA-003]`).
- **Abuse Case 2 — Resource Exhaustion**: A `4097`-unit list line, level-32 nesting, or marker `999999999.` yields no edit instead of unbounded work or overflow (`[SEC-012]`).
- **Abuse Case 3 — Code-Block Smuggling**: `Tab` on `1. Primo punto` never produces `    1. Primo punto` as a root item (`[BC-004]`).

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-20
- Verdict: approved
- Open items: none
