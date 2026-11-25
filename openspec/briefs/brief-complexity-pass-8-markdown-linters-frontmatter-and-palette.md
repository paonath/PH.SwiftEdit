---
id: "brief-complexity-pass-8-markdown-linters-frontmatter-and-palette"
change_id: "039-complexity-pass-8-markdown-linters-frontmatter-and-palette"
capability: "workbench-editor-and-linter-modular-decomposition"
branch: "main"
modifies_specs:
  - "openspec/specs/workbench-editor-and-linter-modular-decomposition/spec.md"
status: "implemented"
date: "2026-11-25"
owners:
  - "swift-macos-expert"
  - "cyber-security-expert"
---

# TDD Specification Brief: `039-complexity-pass-8-markdown-linters-frontmatter-and-palette`

- **Security Review**: approved

## 1. Disambiguated Prompt & Decision Log (`/qa` + `STOP`)

- **Workflow 01 Approval**: Completed via `STOP` approval with `(Recommended)` defaults (`Rule G3` fail-closed: preserve all existing security controls, WCAG-AA contrast anchors, lint rules, and bounds validations intact without any `Security-Waiver`, zero auto-commit, zero `<changes_dir>/` 6-artifact ceremony).
- **Scope (`Iteration 8: complexity-pass-8-markdown-linters-frontmatter-and-palette`)**:
  1. **Point 1 — `MarkdownAllConstructsLinter.evaluateFullRuleLine` (`Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownAllConstructsLinter.swift`)**: Extract `leadingIndentAndUnit(in:)` and `evaluateSingleLineConstruct(at:range:slice:lead:wasBlank:context:)` achieving `cyclomatic: 5, cognitive: 4, max_nesting: 2, lines: 27` while preserving `MarkdownLineIndex.maxLineUTF16` (`4096`) opaqueness and all 26-rule lint passes.
  2. **Point 2 — `MarkdownLinterRuleFamilyPasses.evaluateHeadingLine` (`Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownLinterRuleFamilyPasses.swift`)**: Extract `evaluateHeadingSpacing(at:range:slice:afterHashes:context:)` and `evaluateHeadingSurroundingRules(at:range:level:context:)` achieving `cyclomatic: 3, cognitive: 3, max_nesting: 2, lines: 21` (helpers `cyc <= 4, cog <= 4, nest <= 2`) while preserving ATX heading marker, spacing, increment, blank-line, and inline security scans.
  3. **Point 3 — `FrontmatterProperties.swift` (`Sources/SwiftEditCore/MarkdownLintAndFormat/YAMLSupport/FrontmatterProperties.swift`)**: Decompose `unquote` (`doubleQuotedEscapes`, `decodeDoubleQuotedScalar`, `appendEscapedCharacter`, `consumeHexEscape`), `classifyInlineValueTokens` (`inlineNonEditableKinds`, `nonEditableInlineKind`, `classifyInlineScalarOrFlow`), and `classifySingleChildSequenceLine` (`classifySequenceItemToken`) achieving `cyc: 3 / cog: 2`, `cyc: 4 / cog: 3`, and `cyc: 2 / cog: 1` (all helpers `cyc <= 6, cog <= 5`) while preserving read-only YAML anchor/alias/tag/block-scalar/nested-map guards (`CWE-776`) and escape decoding.
  4. **Point 4 — `SyntaxColorSchemePalette.resolve` (`Sources/SwiftEditUI/Theme/SyntaxColorSchemePalette.swift`)**: Replace the 8-branch `(scheme, mode)` switch with table-driven `PaletteKey` + `PaletteHexSpec` lookup (`specsByKey`, `defaultLightSpec`) achieving `cyclomatic: 1, cognitive: 0, max_nesting: 1, lines: 14` while preserving every WCAG-AA (`>= 4.5:1`) contrast anchor across all 4 color schemes in Light (`#FFFFFF`) and Black (`#000000`) modes.

## 2. 6-Category STRIDE Security Check

| STRIDE Category | Assessment & Preserved Control |
| :--- | :--- |
| **Spoofing** | `FrontmatterPropertyParser` preserves read-only classification for anchors/aliases/tags (`CWE-776`) and `SyntaxColorSchemePalette` preserves exact scheme-to-palette resolution without fallback confusion. |
| **Tampering** | `FrontmatterPropertyParser.unquote` preserves exact `\"`, `\\`, `\n`, `\t`, `\r`, `\xHH`, and `''` decoding without altering `FrontmatterPropertyWriter` injection guards (`CWE-74`). |
| **Repudiation** | Deterministic diagnostics and fail-closed `4096` UTF-16 line limits in `MarkdownAllConstructsLinter` and `MarkdownLinterRuleFamilyPasses` remain unchanged. |
| **Information Disclosure** | Zero new logging, persistence, network calls, or secrets introduced (`SECRET_SCAN_CLEAN`). |
| **Denial of Service** | `MarkdownAllConstructsLinter` preserves `maxLineUTF16` (`4096`) and `256`-line deadline checks; `FrontmatterPropertyParser` preserves bounded prefix scanning and non-expansion of YAML aliases (`CWE-400`, `CWE-776`). |
| **Elevation of Privilege** | Inline security scans (`.unsafeLinkScheme`, `.unsafeImagePath`, `.emptyLinkTarget`) execute identically on headings and non-fenced lines (`SEC-012`). |

## 3. Before / After Metrics & Verification Summary

| Target Symbol | File | Before (`cyc / cog / nest / lines`) | After (`cyc / cog / nest / lines`) |
| :--- | :--- | :--- | :--- |
| `MarkdownAllConstructsLinter.evaluateFullRuleLine` | `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownAllConstructsLinter.swift` | `8 / 8 / 2 / 41` | `5 / 4 / 2 / 27` |
| `MarkdownLinterRuleFamilyPasses.evaluateHeadingLine` | `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownLinterRuleFamilyPasses.swift` | `8 / 11 / 3 / 52` | `3 / 3 / 2 / 21` |
| `FrontmatterPropertyParser.unquote` | `Sources/SwiftEditCore/MarkdownLintAndFormat/YAMLSupport/FrontmatterProperties.swift` | `10 / 18 / 4 / 26` | `3 / 2 / 2 / 7` |
| `FrontmatterPropertyParser.classifyInlineValueTokens` | `Sources/SwiftEditCore/MarkdownLintAndFormat/YAMLSupport/FrontmatterProperties.swift` | `8 / 7 / 2 / 15` | `4 / 3 / 2 / 10` |
| `FrontmatterPropertyParser.classifySingleChildSequenceLine` | `Sources/SwiftEditCore/MarkdownLintAndFormat/YAMLSupport/FrontmatterProperties.swift` | `8 / 8 / 3 / 23` | `2 / 1 / 3 / 8` |
| `SyntaxColorSchemePalette.resolve` | `Sources/SwiftEditUI/Theme/SyntaxColorSchemePalette.swift` | `9 / 8 / 2 / 100` | `1 / 0 / 1 / 14` |

- **Positive (`P#`) & Negative (`N#`) Verification**:
  - `swift test`: exited `0` — `473` tests in `130` suites passed.
  - `tokensave sync`: exited `0`.
  - `tokensave_circular(path="Sources")`: `cycle_count == 0`.
  - `tokensave_recursion(path="Sources")`: `0` recursion cycles in all 4 modified files (1 pre-existing overload self-edge in unrelated `EditorRenderingAttributes.swift:272`).
  - Secret hygiene scan on `git diff Sources/`: zero matches (`SECRET_SCAN_CLEAN`).

## Metadata
- Branch: main
