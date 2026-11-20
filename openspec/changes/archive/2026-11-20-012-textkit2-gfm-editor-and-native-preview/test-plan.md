# Test Plan: Two-Speed GFM TextKit 2 Editor, Markdown CommandMenu, GFM Table Tab and Cmd+P Zero-WebKit Native Preview

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `MarkdownSyntaxHighlighter.spans` | P1: 12 GFM constructs for the visible range only | N1: fenced interior, non-Markdown, empty range; N2 [Security]: binary, degraded, overlong line |
| `MarkdownAuthoringCommands` and `GFMTableEditEngine` | P2: Bold/Italic/Link/Heading single batch; P3: table `Tab` pad, navigate, append row | N3: fence and non-Markdown not applied; N8: `Tab` outside table; N4 [Security]: oversized table, binary |
| `MarkdownPreviewProjector.project` | P4: table, task, quote, inert HTML with `sourceLine` | N5 [Security]: hidden preview zero projections, raw HTML inert |
| `PreviewResourceAndLinkGate` | P5: in-scope image downsampled, https link confirmed | N6 [Security]: remote, `data:`, traversal, SVG, oversize, symlink, `javascript:` blocked |
| `SwiftEditWorkbenchModel` and `TextKit2EditorView` wiring | P6: `Cmd+P` toggle, Tab chain order, debounced recovery, `sourceLine` sync | N7 [Security]: binary tab menu and preview disabled |

## 2. Test Automation Strategy & Commands
- Unit test runner command: `swift test --parallel`
- Targeted suite command: `swift test --filter "MarkdownSyntaxHighlighterTests|MarkdownAuthoringAndTableTests|MarkdownPreviewProjectorAndGateTests"`
- Regression suite command: `swift test --filter "MarkdownSmartListEngineTests|MarkdownLintAndFormatTests|TextKit2EditorAndDiffCoordinatorTests|TranslucentHeaderBrandSubmenuTests|ArchitectureFitnessTests"`

## 3. Testability Seams & Test Doubles
- Real collaborators: `DocumentSnapshot`, `DocumentSession`, the new engines and `SwiftEditWorkbenchModel` (`[TEST-002]`, `[TEST-004]`).
- Isolation seams: in-memory or temporary-directory `FileSystemProviding` fake with fixture PNGs generated in-test, injected clock for debounce, ephemeral `UserDefaults(suiteName:)` (`[TEST-003]`); no network, so zero-socket is asserted by the absence of any `URLSession` reference in the gate (fitness scan).

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | EARS requirements `REQ-001..006` with Given/When/Then scenarios (`[SDD-001]`) |
| Path coverage completeness | Verified | Every unit defines P# and N# paths (`[TEST-001]`, `[TEST-002]`) |
| Security traits tagged | Verified | `N2`, `N4`, `N5`, `N6`, `N7` tagged `- **Trait**: security` (`[SEC-009]`) |
