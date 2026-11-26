# Capability: release-pipeline-and-test-gating

## Purpose
Core release-pipeline-and-test-gating capability living specification, operational contracts, and behavioral requirements.

## Requirements

### Requirement: Lean Release Pipeline Functional-Only Test Gate [TEST-001]
WHEN the release workflow executes `swift test --no-parallel` with `SWIFTEDIT_RELEASE_PIPELINE=1`, the Test Suite SHALL skip UI E2E window suites (`LiveUIMouseAndShortcutsResponsivenessTests`, UI rendering tests in `UIRenderingCoverageTests`, `VisualAuditSnapshotTests`) and wall-clock or CPU timing stress benchmarks (`Perf016` and `Perf019` `[perf]` tests) while running all functional, regression, golden, architecture fitness, and `[Security]` tests serially for deterministic CI execution.

#### Scenario: Release pipeline executes lean functional and security test suite
- **Trait**: functional
- **Given** `SWIFTEDIT_RELEASE_PIPELINE` is set to `"1"` in `.github/workflows/release.yml`
- **When** `swift test --no-parallel` runs during a release tag build
- **Then** E2E UI window tests and timing stress benchmarks are skipped and all functional, golden, fitness, and `[Security]` tests pass serially

#### Scenario: Pull request, branch CI, and local runs execute the full test suite
- **Trait**: functional
- **Given** `SWIFTEDIT_RELEASE_PIPELINE` is unset (as in `.github/workflows/test.yml` and local runs)
- **When** `swift test` runs
- **Then** `ReleasePipelineTestGate.shouldRunE2EUIAndStressTests` evaluates to `true` and E2E UI and timing stress tests execute normally

### Requirement: Optimized Release App Bundle Build & Cleanup [AR-001]
The Release Workflow SHALL build `SwiftEdit.app` via `./Scripts/build-app.sh --configuration Release --clean --derived-data .tmp/DerivedData` preserving `-Osize`, `wholemodule`, `GCC_OPTIMIZATION_LEVEL=s`, `DEAD_CODE_STRIPPING=YES`, `LLVM_LTO=YES_THIN`, and external `.dSYM`, and SHALL clean `.tmp` on job completion.

#### Scenario: Security suites remain ungated in release pipeline
- **Trait**: security
- **Given** the repository test suites `DocumentSecurityQuarantineTests`, `XcodeAppShellAndPackagingFitnessTests`, and `PerformanceCachingAndSecurityLintTests`
- **When** `ReleasePipelineTestGateTests` inspects their source files
- **Then** none of those security suites reference `ReleasePipelineTestGate` and all execute unconditionally in release
