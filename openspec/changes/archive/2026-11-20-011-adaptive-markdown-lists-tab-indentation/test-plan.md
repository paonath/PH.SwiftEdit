# Test Plan: Linter-Governed Adaptive Markdown List Indentation (Tab / Shift+Tab / Return)

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `MarkdownSmartListEngine.evaluateIndent` | P1: `Tab` nests and `Shift+Tab` outdents with parent numbering; P2: multi-line selection and inherited override markers; P4: valid deep list still nests | N1: root first item, prose, fenced code, non-Markdown handled safely; N2 [Security]: binary, degraded, overlong, level cap, number overflow return no edit |
| `MarkdownSmartNewlineEngine` and `MarkdownLintAndFormatEngine` | P3: `Return` continues `b.` / `1.2` and exits nested empty items in two stages | N3: `.nonStandardOutlineMarker` flags `a.`/`1.1` outside fences only |
| `SwiftEditWorkbenchModel.applyListIndentation` | P5: one `BufferRevision` and translated caret | N4 [Security]: binary or non-Markdown tab is not mutated |

## 2. Test Automation Strategy & Commands
- Unit test runner command: `swift test --parallel`
- Targeted suite command: `swift test --filter MarkdownSmartListEngineTests`
- Regression suite command: `swift test --filter "MarkdownSmartNewlineEngineTests|MarkdownLintAndFormatTests|TranslucentHeaderBrandSubmenuTests|FullAppSemanticThemingAndWindowSyncTests"`

## 3. Testability Seams & Test Doubles
- Real collaborators: `DocumentSnapshot`, `DocumentSession`, `MarkdownSmartListEngine`, `MarkdownSmartNewlineEngine`, `MarkdownLintAndFormatEngine`, `SwiftEditWorkbenchModel` (`[TEST-002]`, `[TEST-004]`).
- Isolation seams: ephemeral `UserDefaults(suiteName:)`, temporary recovery directories, injected `systemDarkDetector` and `savePanelProvider` (`[TEST-003]`).

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | EARS requirements and Given/When/Then scenarios across 3 capability specs (`[SDD-001]`) |
| Path coverage completeness | Verified | Every unit defines P# and N# paths (`[TEST-001]`, `[TEST-002]`) |
| Security traits tagged | Verified | `N2` and `N4` tagged `- **Trait**: security` (`[SEC-009]`) |
