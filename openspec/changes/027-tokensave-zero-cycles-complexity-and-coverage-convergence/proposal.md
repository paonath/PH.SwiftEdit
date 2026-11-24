# Proposal: TokenSave Zero-Cycles, Member Flattening (<= 25), Complexity Ceiling, and >= 85% Full-Codebase Coverage Convergence

## Why
Post-026 TokenSave re-analysis of `PH.SwiftEdit` (`quality_signal = 7171/10000`, `node_count = 9029`, `edge_count = 5228`) surfaced five remaining structural and quality bottlenecks that must be resolved in a closed-loop **Refactor -> Verify -> Re-analyze** workflow while preserving 100% of existing features:
1. **Point 1 — High-Member Nominal Structures & Classes (`tokensave_god_class`)**:
   - Nine production types still declare between `26` and `36` members in a single nominal declaration block: `EditorRenderingAttributeTable` (`36`), `PurpleThemePalette` (`34`), `SwiftEditNSTextView` (`34`), `SwiftEditWorkbenchModel` (`34`), `TextKit2EditorView` (`32`), `WorkspaceEditorCoordinator` (`30`), `ZoomedChromeMetrics` (`28`), `DocumentSession` (`26`), and `LogTailController` (`26`).
2. **Point 2 — Call-Graph Recursion Cycles (`tokensave_recursion`: 8 cycles in `Sources/`)**:
   - **Length-4 cycle in `AppTypography.swift`**: `systemFamilyFont` -> `font` -> `nsFont` -> `resolve` -> `systemFamilyFont` caused by calling `NSFontManager.shared.font(withFamily:...)` and `openDyslexic.font(...)` whose `.font` identifier collides with `AppTypography.font(_:size:...)`.
   - **Length-2 cycle in `LogTailController.swift`**: `pollLocked` <-> `armVnodeLocked` inside `LogTailWorker` where `pollLocked` arms a missing vnode source and the `armVnodeLocked` event closure calls back into `pollLocked(force: false)`.
   - **Six length-1 self-loops**: `didChangeText` and `drawBackground` in `SwiftEditNSTextViewAndUndoRegistry.swift`, `moveTab` in `WorkspaceTabSession.swift`, `viewDidMoveToWindow` in `SwiftEditRootView.swift` and `EmbeddedTerminalRegistry.swift`, and `diagnostics` in `MarkdownAllConstructsLinter.swift`.
3. **Point 3 — High Cognitive & Cyclomatic Complexity Outliers (`tokensave_complexity` & `tokensave_gini`)**:
   - Several core and UI methods exceed `cyclomatic > 15` or `cognitive > 25`: `MarkdownLinterInlineSecurityPass.scanInline` (cyclomatic `22`, cognitive `79`), `CursorMetricsCalculator.metrics` (`19` / `65`), `MarkdownPreviewProjector.project` (`22` / `60`), `LogSyntaxHighlighter.scan` (`14` / `52`, `CRAP = 210`), `SwiftEditShortcutDispatcher.dispatchCommandOnly` (`36` / `50`, `CRAP = 1332`), `SwiftEditWorkbenchModel.performCheatSheetCommand` (`44` / `48`), `TextKit2EditorCoordinator.applyProgrammaticTextUpdate` (`13` / `44`), `SwiftEditRootView.attachKeyDownMonitor` (`26` / `40`, `CRAP = 702`), `MarkdownAuthoringCommands.evaluateTab` (`26` / `38`, `CRAP = 702`), `MarkdownLintAndFormatEngine.lint` (`25` / `33`), and `DocumentSession.applyTextEdits` (`17` / `30`).
4. **Point 4 — Deep File Dependency Chains & Dead Private Symbols (`tokensave_dependency_depth` & `tokensave_dead_code`)**:
   - `SwiftEditRootView.swift` chains horizontally through 5 `SwiftEditWorkbenchModel+*.swift` extensions into `SwiftEditCore`, reaching depth `15` (`ideal_chain: 9`), and `tokensave_dead_code` reports `20` unreferenced private symbols in `Sources/`.
5. **Point 5 — Full-Codebase Line Coverage (`>= 85%` across `SwiftEditCore` AND `SwiftEditUI`)**:
   - High-CRAP methods (`dispatchCommandOnly`, `attachKeyDownMonitor`, `evaluateTab`, `scanInline`, `LogSyntaxHighlighter.scan`) and UI helpers require direct positive, negative, and security test coverage so the entire codebase (`SwiftEditCore`, `SwiftEditUI`, and aggregate total) achieves `>= 85%` line coverage.

