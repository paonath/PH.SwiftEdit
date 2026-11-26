# Brief: Lean Release Pipeline & Functional-Only Release Tests

- **Slug**: `lean-release-pipeline-functional-tests`
- **Capability**: `release-pipeline-and-test-gating`
- **Constitution Prefixes**: `AR-001..006`, `TEST-001..008`, `SEC-001..012`, `SDD-007`, `SDD-009`
- **Security Review**: approved

## Disambiguated Prompt

- Keep `.github/workflows/release.yml` lean and deterministic by setting `SWIFTEDIT_RELEASE_PIPELINE: "1"` with `swift test --no-parallel` on the test step and cleaning `.tmp` on exit (`if: always()`).
- Exclude E2E UI window tests (`LiveUIMouseAndShortcutsResponsivenessTests`, UI rendering tests in `UIRenderingCoverageTests`, `VisualAuditSnapshotTests`) and wall-clock/CPU timing stress benchmarks (`Perf016` and `Perf019` `[perf]` tests) ONLY when `SWIFTEDIT_RELEASE_PIPELINE=1` via Swift Testing `.enabled(if: ReleasePipelineTestGate.shouldRunE2EUIAndStressTests)`.
- Preserve every functional, regression, golden fingerprint, architecture fitness, and `[Security]` test in release (zero `Security-Waiver`), and keep all E2E UI and timing stress tests active in `.github/workflows/test.yml` and local runs.
- Preserve all Release optimization flags in `Scripts/build-app.sh` (`SWIFT_COMPILATION_MODE=wholemodule`, `SWIFT_OPTIMIZATION_LEVEL=-Osize`, `GCC_OPTIMIZATION_LEVEL=s`, `DEAD_CODE_STRIPPING=YES`, `LLVM_LTO=YES_THIN`, external `.dSYM`).
- Keep the 3-target SwiftPM topology (`SwiftEditCore`, `SwiftEditUI`, `SwiftEditTests`) intact (`AR-001..006`).

## `/qa` Decision Log

1. **Test isolation strategy**: `(Recommended)` Gate E2E UI and timing stress tests only in `release.yml` via `SWIFTEDIT_RELEASE_PIPELINE=1` + Swift Testing `.enabled(if:)`, keeping them enabled in `test.yml` and local runs.
2. **Release optimization profile**: `(Recommended)` Keep `Scripts/build-app.sh` Release optimization policy (`-Osize` + `wholemodule` + `GCC -Os` + `thin LTO` + `DEAD_CODE_STRIPPING=YES` + external `.dSYM`) and add `.tmp` cleanup in `release.yml`.

## 6-Category STRIDE Review

| Category | Assessment | Mitigation / Status |
| :--- | :--- | :--- |
| **Spoofing** | Low — `SWIFTEDIT_RELEASE_PIPELINE` only affects test execution filtering, never production code. | Guarded strictly inside `Tests/SwiftEditTests/ReleasePipelineTestGate.swift`; production targets untouched. |
| **Tampering** | Low — risk of accidentally gating `[Security]` tests in release. | Enforced by `ReleasePipelineTestGateTests.n2SecuritySuitesNeverGatedInRelease` (`N2 [Security]`). |
| **Repudiation** | Low — CI logs must clearly show which tests were skipped. | Swift Testing logs `➜ Suite/Test ... skipped.` explicitly for every gated test. |
| **Information Disclosure** | None — no secrets, tokens, or credentials added or modified (`CWE-798` clean). | Verified clean diff; existing GitHub Actions secret handling in `release.yml` unchanged. |
| **Denial of Service** | Improved — removes flaky wall-clock CI failures on virtualized `macos-26-arm64` runners. | Release pipeline test duration dropped from ~40s (flaky) to ~3s (deterministic functional suite). |
| **Elevation of Privilege** | None — `permissions: contents: write` and macOS entitlements/signing steps remain unchanged. | `XcodeAppShellAndPackagingFitnessTests` (`N6 [Security]`) remains active in release. |

## Implemented `P#`/`N#` Verification Summary

- `P1`: `ReleasePipelineTestGate.isReleasePipeline(environment:)` parses truthy/falsy values deterministically (`8` parameterized cases passed).
- `P2`: `release.yml` sets `SWIFTEDIT_RELEASE_PIPELINE: "1"`, runs `Scripts/build-app.sh --configuration Release --clean --derived-data .tmp/DerivedData` with full Release optimizations, cleans `.tmp`, while `test.yml` leaves the full suite active.
- `N1`: Absent `SWIFTEDIT_RELEASE_PIPELINE` defaults to running E2E UI and timing stress tests (verified locally with `LiveUIMouseAndShortcutsResponsivenessTests`: 3/3 passed).
- `N2 [Security]`: `DocumentSecurityQuarantineTests`, `XcodeAppShellAndPackagingFitnessTests`, and `PerformanceCachingAndSecurityLintTests` are never gated by `ReleasePipelineTestGate`.
- Full release-mode run (`SWIFTEDIT_RELEASE_PIPELINE=1 swift test --parallel`): `477 tests in 131 suites` completed with `exit 0` in `2.987s` (`15` E2E UI / timing stress tests skipped; `462` functional, golden, fitness, and security tests passed).

## Metadata
- Branch: main
