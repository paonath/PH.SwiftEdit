# Test Plan: 26-Rule All-Construct Markdown Linter, Idempotent Quick-Fix and Fix All, Triple Diagnostics UI and Shift+Cmd+M Popover

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `MarkdownLintAndFormatEngine.lint` (`.allConstructs`) | P1: frontmatter clean, `MD018`/`MD045`/`MD056` found | N1: default profile unchanged, tight sublist; N7: legacy call keeps rule set; N2 [Security]: obfuscated URIs, traversal, SVG, cap keeps errors |
| `MarkdownQuickFixResolver` | P2: idempotent single-batch Fix All | N3: stale revision rejected; N4 [Security]: `quickFix == nil` on security rules |
| `ActiveLintStatus` and suppression policy | P3: Off / Paused / `Lint: N` | N5 [Security]: security errors never suppressed |
| `SwiftEditWorkbenchModel` diagnostics wiring | P4: `⇧⌘M`, Jump-to-Range, one-Undo Fix All | N6 [Security]: binary and non-Markdown tabs inert |

## 2. Test Automation Strategy & Commands
- Unit test runner command: `swift test --parallel`
- Targeted suite command: `swift test --filter "MarkdownAllConstructsLintTests|MarkdownQuickFixAndStatusTests"`
- Regression suite command: `swift test --filter "MarkdownLintAndFormatTests|MarkdownOutlineContinuationAndLintTests|GFMEditorPipelineWiringTests|ArchitectureFitnessTests"`

## 3. Testability Seams & Test Doubles
- Real collaborators: `DocumentSession`, `MarkdownLintAndFormatEngine`, the resolver and `SwiftEditWorkbenchModel` (`[TEST-002]`, `[TEST-004]`).
- Isolation seams: ephemeral `UserDefaults(suiteName:)`, temporary recovery directories, injected save-panel and dark-mode closures (`[TEST-003]`); no mocks or network.

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | EARS requirements `REQ-001..005` with Given/When/Then scenarios (`[SDD-001]`) |
| Path coverage completeness | Verified | Every unit defines P# and N# paths (`[TEST-001]`, `[TEST-002]`) |
| Security traits tagged | Verified | `N2`, `N4`, `N5`, `N6` tagged `- **Trait**: security` (`[SEC-009]`) |
