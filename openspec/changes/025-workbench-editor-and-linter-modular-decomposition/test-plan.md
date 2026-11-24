# Test Plan: Workbench, TextKit 2 Editor, and Markdown Linter Modular Decomposition

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#), citing governing constitutional rules (`[TEST-001]`, `[TEST-005]`, `[TEST-006]`, `[TEST-008]`, `[SEC-003]`, `[SEC-012]`, `[SDD-001]`).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `CodeModularityFitnessScanner` | P1: Live `Sources/SwiftEditCore` and `Sources/SwiftEditUI` directories pass file (`<= 800` lines), nominal block (`<= 600` lines), and declared member (`<= 75`) modularity budgets with zero violations (`[TEST-006]`). | N1: Synthetic Swift fixtures with `801` file lines, `601` nominal block lines, or `76` declared members emit typed `CodeModularityViolation` diagnostics; N2 (`security`): Symlinked `.swift` file escaping root, `../` traversal, or file `> 4 MiB` is rejected fail-closed with `.securityBoundaryViolation` (`[SEC-003]`, `[SEC-012]`). |
| `MarkdownLinterRuleFamilyPasses` | P5: Decomposed rule-family passes (`MarkdownAllConstructsLinter` + `MarkdownLinterRuleFamilyPasses`) produce identical 26-rule diagnostics and `TextEdit` quick-fixes with every method at cyclomatic complexity `<= 15` (`[BC-001]`, `[TEST-005]`). | N6 (`security`): Exceeded deadline budget aborts with `timedOut == true`, and `javascript:`, `vbscript:`, `data:text/html`, `file:`, or `../` link/image targets emit `.unsafeLinkScheme` and `.unsafeImagePath` diagnostics without regression (`[SEC-012]`). |
| `WorkbenchSubControllers` | P2: Isolated sub-controllers (`WorkbenchWordCompletionController`, `WorkbenchFindAndNavigationController`, `WorkbenchTerminalSessionController`, `WorkbenchSidebarFileController`, `WorkbenchUpdateController`) deterministically execute word completion indexing/lookup, find/replace and go-to-line navigation, PTY terminal session queuing, confined sidebar CRUD, and update checks while synchronizing through `SwiftEditWorkbenchModel` (`[AR-010]`, `[UI-005]`). | N3: Single-character completion prefix, out-of-scope sidebar path, out-of-range go-to-line input, or unconfirmed multiline terminal selection is rejected without mutating buffer state, out-of-scope files, or PTY stdin (`[SEC-003]`, `[SEC-004]`). |
| `SwiftEditRootViewDecomposition` | P3: Decomposed `SwiftEditRootView.swift` and `SwiftEditRootView+*.swift` extensions compile under `@MainActor`, preserve `toolbarBar` and `tabBar` anchors in `SwiftEditRootView.swift`, and pass static theme token, accessibility label, and hit-target audits (`[UI-001]`, `[UI-005]`, `[TEST-006]`). | N4: Synthetic view fixtures containing non-palette colors, unlabeled icon-only buttons, or `.milliseconds(20)` submenu polling fail the static view audit (`[UI-001]`, `[TEST-006]`). |
| `TextKit2EditorDecomposition` | P4: `TextKit2ViewportHighlightApplier`, `TextKit2EditorView.Coordinator`, `SwiftEditNSTextView`, and `EditorRenderingAttributes` apply active-line, word-occurrence, bracket-pair, backtick, search, and lint highlight passes strictly within visible UTF-16 viewport ranges in files `<= 800` lines (`[UI-006]`, `[UI-007]`). | N5: Unchanged `HighlightRenderSignature` or highlight ranges outside the visible UTF-16 viewport window skip redundant `NSTextContentStorage` transactions and clamp invalid UTF-16 offsets (`[UI-007]`). |

## 2. Test Automation Strategy & Commands
- Unit test runner command: `swift test --parallel`
- Targeted modularity & architecture fitness suite command: `swift test --filter CodeModularityFitnessTests`
- Targeted decomposed linter suite command: `swift test --filter MarkdownLinterRuleFamilyPassesTests`
- Targeted workbench sub-controllers suite command: `swift test --filter WorkbenchSubControllersDecompositionTests`
- Targeted TextKit 2 highlight applier suite command: `swift test --filter TextKit2EditorDecompositionTests`
- Trait filter command: `swift test --filter "CodeModularityFitnessTests|MarkdownLinterRuleFamilyPassesTests"`

## 3. Testability Seams & Test Doubles
- Real collaborators: `DocumentSession`, `WorkspaceTabSession`, `MarkdownLineIndex`, `EditorHighlightProjection`, `PurpleThemePalette`, `TextKit2BufferAdapter`, `CodeModularityBudgets`.
- Isolation seams: `InMemoryFileSystemFake` (`FileSystemProviding`), `InMemoryKeyValueStore` (`PreferencesProviding`), injectable `deadlineExceeded: () -> Bool` closure, temporary canonical directory fixtures with symlink tests, and `@MainActor` headless `SwiftEditWorkbenchModel` instances (`[AR-007]`, `[TEST-004]`).

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | 5 EARS requirements (`REQ-001..REQ-005`) with 11 Given/When/Then scenarios (`P1..P5`, `N1..N6`) |
| Path coverage completeness | Verified | Every unit under test defines at least 1 positive (`P#`) and 1 negative (`N#`) path |
| Security traits tagged | Verified | Abuse scenarios `N2` and `N6` explicitly tagged `- **Trait**: security` |
