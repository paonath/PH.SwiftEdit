---
id: "brief-tokensave-zero-cycles-complexity-and-coverage-convergence"
change_id: "027-tokensave-zero-cycles-complexity-and-coverage-convergence"
capability: "workbench-editor-and-linter-modular-decomposition"
branch: "main"
modifies_specs:
  - "openspec/specs/workbench-editor-and-linter-modular-decomposition/spec.md"
status: "approved-via-qa"
date: "2026-11-24"
owners:
  - "swift-macos-expert"
  - "oop-architecture-expert"
  - "cyber-security-expert"
  - "spec-sdlc-expert"
  - "test-quality-auditor"
---

# TDD Specification Brief: `027-tokensave-zero-cycles-complexity-and-coverage-convergence`

## 1. Context & Scope

- **Request**: Execute a complete Refactor -> Verify -> Re-analyze cycle resolving every remaining finding from the TokenSave graph analysis while preserving 100% of existing features and enforcing `>= 85%` code coverage across ALL production targets (`SwiftEditCore` and `SwiftEditUI`):
  1. **Nominal Member Flattening (`<= 25` members per nominal block)**: Flatten all remaining high-member structures and classes identified by `tokensave_god_class` (`EditorRenderingAttributeTable`: 36, `PurpleThemePalette`: 34, `SwiftEditNSTextView`: 34, `SwiftEditWorkbenchModel`: 34, `TextKit2EditorView`: 32, `WorkspaceEditorCoordinator`: 30, `ZoomedChromeMetrics`: 28, `DocumentSession`: 26, `LogTailController`: 26).
  2. **Zero Call-Graph Recursion Cycles (`tokensave_recursion == 0` in `Sources/`)**: Eliminate all 8 remaining recursion/cycle findings in `Sources/` (length-4 cycle in `AppTypography.swift`, length-2 cycle `pollLocked <-> armVnodeLocked` in `LogTailController.swift`, and 6 length-1 overload/delegate self-loop edges in `SwiftEditNSTextViewAndUndoRegistry.swift`, `WorkspaceTabSession.swift`, `SwiftEditRootView.swift`, `MarkdownAllConstructsLinter.swift`, and `EmbeddedTerminalRegistry.swift`).
  3. **Cognitive & Cyclomatic Complexity Reduction (`cyclomatic <= 15`, `cognitive <= 25`)**: Decompose all top complex methods in `Sources/` (`MarkdownLinterInlineSecurityPass.scanInline`, `CursorMetricsCalculator.metrics`, `MarkdownPreviewProjector.project`, `LogSyntaxHighlighter.scan`, `SwiftEditShortcutDispatcher.dispatchCommandOnly`, `SwiftEditWorkbenchModel.performCheatSheetCommand`, `TextKit2EditorCoordinator.applyProgrammaticTextUpdate`, `MarkdownAuthoringCommands.evaluateTab`, `MarkdownLintAndFormatEngine.lint`, `SwiftEditRootView.attachKeyDownMonitor`, `DocumentSession.applyTextEdits`, and `SwiftEditWorkbenchModel.refreshDiagnosticsForActiveDocument`).
  4. **Dependency Depth & Dead Code Cleanup (`max_depth <= 10`, `dead_code == 0` in `Sources/`)**: Shorten the 15-file dependency chain from `SwiftEditRootView.swift` to `DocumentTextIndex.swift` (`<= 10` hops) and eliminate/wire the 20 unreferenced private symbols reported by `tokensave_dead_code`.
  5. **Full-Codebase Coverage (`>= 85%` across `SwiftEditCore` AND `SwiftEditUI`) & Iterative Re-Analysis**: Close all coverage gaps (including `CRAP > 30` methods) so both `SwiftEditCore` and `SwiftEditUI` achieve `>= 85%` line coverage under `swift test --parallel --enable-code-coverage`, followed by `tokensave sync` and automated graph re-analysis verification.
- **QA Confirmation**: Confirmed by human operator in Phase 02 (`<= 25` members per nominal block, `0` recursion and file cycles, cyclomatic `<= 15` and cognitive `<= 25`, dead code cleanup, dependency depth `<= 10`, and `>= 85%` line coverage across `SwiftEditCore` + `SwiftEditUI`).
- **Consolidated specs modified**: `openspec/specs/workbench-editor-and-linter-modular-decomposition/spec.md` (`MODIFIED` `REQ-001`, `REQ-002`, `REQ-004`, `REQ-006`, `REQ-007`; `ADDED` `REQ-008`, `REQ-009`, `REQ-010`).
- **Governing Constitutional Rules**: `AR-001`, `AR-002`, `AR-005`, `AR-006`, `AR-007`, `AR-008`, `AR-009`, `AR-010`, `BC-001`, `BC-002`, `UI-001`, `UI-002`, `UI-005`, `UI-006`, `UI-007`, `TEST-001`, `TEST-004`, `TEST-005`, `TEST-006`, `TEST-008`, `SEC-001`, `SEC-003`, `SEC-004`, `SEC-012`, `SDD-001..003`.

