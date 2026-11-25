---
id: "brief-complexity-pass-1-core-search-fs-preview"
change_id: "032-complexity-pass-1-core-search-fs-preview"
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

# TDD Specification Brief: `032-complexity-pass-1-core-search-fs-preview`

- **Security Review**: approved

## 1. Disambiguated Prompt & Decision Log (`/qa` + `STOP`)

- **Workflow 01 Approval**: Completed via `STOP` approval with `(Recommended)` defaults (`Rule G3` fail-closed: preserve all existing security controls intact without any `Security-Waiver`, zero auto-commit, zero `<changes_dir>/` 6-artifact ceremony).
- **Scope (`Iteration 1: complexity-pass-1-core-search-fs-preview`)**:
  1. **Point 1 — `DocumentSearchEngine.find`** (`Sources/SwiftEditCore/SearchDiffAndBracketEngine/DocumentSearchEngine.swift`): Extract `docSearchFindWithNSString`, `docSearchAdvanceRange`, and fold ASCII fast-path eligibility into `findASCIIUTF8(query:in:options:maxMatches:)` to achieve `cognitive <= 12`, `cyclomatic <= 9`, `max_nesting <= 3` while preserving literal-only `NSString` search (`CWE-1333`), binary/degraded guards, query length limit (`1024`), and `maxMatches` flood cap (`CWE-400`).
  2. **Point 2 — `LocalFileSystemAdapter.preScanCopySourceTree`** (`Sources/SwiftEditCore/DocumentCore/FileSystemProviding.swift`): Extract `readAttributesOrIOFailure`, `scanCopyDirectoryTree`, and `accountCopyEntry` in `private extension LocalFileSystemAdapter` to achieve `cognitive <= 12`, `cyclomatic <= 9`, `max_nesting <= 3` while preserving all symlink rejection (`SEC-010`, `SEC-012`), workspace confinement (`CWE-22`), overflow-checked byte accounting, and item/byte batch limits (`CWE-400`).
  3. **Point 3 — `MarkdownNativePreviewView.blockView`** (`Sources/SwiftEditUI/Views/MarkdownNativePreviewView.swift`): Extract cohesive per-block-kind `@ViewBuilder` / SwiftUI helpers (`headingFontSize`, `headingBlockView`, `paragraphBlockView`, `listItemBlockView`, `quoteBlockView`, `tableBlockView`, `tableRowView`, `codeBlockView`, `inertHTMLBlockView`) to achieve `max_nesting <= 3` and `cognitive <= 8` while preserving offline-only thumbnail loading, inert HTML rendering, and `OpenURLAction` link confirmation (`SEC-004`).

## 2. 6-Category STRIDE Security Check

| STRIDE Category | Assessment & Preserved Control |
| :--- | :--- |
| **Spoofing** | `OpenURLAction` in `MarkdownNativePreviewView` continues routing external URIs through `PreviewResourceAndLinkGate.decideLink` and explicit user confirmation; local thumbnails stay gated by `PreviewResourceAndLinkGate`. |
| **Tampering** | `LocalFileSystemAdapter.preScanCopySourceTree` and `accountCopyEntry` preserve `.typeSymbolicLink` rejection before copy, preventing symlink substitution/escape (`SEC-003`, `SEC-010`, `CWE-22`, `CWE-59`). |
| **Repudiation** | Preserved typed `DomainError.securityScopeViolation`, `DomainError.batchLimitExceeded`, `DomainError.ioFailure`, and `DegradedEvaluationReason` outcomes with original paths/limits intact. |
| **Information Disclosure** | `MarkdownNativePreviewView.inertHTMLBlockView` continues rendering raw HTML strictly as inert monospaced text without WebView execution or socket I/O (`SEC-004`). |
| **Denial of Service** | `DocumentSearchEngine` preserves `maxQueryUTF16Units` (`1024`) and `maxMatches` (`100_000`) bounds (`CWE-400`) and regex-free literal search (`CWE-1333`); `accountCopyEntry` preserves `addingReportingOverflow` and `maxCopyItems`/`maxCopyBytes` caps (`CWE-400`). |
| **Elevation of Privilege** | Zero new entitlements, zero shell invocations, zero external network sockets; `LocalFileSystemAdapter` workspace confinement and scope-root protection remain unchanged (`SEC-003`, `SEC-012`). |

## 3. Before / After Metrics & Verification Summary

| Target Method | File | Before (`cyc / cog / nest / lines`) | After (`cyc / cog / nest / lines`) |
| :--- | :--- | :--- | :--- |
| `DocumentSearchEngine.find` | `Sources/SwiftEditCore/SearchDiffAndBracketEngine/DocumentSearchEngine.swift` | `11 / 18 / 4 / 59` | `4 / 3 / 2 / 30` |
| `LocalFileSystemAdapter.preScanCopySourceTree` | `Sources/SwiftEditCore/DocumentCore/FileSystemProviding.swift` | `11 / 18 / 4 / 49` | `3 / 2 / 2 / 15` |
| `MarkdownNativePreviewView.blockView` | `Sources/SwiftEditUI/Views/MarkdownNativePreviewView.swift` | `10 / 10 / 6 / 94` | `9 / 8 / 2 / 36` |

- **Positive (`P#`) & Negative (`N#`) Verification**:
  - `swift test`: exited `0` — `472` tests across `130` suites passed, covering search (`DocumentSearchEngine`), filesystem confinement/symlink/copy limits (`SidebarSymlinkPolicyAndTerminalTests`, `SidebarFileOperationsTests`), preview rendering/inert HTML/diagram blocks (`PreviewZeroSocketFitnessTests`, `Unit 2: Zoom-Scaled Preview...`), and `CodeModularityFitnessScanner` (`ConstitutionFitnessTests`).
  - `tokensave sync`: exited `0` (`0 added, 3 modified, 0 removed`).
  - `tokensave_circular(path="Sources")`: `cycle_count == 0`.
  - `tokensave_recursion(path="Sources")`: `0` recursion cycles in modified files (`1` pre-existing self-edge in `EditorRenderingAttributes.swift:250`).
  - Secret hygiene scan on `git diff Sources/`: `SECRET_SCAN_CLEAN`.

## Metadata
- Branch: main
