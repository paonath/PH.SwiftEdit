# Proposal: God-Class Member Flattening, File-Level Acyclicity, and Recursion Elimination

## Why
Post-025 TokenSave analysis of `PH.SwiftEdit` (`quality_signal = 7526` across `115` production files) surfaced three structural bottlenecks in points 1, 2, and 3:
1. **Point 1 — Remaining Nominal God-Classes (`tokensave_god_class`)**:
   - `SwiftEditWorkbenchModel` (`Sources/SwiftEditUI/Workbench/SwiftEditWorkbenchModel.swift`) still declares `80` nominal members (78 stored/computed properties + `init`/`deinit`), `PurpleThemePalette` (`Sources/SwiftEditUI/Theme/PurpleThemeAndZoom.swift`) declares `72` members, and `TextKit2EditorView.Coordinator` (`Sources/SwiftEditUI/Views/TextKit2EditorCoordinator.swift`) declares `61` members (48 mutable fields + 13 methods). Furthermore, `CodeModularityFitnessScanner` currently permits up to `75` members per nominal block and skips `@ObservationIgnored` declarations containing `(` or `{`.
2. **Point 2 — File-Level Dependency Cycles (`tokensave_circular`: 4 cycles, `acyclicity = 0.6079`, `129` edges in cycles)**:
   - **SCC 1 (42 files, 125 internal edges)**: Caused by (a) upward name-collision call edges from `SwiftEditCore` into `SwiftEditUI` (`PerTabUndoManagerRegistry.removeAll`, `SettingsView.rows`, `KeyboardShortcutsCheatSheetView.matches`), (b) `MarkdownLineIndex` residing inside `MarkdownSyntaxHighlighter.swift` instead of a dedicated leaf module, and (c) bidirectional cross-calls across `SwiftEditWorkbenchModel+*.swift` extensions and view files (`ElementContextualMenuView`, `FindReplaceGoToLineBar`, `EmbeddedTerminalEmulatorView`).
   - **SCC 2 & SCC 3 (2-file UI cycles)**: `TextKit2EditorCoordinator.swift` ↔ `TextKit2EditorCoordinator+GhostCompletionAndCommands.swift` (`handleListIndent`) and `TextKit2EditorView.swift` ↔ `TextKit2ViewportHighlightApplier.swift` (`applyWordOccurrences`).
   - **Cycle 4 (Source ↔ Test cycle)**: `RecentFilesStore.swift` ↔ `RecentFilesStoreTests.swift` via the `now()` closure name collision.
3. **Point 3 — Call-Graph Recursion Cycles (`tokensave_recursion`: 20 cycles in `Sources/`)**:
   - A length-2 mutual recursion cycle `performUpdateCheck` ↔ `checkForUpdates` in `SwiftEditWorkbenchModel+TerminalLogAndUpdates.swift` (caused by `GitHubReleaseUpdateChecker.checkForUpdates(currentVersion:)` sharing the method name of `SwiftEditWorkbenchModel.checkForUpdates()`), recursive `NSView`/`CALayer` tree traversals (`markSubviewsAndLayersNeedsDisplay`, `markLayerTreeNeedsDisplay` in `SwiftEditNSTextViewAndUndoRegistry.swift`), and self-loop wrapper collisions in `PreferencesProviding.swift`, `DesktopWorkspaceIntegrating.swift`, `SettingsView.swift`, and `SwiftEditWorkbenchModel+ContextualMenuAndShortcuts.swift`.

Flattening nominal member counts to `<= 45` (`<= 40` on `SwiftEditWorkbenchModel`, `<= 35` on `Coordinator`), breaking all 4 file-level dependency cycles (`0` cycles, `acyclicity = 1.0`), and replacing recursive view/layer traversals and name-colliding recursion loops with bounded iterative algorithms and unambiguous method contracts significantly raises architectural health while preserving 100% of existing public APIs (`[AR-006]`, `[AR-008]`, `[AR-009]`, `[AR-010]`, `[UI-005]`, `[TEST-006]`, `[SEC-012]`).

