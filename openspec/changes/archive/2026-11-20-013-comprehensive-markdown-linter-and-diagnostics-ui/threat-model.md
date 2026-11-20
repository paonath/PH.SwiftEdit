# Threat Model: 26-Rule All-Construct Markdown Linter, Idempotent Quick-Fix and Fix All, Triple Diagnostics UI and Shift+Cmd+M Popover

## 1. Asset Boundaries & Trust Zones
- **Trusted Core (`SwiftEditCore`)**: Pure value engines (`MarkdownLintAndFormatEngine`, `MarkdownSourceLineTable`, `YAMLFrontmatterScanner`, `MarkdownQuickFixResolver`, `ActiveLintStatus`) over immutable `DocumentSnapshot` and `BufferRevision` (`[AR-002]`, `[BC-006]`).
- **Presentation (`SwiftEditUI`, `@MainActor`)**: `TextKit2EditorView` underlines, `LineNumberGutterView` badges, `MarkdownDiagnosticsPopoverView` applying returned edits (`[UI-005]`, `[UI-007]`).
- **Untrusted Inputs**: Markdown text (obfuscated URIs, huge diagnostics volume, malformed tables, YAML-like headers, multibyte text) and binary or degraded buffers (`[DATA-003]`, `[SEC-012]`).

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | `[x](javascript%3Aalert(1))`, `&#x6A;avascript:`, zero-width or `//host` links disguise unsafe targets. | Decode percent/HTML entities, strip C1/zero-width/BiDi scalars, reject protocol-relative, then classify `.unsafeLinkScheme` as error (`[SEC-004]`). |
| Tampering | A fix applied against a stale buffer corrupts text, or a fix rewrites an unsafe link into a safe-looking one. | `expectedRevision` check, `quickFix == nil` on security rules, one batch per fix (`[BC-006]`, `[BC-011]`). |
| Repudiation | Fix All produces several revisions that cannot be undone together. | One `TextEdit` batch and one `Cmd+Z` step (`[BC-006]`, `[UI-007]`). |
| Information Disclosure | Diagnostics or tooltips echo document content into logs. | Diagnostics carry rule IDs, lines and static messages only (`[SEC-012]`). |
| Denial of Service | Thousands of warnings, pathological tables or fences exhaust time or memory. | `1000` cap with errors first and `isTruncated`, `250 ms` budget, `4096` line cap, `200`-line frontmatter mask (`CWE-400`, `[SEC-012]`). |
| Elevation of Privilege | Quick-Fix or Fix All mutates a binary or degraded buffer, or a `../` image escapes the workspace in preview. | Binary and degraded snapshots return no fixes and `Lint: Off`/`Paused`; `.unsafeImagePath` is a non-fixable error (`[DATA-003]`, `[SEC-003]`). |

## 3. Abuse Cases & Negative Scenarios
- **Abuse Case 1 — Obfuscated Script Link**: `[x](javascript%3Aalert(1))` surfaces an error with no Quick-Fix, even under `1500` trailing-space warnings.
- **Abuse Case 2 — Traversal or SVG Image**: `![x](../../etc/passwd)`, `%2e%2e/`, `x.svg` are errors without fixes.
- **Abuse Case 3 — Stale Fix**: `Fix All` computed at revision `N` applied at `N+1` is rejected.
- **Abuse Case 4 — Diagnostic Flood**: `1500` warnings yield at most `1000` entries retaining every error.
- **Abuse Case 5 — Binary Mutation**: Fix commands on a quarantined binary tab produce no edit and no revision change.

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-20
- Verdict: approved
- Open items: none