## 2. Expert Notes & 4-Pillar Breakdown

- **Pillar 1 — Nominal Member Flattening to `<= 25` (`MODIFIED REQ-001`, `REQ-002`, `REQ-004`)**:
  - Tighten `CodeModularityBudgets.default.maxNominalMembers` from `45` to `25` and `maxNominalBlockLines` from `600` to `400`.
  - Group cohesive properties into nested value sub-structs or move secondary methods/computed forwarders into focused extensions so every nominal declaration block (`class`, `struct`, `enum`, `actor`, `extension`) in `Sources/` declares `<= 25` members:
    - `EditorRenderingAttributeTable` (`36 -> <= 20`), `PurpleThemePalette` (`34 -> <= 20`), `SwiftEditNSTextView` (`34 -> <= 20`), `SwiftEditWorkbenchModel` (`34 -> <= 22`), `TextKit2EditorView` (`32 -> <= 20`), `WorkspaceEditorCoordinator` (`30 -> <= 20`), `ZoomedChromeMetrics` (`28 -> <= 18`), `DocumentSession` (`26 -> <= 20`), `LogTailController` (`26 -> <= 20`).
- **Pillar 2 — Zero Call-Graph Recursion & Shortened Dependency Depth (`MODIFIED REQ-006`, `REQ-007`; `ADDED REQ-009`)**:
  - **Eliminate all 8 `tokensave_recursion` cycles in `Sources/`**:
    - `AppTypography.swift` (length-4 cycle): Disambiguate external font lookup helpers (`lookupOpenDyslexicFace`, `lookupSystemFamilyFace`) and avoid calling `.font(...)` names that collide with `AppTypography.font(_:size:...)`.
    - `LogTailController.swift` (length-2 cycle `pollLocked <-> armVnodeLocked`): Extract `readAndDeliverLogSnapshotLocked(force:)` so `armVnodeLocked()` invokes `readAndDeliverLogSnapshotLocked(force: false)` and `rearmVnodeOnRotationLocked()` without calling back into `pollLocked`.
    - Length-1 self-loops: Disambiguate private helper `moveTabAtIndices(fromIndex:toIndex:)` in `WorkspaceTabSession.swift`, `runRulePasses(index:securityOnly:deadlineExceeded:)` in `MarkdownAllConstructsLinter.swift`, and use distinct helper delegates for `didChangeText`, `drawBackground`, and `viewDidMoveToWindow`.
  - **Dependency Depth `<= 10` & Zero Dead Code (`REQ-009`)**:
    - Flatten horizontal extension chaining across `SwiftEditWorkbenchModel+*.swift` so extension files call core services and state structs directly rather than chaining through 5 sibling extension files, reducing `max_depth` from `15` to `<= 10`.
    - Remove or wire all 20 unreferenced private helpers identified by `tokensave_dead_code`.
- **Pillar 3 — Method Complexity Ceiling (`cyclomatic <= 15`, `cognitive <= 25`) (`ADDED REQ-008`)**:
  - Decompose `MarkdownLinterInlineSecurityPass.scanInline` (cognitive `79 -> <= 20`), `CursorMetricsCalculator.metrics` (`65 -> <= 20`), `MarkdownPreviewProjector.project` (`60 -> <= 20`), `LogSyntaxHighlighter.scan` (`52 -> <= 20`), `TextKit2EditorCoordinator.applyProgrammaticTextUpdate` (`44 -> <= 20`), `MarkdownAuthoringCommands.evaluateTab` (cyclomatic `26 -> <= 12`), `MarkdownLintAndFormatEngine.lint` (cyclomatic `25 -> <= 12`), and `DocumentSession.applyTextEdits` (cyclomatic `17 -> <= 12`) into small, pure, single-responsibility helper functions.
  - Replace giant branching switches in `SwiftEditWorkbenchModel.performCheatSheetCommand` (cyclomatic `44 -> <= 10`), `SwiftEditShortcutDispatcher.dispatchCommandOnly` (`36 -> <= 10`), and `SwiftEditRootView.attachKeyDownMonitor` (`26 -> <= 12`) with declarative static lookup tables / key-chord command maps.
