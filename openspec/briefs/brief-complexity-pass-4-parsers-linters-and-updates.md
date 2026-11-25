---
id: "brief-complexity-pass-4-parsers-linters-and-updates"
change_id: "035-complexity-pass-4-parsers-linters-and-updates"
capability: "workbench-editor-and-linter-modular-decomposition"
branch: "main"
modifies_specs:
  - "openspec/specs/workbench-editor-and-linter-modular-decomposition/spec.md"
status: "implemented"
date: "2026-11-25"
owners:
  - "swift-macos-expert"
  - "oop-architecture-expert"
  - "cyber-security-expert"
---

# TDD Specification Brief: `035-complexity-pass-4-parsers-linters-and-updates`

- **Security Review**: approved

## 1. Disambiguated Prompt & Decision Log (`/qa` + `STOP`)

- **Workflow 01 Approval**: Completed via `STOP` approval with `(Recommended)` defaults (`Rule G3` fail-closed: preserve all existing security controls intact without any `Security-Waiver`, zero auto-commit, zero `<changes_dir>/` 6-artifact ceremony).
- **Scope (`Iteration 4: complexity-pass-4-parsers-linters-and-updates`)**:
  1. **Point 1 — `MarkdownDiagramParser.parse`** (`Sources/SwiftEditCore/MarkdownLintAndFormat/DiagramSupport/MermaidParserAndLayout.swift`): Extract `parseMermaidDiagram(source:)` and switch on normalized language to achieve `cognitive <= 10, cyclomatic <= 8` while preserving the `maxSourceUTF8Bytes` (`65_536`), `maxNodes` (`256`), `maxEdges` (`512`), `maxDepth` (`12`), and zero-WebKit isolation controls.
  2. **Point 2 — `JSONStructureLinter.advanceJSONToken`** (`Sources/SwiftEditCore/MarkdownLintAndFormat/JSONSupport/JSONStructureLinter.swift`): Extract `consumeStructuralDelimiter(_:state:)` and `consumeColon(_:)` to achieve `cognitive <= 10, cyclomatic <= 8` while preserving trailing-token checks, iterative stack `maxDepth` (`128`), and `maxDiagnostics` (`128`).
  3. **Point 3 — `MarkdownSyntaxHighlighter.matchInlineSyntaxConstruct`** (`Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownSyntaxHighlighter.swift`): Split inline matching into `matchLinkOrTagConstruct(in:at:memo:)` and `matchDelimitedInlineConstruct(in:at:memo:)` to achieve `cognitive <= 10, cyclomatic <= 8` while preserving `O(L)` linear memoized scanning and `4096` UTF-16 line bounds.
  4. **Point 4 — `SemanticVersion.<` and `GitHubReleaseUpdateChecker.evaluate`** (`Sources/SwiftEditUI/Updates/GitHubReleaseUpdateChecker.swift`): Extract `SemanticVersion.comparePrereleaseLists(_:_:)` and `GitHubReleaseUpdateChecker.newestRelease(in:)` to achieve `cognitive <= 8, cyclomatic <= 7` while preserving `verifiedGitHubHTTPSURL` host allowlist validation (`SEC-001`, `SEC-004`) unchanged.

## 2. 6-Category STRIDE Security Check

| STRIDE Category | Assessment & Preserved Control |
| :--- | :--- |
| **Spoofing** | `GitHubReleaseUpdateChecker.verifiedGitHubHTTPSURL` remains completely unchanged, enforcing strict `https` and canonical GitHub host allowlist (`github.com`, `www.github.com`, `api.github.com`, `objects.githubusercontent.com`, `release-assets.githubusercontent.com`) for both `html_url` and `.zip` asset `browser_download_url` (`SEC-001`, `SEC-004`). |
| **Tampering** | `JSONStructureLinter` preserves trailing top-level token rejection, strict structural delimiter matching, and unescaped control-character rejection; `GitHubReleaseUpdateChecker.evaluate` continues rejecting untrusted release URLs fail-closed. |
| **Repudiation** | Deterministic `MarkdownDiagramParseOutcome`, `MarkdownLintDiagnostic`, `MarkdownSyntaxSpan`, and `UpdateCheckOutcome` outputs remain identical across all callers. |
| **Information Disclosure** | Zero new logging, disk writes, or network endpoints; `URLSessionHTTPFetcher` remains ephemeral (`SEC-001`, `SEC-004`). |
| **Denial of Service** | Preserved `maxSourceUTF8Bytes` (`65_536`), `maxNodes` (`256`), `maxEdges` (`512`), `maxDepth` (`12` diagrams / `128` JSON), `maxLineUTF16` (`4096`), and `O(L)` inline memoization (`CWE-400`, `CWE-674`). |
| **Elevation of Privilege** | Pure stateless functions with zero new entitlements, zero WebKit/JS execution, zero shell invocation, and `<= 25` nominal members per type. |

## 3. Before / After Metrics & Verification Summary

| Target Method | File | Before (`cyc / cog / nest / lines`) | After (`cyc / cog / nest / lines`) |
| :--- | :--- | :--- | :--- |
| `MarkdownDiagramParser.parse` | `Sources/SwiftEditCore/MarkdownLintAndFormat/DiagramSupport/MermaidParserAndLayout.swift` | `9 / 8 / 2 / 26` | `5 / 4 / 2 / 12` |
| `JSONStructureLinter.advanceJSONToken` | `Sources/SwiftEditCore/MarkdownLintAndFormat/JSONSupport/JSONStructureLinter.swift` | `9 / 9 / 3 / 25` | `5 / 4 / 2 / 14` |
| `MarkdownSyntaxHighlighter.matchInlineSyntaxConstruct` | `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownSyntaxHighlighter.swift` | `9 / 8 / 3 / 25` | `4 / 3 / 2 / 14` |
| `SemanticVersion.<` | `Sources/SwiftEditUI/Updates/GitHubReleaseUpdateChecker.swift` | `11 / 13 / 4 / 23` | `2 / 1 / 2 / 8` |
| `GitHubReleaseUpdateChecker.evaluate` | `Sources/SwiftEditUI/Updates/GitHubReleaseUpdateChecker.swift` | `9 / 9 / 4 / 46` | `5 / 4 / 2 / 28` |

- **Positive (`P#`) & Negative (`N#`) Verification**:
  - `swift test`: exited `0` — `473` tests across `130` suites passed (including `Unit 2`, `Unit 6`, `MarkdownSyntaxHighlighterTests`, `AutoUpdateAndTerminalPerfTests`, `SwiftEditBrandingSettingsUpdatesTests`, and `CodeModularityComplexityAndDepthFitnessTests`).
  - `tokensave sync`: exited `0`.
  - `tokensave_circular(path="Sources")`: `cycle_count == 0`.
  - `tokensave_recursion(path="Sources")`: `0` recursion cycles across all 4 modified files (`1` pre-existing self-edge in `EditorRenderingAttributes.swift:272`).
  - Secret hygiene scan on `git diff -- Sources`: zero matches (`CLEAN_SECRETS`).

## Metadata
- Branch: main
