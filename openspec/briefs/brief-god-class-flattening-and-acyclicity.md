---
id: "brief-god-class-flattening-and-acyclicity"
change_id: "026-god-class-flattening-and-acyclicity"
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
---

# TDD Specification Brief: `026-god-class-flattening-and-acyclicity`

## 1. Context & Scope

- **Request**: Flatten remaining nominal God Classes identified by `tokensave_god_class` (`SwiftEditWorkbenchModel`: 80 members, `PurpleThemePalette`: 72 members, `TextKit2EditorView.Coordinator`: 61 members), eliminate all 4 file-level circular dependency cycles (`tokensave_circular`, 129 cycle edges, raising Acyclicity from `0.6079` to `1.0`), and eliminate recursion/self-loop call cycles (`tokensave_recursion`: `performUpdateCheck` ↔ `checkForUpdates`, recursive `NSView`/`CALayer` tree traversals, and wrapper self-loops).
- **QA Confirmation**: Confirmed by human operator in Phase 02 (`maxNominalMembers <= 45` across all nominal declaration blocks, `0` file-level dependency cycles, and iterative/disambiguated recursion elimination).
- **Consolidated specs modified**: `openspec/specs/workbench-editor-and-linter-modular-decomposition/spec.md` (`MODIFIED` `REQ-001`, `REQ-002`, `REQ-004`; `ADDED` `REQ-006`, `REQ-007`).
- **Governing Constitutional Rules**: `AR-001`, `AR-002`, `AR-005`, `AR-006`, `AR-007`, `AR-008`, `AR-009`, `AR-010`, `BC-001`, `BC-002`, `UI-001`, `UI-002`, `UI-005`, `UI-006`, `UI-007`, `TEST-001`, `TEST-004`, `TEST-006`, `TEST-008`, `SEC-001`, `SEC-003`, `SEC-004`, `SEC-012`, `SDD-001..003`.

## 2. Expert Notes & 4-Pillar Breakdown

- **Pillar 1 — God-Class Member Flattening (`MODIFIED REQ-001`, `REQ-002`, `REQ-004`)**:
  - Tighten `CodeModularityBudgets.default.maxNominalMembers` from `75` to `45` and ensure `CodeModularityFitnessScanner.isMemberDeclaration` counts `@ObservationIgnored` and attribute-prefixed declarations accurately alongside `init`/`deinit`.
  - Flatten `SwiftEditWorkbenchModel` (`Sources/SwiftEditUI/Workbench/SwiftEditWorkbenchModel.swift`) from `80` nominal members to `<= 40` by grouping cohesive state domains (e.g., workspace/folder navigation state, modal sheet/dialog presentation state, compare/log-tail session registries, and appearance/accessibility state) and moving forwarding computed properties to their domain extension files while preserving 100% public `@MainActor @Observable` property/method source compatibility.
  - Flatten `TextKit2EditorView.Coordinator` (`Sources/SwiftEditUI/Views/TextKit2EditorCoordinator.swift`) from `61` nominal members to `<= 35` by encapsulating typography/style cache fields, buffer synchronization tokens, line-index/viewport caches, and editor action callbacks into dedicated state structs (`CoordinatorStyleState`, `CoordinatorBufferSyncState`, `CoordinatorLineIndexCache`) and moving secondary methods into extension blocks.
  - Flatten `PurpleThemePalette` (`Sources/SwiftEditUI/Theme/PurpleThemeAndZoom.swift`) from `72` nominal members in the primary `struct` declaration to `<= 45` by grouping log syntax and safety warning tokens into cohesive sub-structs with backward-compatible computed forwarding properties in a `PurpleThemePalette` extension.
- **Pillar 2 — File-Level Acyclicity & Zero Circular Dependencies (`ADDED REQ-006`)**:
  - Eliminate all upward `SwiftEditCore -> SwiftEditUI` and `Sources -> Tests` call-graph edges: rename/disambiguate `PerTabUndoManagerRegistry.removeAll()` (`clearAllUndoManagers()`), private `SettingsView.rows` (`settingPickerRows`), private `KeyboardShortcutsCheatSheetView.matches` (`shortcutEntryMatches`), and `RecentFilesStore.now` (`clockNow`).
  - Break internal `SwiftEditCore/MarkdownLintAndFormat` cycles by extracting `MarkdownLineIndex` and `SyntaxHighlightSpan` into a leaf file `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownLineIndex.swift` and disambiguating private span/diagnostic collector methods (`appendHighlightSpan`, `appendLintDiagnostic`, `activeFenceTracker`).
  - Break `SwiftEditUI/Views` and `SwiftEditUI/Workbench` cycles: move `handleListIndent` to `TextKit2EditorCoordinator+GhostCompletionAndCommands.swift` (breaking SCC 2), move `applyWordOccurrences` to `TextKit2ViewportHighlightApplier.swift` (breaking SCC 3), decouple `ElementContextualMenuView`, `FindReplaceGoToLineBar`, and `EmbeddedTerminalEmulatorView` from reverse Workbench calls, and stratify `SwiftEditWorkbenchModel+*.swift` extensions into a unidirectional DAG.
