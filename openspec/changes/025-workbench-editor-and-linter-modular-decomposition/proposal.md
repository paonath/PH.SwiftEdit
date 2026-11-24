# Proposal: Workbench, TextKit 2 Editor, and Markdown Linter Modular Decomposition

## Why
TokenSave static analysis of `PH.SwiftEdit` (`quality_signal = 7388`, `equality = 0.2754`, `gini = 0.7246` — *"extreme inequality (god files likely)"*) revealed severe concentration of responsibilities in three production hotspots:
1. **`SwiftEditWorkbenchModel` & `SwiftEditRootView`** in `Sources/SwiftEditUI/Views/SwiftEditRootView.swift` (`4,523` lines on disk; `282+` members and `136+` methods in `SwiftEditWorkbenchModel`, `43+` members in `SwiftEditRootView`, coupled to `47` incoming and `31` outgoing files).
2. **`TextKit2EditorView` & `Coordinator`** in `Sources/SwiftEditUI/Views/TextKit2EditorView.swift` (`1,939` lines on disk; `68+` members in `Coordinator`, `33+` members in `TextKit2EditorView`, and `applyNonMutatingHighlightsIfNeeded` at cyclomatic complexity `31`).
3. **`MarkdownAllConstructsLinter.diagnostics`** in `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownAllConstructsLinter.swift` (`829` lines; `diagnostics(index:securityOnly:deadlineExceeded:)` spans `287` lines with cyclomatic complexity `56`, cognitive complexity `232`, and `CRAP: 3192.0`).

Decomposing these God Classes, God Views, and high-complexity methods into single-responsibility, independently testable units—guarded by an automated `CodeModularityFitnessScanner` fitness gate—restores structural equality, reduces merge/regression blast radius, and improves unit testability while keeping 100% of existing public APIs and specifications intact (`[AR-001]`, `[AR-006]`, `[AR-008]`, `[AR-009]`, `[AR-010]`, `[UI-005]`, `[TEST-006]`).

## What Changes
- **Decompose `SwiftEditWorkbenchModel` (`Sources/SwiftEditUI/Workbench/`)**:
  - Extract cohesive, independently testable `@MainActor` sub-controllers (`WorkbenchWordCompletionController`, `WorkbenchFindAndNavigationController`, `WorkbenchTerminalSessionController`, `WorkbenchSidebarFileController`, `WorkbenchUpdateController`) and domain-scoped extension files (`SwiftEditWorkbenchModel+WorkspaceAndSidebar.swift`, `SwiftEditWorkbenchModel+DocumentLifecycleAndSave.swift`, `SwiftEditWorkbenchModel+FindReplaceAndNavigation.swift`, `SwiftEditWorkbenchModel+MarkdownLintPreviewAndFrontmatter.swift`, `SwiftEditWorkbenchModel+TerminalLogAndUpdates.swift`, `SwiftEditWorkbenchModel+ContextualMenuAndShortcuts.swift`).
  - Keep `SwiftEditWorkbenchModel` public signatures and `@Observable` properties 100% backward-compatible as a coordinating facade (`[AR-009]`, `[AR-010]`, `[UI-005]`).
- **Decompose `SwiftEditRootView` (`Sources/SwiftEditUI/Views/`)**:
  - Extract sidebar/context menus, panels/compare/status bar, and lifecycle/sheets/alerts/keyboard-monitor logic into dedicated files (`SwiftEditRootView+SidebarAndContextMenus.swift`, `SwiftEditRootView+PanelsCompareAndStatusBar.swift`, `SwiftEditRootView+LifecycleSheetsAlertsAndKeyMonitor.swift`), while retaining `private var toolbarBar: some View` and `private var tabBar: some View` inside `Sources/SwiftEditUI/Views/SwiftEditRootView.swift` so existing static regression checks (`AuditFindingsRegressionTests`, `Integrations021Tests`, `TranslucentHeaderBrandSubmenuTests`) pass unchanged (`[UI-001]`, `[UI-005]`, `[TEST-006]`).
- **Decompose `TextKit2EditorView` & `Coordinator` (`Sources/SwiftEditUI/Views/`)**:
  - Split `TextKit2EditorView.swift` into single-responsibility files: `SwiftEditNSTextViewAndUndoRegistry.swift`, `EditorRenderingAttributes.swift`, `TextKit2ViewportHighlightApplier.swift` (decomposing `applyNonMutatingHighlightsIfNeeded` and `applyStylingIfNeeded` into isolated, testable highlight passes for active line, word occurrences, bracket pairs, backtick spans, and lint underlines), `TextKit2EditorCoordinator.swift`, and `TextKit2EditorCoordinator+GhostCompletionAndCommands.swift` (`[UI-006]`, `[UI-007]`, `[AR-010]`).
- **Decompose `MarkdownAllConstructsLinter.diagnostics` (`Sources/SwiftEditCore/MarkdownLintAndFormat/`)**:
  - Refactor the 287-line `diagnostics(index:securityOnly:deadlineExceeded:)` method into pure rule-family evaluator passes (`MarkdownLinterRuleFamilyPasses.swift`: headings/frontmatter, fenced code & math blocks, lists & blockquotes, tables/thematic-breaks/whitespace, and inline link/image security) with per-method cyclomatic complexity `<= 15`, preserving all 26 `.allConstructs` rules, UTF-8 `securityOnlyDiagnostics`, and deadline budget fail-closed behavior (`[BC-001]`, `[BC-002]`, `[SEC-012]`).
