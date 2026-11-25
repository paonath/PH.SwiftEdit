---
id: "brief-complexity-pass-5-scripts-and-asset-verifier"
change_id: "036-complexity-pass-5-scripts-and-asset-verifier"
capability: "workbench-editor-and-linter-modular-decomposition"
branch: "main"
modifies_specs:
  - "openspec/specs/workbench-editor-and-linter-modular-decomposition/spec.md"
status: "implemented"
date: "2026-11-25"
owners:
  - "shell-expert"
  - "swift-macos-expert"
  - "cyber-security-expert"
---

# TDD Specification Brief: `036-complexity-pass-5-scripts-and-asset-verifier`

- **Security Review**: approved

## 1. Disambiguated Prompt & Decision Log (`/qa` + `STOP`)

- **Workflow 01 Approval**: Completed via `STOP` approval with `(Recommended)` defaults (`Rule G3` fail-closed: preserve all existing security controls intact without any `Security-Waiver`, zero auto-commit, zero `<changes_dir>/` 6-artifact ceremony).
- **Scope (`Iteration 5: complexity-pass-5-scripts-and-asset-verifier`)**:
  1. **Point 1 — `main` in `Scripts/install-from-github.sh`**: Decompose into cohesive Bash 3.2-compatible helper functions (`require_arg_value`, `apply_cli_option`, `parse_args`, `require_tools`, `resolve_release_tag`, `determine_quarantine_plan`, `print_dry_run_plan`, `download_and_verify_archive`, `install_verified_app`, `cleanup_workdir`) achieving `cognitive <= 12, cyclomatic <= 10` (`main` at `cyc=2, cog=1`; all helpers `cyc <= 8, cog <= 7`) while preserving `set -euo pipefail`, `"$var"` quoting (`CWE-78`), tag validation, HTTPS GitHub API/Release URLs, and `shasum -a 256 -c` verification.
  2. **Point 2 — `main` in `Scripts/build-app.sh`**: Decompose into cohesive Bash 3.2-compatible helper functions (`require_arg_value`, `validate_configuration`, `apply_cli_option`, `parse_args`, `validate_build_prerequisites`, `stamp_info_plist`, `prepare_xcodebuild_args`, `stage_built_product`) achieving `cognitive <= 12, cyclomatic <= 10` (`main` at `cyc=2, cog=1`; all helpers `cyc <= 8, cog <= 7`) while preserving `set -euo pipefail` and all build/optimization/staging flags.
  3. **Point 3 — `verifySingleAppIconSet` in `Scripts/verify-design-assets.swift`**: Decompose into cohesive Swift helpers (`loadAppIconManifest`, `validateAppIconSlot`, `validateAppIconFile`, `validatePngRaster`, `verifyStrayAppIconEntries`) achieving `cognitive <= 8, cyclomatic <= 8` (`verifySingleAppIconSet` at `cyc=4, cog=3`; all helpers `cyc <= 5, cog <= 4`) while preserving all `AppIcon.appiconset` slot completeness, traversal (`CWE-22`), symlink ban, directory confinement, `16 MiB` cap (`CWE-400`), pixel dimension, and `hasAlpha` (`UI-001`/`ITMS-90717`) checks.

## 2. 6-Category STRIDE Security Check

| STRIDE Category | Assessment & Preserved Control |
| :--- | :--- |
| **Spoofing** | `Scripts/install-from-github.sh` preserves HTTPS-only `api.github.com` and `github.com` release URLs plus `validate_tag` path/whitespace rejection (`SEC-001`, `SEC-004`). |
| **Tampering** | `Scripts/install-from-github.sh` preserves mandatory `shasum -a 256 -c` checksum verification before extraction and backup-rollback around `ditto`; `Scripts/verify-design-assets.swift` preserves `Contents.json` slot, dimension, and `hasAlpha` checks (`ITMS-90717`). |
| **Repudiation** | Deterministic CLI stdout/stderr diagnostics and exit codes (`0`, `1`, `2`) remain identical across all scripts. |
| **Information Disclosure** | Zero new network endpoints, credentials, or host-path leaks (`CWE-200` check preserved in `verify-design-assets.swift`). |
| **Denial of Service** | `verifySingleAppIconSet` preserves the `16 MiB` (`maxAssetBytes`) pre-decode ceiling (`CWE-400`) and `kCGImageSourceShouldCache: false`; `install-from-github.sh` cleans up `INSTALL_WORKDIR` via `EXIT` trap. |
| **Elevation of Privilege** | Full `"$var"` quoting (`CWE-78`), `rm -rf -- "${var:?}"` guards, and `CWE-22` path traversal/symlink confinement checks inside `AppIcon.appiconset` remain strictly enforced. |

## 3. Before / After Metrics & Verification Summary

| Target Symbol | File | Before (`cyc / cog / nest / lines`) | After (`cyc / cog / nest / lines`) |
| :--- | :--- | :--- | :--- |
| `main` | `Scripts/install-from-github.sh` | `22 / 39 / 2 / 149` | `2 / 1 / 1 / 27` |
| `main` | `Scripts/build-app.sh` | `18 / 35 / 2 / 148` | `2 / 1 / 1 / 34` |
| `verifySingleAppIconSet` | `Scripts/verify-design-assets.swift` | `14 / 13 / 3 / 124` | `4 / 3 / 2 / 50` |

- **Positive (`P#`) & Negative (`N#`) Verification**:
  - `bash -n Scripts/install-from-github.sh Scripts/build-app.sh`: exited `0`.
  - Dry-run positive & negative CLI checks (`install-from-github.sh --dry-run`, `--version v0.1.3 --remove-quarantine --no-relaunch --dry-run`, `build-app.sh --dry-run`, `-c Debug --clean --dry-run`, plus rejected `--version "../bad"`, missing flag value, and `-c Invalid`): exited `0`.
  - `swift Scripts/verify-design-assets.swift --self-test`: exited `0` (`14/14` passed).
  - `swift Scripts/verify-design-assets.swift --root .`: exited `0`.
  - `swift test`: exited `0` — `473` tests across `130` suites passed.
  - `tokensave sync`: exited `0`.
  - `tokensave_circular(path="Sources")`: `cycle_count == 0`.
  - Secret hygiene scan on `git diff -- Scripts`: zero matches (`CLEAN_SECRETS`).

## Metadata
- Branch: main
