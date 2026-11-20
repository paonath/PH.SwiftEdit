# Threat Model: Two-Speed GFM TextKit 2 Editor, Markdown CommandMenu, GFM Table Tab and Cmd+P Zero-WebKit Native Preview

## 1. Asset Boundaries & Trust Zones
- **Trusted Core (`SwiftEditCore`)**: Pure value engines (`MarkdownSyntaxHighlighter`, `MarkdownAuthoringCommands`, `GFMTableEditEngine`, `MarkdownPreviewProjector`, `PreviewResourceAndLinkGate`) over immutable `DocumentSnapshot` and `BufferRevision` (`[AR-002]`, `[BC-006]`).
- **Presentation (`SwiftEditUI`, `@MainActor`)**: `TextKit2EditorView`, `MarkdownNativePreviewView`, `CommandMenu("Markdown")` applying returned edits and attributes (`[UI-005]`, `[UI-007]`).
- **Untrusted Inputs**: Markdown text (huge lines, giant tables, raw HTML, BiDi scalars), image references (remote URLs, `data:`, traversal, SVG, symlinks, decompression bombs), link URIs (`javascript:`, `file://`), and binary or degraded buffers (`[DATA-003]`, `[SEC-003]`, `[SEC-012]`).

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | A link label shows a trusted host while the target differs, or raw HTML mimics UI. | Links open only through `prepareExternalURIConfirmation` showing the canonical URI; raw HTML renders as inert monospaced text (`[SEC-004]`). |
| Tampering | A Bold/Table command edits inside a fenced block or mutates a binary buffer. | Engines skip fenced interiors and return no edit on binary/degraded snapshots; one batch per command (`[DATA-003]`, `[BC-006]`). |
| Repudiation | A multi-step table edit produces several revisions that cannot be undone atomically. | One `TextEdit` batch and one `shouldChangeText` Undo group per command (`[BC-006]`, `[UI-007]`). |
| Information Disclosure | A remote image beacon leaks reading activity, or `../../etc/passwd` is read as an image. | Zero sockets (`AsyncImage` banned), `FileSystemProviding` confinement in `grantedScopeRootURL`, extension allowlist, SVG/PDF blocked (`[SEC-002]`, `[SEC-003]`, `[SEC-004]`). |
| Denial of Service | Huge lines, `65`+ column or `2001`+ row tables, or decompression-bomb images stall typing or preview. | `4096` line cap, table caps, `16 MiB` / `8192 px` / `16 MP` header pre-check, thumbnail `<= 2048 px`, max `64` images, viewport-only highlighting (`CWE-400`, `[SEC-012]`). |
| Elevation of Privilege | A `javascript:`, `data:` or `file://` link, or a symlink inside the scope, reaches outside the sandbox. | Scheme allowlist `https`/`http`/`mailto`; symlink resolved outside scope aborts with `securityScopeViolation` (`[SEC-003]`, `[SEC-004]`). |

## 3. Abuse Cases & Negative Scenarios
- **Abuse Case 1 — Tracking Pixel**: `![x](https://tracker.example/p.png)` produces an offline placeholder and zero network activity (`[SEC-004]`).
- **Abuse Case 2 — Path Traversal / SVG**: `../../etc/passwd` and `./x.svg` are blocked with zero out-of-scope reads (`[SEC-003]`).
- **Abuse Case 3 — Raw HTML Injection**: `<script>x()</script>` is shown as inert text, never interpreted.
- **Abuse Case 4 — Resource Exhaustion**: a `4097`-unit line, a `65`-column table, or a `20000 px` image yields no spans, no edit, or a blocked image instead of unbounded work (`[SEC-012]`).
- **Abuse Case 5 — Binary Mutation**: Markdown commands and preview on a quarantined binary tab produce no edit and no `BufferRevision` change (`[DATA-003]`).

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-20
- Verdict: approved
- Open items: none