- **Add `CodeModularityFitnessScanner` (`Sources/SwiftEditCore/ArchitectureFitness/`)**:
  - Implement a pure-`Foundation` static scanner and `ArchitectureFitnessTests` suite enforcing production modularity budgets across `Sources/SwiftEditCore` and `Sources/SwiftEditUI`: `<= 800` lines per `.swift` file, `<= 600` lines per nominal type/extension block, and `<= 75` declared members per nominal block, with canonical symlink and `..` path-traversal rejection (`[AR-006]`, `[TEST-006]`, `[SEC-003]`, `[SEC-012]`).

## Capabilities
- New Capabilities: `workbench-editor-and-linter-modular-decomposition`
- Modified Capabilities: None

## Domain Carrier & Decision Ownership (BC-###)
- **BC-001**: `MarkdownLintAndFormat` (`Core`) and `ArchitectureFitness` (`Supporting`) in `SwiftEditCore` (pure `Foundation`), plus `@MainActor` `SwiftEditUI` workbench, view, and TextKit 2 presentation adapters (`[BC-001]`, `[BC-002]`, `[AR-006]`).
- **Owned Decisions**: Static source modularity validation (`CodeModularityFitnessScanner`), pure rule-family pass orchestration in `MarkdownAllConstructsLinter`, scoped TextKit 2 viewport highlight pass application (`TextKit2ViewportHighlightApplier`), and `@MainActor` workbench sub-controller state coordination (`[BC-004]`, `[UI-005]`, `[UI-007]`).
- **Forbidden Responsibilities**: `SwiftEditCore` components (`CodeModularityFitnessScanner`, `MarkdownAllConstructsLinter` rule passes) MUST NEVER import `AppKit`, `UIKit`, `SwiftUI`, `WebKit`, `Combine`, or `Network`, MUST NEVER follow symlinks escaping the scanned repository root, and MUST NEVER alter or weaken any of the 26 `.allConstructs` lint rules or existing `SwiftEditWorkbenchModel` public behavioral contracts (`[AR-006]`, `[BC-002]`, `[SEC-003]`, `[SEC-010]`).
- **External Decision References**: `(DocumentID, BufferRevision)` immutable value-type tags exchanged between `SwiftEditUI` coordinators and `SwiftEditCore` engines (`[AR-008]`).

## Impact
- `Sources/SwiftEditCore/ArchitectureFitness/CodeModularityFitnessScanner.swift` (new)
- `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownAllConstructsLinter.swift` and `MarkdownLinterRuleFamilyPasses.swift` (decomposed)
- `Sources/SwiftEditUI/Workbench/` (`SwiftEditWorkbenchModel.swift`, sub-controllers, and `+*.swift` domain extensions)
- `Sources/SwiftEditUI/Views/SwiftEditRootView.swift` and `SwiftEditRootView+*.swift` view extensions
- `Sources/SwiftEditUI/Views/TextKit2EditorView.swift`, `SwiftEditNSTextViewAndUndoRegistry.swift`, `EditorRenderingAttributes.swift`, `TextKit2ViewportHighlightApplier.swift`, `TextKit2EditorCoordinator.swift`, and `TextKit2EditorCoordinator+GhostCompletionAndCommands.swift`
- `Tests/SwiftEditTests/` (new modularity fitness, workbench sub-controller, viewport highlight applier, and linter family pass unit tests)

## Security Impact
- `CodeModularityFitnessScanner` enforces canonical symlink resolution (`resolvingSymlinksInPath`) and rejects any path escaping the scanned directory root or exceeding `4 MiB` per source file (`CWE-22`, `CWE-400`, `[SEC-003]`, `[SEC-012]`).
- Extracted `WorkbenchSidebarFileController`, `WorkbenchTerminalSessionController`, and `MarkdownAllConstructsLinter` rule passes preserve all existing security boundaries: symlink-confined workspace file CRUD (`[SEC-003]`), multiline terminal payload confirmation (`[SEC-004]`), verified HTTPS update checks (`[SEC-001]`), and unsafe URI scheme / image path traversal lint detection (`[SEC-012]`).

## Metadata
- Owner: swift-macos-expert
- Domain: apple-swift-macos, oop-architecture, cyber-security
- Reviewer: oop-architecture-expert, cyber-security-expert, spec-sdlc-expert
- Branch: main
- Manual-Steps: none
- Modifies-Specs: none
- Constitutional-Rules: AR-001, AR-002, AR-005, AR-006, AR-007, AR-008, AR-009, AR-010, BC-001, BC-002, BC-004, UI-001, UI-005, UI-006, UI-007, TEST-001, TEST-006, TEST-008, SEC-003, SEC-009, SEC-010, SEC-012, SDD-001, SDD-002, SDD-003
- Amends-Constitution: none

## Prerequisites
- `024-send-to-terminal-contextual-action`
- `023-embedded-terminal-json-settings-log-highlights-and-onboard-docs`
- `017-deep-debug-zoom-fonts-opendyslexic-and-perf`
- `013-comprehensive-markdown-linter-and-diagnostics-ui`
