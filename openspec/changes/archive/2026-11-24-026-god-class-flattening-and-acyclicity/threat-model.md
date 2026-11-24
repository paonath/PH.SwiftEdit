# Threat Model: God-Class Member Flattening, File-Level Acyclicity, and Recursion Elimination

## 1. Asset Boundaries & Trust Zones
- **Trust Zone 1 — Pure Core Static Modularity & Acyclicity Scanner (`SwiftEditCore/ArchitectureFitness`)**:
  - `CodeModularityFitnessScanner` reads `.swift` source files from disk under `Sources/SwiftEditCore` and `Sources/SwiftEditUI` and evaluates nominal member budgets (`<= 45`), file/block line limits, and cross-file dependency acyclicity (`[AR-006]`, `[TEST-006]`).
- **Trust Zone 2 — Pure Core Markdown Line Table & Linter (`SwiftEditCore/MarkdownLintAndFormat`)**:
  - `MarkdownLineIndex.swift` indexes untrusted UTF-8/UTF-16 Markdown buffers and masks YAML frontmatter ranges for downstream highlighters, projectors, and linters (`[BC-001]`, `[SEC-012]`).
- **Trust Zone 3 — `@MainActor` Workbench, Theme Palette, Update Controller & AppKit View Layer (`SwiftEditUI`)**:
  - `SwiftEditWorkbenchModel`, `WorkbenchUpdateController`, and `GitHubReleaseUpdateChecker` execute HTTPS GitHub release checks (`[SEC-001]`, `[SEC-004]`).
  - `SwiftEditNSTextView` traverses `NSView` and `CALayer` subtrees during appearance and redraw invalidation (`[UI-007]`, `[SEC-012]`).

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | Disambiguating `GitHubReleaseUpdateChecker.evaluateReleaseUpdate(currentVersion:)` to eliminate the `checkForUpdates` ↔ `performUpdateCheck` mutual recursion accidentally weakens HTTPS host or release URL verification. | `REQ-007` (`P7`), `REQ-002`: Preserve `GitHubReleaseUpdateChecker.verifiedGitHubHTTPSURL` and strict HTTPS host verification across the renamed method boundary (`[SEC-001]`, `[SEC-004]`). |
| Tampering | Symlinked `.swift` files or `../` parent-traversal segments inside a scanned directory trick `CodeModularityFitnessScanner` or `verifyAcyclicFileGraph` into scanning files outside the repository root (`CWE-22`). | `REQ-001` (`N2`), `REQ-006` (`N7`): Canonicalize directory and candidate URLs via `resolvingSymlinksInPath()`, inspect `isSymbolicLinkKey`, and reject out-of-root paths fail-closed (`[SEC-003]`, `[SEC-012]`). |
| Repudiation | Lowering `maxNominalMembers` to `45` or checking file-level acyclicity fails to report the exact symbol name, file cycle path, or observed count when a violation occurs. | `REQ-001` (`N1`), `REQ-006` (`N7`): Emit typed `CodeModularityViolation` values carrying `filePath`, `symbolName`, `kind` (`.nominalMemberCount`, `.circularFileDependency`), `observed`, `limit`, and human-readable cycle paths (`[SDD-001]`, `[TEST-006]`). |
| Information Disclosure | A symlink inside a scanned directory causes `CodeModularityFitnessScanner` to read external sensitive files and expose their content in failure diagnostics (`CWE-200`). | `REQ-001` (`N2`): Reject out-of-root symlinks prior to opening file handles and include only relative paths and structural counts in diagnostics (`[SEC-003]`, `[SEC-005]`). |
| Denial of Service | Pathological or deeply nested `NSView` / `CALayer` trees cause uncontrolled recursion (`CWE-674`) or main-thread stack exhaustion (`CWE-400`) during `markSubviewsAndLayersNeedsDisplay` or `markLayerTreeNeedsDisplay`, or an oversized `.swift` file (`> 4 MiB`) stalls static scanning. | `REQ-007` (`N8`), `REQ-001` (`N2`): Replace recursive view/layer invalidation with an iterative worklist bounded to `maxVisitedNodes = 4_096` and enforce the `4_194_304`-byte file cap (`[UI-007]`, `[SEC-012]`). |
| Elevation of Privilege | Refactoring `SwiftEditWorkbenchModel` state groups or `WorkbenchTerminalSessionController` forwarding properties bypasses workspace symlink confinement or multiline terminal payload confirmation (`CWE-78`). | `REQ-002` (`P2`, `N3`): Keep all sidebar file CRUD routed through `WorkbenchSidebarFileController` and all terminal payloads gated by `WorkbenchTerminalSessionController` multiline confirmation (`[SEC-003]`, `[SEC-004]`). |

## 3. Abuse Cases & Negative Scenarios
- **Abuse Case 1 (`REQ-001` Scenario `N2` — Symlink Escape & Oversized Source in Modularity and Acyclicity Scanner)**: A malformed or adversarial fixture places a symbolic link `Escape.swift -> /etc/passwd`, a `../` path segment, or a `5 MiB` file inside a directory scanned by `CodeModularityFitnessScanner`. The scanner rejects the entry fail-closed with `.securityBoundaryViolation` before reading external bytes (`- **Trait**: security`, `[SEC-003]`, `[SEC-012]`).
- **Abuse Case 2 (`REQ-007` Scenario `N8` — Deeply Nested or Cyclic View/Layer Tree Invalidation Cap)**: A pathological `CALayer` or `NSView` hierarchy containing `> 4_096` nested nodes is passed to `SwiftEditNSTextView.markLayerTreeNeedsDisplay(_:maxVisitedNodes:)` or `markSubviewsAndLayersNeedsDisplay(_:maxVisitedNodes:)`. The iterative worklist tracks visited object identities and halts deterministically at `4_096` nodes without stack recursion (`CWE-674`) or main-thread hang (`- **Trait**: security`, `[SEC-012]`).

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-24
- Status: approved
- Verdict: approved # approved | changes-required
- Open items: none
