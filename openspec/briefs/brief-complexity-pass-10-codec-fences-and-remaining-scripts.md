---
id: "brief-complexity-pass-10-codec-fences-and-remaining-scripts"
change_id: "041-complexity-pass-10-codec-fences-and-remaining-scripts"
capability: "workbench-editor-and-linter-modular-decomposition"
branch: "main"
modifies_specs:
  - "openspec/specs/workbench-editor-and-linter-modular-decomposition/spec.md"
status: "implemented"
date: "2026-11-25"
owners:
  - "swift-macos-expert"
  - "shell-expert"
  - "cyber-security-expert"
---

# TDD Specification Brief: `041-complexity-pass-10-codec-fences-and-remaining-scripts`

- **Security Review**: approved

## 1. Disambiguated Prompt & Decision Log (`/qa` + `STOP`)

- **Workflow 01 Approval**: Completed via `STOP` approval with `(Recommended)` defaults (`Rule G3` fail-closed: preserve binary quarantine, strict UTF-8/UTF-16 decoding, `set -euo pipefail`, `"$var"` quoting (`CWE-78`), and all design asset/confinement checks intact without any `Security-Waiver`, zero auto-commit, zero `<changes_dir>/` 6-artifact ceremony).
- **Scope (`Iteration 10: complexity-pass-10-codec-fences-and-remaining-scripts`)**:
  1. **Point 1 — `DocumentCodec.decode` (`Sources/SwiftEditCore/DocumentCore/DocumentCodec.swift`)**: Extract `bomDetectionOrder`, `detectBOMEncoding`, `stripOptionalBOM`, `isUTF8Encoding`, `decodePayloadText`, `requireStrictUTF16`, and `makeTextPayload` reducing `decode(_:)` (`9 / 20 / 3 / 46` -> `2 / 1 / 2 / 8`) and `decode(_:explicitEncoding:)` (`8 / 11 / 3 / 31` -> `2 / 1 / 2 / 8`) while preserving binary NUL-prefix quarantine (`DATA-003`, `SEC-011`) and strict UTF-8/UTF-16 decoding.
  2. **Point 2 — `MarkdownSmartNewlineEngine.isInsideFencedCodeBlockUTF8` & `openingFenceUTF8` (`Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownSmartNewlineEngine.swift`)**: Parameterize `findLineEndUTF8`, extract `updateFenceState`, and add `private enum MarkdownUTF8FenceCursor` reducing `isInsideFencedCodeBlockUTF8` (`8 / 20 / 4 / 38` -> `2 / 2 / 2 / 20`) and `openingFenceUTF8` (`6 / 11 / 4 / 24` -> `5 / 4 / 2 / 12`) while preserving `4096`-unit bounds and fenced code block suppression.
  3. **Point 3 — `Scripts/stamp-info-plist.sh:main` (`Scripts/stamp-info-plist.sh`)**: Extract `require_arg_value`, `apply_cli_option`, `parse_args`, `resolve_versions_from_json`, and `stamp_built_plist_if_present` reducing `main` (`8 / 15 / 2 / 65` -> `1 / 0 / 1 / 11`) while preserving `set -euo pipefail`, `IFS=$'\n\t'`, and `"$var"` quoting (`CWE-78`).
  4. **Point 4 — `Scripts/verify-design-assets.swift:verifyDocumentationAndAssets` (`Scripts/verify-design-assets.swift`)**: Extract `forbiddenHostPathSubstrings`, `verifyRequiredPromotedFiles`, `verifyReasoningSourcePreservation`, `verifyMarkdownFile`, `verifyHostPathLeak`, `validateRelativeMarkdownTarget`, and `isTraversalOrAbsoluteTarget` reducing `verifyDocumentationAndAssets` (`9 / 8 / 4 / 89` -> `1 / 0 / 2 / 17`) while preserving all `CWE-22`, `CWE-79`, `CWE-200`, `CWE-400`, and `CWE-611` checks.

## 2. 6-Category STRIDE Security Check

