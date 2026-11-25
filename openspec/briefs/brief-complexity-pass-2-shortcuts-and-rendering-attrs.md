---
id: "brief-complexity-pass-2-shortcuts-and-rendering-attrs"
change_id: "033-complexity-pass-2-shortcuts-and-rendering-attrs"
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

# TDD Specification Brief: `033-complexity-pass-2-shortcuts-and-rendering-attrs`

- **Security Review**: approved

## 1. Disambiguated Prompt & Decision Log (`/qa` + `STOP`)

- **Workflow 01 Approval**: Completed via `STOP` approval with `(Recommended)` defaults (`Rule G3` fail-closed: preserve all existing security controls intact without any `Security-Waiver`, zero auto-commit, zero `<changes_dir>/` 6-artifact ceremony).
- **Scope (`Iteration 2: complexity-pass-2-shortcuts-and-rendering-attrs`)**:
  1. **Point 1 — `SwiftEditShortcutDispatcher.dispatchNonCommandChord`** (`Sources/SwiftEditUI/Views/SwiftEditShortcutDispatcher.swift`): Extract cohesive modifier-group helpers (`dispatchOptionShift`, `dispatchControlOnly`, `dispatchControlShift`, `dispatchDiffHunkNavigation`) to achieve `cognitive <= 10, cyclomatic <= 8` while preserving malformed/BiDi/NUL chord validation (`isWellFormedChordString`), overlay text-field editing guards, and binary read-only quarantine invariants.
  2. **Point 2 — `SwiftEditShortcutDispatcher.dispatchCommandOption`** (`Sources/SwiftEditUI/Views/SwiftEditShortcutDispatcher.swift`): Replace the inline `switch` with a static `commandOptionTable` reusing `CommandTableEntry` and a shared `dispatchTableEntry` helper (also reused by `dispatchCommandOnly` and `dispatchCommandShift`) to achieve `cognitive <= 10, cyclomatic <= 8` while preserving overlay text-field blocking on editing/markdown commands.
  3. **Point 3 — `EditorRenderingAttributeTable.lookupSemanticEntries`** (`Sources/SwiftEditUI/Views/EditorRenderingAttributes.swift`): Decompose semantic lookup into cohesive `lookupHTMLEntries` and `lookupJSONEntries` helpers under `<= 20` nominal members per block to achieve `cognitive <= 8, cyclomatic <= 8` while preserving all WCAG-AA syntax scheme and prose/YAML `21:1` contrast mappings.
  4. **Point 4 — `EditorRenderingAttributeTable.attributes`** (`Sources/SwiftEditUI/Views/EditorRenderingAttributes.swift`): Extract `lookupInlineEntries` and `lookupBlockAndYAMLEntries` and compose via nil-coalescing lookup chain to achieve `cognitive <= 8, cyclomatic <= 8` with zero attribute allocation regressions.

## 2. 6-Category STRIDE Security Check

| STRIDE Category | Assessment & Preserved Control |
| :--- | :--- |
| **Spoofing** | `SwiftEditShortcutDispatcher.dispatch` preserves `isWellFormedChordString` validation on `characters` and `charactersIgnoringModifiers`, rejecting oversized (`> 2` scalars), NUL-embedded, control, and BiDi-override (`U+202A..U+202E`, `U+2066..U+2069`) chord payloads fail-closed (`REQ-008`, `SEC-012`). |
| **Tampering** | Overlay text-field guard (`blocksOnOverlayField` / `!isEditingOverlayTextField`) and binary read-only quarantine remain intact across `dispatchTableEntry`, `dispatchControlOnly`, `dispatchControlShift`, and `dispatchCommandOption`, preventing unintended buffer mutations. |
| **Repudiation** | Preserved deterministic boolean dispatch return values (`true` when consumed, `false` when rejected/unmapped) and unchanged `EditorRenderingAttributes` palette/scheme contract. |
| **Information Disclosure** | `EditorRenderingAttributeTable` preserves `21:1` canvas contrast for prose and `.yamlValue`, inert HTML warning foreground, and zero dynamic evaluation or external I/O. |
| **Denial of Service** | Static dictionary lookups (`commandOptionTable`) and shallow `switch` helpers execute in `O(1)` time without recursion or unbounded allocations. |
| **Elevation of Privilege** | Zero new entitlements, zero shell invocations, and unmapped modifier chords continue failing closed (`false`) without mutating `SwiftEditWorkbenchModel`. |

## 3. Before / After Metrics & Verification Summary

| Target Method | File | Before (`cyc / cog / nest / lines`) | After (`cyc / cog / nest / lines`) |
| :--- | :--- | :--- | :--- |
| `SwiftEditShortcutDispatcher.dispatchNonCommandChord` | `Sources/SwiftEditUI/Views/SwiftEditShortcutDispatcher.swift` | `13 / 17 / 3 / 40` | `8 / 7 / 2 / 24` |
| `SwiftEditShortcutDispatcher.dispatchCommandOption` | `Sources/SwiftEditUI/Views/SwiftEditShortcutDispatcher.swift` | `12 / 16 / 3 / 28` | `1 / 0 / 1 / 12` |
| `EditorRenderingAttributeTable.lookupSemanticEntries` | `Sources/SwiftEditUI/Views/EditorRenderingAttributes.swift` | `14 / 13 / 2 / 17` | `2 / 1 / 2 / 4` |
| `EditorRenderingAttributeTable.attributes` | `Sources/SwiftEditUI/Views/EditorRenderingAttributes.swift` | `12 / 11 / 2 / 15` | `1 / 0 / 1 / 7` |

- **Positive (`P#`) & Negative (`N#`) Verification**:
  - `swift test`: exited `0` — `472` tests across `130` suites passed, covering shortcut dispatch (`AllKeyboardShortcutsDispatchTests`, `ShortcutsFindGutterAndAccessibilityTests`), rendering attributes (`TextKit2EditorDecompositionTests` `<= 20` member budget, `SemanticSyntaxColorSchemesAndHTMLTests`, `YAMLKeyValuePaletteTokensTests`, `AuditFindingsRegressionTests`), and `CodeModularityFitnessScanner`.
  - `tokensave sync`: exited `0` (`1 added, 4 modified, 0 removed`).
  - `tokensave_circular(path="Sources")`: `cycle_count == 0`.
  - `tokensave_recursion(path="Sources")`: `0` recursion cycles in `SwiftEditShortcutDispatcher.swift` (`1` pre-existing self-edge in `EditorRenderingAttributes.swift:272`).
  - Secret hygiene scan on `git diff Sources/`: `SECRET_SCAN_CLEAN`.

## Metadata
- Branch: main
