# Test Plan: TokenSave Zero-Cycles, Member Flattening (<= 25), Complexity Ceiling, and >= 85% Full-Codebase Coverage Convergence

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `CodeModularityFitnessScanner` (`REQ-001`) | P1: Live `Sources/SwiftEditCore` and `Sources/SwiftEditUI` pass `maxFileLines: 800`, `maxNominalBlockLines: 400`, and `maxNominalMembers: 25` with zero violations across all nominal and extension blocks | N1: Synthetic `.swift` fixture with `26` nominal members, `401` block lines, or `801` file lines emits typed `CodeModularityViolation`; N2 (`Trait: security`): Symlink escape, `../` segment, or `> 4 MiB` file fails closed with `.securityBoundaryViolation` |
| `FlattenedWorkbenchAndEditorTypes` (`REQ-002`, `REQ-004`) | P2: Flattened `SwiftEditWorkbenchModel`, `WorkspaceEditorCoordinator`, `DocumentSession`, and `LogTailController` (`<= 25` members each) preserve all domain behaviors; P4: Flattened `EditorRenderingAttributeTable`, `PurpleThemePalette`, `SwiftEditNSTextView`, `TextKit2EditorView`, `Coordinator`, and `ZoomedChromeMetrics` (`<= 25` members each) apply scoped viewport highlights and theme/zoom tokens | N3: Single-char completion prefix, out-of-root sidebar path, out-of-range go-to-line, or unconfirmed multiline terminal send is rejected; N5: Unchanged `HighlightRenderSignature` or out-of-viewport span skips storage transactions |
| `AcyclicFileGraphAndDepthVerifier` (`REQ-006`, `REQ-009`) | P6: Production file graph across `Sources/SwiftEditCore` and `Sources/SwiftEditUI` has `0` Strongly Connected Components and `0` upward `Core -> UI` edges; P9: `Sources/` contains `0` unreferenced private functions/methods and max file dependency chain depth `<= 10` | N7: Synthetic 2-file cycle (`A.swift <-> B.swift`) or upward `Core -> UI` call edge emits `.circularFileDependency`; N10: Uncalled `private func` or `11`-hop file chain emits `.deadPrivateSymbol` / `.dependencyDepthExceeded` violation |
| `ZeroCallGraphRecursionAndIterativeTraversal` (`REQ-007`) | P7: `AppTypography`, `LogTailWorker`, `WorkspaceTabSession`, `MarkdownAllConstructsLinter`, `SwiftEditNSTextView`, `SwiftEditRootView`, and `EmbeddedTerminalRegistry` execute with `0` call-graph recursion cycles in `Sources/` | N8 (`Trait: security`): `CALayer`/`NSView` hierarchy with `> 4_096` nodes halts at the visitation cap without stack recursion (`CWE-674`), and rotated/missing log files re-arm cleanly without recursive re-entrancy (`CWE-400`) |
| `LowComplexityEnginesAndShortcutTables` (`REQ-008`) | P8: Decomposed `scanInline`, `CursorMetricsCalculator.metrics`, `MarkdownPreviewProjector.project`, `LogSyntaxHighlighter.scan`, `evaluateTab`, `MarkdownLintAndFormatEngine.lint`, `DocumentSession.applyTextEdits`, `applyProgrammaticTextUpdate`, `refreshDiagnosticsForActiveDocument`, and table-driven `performCheatSheetCommand`, `dispatchCommandOnly`, and `attachKeyDownMonitor` satisfy `cyclomatic <= 15` and `cognitive <= 25` | N9 (`Trait: security`): Malicious Markdown links/images (`javascript:`, `vbscript:`, `data:text/html`, `file:`, `../`, BiDi/control scalars) emit security diagnostics without false negatives, and unmapped/malformed shortcut chords are rejected |
| `FullCodebaseCoverageAndTokenSaveConvergence` (`REQ-010`) | P10: `swift test --parallel --enable-code-coverage` and coverage verifier confirm `>= 85.0%` line coverage in `SwiftEditCore`, `>= 85.0%` in `SwiftEditUI`, and `>= 85.0%` overall, and post-`tokensave sync` audit confirms `0` cycles and `<= 25` members | N11: Coverage evaluator rejects any target or total coverage summary below `85.0%` (`84.9%` fixture) or any residual graph violation fail-closed |

## 2. Test Automation Strategy & Commands
- Unit test runner command: `swift test --parallel`
- Coverage verification command: `swift test --parallel --enable-code-coverage && xcrun llvm-cov report .build/debug/SwiftEditPackageTests.xctest/Contents/MacOS/SwiftEditPackageTests -instr-profile=.build/debug/codecov/default.profdata -ignore-filename-regex='Tests|\.build'`
- Specific suite filter command: `swift test --filter CodeModularityAndAcyclicityFitnessTests`

## 3. Testability Seams & Test Doubles
- Real collaborators: `CodeModularityFitnessScanner`, `DocumentSession`, `CursorMetricsCalculator`, `MarkdownPreviewProjector`, `MarkdownLinterInlineSecurityPass`, `MarkdownLintAndFormatEngine`, `MarkdownAuthoringCommands`, `LogSyntaxHighlighter`, `WorkspaceTabSession`, `PurpleThemePalette`, `ZoomedChromeMetrics`, `AppTypography`, `EditorRenderingAttributeTable`, `SwiftEditShortcutDispatcher`, `SwiftEditWorkbenchModel`, `TextKit2EditorView`, `SwiftEditNSTextView`.
- Isolation seams: `InMemoryFileSystemFake` (`FileSystemProviding`), `InMemoryKeyValueStore` (`PreferencesProviding`), controllable clock closures, synthetic Swift AST/source fixtures, and headless `@MainActor` AppKit `NSWindow`/`NSTextView` harnesses (`[AR-007]`, `[AR-010]`, `[TEST-004]`).

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | Given/When/Then scenarios defined for `REQ-001`, `REQ-002`, `REQ-004`, `REQ-006`..`REQ-010` |
| Path coverage completeness | Verified | All 6 units define explicit positive (`P1..P10`) and negative/security (`N1..N11`) paths |
| Security traits tagged | Verified | Abuse cases `N2`, `N8`, and `N9` tagged `- **Trait**: security` |
