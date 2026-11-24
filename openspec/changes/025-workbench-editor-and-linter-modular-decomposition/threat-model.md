# Threat Model: Workbench, TextKit 2 Editor, and Markdown Linter Modular Decomposition

## 1. Asset Boundaries & Trust Zones
- **Trust Zone 1 — Pure Core Static Analysis & Markdown Engine (`SwiftEditCore`)**:
  - `CodeModularityFitnessScanner` reads repository `.swift` source files from disk during architecture fitness tests (`[AR-006]`, `[TEST-006]`).
  - `MarkdownAllConstructsLinter` and `MarkdownLinterRuleFamilyPasses` inspect untrusted user Markdown buffers in memory (`[BC-001]`, `[SEC-012]`).
- **Trust Zone 2 — `@MainActor` Workbench Sub-Controllers & Editor View Layer (`SwiftEditUI`)**:
  - `WorkbenchSidebarFileController` executes user-requested file/folder CRUD within the active workspace root (`[SEC-003]`).
  - `WorkbenchTerminalSessionController` queues text payloads for the embedded SwiftTerm PTY session and launches allowlisted directory-only external terminals (`[SEC-004]`).
  - `WorkbenchUpdateController` validates HTTPS GitHub release URLs and installer downloads (`[SEC-001]`).
  - `TextKit2ViewportHighlightApplier` mutates `NSTextContentStorage` attributes within visible UTF-16 ranges (`[UI-006]`, `[UI-007]`).

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | A malicious or spoofed update URL or non-allowlisted terminal bundle identifier is passed to the extracted `WorkbenchUpdateController` or `WorkbenchTerminalSessionController` during refactoring. | `REQ-002`: `WorkbenchUpdateController` and `WorkbenchTerminalSessionController` preserve strict HTTPS host verification and the allowlisted terminal bundle identifier check (`[SEC-001]`, `[SEC-004]`). |
| Tampering | Symlinked `.swift` files or `../` relative traversal segments inside a scanned directory trick `CodeModularityFitnessScanner` or `WorkbenchSidebarFileController` into reading or mutating files outside the canonical root (`CWE-22`). | `REQ-001` (`N2`), `REQ-002` (`N3`): Canonicalize roots and candidate URLs via `resolvingSymlinksInPath()`, verify `URLResourceValues.isSymbolicLinkKey`, and reject out-of-scope paths fail-closed (`[SEC-003]`, `[SEC-012]`). |
| Repudiation | Refactoring `MarkdownAllConstructsLinter` or `CodeModularityFitnessScanner` silently drops rule identifiers, file paths, or violation metadata needed to audit security or modularity failures. | `REQ-001` (`N1`, `N2`), `REQ-005` (`P5`, `N6`): Emit deterministic, strongly typed `CodeModularityViolation` and `MarkdownLintDiagnostic` structs containing explicit rule IDs, file paths, and 1-based line numbers (`[SDD-001]`, `[TEST-006]`). |
| Information Disclosure | A symlink inside a scanned fixture directory causes `CodeModularityFitnessScanner` to read sensitive files outside the repository and leak their contents in test failure messages (`CWE-200`). | `REQ-001` (`N2`): Reject symlinks and out-of-root paths before opening file handles, and emit only relative path and metric counts in `CodeModularityViolation` (`[SEC-003]`, `[SEC-005]`). |
| Denial of Service | An oversized `.swift` file (`> 4 MiB`) in `CodeModularityFitnessScanner`, an adversarial Markdown document exceeding the lint deadline in `MarkdownLinterRuleFamilyPasses`, or out-of-viewport UTF-16 attribute mutations in `TextKit2ViewportHighlightApplier` stalls the main thread (`CWE-400`). | `REQ-001` (`N2`), `REQ-004` (`N5`), `REQ-005` (`N6`): Enforce a `4_194_304`-byte cap per scanned source file, check `deadlineExceeded()` across every linter rule-family pass, and clamp/skip non-intersecting viewport highlight ranges (`[UI-007]`, `[UI-012]`, `[SEC-012]`). |
| Elevation of Privilege | Refactoring `requestSendSelectionToTerminal` into `WorkbenchTerminalSessionController` or inline link/image scanning into `MarkdownLinterRuleFamilyPasses` bypasses the multiline terminal confirmation gate or fails to flag `javascript:`/`vbscript:`/`file:`/`../` payloads (`CWE-78`, `CWE-79`). | `REQ-002` (`N3`), `REQ-005` (`N6`): Gate multiline payloads (`\n` or `\r`) behind explicit confirmation without auto-appending Return, and preserve UTF-8/UTF-16 unsafe scheme and image path traversal detection (`[SEC-004]`, `[SEC-012]`). |

## 3. Abuse Cases & Negative Scenarios
- **Abuse Case 1 (`REQ-001` Scenario `N2` — Symlink Escape & Oversized Source in Modularity Scanner)**: An attacker or malformed fixture places a symbolic link `Evil.swift -> /etc/passwd`, a `../` path traversal segment, or a `5 MiB` generated file inside a directory scanned by `CodeModularityFitnessScanner`. The scanner detects the symlink/out-of-root canonical path or size overflow via `URLResourceValues` before reading bytes and returns a `.securityBoundaryViolation` (`- **Trait**: security`, `[SEC-003]`, `[SEC-012]`).
- **Abuse Case 2 (`REQ-005` Scenario `N6` — Unsafe Scheme, Parent Traversal & Deadline Exhaustion in Decomposed Linter Passes)**: A crafted Markdown payload embeds `[click](javascript:alert(1))`, `![img](../../secret.png)`, or thousands of lines designed to exceed the linter time budget. The decomposed `MarkdownLinterRuleFamilyPasses` abort immediately with `timedOut == true` when `deadlineExceeded()` triggers and deterministically emit `.unsafeLinkScheme` and `.unsafeImagePath` diagnostics (`- **Trait**: security`, `[SEC-012]`).

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-24
- Status: approved
- Verdict: approved # approved | changes-required
- Open items: none