| STRIDE Category | Assessment & Preserved Control |
| :--- | :--- |
| **Spoofing** | `DocumentCodec.decode` preserves strict BOM detection and explicit-encoding validation; `verifyDocumentationAndAssets` preserves host-path leak (`file://`, `/Users/`) and SVG token checks (`CWE-200`). |
| **Tampering** | `DocumentCodec.decode` rejects invalid UTF-8 and odd/unpaired UTF-16 payloads fail-closed with `DomainError.unsupportedEncoding`; `stamp-info-plist.sh` preserves `plutil` and `PlistBuddy` exact-key stamping with quoted `"$var"` arguments (`CWE-78`). |
| **Repudiation** | Deterministic `DomainError.unsupportedEncoding`, `VerificationIssue` (`integrity` exit `1`, `security` exit `2`), and `stamp-info-plist.sh` stderr error reporting remain unchanged. |
| **Information Disclosure** | Zero new logging, network calls, persistence, or secrets introduced (`SECRET_SCAN_CLEAN`). |
| **Denial of Service** | `DocumentCodec.decodeBinaryInspectionPreview` preserves the `8 KiB` binary probe and `1 MiB` preview cap (`SEC-011`); `MarkdownSmartNewlineEngine` preserves linear UTF-8 scanning with `4096`-unit line bounds (`CWE-400`); `verifyRequiredPromotedFiles` preserves `16 MiB` file size checks (`CWE-400`). |
| **Elevation of Privilege** | `DocumentCodec` preserves `isBinaryReadOnly: true` quarantine on binary payloads; `verifyDocumentationAndAssets` preserves symlink escape and `..` path-traversal rejection (`CWE-22`). |

## 3. Before / After Metrics & Verification Summary

| Target Symbol | File | Before (`cyc / cog / nest / lines`) | After (`cyc / cog / nest / lines`) |
| :--- | :--- | :--- | :--- |
| `DocumentCodec.decode(_:)` | `Sources/SwiftEditCore/DocumentCore/DocumentCodec.swift` | `9 / 20 / 3 / 46` | `2 / 1 / 2 / 8` |
| `DocumentCodec.decode(_:explicitEncoding:)` | `Sources/SwiftEditCore/DocumentCore/DocumentCodec.swift` | `8 / 11 / 3 / 31` | `2 / 1 / 2 / 8` |
| `MarkdownSmartNewlineEngine.isInsideFencedCodeBlockUTF8` | `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownSmartNewlineEngine.swift` | `8 / 20 / 4 / 38` | `2 / 2 / 2 / 20` |
| `MarkdownSmartNewlineEngine.openingFenceUTF8` | `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownSmartNewlineEngine.swift` | `6 / 11 / 4 / 24` | `5 / 4 / 2 / 12` |
| `Scripts/stamp-info-plist.sh:main` | `Scripts/stamp-info-plist.sh` | `8 / 15 / 2 / 65` | `1 / 0 / 1 / 11` |
| `DesignAssetsVerifier.verifyDocumentationAndAssets` | `Scripts/verify-design-assets.swift` | `9 / 8 / 4 / 89` | `1 / 0 / 2 / 17` |

- **Positive (`P#`) & Negative (`N#`) Verification**:
  - `bash -n Scripts/stamp-info-plist.sh Scripts/install-from-github.sh Scripts/build-app.sh`: exited `0`.
  - `bash Scripts/stamp-info-plist.sh --dry-run`: exited `0`.
  - `swift Scripts/verify-design-assets.swift --self-test`: exited `0` (`14/14` passed).
  - `swift Scripts/verify-design-assets.swift --root .`: exited `0`.
  - `swift test`: exited `0` (`473` tests in `130` suites passed).
  - `tokensave sync`: exited `0`.
  - `tokensave_circular(path="Sources")`: `cycle_count == 0`.
  - `tokensave_recursion(path="Sources")`: `0` recursion cycles in all modified files (`1` pre-existing overload self-edge in unrelated `EditorRenderingAttributes.swift:272`).

## Metadata
- Branch: main
