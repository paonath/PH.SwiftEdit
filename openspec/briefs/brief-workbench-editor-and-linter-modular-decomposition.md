---
id: "brief-workbench-editor-and-linter-modular-decomposition"
change_id: "025-workbench-editor-and-linter-modular-decomposition"
capability: "workbench-editor-and-linter-modular-decomposition"
branch: "main"
modifies_specs: "none"
status: "approved-via-qa"
date: "2026-11-24"
owners:
  - "swift-macos-expert"
  - "oop-architecture-expert"
  - "cyber-security-expert"
  - "spec-sdlc-expert"
---

# TDD Specification Brief: `025-workbench-editor-and-linter-modular-decomposition`

## 1. Context & Scope

- **Request**: Decompose the project's God Classes, God Views, and high-complexity monoliths identified via TokenSave (`SwiftEditWorkbenchModel`, `SwiftEditRootView`, `TextKit2EditorView` + `Coordinator`, and `MarkdownAllConstructsLinter.diagnostics`) into modular, testable, reliable, and maintainable units, guarded by an automated `CodeModularityFitnessScanner` fitness gate.
- **QA Confirmation**: Full 4-part scope and modularity thresholds (`<= 800` lines per `.swift` file, `<= 600` lines per nominal type/extension block, `<= 75` declared members per nominal block) confirmed by the human operator in Phase 02.
- **Consolidated specs modified**: `none` (net-new `ADDED` capability `workbench-editor-and-linter-modular-decomposition`; 100% public API and behavioral backward-compatibility preserved across all prior living specifications `000..024`).
- **Governing Constitutional Rules**: `AR-001`, `AR-002`, `AR-005`, `AR-006`, `AR-007`, `AR-008`, `AR-009`, `AR-010`, `BC-001`, `BC-002`, `BC-004`, `UI-001`, `UI-005`, `UI-006`, `UI-007`, `TEST-001`, `TEST-006`, `TEST-008`, `SEC-003`, `SEC-009`, `SEC-010`, `SEC-012`, `SDD-001..003`.

## 2. Expert Notes & 4-Pillar Breakdown

- **Pillar 1 — Public Behaviors & Nominal Decomposition (`SwiftEditWorkbenchModel` & `SwiftEditRootView`)**:
  - Extract `SwiftEditWorkbenchModel` (~3,035 lines, 282+ members in `SwiftEditRootView.swift`) into `Sources/SwiftEditUI/Workbench/` with cohesive, unit-testable domain collaborators (`WorkbenchWordCompletionController`, `WorkbenchFindAndNavigationController`, `WorkbenchTerminalSessionController`, `WorkbenchSidebarFileController`, `WorkbenchUpdateController`) and domain-scoped extension files (`SwiftEditWorkbenchModel+WorkspaceAndSidebar.swift`, `+DocumentLifecycleAndSave.swift`, `+FindReplaceAndNavigation.swift`, `+MarkdownLintPreviewAndFrontmatter.swift`, `+TerminalLogAndUpdates.swift`, `+ContextualMenuAndShortcuts.swift`).
  - Keep `SwiftEditWorkbenchModel`'s public `@MainActor` facade methods and observable properties 100% source-compatible so existing `SwiftEditTests` suites pass without weakening any assertion.
  - Decompose `SwiftEditRootView` (~1,300 lines) into focused view extension files under `Sources/SwiftEditUI/Views/` (`SwiftEditRootView+SidebarAndContextMenus.swift`, `SwiftEditRootView+PanelsCompareAndStatusBar.swift`, `SwiftEditRootView+LifecycleSheetsAlertsAndKeyMonitor.swift`) while retaining `private var toolbarBar: some View` and `private var tabBar: some View` inside `Sources/SwiftEditUI/Views/SwiftEditRootView.swift` to preserve static source inspection anchors in `AuditFindingsRegressionTests` (`F-017-03`), `Integrations021Tests` (`P-HDR2`), and `TranslucentHeaderBrandSubmenuTests`.
- **Pillar 2 — Editor & Linter Complexity Boundaries (`TextKit2EditorView`, `Coordinator`, `MarkdownAllConstructsLinter`)**:
  - Split `Sources/SwiftEditUI/Views/TextKit2EditorView.swift` (1,939 lines) into dedicated single-responsibility files: `SwiftEditNSTextViewAndUndoRegistry.swift`, `EditorRenderingAttributes.swift`, `TextKit2ViewportHighlightApplier.swift` (decomposing `applyNonMutatingHighlightsIfNeeded` and `applyStylingIfNeeded` into isolated passes for active line, word occurrences, bracket pairs, backtick spans, and lint underlines), `TextKit2EditorCoordinator.swift`, and `TextKit2EditorCoordinator+GhostCompletionAndCommands.swift`.
  - Refactor `MarkdownAllConstructsLinter.diagnostics(index:securityOnly:deadlineExceeded:)` (287 lines, `cyclomatic_complexity: 56`, `cognitive_complexity: 232`) into pure rule-family evaluator passes in `Sources/SwiftEditCore/MarkdownLintAndFormat/` (headings/frontmatter, fenced code & math blocks, lists & blockquotes, tables/thematic-breaks/whitespace, and inline link/image security) with per-method cyclomatic complexity `<= 15`, preserving 100% of the 26 `.allConstructs` rules, UTF-8 `securityOnlyDiagnostics` fast-path, and deadline budget fail-closed semantics.
