---
id: "brief-complexity-pass-6-safety-banner-textview-and-logtail"
change_id: "037-complexity-pass-6-safety-banner-textview-and-logtail"
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

# TDD Specification Brief: `037-complexity-pass-6-safety-banner-textview-and-logtail`

- **Security Review**: approved

## 1. Disambiguated Prompt & Decision Log (`/qa` + `STOP`)

- **Workflow 01 Approval**: Completed via `STOP` approval with `(Recommended)` defaults (`Rule G3` fail-closed: preserve all existing security controls intact without any `Security-Waiver`, zero auto-commit, zero `<changes_dir>/` 6-artifact ceremony).
- **Scope (`Iteration 6: complexity-pass-6-safety-banner-textview-and-logtail`)**:
  1. **Point 1 — `InspectionSafetyBannerState.bidiDescriptor` & `scanBiDiControlScalars` (`Sources/SwiftEditUI/Theme/InspectionSafetyBannerState.swift`)**: Replace the 10-case `switch` in `bidiDescriptor(for:)` with static lookup dictionary `bidiDescriptorsByScalar`, and decompose `scanBiDiControlScalars(in:)` via `textMayContainBiDiBytes(_:)` and `lineIncrement(at:in:)` achieving `cognitive <= 8, cyclomatic <= 7, max_nesting <= 3` while preserving all Trojan Source BiDi control-scalar (`U+202A..U+202E`, `U+2066..U+2069`, `U+061C`) detection rules unchanged (`<= 25` nominal members).
  2. **Point 2 — `SwiftEditNSTextView.drawWordOccurrencesBackground` & `currentLineFullWidthRect` (`Sources/SwiftEditUI/Views/SwiftEditNSTextViewAndUndoRegistry.swift`)**: Decompose `drawWordOccurrencesBackground(in:)` via `WordOccurrenceDrawContext`, `firstOccurrenceIndex(in:intersectingFrom:)`, `drawWordOccurrence(_:in:context:)`, and `paintOccurrenceSegment(frame:dirtyRect:origin:hasUnderline:)`, and decompose `currentLineFullWidthRect(onlyIfInViewport:)` via `isLocationOutsideViewport(_:in:onlyIfInViewport:)` and `fullWidthLineRect(for:origin:fallbackHeight:)` achieving `cognitive <= 8, cyclomatic <= 7, max_nesting <= 3` (`<= 25` nominal members in extension).
  3. **Point 3 — `LocalLogFileReader.read` (`Sources/SwiftEditCore/LogSupport/LogTail.swift`)**: Extract `readContiguousBytes(fd:into:offset:length:)` and `readPreadChunk(fd:destination:remaining:offset:)` achieving `cognitive <= 8, cyclomatic <= 7, max_nesting <= 3` while preserving `O_RDONLY | O_NONBLOCK | O_CLOEXEC`, `defer { close(fd) }`, `EINTR` retry, and exact `pread` bounds handling.
  4. **Point 4 — `DocumentLanguage.resolve` (`Sources/SwiftEditCore/DocumentCore/DocumentLanguage.swift`)**: Replace the 5 extension `Set` checks with a single `languageByExtension` lookup table achieving `cognitive <= 8, cyclomatic <= 7` while preserving quarantine (`isBinary`/`isDegraded`), untitled fallback, and final-extension-only spoofing protection.

## 2. 6-Category STRIDE Security Check

| STRIDE Category | Assessment & Preserved Control |
| :--- | :--- |
| **Spoofing** | `DocumentLanguage.resolve` preserves final-extension-only classification (`config.yml.bak` -> `.plainText`, `notes.yaml.md` -> `.markdown`) and binary/degraded lockout; `InspectionSafetyBannerState` preserves all 10 Trojan Source BiDi scalar detections (`U+202A..U+202E`, `U+2066..U+2069`, `U+061C`) and `allowedExternalSchemes` URI gating. |
| **Tampering** | All helper extractions are strictly behavior-preserving with identical buffer bounds, UTF-16 offset tracking, and non-mutating TextKit 2 background painting. |
| **Repudiation** | Deterministic `DomainError.ioFailure` errno reporting in `LocalLogFileReader.read` and `BiDiControlCharacterWarning` line/offset diagnostics remain unchanged. |
| **Information Disclosure** | Zero new logging, network calls, or secrets introduced (`SECRET_SCAN_CLEAN`). |
| **Denial of Service** | `LocalLogFileReader` preserves bounded positional `pread` loop (`O_NONBLOCK | O_CLOEXEC`), `EINTR` handling, and `defer { close(fd) }`; `SwiftEditNSTextView` preserves viewport-window binary search (`visStart - 256 ..< visEnd + 256`) and off-screen `.ensuresLayout` skip. |
| **Elevation of Privilege** | Binary and degraded snapshot lockouts (`canSave = false`, `canFormat = false`, `DocumentLanguage.plainText`) remain strictly enforced. |

## 3. Before / After Metrics & Verification Summary

| Target Symbol | File | Before (`cyc / cog / nest / lines`) | After (`cyc / cog / nest / lines`) |
| :--- | :--- | :--- | :--- |
| `bidiDescriptor` | `Sources/SwiftEditUI/Theme/InspectionSafetyBannerState.swift` | `12 / 11 / 2 / 15` | `1 / 0 / 1 / 3` |
| `scanBiDiControlScalars` | `Sources/SwiftEditUI/Theme/InspectionSafetyBannerState.swift` | `7 / 14 / 4 / 37` | `3 / 4 / 3 / 25` |
| `drawWordOccurrencesBackground` | `Sources/SwiftEditUI/Views/SwiftEditNSTextViewAndUndoRegistry.swift` | `8 / 17 / 6 / 69` | `2 / 2 / 2 / 32` |
| `currentLineFullWidthRect` | `Sources/SwiftEditUI/Views/SwiftEditNSTextViewAndUndoRegistry.swift` | `7 / 7 / 4 / 48` | `5 / 4 / 2 / 29` |
| `read` | `Sources/SwiftEditCore/LogSupport/LogTail.swift` | `8 / 14 / 4 / 27` | `4 / 3 / 2 / 14` |
| `resolve` | `Sources/SwiftEditCore/DocumentCore/DocumentLanguage.swift` | `9 / 8 / 2 / 12` | `4 / 3 / 2 / 9` |

- **Positive (`P#`) & Negative (`N#`) Verification**:
  - `swift test`: exited `0` — `473` tests in `130` suites passed.
  - `tokensave sync`: exited `0`.
  - `tokensave_circular(path="Sources")`: `cycle_count == 0`.
  - `tokensave_recursion(path="Sources")`: `0` recursion cycles in all 4 modified files (1 pre-existing overload self-edge in unrelated `EditorRenderingAttributes.swift:272`).
  - Secret hygiene scan on `git diff Sources/`: zero matches (`SECRET_SCAN_CLEAN`).

## Metadata
- Branch: main
