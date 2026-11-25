---
id: "brief-complexity-pass-7-yaml-outline-contextual-and-completion"
change_id: "038-complexity-pass-7-yaml-outline-contextual-and-completion"
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

# TDD Specification Brief: `038-complexity-pass-7-yaml-outline-contextual-and-completion`

- **Security Review**: approved

## 1. Disambiguated Prompt & Decision Log (`/qa` + `STOP`)

- **Workflow 01 Approval**: Completed via `STOP` approval with `(Recommended)` defaults (`Rule G3` fail-closed: preserve all existing security controls intact without any `Security-Waiver`, zero auto-commit, zero `<changes_dir>/` 6-artifact ceremony).
- **Scope (`Iteration 7: complexity-pass-7-yaml-outline-contextual-and-completion`)**:
  1. **Point 1 — `YAMLOutlineEngine.outline` (`Sources/SwiftEditCore/MarkdownLintAndFormat/YAMLSupport/YAMLOutlineEngine.swift`)**: Extract `outlineHeading(forLine:in:)`, `contentLineRange(forLine:units:starts:)`, `isIgnoredTopLevelLine(_:start:end:)`, and `isDocumentBoundaryMarker(_:start:end:first:)` achieving `cyclomatic: 3, cognitive: 2, max_nesting: 3, lines: 11` (all helpers `cyc <= 4, cog <= 3, nest <= 2`) while preserving empty-line bounds hardening across `LF`, `CRLF`, and `CR` endings, `YAMLSupportLimits.maxLineUTF16`, and `YAMLSupportLimits.maxOutlineEntries`.
  2. **Point 2 — `TerminalSelectionPayload.prepare` (`Sources/SwiftEditCore/MarkdownLintAndFormat/ElementContextualActions.swift`)**: Extract `scalarSelectionRange(for:in:isBinaryReadOnly:)`, `sanitizeTerminalText(_:capacity:)`, and `appendSanitizedScalar(_:previousWasCR:into:)` achieving `cyclomatic: 3, cognitive: 2, max_nesting: 2, lines: 17` (all helpers `cyc <= 5, cog <= 5, nest <= 3`) while preserving `isBinaryReadOnly` lockout, `maxUTF16Length` (`65_536`) bounds, UTF-16 scalar-alignment checks, C0/ESC/DEL control stripping, and trailing-newline stripping (`CWE-78`, `CWE-150`, `CWE-400`).
  3. **Point 3 — `WordCompletionIndex.wordPrefix` (`Sources/SwiftEditCore/SearchDiffAndBracketEngine/WordCompletionIndex.swift`)**: Extract `previousWordCharacterStart(in:before:)` achieving `cyclomatic: 5, cognitive: 6, max_nesting: 3, lines: 13` (helper `cyc: 2, cog: 1, nest: 2`) while preserving UTF-16 composed-character boundaries, `minPrefixUTF16Length`, and `maxIndexedWordUTF16Length` bounds.
  4. **Point 4 — `MarkdownListGrammar.parseNumericOutlineContinuation` (`Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownListGrammar.swift`)**: Extract shared `scanBoundedDecimal(_:from:)` achieving `cyclomatic: 3, cognitive: 2, max_nesting: 2, lines: 20` (helper `cyc: 2, cog: 3, nest: 3`) while preserving 9-digit caps, `addingReportingOverflow(1)`, and `maxOrderedNumber` (`999_999_999`) overflow protection.

## 2. 6-Category STRIDE Security Check

| STRIDE Category | Assessment & Preserved Control |
| :--- | :--- |
| **Spoofing** | `YAMLOutlineEngine` preserves top-level column-0 key filtering and document-marker (`---`/`...`) exclusion without alias or tag resolution (`CWE-776`). |
| **Tampering** | `TerminalSelectionPayload.prepare` preserves `C0` (`< 0x20`, excluding `\t`), `ESC` (`0x1B`), and `DEL` (`0x7F`) stripping plus trailing `\n` removal so PTY writes never inject escape sequences or auto-execute `Return` (`CWE-78`, `CWE-150`). |
| **Repudiation** | Deterministic `nil` fail-closed returns on invalid UTF-16 ranges, binary tabs, or overflowing list numbers remain unchanged. |
| **Information Disclosure** | Zero new logging, persistence, network calls, or secrets introduced (`SECRET_SCAN_CLEAN`). |
| **Denial of Service** | `YAMLOutlineEngine` preserves `maxOutlineEntries` and `maxLineUTF16` bounds; `TerminalSelectionPayload` preserves `maxUTF16Length` (`65_536`); `WordCompletionIndex` preserves `maxIndexedWordUTF16Length` (`64`); `MarkdownListGrammar` preserves `9`-digit and `maxOrderedNumber` caps (`CWE-400`, `CWE-190`). |
| **Elevation of Privilege** | `TerminalSelectionPayload.prepare` retains `isBinaryReadOnly` lockout (`nil`), preventing PTY staging from quarantined binary tabs. |

## 3. Before / After Metrics & Verification Summary

| Target Symbol | File | Before (`cyc / cog / nest / lines`) | After (`cyc / cog / nest / lines`) |
| :--- | :--- | :--- | :--- |
| `YAMLOutlineEngine.outline` | `Sources/SwiftEditCore/MarkdownLintAndFormat/YAMLSupport/YAMLOutlineEngine.swift` | `9 / 8 / 3 / 34` | `3 / 2 / 3 / 11` |
| `TerminalSelectionPayload.prepare` | `Sources/SwiftEditCore/MarkdownLintAndFormat/ElementContextualActions.swift` | `8 / 9 / 4 / 57` | `3 / 2 / 2 / 17` |
| `WordCompletionIndex.wordPrefix` | `Sources/SwiftEditCore/SearchDiffAndBracketEngine/WordCompletionIndex.swift` | `8 / 14 / 4 / 21` | `5 / 6 / 3 / 13` |
| `MarkdownListGrammar.parseNumericOutlineContinuation` | `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownListGrammar.swift` | `7 / 10 / 3 / 31` | `3 / 2 / 2 / 20` |

- **Positive (`P#`) & Negative (`N#`) Verification**:
  - `swift test`: exited `0` — `473` tests in `130` suites passed.
  - `tokensave sync`: exited `0`.
  - `tokensave_circular(path="Sources")`: `cycle_count == 0`.
  - `tokensave_recursion(path="Sources")`: `0` recursion cycles in all 4 modified files (1 pre-existing overload self-edge in unrelated `EditorRenderingAttributes.swift:272`).
  - Secret hygiene scan on `git diff Sources/`: zero matches (`SECRET_SCAN_CLEAN`).

## Metadata
- Branch: main