- **Pillar 3 — Testability, KISS/SOLID Balance & Architecture Fitness (`CodeModularityFitnessScanner`)**:
  - Enforce `KISS`-First and `AR-009` (`Rule of Three`): use concrete `@MainActor` controllers and pure value-type evaluators rather than speculative 1:1 protocol hierarchies, reserving protocol seams strictly for external I/O (`FileSystemProviding`, `PreferencesProviding`, `Clock`).
  - Introduce `CodeModularityFitnessScanner` in `Sources/SwiftEditCore/ArchitectureFitness/` (pure `Foundation`, zero UI imports) verifying that every production `.swift` file under `Sources/SwiftEditCore` and `Sources/SwiftEditUI` complies with: file lines `<= 800`, nominal declaration/extension block lines `<= 600`, and declared members per block `<= 75`.
- **Pillar 4 — Abuse Cases & Negative Security (`SEC-003`, `SEC-012`)**:
  - `CodeModularityFitnessScanner.scanDirectory(at:budgets:)` MUST canonicalize root and enumerated paths (`resolvingSymlinksInPath`), rejecting symlinks or relative `..` path traversal escaping the repository `Sources/` root fail-closed (`Trait: security`), and bound input source size (`<= 4 MiB` per source file) to prevent memory exhaustion during static analysis.
  - Extracted `WorkbenchSidebarFileController`, `WorkbenchTerminalSessionController`, and `MarkdownAllConstructsLinter` rule passes MUST preserve all symlink confinement, multiline terminal payload warnings, and unsafe scheme/image path lint rejections (`SEC-001..SEC-012`).

## 3. Given/When/Then Contracts & Path Coverage Matrix

| Unit | Path | Trait | Summary |
| :--- | :--- | :--- | :--- |
| `CodeModularityFitnessScanner` | P1 | positive | Live `Sources/SwiftEditCore` and `Sources/SwiftEditUI` trees pass file (`<= 800` lines), nominal block (`<= 600` lines), and member (`<= 75`) modularity budgets with zero violations |
| `CodeModularityFitnessScanner` | N1 | negative | Synthetic `.swift` fixture exceeding `800` file lines, `600` nominal block lines, or `75` declared members returns typed `CodeModularityViolation` diagnostics |
| `CodeModularityFitnessScanner` | N2 | security | Symlinked `.swift` file or `..` traversal escaping the scanned root directory or source exceeding `4 MiB` is rejected fail-closed with a security boundary violation |
| `WorkbenchSubControllers` | P2 | positive | Isolated `WorkbenchWordCompletionController`, `WorkbenchFindAndNavigationController`, `WorkbenchTerminalSessionController`, and `WorkbenchSidebarFileController` execute completion, find/replace, PTY queuing, and confined sidebar CRUD deterministically and delegate seamlessly through `SwiftEditWorkbenchModel` |
| `WorkbenchSubControllers` | N3 | negative | Out-of-scope sidebar path, empty/stale completion prefix, invalid go-to-line input, or multiline terminal send without confirmation is rejected without mutating active session state |
| `SwiftEditRootViewDecomposition` | P3 | positive | Decomposed `SwiftEditRootView` and extension files compile under `@MainActor`, preserve `toolbarBar` and `tabBar` anchors in `SwiftEditRootView.swift`, and pass static theme token and accessibility audits |
| `SwiftEditRootViewDecomposition` | N4 | negative | Unlabeled icon-only buttons, hardcoded non-palette colors, or 20ms polling regressions in any extracted view file are caught and rejected by static view fitness audits |
| `TextKit2EditorDecomposition` | P4 | positive | `TextKit2ViewportHighlightApplier`, `TextKit2EditorCoordinator`, `SwiftEditNSTextView`, and `EditorRenderingAttributes` apply scoped viewport highlights, ghost completion, and per-tab undo in files `<= 800` lines |
| `TextKit2EditorDecomposition` | N5 | negative | Matching `HighlightRenderSignature`, out-of-viewport ranges, or stale `BufferRevision` skips redundant `NSTextContentStorage` attribute mutations and rejects out-of-bounds UTF-16 ranges |
| `MarkdownLinterRuleFamilies` | P5 | positive | Modular `MarkdownAllConstructsLinter` rule-family passes emit identical 26-rule diagnostics and quick-fixes with every pass method at cyclomatic complexity `<= 15` |
| `MarkdownLinterRuleFamilies` | N6 | security | Exceeded deadline budget or malicious `javascript:`/`vbscript:`/`file:`/parent-traversal `../` markdown links and images fail closed and emit security diagnostics identically to the baseline linter |