## What Changes
- **Point 1 — Flatten Nominal God-Classes & Tighten `CodeModularityFitnessScanner` (`MODIFIED REQ-001`, `REQ-002`, `REQ-004`)**:
  - Lower `CodeModularityBudgets.default.maxNominalMembers` from `75` to `45` and refine `CodeModularityFitnessScanner.isMemberDeclaration` so attribute-prefixed (`@ObservationIgnored`, `@MainActor`) properties and `init`/`deinit` are always counted accurately (`[AR-006]`, `[TEST-006]`, `[SEC-003]`, `[SEC-012]`).
  - Reduce `SwiftEditWorkbenchModel` nominal declaration block members from `80` to `<= 40` by grouping cohesive state domains and moving forwarding/computed accessors to domain extensions while preserving every public `@MainActor @Observable` property and method signature (`[AR-009]`, `[AR-010]`, `[UI-005]`).
  - Reduce `TextKit2EditorView.Coordinator` nominal declaration block members from `61` to `<= 35` by encapsulating typography/style cache fields, buffer synchronization state, and line-index/viewport cache fields into cohesive sub-state structs and moving secondary helpers to extension blocks (`[AR-010]`, `[UI-006]`, `[UI-007]`).
  - Reduce `PurpleThemePalette` primary `struct` nominal members from `72` to `<= 45` by grouping log syntax and warning tokens into cohesive sub-structs with backward-compatible computed forwarding properties in an extension (`[UI-001]`, `[UI-002]`).
- **Point 2 — Eliminate All 4 File-Level Circular Dependency Cycles (`ADDED REQ-006`)**:
  - Extract `MarkdownLineIndex` and `SyntaxHighlightSpan` from `MarkdownSyntaxHighlighter.swift` into a dedicated leaf file `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownLineIndex.swift` and disambiguate private span/diagnostic collectors (`appendHighlightSpan`, `appendLintDiagnostic`) so `SwiftEditCore/MarkdownLintAndFormat` forms a strict acyclic DAG (`[AR-006]`, `[BC-001]`, `[BC-002]`).
  - Eliminate all upward `SwiftEditCore -> SwiftEditUI` and `Sources -> Tests` call edges by disambiguating `PerTabUndoManagerRegistry` clear operations, `SettingsView` row helpers, `KeyboardShortcutsCheatSheetView` filter helpers, and `RecentFilesStore`'s injected clock closure (`[AR-006]`, `[AR-007]`).
  - Eliminate SCC 2 (`TextKit2EditorCoordinator.swift` ↔ `+GhostCompletionAndCommands.swift`), SCC 3 (`TextKit2EditorView.swift` ↔ `TextKit2ViewportHighlightApplier.swift`), and the intra-`Workbench` / `Views` cycles so `tokensave_circular` reports `0` cycles (`[AR-006]`, `[AR-010]`, `[UI-005]`).
- **Point 3 — Eliminate Call-Graph Recursion Cycles & Add Bounded Iterative View/Layer Traversal (`ADDED REQ-007`)**:
  - Eliminate the length-2 mutual recursion cycle `performUpdateCheck` ↔ `checkForUpdates` by disambiguating the `GitHubReleaseUpdateChecker` evaluation method name (`[SEC-001]`, `[SEC-004]`, `[TEST-004]`).
  - Replace recursive `markSubviewsAndLayersNeedsDisplay` and `markLayerTreeNeedsDisplay` in `SwiftEditNSTextViewAndUndoRegistry.swift` with bounded iterative worklist traversals (`maxVisitedNodes: 4_096`) to prevent uncontrolled recursion (`CWE-674`, `[UI-007]`, `[SEC-012]`).
  - Disambiguate self-loop wrapper call edges in `PreferencesProviding.swift`, `DesktopWorkspaceIntegrating.swift`, `SettingsView.swift`, and `SwiftEditWorkbenchModel+ContextualMenuAndShortcuts.swift` (`[AR-007]`, `[AR-010]`).

## Capabilities
- New Capabilities: None
- Modified Capabilities: `workbench-editor-and-linter-modular-decomposition`