## What Changes
- **Point 1 — Tighten Nominal Member Budget to `<= 25` & Flatten All 9 High-Member Types (`MODIFIED REQ-001`, `REQ-002`, `REQ-004`)**:
  - Lower `CodeModularityBudgets.default.maxNominalMembers` from `45` to `25` and `maxNominalBlockLines` from `600` to `400` (`[AR-006]`, `[TEST-006]`, `[SEC-003]`, `[SEC-012]`).
  - Flatten `EditorRenderingAttributeTable`, `PurpleThemePalette`, `SwiftEditNSTextView`, `SwiftEditWorkbenchModel`, `TextKit2EditorView`, `WorkspaceEditorCoordinator`, `ZoomedChromeMetrics`, `DocumentSession`, and `LogTailController` so every nominal declaration block in `Sources/` declares `<= 25` members (`[AR-009]`, `[AR-010]`, `[UI-001]`, `[UI-002]`, `[UI-005]`, `[UI-006]`, `[UI-007]`).
- **Point 2 — Eliminate All 8 Call-Graph Recursion Cycles in `Sources/` (`MODIFIED REQ-007`)**:
  - Break the length-4 `AppTypography.swift` cycle by extracting non-colliding font lookup helpers (`lookupOpenDyslexicFace`, `lookupSystemFamilyFace`) (`[UI-002]`).
  - Break the length-2 `LogTailController.swift` cycle (`pollLocked <-> armVnodeLocked`) by extracting `readAndDeliverSnapshotLocked(force:)` so `armVnodeLocked()` and `pollLocked(force:)` share a leaf reader without mutual calls (`[AR-010]`, `[SEC-012]`).
  - Eliminate all 6 length-1 self-loops in `WorkspaceTabSession.swift` (`moveTabAtIndices`), `MarkdownAllConstructsLinter.swift` (`evaluateConstructPasses`), `SwiftEditNSTextViewAndUndoRegistry.swift`, `SwiftEditRootView.swift`, and `EmbeddedTerminalRegistry.swift` so `tokensave_recursion` reports `0` cycles in `Sources/` (`[AR-006]`, `[AR-010]`, `[BC-001]`).
- **Point 3 — Enforce Method Complexity Ceiling (`cyclomatic <= 15`, `cognitive <= 25`) (`ADDED REQ-008`)**:
  - Decompose `scanInline`, `CursorMetricsCalculator.metrics`, `MarkdownPreviewProjector.project`, `LogSyntaxHighlighter.scan`, `applyProgrammaticTextUpdate`, `evaluateTab`, `MarkdownLintAndFormatEngine.lint`, `DocumentSession.applyTextEdits`, and `refreshDiagnosticsForActiveDocument` into focused single-responsibility sub-passes with `cyclomatic <= 15` and `cognitive <= 25` (`[BC-001]`, `[BC-002]`, `[SEC-012]`).
  - Replace branching switches in `performCheatSheetCommand`, `dispatchCommandOnly`, and `attachKeyDownMonitor` with table-driven command dispatch maps (`[UI-005]`, `[AR-010]`).
- **Point 4 — Shorten File Dependency Depth (`<= 10`) & Eliminate Dead Private Symbols (`MODIFIED REQ-006`, `ADDED REQ-009`)**:
  - Decouple horizontal `SwiftEditWorkbenchModel+*.swift` extension-to-extension call chains so max file dependency depth across `Sources/` drops from `15` to `<= 10` while maintaining `0` circular file dependencies (`[AR-006]`, `[AR-007]`).
  - Remove or wire all `20` unreferenced private symbols flagged by `tokensave_dead_code` in `Sources/` (`[TEST-006]`).
- **Point 5 — Enforce `>= 85%` Full-Codebase Line Coverage & TokenSave Re-Analysis Convergence (`ADDED REQ-010`)**:
  - Expand unit and integration tests across `SwiftEditCore` and `SwiftEditUI` so `llvm-cov report` confirms `>= 85.0%` line coverage on `SwiftEditCore`, `>= 85.0%` on `SwiftEditUI`, and `>= 85.0%` overall, followed by `tokensave sync` and automated verification of all graph metrics (`[TEST-001]`, `[TEST-005]`, `[TEST-008]`).

## Capabilities
- New Capabilities: None
- Modified Capabilities: `workbench-editor-and-linter-modular-decomposition`

## Domain Carrier & Decision Ownership (BC-###)
- **BC-001**: `DocumentCore`, `MarkdownLintAndFormat`, `LogSupport`, `WorkspaceAndTabSession`, and `ArchitectureFitness` in `SwiftEditCore` (pure `Foundation`), plus `@MainActor` `SwiftEditUI` theme, coordinators, workbench, and TextKit 2 editor layers (`[BC-001]`, `[BC-002]`, `[AR-006]`).
- **Owned Decisions**: Static enforcement of `maxNominalMembers <= 25` and `maxNominalBlockLines <= 400`, zero call-graph recursion in `Sources/`, per-method cyclomatic (`<= 15`) and cognitive (`<= 25`) complexity ceilings, file dependency chain depth (`<= 10`), zero dead private functions, and `>= 85%` line coverage across `SwiftEditCore` and `SwiftEditUI` (`[BC-004]`, `[UI-005]`, `[TEST-006]`, `[TEST-008]`).
- **Forbidden Responsibilities**: Refactoring MUST NEVER drop or alter any user-facing feature, shortcut, theme color, or Markdown/YAML/Log lint rule; `SwiftEditCore` MUST NEVER import or call `SwiftEditUI`; complexity reduction MUST NEVER weaken security validation in `MarkdownLinterInlineSecurityPass` or `CodeModularityFitnessScanner` (`[AR-006]`, `[SEC-003]`, `[SEC-012]`).
- **External Decision References**: `(DocumentID, BufferRevision)` immutable value-type tags exchanged between `SwiftEditUI` and `SwiftEditCore` (`[AR-008]`).