- **Pillar 3 — Recursion Cycle Elimination & Iterative Bounded Traversal (`ADDED REQ-007`)**:
  - Eliminate the length-2 mutual recursion cycle `performUpdateCheck` ↔ `checkForUpdates` in `SwiftEditWorkbenchModel+TerminalLogAndUpdates.swift` by disambiguating the underlying checker method (`evaluateReleaseUpdate(currentVersion:)` on `GitHubReleaseUpdateChecker`).
  - Replace recursive `NSView` and `CALayer` tree traversals (`markSubviewsAndLayersNeedsDisplay(_:)` and `markLayerTreeNeedsDisplay(_:)` in `SwiftEditNSTextViewAndUndoRegistry.swift`) with iterative worklist traversals bounded by a deterministic node visitation cap (`maxVisitedNodes: 4_096`) to prevent stack overflow on pathological view/layer hierarchies.
  - Eliminate false self-recursion call edges in `PreferencesProviding.swift` (`UserDefaultsPreferencesStore`), `DesktopWorkspaceIntegrating.swift` (`resolveTerminalLaunch`), `SettingsView.swift` (`entries`), and `SwiftEditWorkbenchModel+ContextualMenuAndShortcuts.swift` (`editableEditorTextView`).
- **Pillar 4 — Abuse Cases & Negative Security (`SEC-003`, `SEC-012`)**:
  - `CodeModularityFitnessScanner` continues to enforce canonical root confinement (`resolvingSymlinksInPath`), rejecting symlinks or `..` segments escaping `Sources/` and oversized files (`> 4 MiB`) fail-closed (`Trait: security`).
  - Iterative `NSView`/`CALayer` invalidation traversal MUST enforce a hard node visitation cap (`4_096` nodes) and cycle-visited guard so cyclic or deeply nested layer graphs terminate deterministically without stack overflow or main-thread hang (`CWE-674` Uncontrolled Recursion / `CWE-400`).

## 3. Given/When/Then Contracts & Path Coverage Matrix

| Unit | Path | Trait | Summary |
| :--- | :--- | :--- | :--- |
| `CodeModularityFitnessScanner` | P1 | positive | Live `Sources/SwiftEditCore` and `Sources/SwiftEditUI` trees pass file (`<= 800` lines), nominal block (`<= 600` lines), and tightened nominal member (`<= 45`) budgets with zero violations; `SwiftEditWorkbenchModel` (`<= 40`), `Coordinator` (`<= 35`), and `PurpleThemePalette` (`<= 45`) all pass |
| `CodeModularityFitnessScanner` | N1 | negative | Synthetic `.swift` fixture declaring `46` nominal members (including `@ObservationIgnored` properties and `init`/`deinit`), `601` block lines, or `801` file lines emits typed `CodeModularityViolation` diagnostics |
| `CodeModularityFitnessScanner` | N2 | security | Symlinked `.swift` file or `..` traversal escaping the canonical `Sources/` root or payload exceeding `4 MiB` fails closed with `.securityBoundaryViolation` |
| `FileDependencyAcyclicityGate` | P6 | positive | Production file dependency graph across `Sources/SwiftEditCore` and `Sources/SwiftEditUI` contains `0` Strongly Connected Components (`cycle_count == 0`, `edges_in_cycles == 0`) with `MarkdownLineIndex.swift` as an acyclic leaf |
| `FileDependencyAcyclicityGate` | N7 | negative | Synthetic file graph fixture containing a 2-file cycle (`A.swift <-> B.swift`) or an upward `SwiftEditCore -> SwiftEditUI` call edge is detected and rejected with explicit cycle path diagnostics |
| `BoundedIterativeTraversalAndUpdateFlow` | P7 | positive | `checkForUpdates()` / `performUpdateCheck()`, iterative `markSubviewsAndLayersNeedsDisplay` / `markLayerTreeNeedsDisplay`, and `UserDefaultsPreferencesStore` execute without recursive call cycles while preserving all observable update and display behaviors |
| `BoundedIterativeTraversalAndUpdateFlow` | N8 | security | Deeply nested or cyclic layer/view hierarchy exceeding `4_096` nodes terminates deterministically at the visitation cap without uncontrolled recursion (`CWE-674`) or crash |
