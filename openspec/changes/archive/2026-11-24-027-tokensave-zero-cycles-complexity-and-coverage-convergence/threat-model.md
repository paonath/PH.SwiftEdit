# Threat Model: TokenSave Zero-Cycles, Member Flattening (<= 25), Complexity Ceiling, and >= 85% Full-Codebase Coverage Convergence

## 1. Asset Boundaries & Trust Zones
- **Trust Zone 1 — Pure Domain & Fitness Scanner (`SwiftEditCore`)**: Parses untrusted Markdown, YAML frontmatter, log streams, and repository `.swift` files using pure `Foundation` APIs (`[AR-001]`, `[AR-006]`).
- **Trust Zone 2 — `@MainActor` Presentation, Shortcut Dispatch & Log Tail Worker (`SwiftEditUI`)**: Renders TextKit 2 editor buffers, dispatches keyboard/cheat-sheet commands, tails rotated local log files via `DispatchSource` vnode descriptors, and traverses `NSView`/`CALayer` trees (`[AR-010]`, `[UI-005]`, `[UI-007]`).
- **Protected Assets**: Local workspace files within canonical workspace root (`[SEC-003]`), Markdown preview & inline link/image security diagnostics (`[SEC-012]`), file descriptors in `LogTailWorker`, and main-thread stack/CPU availability (`CWE-400`, `CWE-674`).

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | Malicious symlinked `.swift` file or rotated log path spoofing an in-root workspace file during fitness scanning or log tailing (`CWE-59`, `CWE-22`). | `REQ-001` (`N2`) and `CodeModularityFitnessScanner` verify canonical root confinement via `resolvingSymlinksInPath` and reject symlinks or `../` traversal fail-closed (`[SEC-003]`). |
| Tampering | Malicious Markdown inline link/image payload (`javascript:`, `vbscript:`, `data:text/html`, `file:`, `../`) or Trojan Source BiDi control characters bypassing decomposed `scanInline` sub-passes (`CWE-79`, `CWE-22`). | `REQ-008` (`N9`) preserves deterministic scheme, path-traversal, and disallowed control/BiDi scalar detection across every extracted `MarkdownLinterInlineSecurityPass` helper (`[SEC-012]`). |
| Repudiation | Silent omission of security lint rules, modularity violations, or sub-85% target coverage during refactoring. | `REQ-001`, `REQ-008`, `REQ-009`, and `REQ-010` emit deterministic, typed `CodeModularityViolation` and coverage gate diagnostics with exact file, symbol, and percentage attribution (`[TEST-006]`, `[TEST-008]`, `[SDD-001]`). |
| Information Disclosure | Out-of-root file read via relative `../` image path in `MarkdownPreviewProjector` or symlink escape in `CodeModularityFitnessScanner`. | `REQ-001` (`N2`) and `REQ-008` (`N9`) reject out-of-root paths before reading file bytes and never include external file contents in diagnostics (`[SEC-003]`, `[SEC-010]`). |
| Denial of Service | Uncontrolled recursion (`CWE-674`), descriptor leak on log rotation (`CWE-400`), or oversized source payload (`> 4 MiB`) hanging the main thread or test runner. | `REQ-001` enforces a `4_194_304`-byte file cap; `REQ-007` (`N8`) enforces `0` call-graph recursion cycles in `Sources/`, a `4_096`-node cap on iterative `NSView`/`CALayer` walks, and single-descriptor cancel/close in `LogTailWorker` (`[SEC-012]`). |
| Elevation of Privilege | Unmapped or malformed keyboard chord triggering privileged workspace or terminal operations outside user confirmation guards. | `REQ-002` (`N3`) and `REQ-008` (`N9`) ensure table-driven shortcut dispatchers only invoke allowlisted `@MainActor` commands and preserve multiline terminal confirmation and root-confined sidebar gates (`[SEC-003]`, `[SEC-004]`). |

## 3. Abuse Cases & Negative Scenarios
- **Abuse Case 1 — Symlink Escape, `../` Traversal, or `> 4 MiB` Source File in Fitness Scanner (`N2`, `Trait: security`)**:
  - A scanned directory contains a symlinked `.swift` file pointing outside the repository root or a file larger than `4_194_304` bytes; `CodeModularityFitnessScanner` rejects it fail-closed with `.securityBoundaryViolation`.
- **Abuse Case 2 — Deep/Cyclic Layer Tree or Rapid Log Rotation Re-Entrancy (`N8`, `Trait: security`)**:
  - A `CALayer`/`NSView` tree exceeding `4_096` nodes or rapid log file delete/rename events are processed iteratively and non-recursively without stack overflow (`CWE-674`) or file descriptor leak (`CWE-400`).
- **Abuse Case 3 — Malicious Inline Markdown Schemes, Path Traversal, or BiDi Scalars in Decomposed Scanner (`N9`, `Trait: security`)**:
  - Inline Markdown containing `javascript:alert(1)`, `data:text/html,...`, `../../etc/passwd`, or BiDi override scalars (`U+202E`) is flagged with `.unsafeLinkScheme`, `.unsafeImagePath`, or `.disallowedControlCharacter` by the decomposed `scanInline` sub-passes.

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-24
- Verdict: approved
- Open items: none