## Impact
- `Sources/SwiftEditCore/ArchitectureFitness/CodeModularityFitnessScanner.swift` (tightened `maxNominalMembers: 25`, `maxNominalBlockLines: 400`, method complexity & dead-code / depth verifiers)
- `Sources/SwiftEditCore/DocumentCore/` (`DocumentSession.swift`, `CursorMetricsCalculator.swift`, `DoubleClickSelectionCycle.swift`)
- `Sources/SwiftEditCore/MarkdownLintAndFormat/` (`MarkdownPreviewProjector.swift`, `MarkdownLinterInlineSecurityPass.swift`, `MarkdownLintAndFormatEngine.swift`, `MarkdownAuthoringCommands.swift`, `MarkdownAllConstructsLinter.swift`, `YAMLSupport/`)
- `Sources/SwiftEditCore/LogSupport/LogSyntaxHighlighter.swift`
- `Sources/SwiftEditCore/WorkspaceAndTabSession/WorkspaceTabSession.swift`
- `Sources/SwiftEditUI/Theme/` (`PurpleThemeAndZoom.swift`, `ZoomedChromeMetrics.swift`, `AppTypography.swift`)
- `Sources/SwiftEditUI/Views/` (`EditorRenderingAttributes.swift`, `SwiftEditNSTextViewAndUndoRegistry.swift`, `TextKit2EditorView.swift`, `TextKit2EditorCoordinator.swift`, `SwiftEditShortcutDispatcher.swift`, `SwiftEditRootView.swift`, `SwiftEditRootView+LifecycleSheetsAlertsAndKeyMonitor.swift`, `UpdateCheckSheetView.swift`, `PropertiesPanelView.swift`)
- `Sources/SwiftEditUI/Coordinators/WorkspaceEditorAndDiffCoordinators.swift`
- `Sources/SwiftEditUI/Workbench/` (`SwiftEditWorkbenchModel.swift` and `+*.swift` extensions)
- `Sources/SwiftEditUI/Workspace/` (`LogTailController.swift`, `EmbeddedTerminalRegistry.swift`)
- `Tests/SwiftEditTests/` (new and expanded coverage suites for complexity-reduced methods, recursion-free helpers, and `>= 85%` full-codebase coverage gate)

## Security Impact
- Preserves all 5-gate inline security checks in `MarkdownLinterInlineSecurityPass.scanInline` (`javascript:`, `vbscript:`, `data:text/html`, `file:`, `../` path traversal, and disallowed control/BiDi scalars `CWE-79`/`CWE-22`) while decomposing cognitive complexity from `79` to `<= 25` (`[SEC-012]`).
- Eliminates vnode event-handler cycle coupling in `LogTailWorker` while preserving `O_EVTONLY | O_CLOEXEC` descriptor cleanup on cancel (`CWE-400`, `[SEC-012]`).
- Preserves canonical root confinement (`CWE-22`, `[SEC-003]`), `4 MiB` file size limits, and `4_096`-node bounded iterative `NSView`/`CALayer` traversal (`CWE-674`, `[SEC-012]`).

## Metadata
- Owner: swift-macos-expert
- Domain: apple-swift-macos, oop-architecture, cyber-security, test-quality
- Reviewer: oop-architecture-expert, cyber-security-expert, test-quality-auditor, spec-sdlc-expert
- Branch: main
- Manual-Steps: none
- Modifies-Specs: 026-god-class-flattening-and-acyclicity (REQ-001, REQ-002, REQ-004, REQ-006, REQ-007)
- Constitutional-Rules: AR-001, AR-002, AR-005, AR-006, AR-007, AR-008, AR-009, AR-010, BC-001, BC-002, BC-004, UI-001, UI-002, UI-005, UI-006, UI-007, TEST-001, TEST-004, TEST-005, TEST-006, TEST-008, SEC-001, SEC-003, SEC-004, SEC-009, SEC-010, SEC-012, SDD-001, SDD-002, SDD-003
- Amends-Constitution: none

## Prerequisites
- `026-god-class-flattening-and-acyclicity`
- `025-workbench-editor-and-linter-modular-decomposition`
- `024-send-to-terminal-contextual-action`