## Domain Carrier & Decision Ownership (BC-###)
- **BC-001**: `MarkdownLintAndFormat` (`Core`), `WorkspaceAndTabSession` (`Supporting`), and `ArchitectureFitness` (`Supporting`) in `SwiftEditCore` (pure `Foundation`), plus `@MainActor` `SwiftEditUI` theme, workbench, and TextKit 2 editor presentation layers (`[BC-001]`, `[BC-002]`, `[AR-006]`).
- **Owned Decisions**: Tightened static nominal member budget validation (`maxNominalMembers: 45`), leaf `MarkdownLineIndex` UTF-8/UTF-16 line table indexing, acyclic file-level dependency layering between `SwiftEditCore` and `SwiftEditUI`, and bounded iterative `NSView`/`CALayer` display invalidation (`[BC-004]`, `[UI-005]`, `[UI-007]`, `[TEST-006]`).
- **Forbidden Responsibilities**: `SwiftEditCore` files MUST NEVER reference or resolve call edges into `SwiftEditUI` or `Tests/`, `CodeModularityFitnessScanner` MUST NEVER follow symlinks escaping the canonical repository root, and iterative view/layer invalidation MUST NEVER recurse unboundedly on deep or cyclic layer trees (`[AR-006]`, `[SEC-003]`, `[SEC-010]`, `[SEC-012]`).
- **External Decision References**: `(DocumentID, BufferRevision)` immutable value-type tags exchanged between `SwiftEditUI` coordinators and `SwiftEditCore` engines (`[AR-008]`).

## Impact
- `Sources/SwiftEditCore/ArchitectureFitness/CodeModularityFitnessScanner.swift` (tightened `maxNominalMembers: 45` and attribute-aware member counting)
- `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownLineIndex.swift` (extracted leaf file) and `MarkdownSyntaxHighlighter.swift`, `MarkdownLinterRuleFamilyPasses.swift`, `MarkdownPreviewProjector.swift`
- `Sources/SwiftEditCore/WorkspaceAndTabSession/RecentFilesStore.swift` and `PreferencesProviding.swift`
- `Sources/SwiftEditUI/Theme/PurpleThemeAndZoom.swift` (`PurpleThemePalette` sub-group flattening)
- `Sources/SwiftEditUI/Workbench/` (`SwiftEditWorkbenchModel.swift` and `+*.swift` unidirectional DAG stratification)
- `Sources/SwiftEditUI/Views/` (`TextKit2EditorCoordinator.swift`, `TextKit2EditorCoordinator+GhostCompletionAndCommands.swift`, `TextKit2EditorView.swift`, `TextKit2ViewportHighlightApplier.swift`, `SwiftEditNSTextViewAndUndoRegistry.swift`, `SettingsView.swift`, `KeyboardShortcutsCheatSheetView.swift`, `ElementContextualMenuView.swift`, `FindReplaceGoToLineBar.swift`, `EmbeddedTerminalEmulatorView.swift`)
- `Tests/SwiftEditTests/` (updated modularity fitness tests, acyclicity tests, and bounded iterative traversal tests)

## Security Impact
- Prevents uncontrolled recursion (`CWE-674`) and main-thread stack exhaustion (`CWE-400`) during `NSView` and `CALayer` appearance/redraw invalidation by replacing recursive tree walks with an iterative worklist bounded to `4_096` visited nodes (`[SEC-012]`).
- Preserves canonical symlink confinement (`CWE-22`, `[SEC-003]`), `4 MiB` static scan file size caps (`[SEC-012]`), verified GitHub HTTPS update checks (`[SEC-001]`, `[SEC-004]`), and 26-rule Markdown inline link/image security linting (`[SEC-012]`).

## Metadata
- Owner: swift-macos-expert
- Domain: apple-swift-macos, oop-architecture, cyber-security
- Reviewer: oop-architecture-expert, cyber-security-expert, spec-sdlc-expert
- Branch: main
- Manual-Steps: none
- Modifies-Specs: 025-workbench-editor-and-linter-modular-decomposition (REQ-001, REQ-002, REQ-004)
- Constitutional-Rules: AR-001, AR-002, AR-005, AR-006, AR-007, AR-008, AR-009, AR-010, BC-001, BC-002, BC-004, UI-001, UI-002, UI-005, UI-006, UI-007, TEST-001, TEST-004, TEST-006, TEST-008, SEC-001, SEC-003, SEC-004, SEC-009, SEC-010, SEC-012, SDD-001, SDD-002, SDD-003
- Amends-Constitution: none

## Prerequisites
- `025-workbench-editor-and-linter-modular-decomposition`
- `024-send-to-terminal-contextual-action`
- `023-embedded-terminal-json-settings-log-highlights-and-onboard-docs`
