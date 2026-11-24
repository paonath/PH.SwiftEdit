# Test Plan: God-Class Member Flattening, File-Level Acyclicity, and Recursion Elimination

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#), citing governing constitutional rules (`[AR-006]`, `[TEST-001]`, `[TEST-005]`, `[TEST-006]`, `[TEST-008]`, `[SEC-003]`, `[SEC-012]`, `[SDD-001]`).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `CodeModularityFitnessScanner` | P1: Live `Sources/SwiftEditCore` and `Sources/SwiftEditUI` directories pass file (`<= 800` lines), nominal block (`<= 600` lines), and tightened declared member (`<= 45`) budgets with zero violations, confirming `SwiftEditWorkbenchModel <= 40`, `TextKit2EditorView.Coordinator <= 35`, and `PurpleThemePalette <= 45` (`[AR-006]`, `[TEST-006]`). | N1: Synthetic Swift fixtures with `801` file lines, `601` nominal block lines, or `46` declared members (including `@ObservationIgnored` properties and `init`/`deinit`) emit typed `CodeModularityViolation` diagnostics; N2 (`security`): Symlinked `.swift` file escaping canonical root, `../` traversal, or file `> 4 MiB` fails closed with `.securityBoundaryViolation` (`[SEC-003]`, `[SEC-012]`). |
| `WorkbenchAndEditorFlattening` | P2: Flattened `SwiftEditWorkbenchModel` (`<= 40` nominal members) and `WorkbenchSubControllers` preserve 100% observable state synchronization across completion, find/replace, terminal sessions, sidebar file CRUD, appearance, and updates; P4: Flattened `TextKit2EditorView.Coordinator` (`<= 35` members), `PurpleThemePalette` (`<= 45` members), and `TextKit2ViewportHighlightApplier` apply viewport highlights and token lookups identically (`[AR-010]`, `[UI-001]`, `[UI-005]`, `[UI-007]`). | N3: Invalid completion prefix, out-of-scope sidebar path, out-of-range go-to-line query, or unconfirmed multiline terminal send is rejected without mutating state; N5: Matching `HighlightRenderSignature` or out-of-viewport range skips redundant `NSTextContentStorage` attribute mutations (`[UI-007]`, `[SEC-003]`, `[SEC-004]`). |
| `FileDependencyAcyclicityGate` | P6: `CodeModularityFitnessScanner.verifyAcyclicFileGraph(at:)` confirms `0` circular file dependency cycles (`cycleCount == 0`) across `Sources/SwiftEditCore` and `Sources/SwiftEditUI`, with `MarkdownLineIndex.swift` as an acyclic leaf and zero upward edges from `SwiftEditCore` into `SwiftEditUI` (`[AR-006]`, `[BC-001]`, `[TEST-006]`). | N7: Synthetic Swift file graph fixtures introducing a 2-file cycle (`FileA.swift <-> FileB.swift`) or an upward reference from `SwiftEditCore` to `SwiftEditUI` are rejected with `.circularFileDependency` diagnostics identifying the exact cycle path (`[AR-006]`, `[TEST-006]`). |
| `BoundedIterativeTraversalAndUpdateFlow` | P7: `checkForUpdates()` / `performUpdateCheck()` delegates to `GitHubReleaseUpdateChecker.evaluateReleaseUpdate(currentVersion:)` without mutual recursion, `UserDefaultsPreferencesStore` executes without wrapper self-loops, and `SwiftEditNSTextView.markSubviewsAndLayersNeedsDisplay` / `markLayerTreeNeedsDisplay` invalidate nested views/layers iteratively (`[AR-007]`, `[UI-007]`, `[SEC-001]`). | N8 (`security`): Deeply nested or cyclic `NSView` / `CALayer` hierarchy exceeding `4_096` child nodes halts deterministically at `maxVisitedNodes = 4_096` without uncontrolled recursion (`CWE-674`) or main-thread hang (`[SEC-012]`). |

## 2. Test Automation Strategy & Commands
- Unit test runner command: `swift test --parallel`
- Targeted modularity & acyclicity fitness suite command: `swift test --filter CodeModularityFitnessTests`
- Targeted workbench & coordinator flattening suite command: `swift test --filter "WorkbenchSubControllersDecompositionTests|TextKit2EditorDecompositionTests"`
- Targeted bounded iterative traversal & recursion elimination suite command: `swift test --filter "CodeModularityFitnessTests|AutoUpdateAndTerminalPerfTests"`
- Trait filter command: `swift test --filter CodeModularityFitnessTests`

## 3. Testability Seams & Test Doubles
- Real collaborators: `CodeModularityFitnessScanner`, `CodeModularityBudgets`, `MarkdownLineIndex`, `PurpleThemePalette`, `SwiftEditWorkbenchModel`, `TextKit2EditorView.Coordinator`, `TextKit2ViewportHighlightApplier`, `SwiftEditNSTextView`, `CALayer`, `NSView`.
- Isolation seams: `InMemoryFileSystemFake` (`FileSystemProviding`), `InMemoryKeyValueStore` (`PreferencesProviding`), stubbed `HTTPDataFetching` for `GitHubReleaseUpdateChecker`, temporary canonical directory fixtures with symlink tests, and synthetic multi-file source maps for `verifyAcyclicFileGraph` (`[AR-007]`, `[TEST-004]`).

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | 5 EARS requirements (`MODIFIED` `REQ-001`, `REQ-002`, `REQ-004`; `ADDED` `REQ-006`, `REQ-007`) with 11 Given/When/Then scenarios (`P1`, `N1`, `N2`, `P2`, `N3`, `P4`, `N5`, `P6`, `N7`, `P7`, `N8`) |
| Path coverage completeness | Verified | Every unit under test defines at least 1 positive (`P#`) and 1 negative (`N#`) path |
| Security traits tagged | Verified | Abuse scenarios `N2` and `N8` explicitly tagged `- **Trait**: security` |