- **Pillar 4 — Abuse Cases, Negative Security & Full-Codebase `>= 85%` Coverage Gate (`ADDED REQ-010`)**:
  - Preserve all STRIDE security controls during complexity decomposition (`MarkdownLinterInlineSecurityPass` scheme/traversal/BiDi checks, `CodeModularityFitnessScanner` canonical root confinement, `LogTailWorker` descriptor lifecycle, and `4_096` node iterative view/layer traversal cap).
  - Add comprehensive positive, negative, and security unit tests covering every refactored method and previously uncovered UI/Core path (`LogSyntaxHighlighter.scan`, `MarkdownAuthoringCommands.evaluateTab`, `MarkdownLinterInlineSecurityPass.scanInline`, `SwiftEditShortcutDispatcher.dispatchCommandOnly`, `attachKeyDownMonitor`, `UpdateCheckSheetView`, `PropertiesPanelView`), achieving `>= 85%` line coverage across BOTH `SwiftEditCore` and `SwiftEditUI` and verifying convergence via `tokensave sync` + graph re-analysis.

## 3. Given/When/Then Contracts & Path Coverage Matrix

| Unit | Path | Trait | Summary |
| :--- | :--- | :--- | :--- |
| `CodeModularityFitnessScanner` | P1 | positive | Live `Sources/SwiftEditCore` and `Sources/SwiftEditUI` pass `maxFileLines: 800`, `maxNominalBlockLines: 400`, and `maxNominalMembers: 25` with zero violations across all 9 flattened types |
| `CodeModularityFitnessScanner` | N1 | negative | Synthetic `.swift` fixture with `26` nominal members or `401` nominal block lines emits typed `CodeModularityViolation` diagnostics |
| `CodeModularityFitnessScanner` | N2 | security | Symlink escape, `../` traversal, or `> 4 MiB` file fails closed with `.securityBoundaryViolation` |
| `WorkbenchAndEditorFlattenedModels` | P2 | positive | Flattened `SwiftEditWorkbenchModel`, `TextKit2EditorView`, `SwiftEditNSTextView`, `WorkspaceEditorCoordinator`, `EditorRenderingAttributeTable`, `PurpleThemePalette`, `ZoomedChromeMetrics`, `DocumentSession`, and `LogTailController` (`<= 25` members each) preserve 100% observable behavior |
| `WorkbenchAndEditorFlattenedModels` | N3 | negative | Invalid completion prefixes, out-of-root sidebar paths, unchanged viewport highlight signatures, or invalid UTF-16 edit ranges are rejected without state corruption |
| `AcyclicCallGraphAndRecursionElimination` | P7 | positive | `AppTypography`, `LogTailWorker`, `WorkspaceTabSession`, `MarkdownAllConstructsLinter`, `SwiftEditNSTextView`, `SwiftEditRootView`, and `EmbeddedTerminalRegistry` execute with `0` recursion cycles (`tokensave_recursion == 0` in `Sources/`) |
| `AcyclicCallGraphAndRecursionElimination` | N8 | security | Cyclic or `> 4_096`-node view/layer trees and rotated/missing log files terminate deterministically without stack overflow (`CWE-674`) or descriptor leak (`CWE-400`) |
| `LowComplexityEnginesAndShortcutTables` | P8 | positive | Decomposed `scanInline`, `metrics`, `project`, `LogSyntaxHighlighter.scan`, `evaluateTab`, `lint`, `applyTextEdits`, `applyProgrammaticTextUpdate`, and table-driven `performCheatSheetCommand` / `dispatchCommandOnly` / `attachKeyDownMonitor` satisfy `cyclomatic <= 15` and `cognitive <= 25` with identical output |
| `LowComplexityEnginesAndShortcutTables` | N9 | security | Malicious Markdown inline links (`javascript:`, `data:text/html`, `file:`, `../`, BiDi/control scalars) and unmapped/invalid shortcut chords are flagged or rejected fail-closed |
| `DependencyDepthAndDeadCodeGate` | P9 | positive | File dependency depth across `Sources/` is `<= 10` hops (`cycle_count == 0`) and `tokensave_dead_code` reports `0` unreferenced private symbols in `Sources/` |
| `DependencyDepthAndDeadCodeGate` | N10 | negative | Synthetic source graph with dependency depth `> 10` or unreferenced private helper methods emits deterministic fitness violations |
| `FullCodebaseCoverageAndTokenSaveConvergence` | P10 | positive | `swift test --parallel --enable-code-coverage` passes with `>= 85%` line coverage in `SwiftEditCore`, `>= 85%` in `SwiftEditUI`, and `>= 85%` total, followed by `tokensave sync` confirming all graph targets |
| `FullCodebaseCoverageAndTokenSaveConvergence` | N11 | negative | Coverage verifier rejects any target or aggregate coverage report below `85.0%` or containing unresolved `tokensave` cycle/member regressions |
