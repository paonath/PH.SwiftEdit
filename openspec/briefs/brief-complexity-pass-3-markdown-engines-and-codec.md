---
id: "brief-complexity-pass-3-markdown-engines-and-codec"
change_id: "034-complexity-pass-3-markdown-engines-and-codec"
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

# TDD Specification Brief: `034-complexity-pass-3-markdown-engines-and-codec`

- **Security Review**: approved

## 1. Disambiguated Prompt & Decision Log (`/qa` + `STOP`)

- **Workflow 01 Approval**: Completed via `STOP` approval with `(Recommended)` defaults (`Rule G3` fail-closed: preserve all existing security controls intact without any `Security-Waiver`, zero auto-commit, zero `<changes_dir>/` 6-artifact ceremony).
- **Scope (`Iteration 3: complexity-pass-3-markdown-engines-and-codec`)**:
  1. **Point 1 — `MarkdownSmartNewlineEngine.evaluateNewline`** (`Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownSmartNewlineEngine.swift`): Extract cohesive line-resolution and empty-marker helpers (`CaretLineContext`, `resolveCaretLine`, `findLineStartUTF8`, `findLineEndUTF8`, `emptyMarkerNewlineEdit`) to achieve `cognitive <= 10, cyclomatic <= 8` while preserving binary/degraded fail-closed guards, `4096` UTF-16 line bounds, fenced-code suppression, and `Int.addingReportingOverflow` safety.
  2. **Point 2 — `DocumentCodec.decodeStrictUTF16`** (`Sources/SwiftEditCore/DocumentCore/DocumentCodec.swift`): Extract `readUTF16CodeUnit`, `decodeNextUTF16Scalar`, and `appendUTF8Bytes` to achieve `cognitive <= 10, cyclomatic <= 8` while preserving strict UTF-16LE/BE BOM, odd-byte rejection, and surrogate-pair validation (`DomainError.unsupportedEncoding`).
  3. **Point 3 — `MarkdownSmartListEngine.evaluateIndent`** (`Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownSmartListEngine.swift`): Extract `collectIndentEdits` and consolidate preflight guards to achieve `cognitive <= 10, cyclomatic <= 8` while preserving binary/degraded guards, bounds checks, fenced-code exclusion, `32`-level nesting cap, and `999_999_999` numbering cap.

## 2. 6-Category STRIDE Security Check

| STRIDE Category | Assessment & Preserved Control |
| :--- | :--- |
| **Spoofing** | `DocumentCodec.decodeStrictUTF16` preserves strict UTF-16LE/BE BOM and surrogate-pair validation (`0xD800..0xDBFF` followed by `0xDC00..0xDFFF`), rejecting unpaired surrogates and odd byte counts fail-closed with `DomainError.unsupportedEncoding`. |
| **Tampering** | `MarkdownSmartNewlineEngine` and `MarkdownSmartListEngine` preserve `isBinaryReadOnly` and `isDegradedPlainText` guards, out-of-range caret/selection rejection, and fenced-code block suppression without mutating document state on invalid inputs. |
| **Repudiation** | Deterministic `SmartNewlineEdit`, `SmartListOutcome` (`.edit`, `.consumedNoOp`, `.notApplicable`), and `DecodedDocumentPayload` contracts remain unchanged across all callers. |
| **Information Disclosure** | Zero new logging, network, or filesystem access; `DocumentCodec` continues confining binary streams to read-only inspection previews. |
| **Denial of Service** | Preserved `maxBracketScanLineUTF16Length` (`4096`), `MarkdownListGrammar.maxLineUTF16`, `maxNestingLevels` (`32`), `maxSiblingLookbackLines` (`128`), `maxOrderedNumber` (`999_999_999`), and `Int.addingReportingOverflow(1)` checks (`CWE-400`). |
| **Elevation of Privilege** | Pure stateless domain engines in `SwiftEditCore` with zero new entitlements, zero shell calls, and `<= 25` nominal members per type. |

## 3. Before / After Metrics & Verification Summary

| Target Method | File | Before (`cyc / cog / nest / lines`) | After (`cyc / cog / nest / lines`) |
| :--- | :--- | :--- | :--- |
| `MarkdownSmartNewlineEngine.evaluateNewline` | `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownSmartNewlineEngine.swift` | `11 / 14 / 3 / 82` | `3 / 2 / 2 / 31` |
| `DocumentCodec.decodeStrictUTF16` | `Sources/SwiftEditCore/DocumentCore/DocumentCodec.swift` | `10 / 25 / 5 / 47` | `5 / 6 / 4 / 23` |
| `MarkdownSmartListEngine.evaluateIndent` | `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownSmartListEngine.swift` | `9 / 8 / 3 / 38` | `6 / 5 / 2 / 27` |

- **Positive (`P#`) & Negative (`N#`) Verification**:
  - `swift test`: exited `0` — `473` tests across `130` suites passed, covering `MarkdownSmartNewlineEngineTests`, `DocumentCodecAndLoaderTests` (including new `N2` malformed UTF-16 surrogate/odd-byte test), `MarkdownSmartListEngineTests`, `ListIndentationWorkbenchTests`, and `CodeModularityFitnessTests`.
  - `tokensave sync`: exited `0` (`1 added, 6 modified, 0 removed`).
  - `tokensave_gini(path="Sources/SwiftEditCore", scope="symbol")`: Gini dropped `0.3549 -> 0.3511`; all 3 targets removed from top-10 complexity outliers.
  - `tokensave_circular(path="Sources")`: `cycle_count == 0`.
  - `tokensave_recursion(path="Sources")`: `0` recursion cycles in modified `SwiftEditCore` files (`1` pre-existing self-edge in `EditorRenderingAttributes.swift:272`).
  - Secret hygiene scan on `git diff`: `SECRET_CHECK_EXIT=1` (zero matches).

## Metadata
- Branch: main
