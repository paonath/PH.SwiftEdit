---
id: "brief-complexity-pass-9-workbench-commands-filesystem-and-mermaid"
change_id: "040-complexity-pass-9-workbench-commands-filesystem-and-mermaid"
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

# TDD Specification Brief: `040-complexity-pass-9-workbench-commands-filesystem-and-mermaid`

- **Security Review**: approved

## 1. Disambiguated Prompt & Decision Log (`/qa` + `STOP`)

- **Workflow 01 Approval**: Completed via `STOP` approval with `(Recommended)` defaults (`Rule G3` fail-closed: preserve all existing security controls, confinement/symlink/collision guards, `maxNodes`/`maxEdges`/`maxDepth` diagram ceilings, and binary/tail edit guards intact without any `Security-Waiver`, zero auto-commit, zero `<changes_dir>/` 6-artifact ceremony).
- **Scope (`Iteration 9: complexity-pass-9-workbench-commands-filesystem-and-mermaid`)**:
  1. **Point 1 — `LocalFileSystemAdapter.pasteItem` (`Sources/SwiftEditCore/DocumentCore/FileSystemProviding.swift`)**: Extract `verifyPasteEndpoints`, `movePasteItem`, and `copyPasteItem` in `private extension LocalFileSystemAdapter` achieving `cyclomatic: 3, cognitive: 2, max_nesting: 2, lines: 11` while preserving all `SEC-010`, `SEC-012`, and `CWE-22`/`CWE-59` confinement, scope-root, symlink, collision-suffix, and batch-limit security guards unchanged.
  2. **Point 2 — `MarkdownDiagramParser.parseFlowchartDiagram` (`Sources/SwiftEditCore/MarkdownLintAndFormat/DiagramSupport/MermaidParserAndLayout.swift`)**: Extract `ignoredFlowchartPrefixes`, `consumeFlowchartLine`, and `pushFlowchartSubgraph` achieving `cyclomatic: 3, cognitive: 2, max_nesting: 3, lines: 11` while preserving `maxNodes` (`256`), `maxEdges` (`512`), and `maxDepth` (`12`) resource bounds (`CWE-400`, `CWE-674`).
  3. **Point 3 — `SwiftEditWorkbenchModel.performElementContextualAction` & `performHeaderCommand` (`Sources/SwiftEditUI/Workbench/SwiftEditWorkbenchModel+CheatSheetAndHeaderCommands.swift`)**: Extract `performWorkbenchContextualAction`, `applyContextualEdit`, and table-driven `headerCommandActions` achieving `cyclomatic: 4, cognitive: 3, max_nesting: 2, lines: 13` for `performElementContextualAction` and `cyclomatic: 2, cognitive: 1, max_nesting: 2, lines: 5` for `performHeaderCommand`.
  4. **Point 4 — `SwiftEditWorkbenchModel.formatActiveDocument` (`Sources/SwiftEditUI/Workbench/SwiftEditWorkbenchModel+DocumentLifecycleAndSave.swift`)**: Extract `resolveFormattableSession`, `formatJSONDocument`, `formatMarkdownDocument`, and `commitFormattedEdits` achieving `cyclomatic: 3, cognitive: 2, max_nesting: 2, lines: 8` while preserving live log-tail, binary read-only, JSON depth (`> 128`), and Markdown engine guards.

## 2. 6-Category STRIDE Security Check

| STRIDE Category | Assessment & Preserved Control |
| :--- | :--- |
| **Spoofing** | `LocalFileSystemAdapter.verifyPasteEndpoints` preserves canonical `resolvingSymlinksInPath()` scope checks and `SidebarItemNameValidator.validate` single-segment name enforcement (`CWE-22`, `SEC-003`). |
| **Tampering** | `movePasteItem` and `copyPasteItem` preserve `itemExistsIncludingDanglingSymlink` collision checks and `.cut` scope-root protection; `formatActiveDocument` preserves `expectedRevision` optimistic concurrency (`DATA-004`). |
| **Repudiation** | Deterministic status banner messages and typed `DomainError` throws (`securityScopeViolation`, `invalidPasteTarget`, `destinationAlreadyExists`, `batchLimitExceeded`) remain unchanged. |
| **Information Disclosure** | Zero new logging, persistence, network calls, or secrets introduced (`SECRET_SCAN_CLEAN`). |
| **Denial of Service** | `copyPasteItem` preserves `preScanCopySourceTree` (`maxCopyItems`/`maxCopyBytes`, `CWE-400`); `parseFlowchartDiagram` preserves `maxDepth` (`12`), `maxNodes` (`256`), and `maxEdges` (`512`) bounds (`CWE-400`, `CWE-674`). |
| **Elevation of Privilege** | `formatActiveDocument` and `applyContextualEdit` preserve `activeLogTail == nil`, `!logTailOnlyTabIDs.contains(activeID)`, `!session.isBinaryReadOnly`, and `safetyBanner.canFormat`/`canSave` quarantine gates (`SEC-012`). |

## 3. Before / After Metrics & Verification Summary

| Target Symbol | File | Before (`cyc / cog / nest / lines`) | After (`cyc / cog / nest / lines`) |
| :--- | :--- | :--- | :--- |
| `LocalFileSystemAdapter.pasteItem` | `Sources/SwiftEditCore/DocumentCore/FileSystemProviding.swift` | `9 / 11 / 3 / 44` | `3 / 2 / 2 / 11` |
| `MarkdownDiagramParser.parseFlowchartDiagram` | `Sources/SwiftEditCore/MarkdownLintAndFormat/DiagramSupport/MermaidParserAndLayout.swift` | `8 / 9 / 4 / 26` | `3 / 2 / 3 / 11` |
| `SwiftEditWorkbenchModel.performElementContextualAction` | `Sources/SwiftEditUI/Workbench/SwiftEditWorkbenchModel+CheatSheetAndHeaderCommands.swift` | `8 / 7 / 2 / 39` | `4 / 3 / 2 / 13` |
| `SwiftEditWorkbenchModel.performHeaderCommand` | `Sources/SwiftEditUI/Workbench/SwiftEditWorkbenchModel+CheatSheetAndHeaderCommands.swift` | `15 / 14 / 2 / 19` | `2 / 1 / 2 / 5` |
| `SwiftEditWorkbenchModel.formatActiveDocument` | `Sources/SwiftEditUI/Workbench/SwiftEditWorkbenchModel+DocumentLifecycleAndSave.swift` | `9 / 10 / 3 / 45` | `3 / 2 / 2 / 8` |

- **Positive (`P#`) & Negative (`N#`) Verification**:
  - `swift test`: exited `0` — `473` tests in `130` suites passed.
  - `tokensave sync`: exited `0`.
  - `tokensave_circular(path="Sources")`: `cycle_count == 0`.
  - `tokensave_recursion(path="Sources")`: `0` recursion cycles in all 4 modified files (1 pre-existing overload self-edge in unrelated `EditorRenderingAttributes.swift:272`).
  - Secret hygiene scan on `git diff Sources/`: zero matches (`SECRET_SCAN_CLEAN`).

## Metadata
- Branch: main
