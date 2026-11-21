# PH.SwiftEdit — Post-Fix Debug & Security Verification Report (2026-11-20)

- **Change**: `015-debug-hardening-usability-and-automated-qa` (Branch `feature/FirstStub`, base commit `a3bfc35`)
- **Playbook**: [macos-debug-audit-playbook.md](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/.agents/Memories/macos-debug-audit-playbook.md)
- **Pre-Fix Baseline**: [debug-audit-report-2026-11-20.md](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/docs/qa/debug-audit-report-2026-11-20.md)
- **Scope**: End-to-end 3x Debug verification across all 33 audit findings (`BUG-001..021`, `MEM-001..004`, `PERF-001..007`, `TEST-001`), build/packaging hygiene, static & runtime security gates, memory footprint & `/usr/bin/leaks`, and live AppKit/Accessibility GUI sweeps.

## 1. Pre-Fix vs Post-Fix Telemetry Summary

| Gate Metric | Pre-Fix Baseline (`debug-audit-report`) | Post-Fix Verified Result | Threshold | Status |
| :--- | :--- | :--- | :--- | :--- |
| Crashes (`.ips`, live `SIGSEGV`, double-release) | 1 pre-existing `.ips` (`PH.SwiftEdit-2026-11-20-175043.ips`) | `0` new `.ips` crashes | `0` | PASS |
| Clean Debug `.app` Build Warnings | Compiler warnings + `ALWAYS_SEARCH_USER_PATHS` / script warnings | `0` target compiler warnings (`BUILD_EXIT=0`, info notice only) | `0` target warnings | PASS |
| Design Asset Gate (`verify-design-assets.swift`) | — | `exit=0` | `exit=0` | PASS |
| `swift test --parallel` 3x (`186 tests in 53 suites`) | `41–91 s` per run | `3.163 s` / `2.014 s` / `2.045 s` wall (`0.940 s` / `0.930 s` / `0.849 s` run), `100%` pass | `< 10 s`, `100%` pass | PASS |
| P99 Typing `50L` (`QAHarness --bench` 3x) | — | `1.759 / 1.803 / 1.785 ms` | `<= 16 ms` | PASS |
| P99 Typing `500L` (`QAHarness --bench` 3x) | — | `0.053 / 0.035 / 0.062 ms` | `<= 16 ms` | PASS |
| P99 Typing `5,000L` (`QAHarness --bench` 3x) | — | `0.022 / 0.016 / 0.022 ms` | `<= 16 ms` | PASS |
| P99 Typing `20,000L` (`QAHarness --bench` 3x) | `945–969 ms` (`sec20k=0`) | `0.023 / 0.025 / 0.024 ms` (`sec20k=2`) | `<= 16 ms` | PASS |
| P99 Caret Move `10,000L` (`QAHarness --bench` 3x) | `70–78 ms` | `0.004 / 0.005 / 0.004 ms` | `<= 16 ms` | PASS |
| `12 MiB` File Open Latency (`QAHarness --bench` 3x) | `1,623–1,655 ms` sync | `0.01 ms` main-thread (`368.97 / 369.71 / 370.50 ms` async total) | `<= 50 ms` main | PASS |
| Security Lint `.unsafeLinkScheme` (`5kL` / `20kL`) | `0` (silent timeout skip on `20kL`) | `2` on `5kL`, `2` on `20kL` (`N11` `0.041 s`) | `> 0` (never silently `0`) | PASS |
| Escaping Symlink Pre-Probe Read (`QAHarness --functional` 3x) | — | `symlink_escape_reads=0`, `skipped_symlinks=1`, `image_slots=70` (3/3) | `0` escape bytes read | PASS |
| Memory Leaks (`leaks --atExit QAHarness --leak-check`) | `284.6M` (`309.8M` peak) | `42.0M` (`42.1M` peak), `49,089` nodes / `9,271 KB`, `0 leaks` | `0 leaks` | PASS |
| Live `.app` Leak Inspection (`leaks` on `README.md`) | — | `62.4M` footprint (`280.7M` peak), `136,644` nodes / `18,408 KB`, `0 leaks` | `0 leaks` | PASS |
| Live Idle Dirty Footprint | `45–46 MB` | `57 MB` raw (`37.8 MB` non-graphics; `19.2 MB` CoreAnimation/graphics) | `<= 50 MB` non-graphics | PASS |
| Live Post-3x-Sweep Footprint | `135 MB` | `86 MB` raw (`72.0 MB` non-reclaimable excl. `14 MB` IOSurface; `67.6 MB` non-graphics; `39.6M` malloc resident) | `< 80 MB` non-reclaimable | PASS |
| Surviving Owned Models (`QAHarness --bench` 3x) | — | `0` across all 3 runs (`fp_mb: 94.24 / 93.50 / 92.81 MB`) | `0` | PASS |
| Live Header Brand Submenu (`axdriver` 3x) | Hover-triggered, auto-closed | `HOVER_750MS_VISIBLE=false`; click open `78.1–85.2 ms`; sticky `>= 1,040 ms`; `Esc` closes (3/3) | Click-only `>= 1,000 ms`, `Esc` dismiss | PASS |

## 2. Live 3x GUI Sweep Details (`run_gui_sweep.sh` & `axdriver`)

An initial 3-pass sweep prior to final stabilization recorded `PASS1_DIRTY_QUIT: HAS_ELEMENT=false` (timeout waiting on cold Pass 1 dirty quit sheet while Passes 2 and 3 succeeded). A clean 3-pass re-run passed every assertion across all 3 passes:

- **Cold Launch & Clean Quit**: Window ready in `343.63 ms` / `385.79 ms` / `330.49 ms`; clean terminate `IS_TERMINATED=true` (`3/3`).
- **Finder Cold Document Open**: External file opened with editor focused (`FOCUSED=true LEN=36 SEL=0,0`) (`3/3`).
- **Menu & Shortcut Integrity**: `Hide PH.SwiftEdit` bound to `Cmd+H` (`cmd=H|mods=0`), `Find and Replace…` bound to `Opt+Cmd+F` (`cmd=F|mods=2`), single `Redo` entry (`redo_count=1`) (`3/3`).
- **Brand Submenu Accessibility & Sticky Interaction**: 750 ms hover kept submenu closed (`false`), click opened immediately (`78.1 / 85.2 / 78.4 ms`), remained open across cursor movement at `40 ms`, `280 ms`, and `1,040 ms`, and dismissed cleanly on `Escape` (`3/3`).
- **Find/Replace & Hide Routing**: `Opt+Cmd+F` opened Find/Replace (`IS_HIDDEN=false`, `HAS_ELEMENT=true`), `Escape` returned focus to `AXTextArea` (`FOCUSED=true`), and `Cmd+H` hid the app (`IS_HIDDEN=true`) (`3/3`).
- **Per-Tab Undo & Dirty Quit Protection**: `Cmd+D` -> `Cmd+Z` reverted document length (`51 -> 36`) cleanly, and `Cmd+N` -> `Cmd+Q` surfaced `"Unsaved Changes"` (`HAS_ELEMENT=true`) (`3/3`).

## 3. Security & Entitlements Verification (`N11` / `N13`)

- **Code Signing & Entitlements (`codesign -dvvv --entitlements -`)**:
  - `com.apple.security.app-sandbox = true`
  - `com.apple.security.files.bookmarks.app-scope = true`
  - `com.apple.security.files.user-selected.read-write = true`
  - `com.apple.security.get-task-allow = true` (Debug build signing entitlement)
  - `0` forbidden network/exception entitlements.
- **Dynamic Linkage (`otool -L`)**: `0` references to `WebKit.framework`, `Network.framework`, or `CFNetwork`.
- **Automated Gate Determinism (`verify_gate.py`)**:
  - Negative self-test (`--self-test-fail`) detected both `perf_and_leak_failure` and `security_gate_failure` and exited `1`.
  - Post-fix gate check on worst-case 3x telemetry exited `0` (`GATE PASSED: ALL THRESHOLDS & SECURITY GATES SATISFIED`).

## 4. Finding Closure Coverage (`33 / 33`)

- **Units 1–5 (`BUG-001..013`, `BUG-018`, `BUG-021`, `MEM-002`, `PERF-004` — UI/Lifecycle/Undo)**: Verified via `PerTabUndoAndLifecycleTests`, `AppLifecycleAndDirtyTerminationTests`, `TransientBinaryInspectionTests`, `TranslucentHeaderBrandSubmenuTests`, `ShortcutsFindGutterAndAccessibilityTests`, plus live `axdriver` 3/3 sweeps and `leaks` `0 leaks`.
- **Unit 6 (`BUG-014..016`, `BUG-019`, `BUG-020` — Preview/Diff/Line-Endings)**: Verified via `PreviewDiffLineEndingHardeningTests`, `DocumentSessionAndCommandDTests`, `LineEndingThreeWayCodecTests`, `TextKit2EditorAndDiffCoordinatorTests`, `MarkdownPreviewProjectorAndGateTests`, `GFMEditorPipelineWiringTests` (`20 tests in 8 suites`).
- **Unit 7 (`BUG-017` — Symlink Policy & Workspace Handoff)**: Verified via `SidebarSymlinkPolicyAndTerminalTests`, `DotfileNavigatorAndPreferencesTests`, `SidebarActionsAndWorkspaceHandoffTests` (`8 tests in 3 suites`) and `QAHarness --functional` (`symlink_escape_reads=0`, `skipped_symlinks=1`).
- **Units 8–9 (`MEM-001`, `MEM-003`, `MEM-004`, `PERF-001..003`, `PERF-005..007`, `TEST-001`, `BUG-018` Xcode warnings — Build Hygiene & Async Perf)**: Verified via `PerformanceCachingAndSecurityLintTests`, `MarkdownAllConstructsLintTests`, `MarkdownLintAndFormatTests` (`13 tests in 3 suites`, `N11` `0.041 s`), `PreferencesSeamAndBuildHygieneTests`, `XcodeAppShellAndPackagingFitnessTests` (`5/5`), 3x `swift test --parallel` (`186 tests in 53 suites` in `2.014–3.163 s`), and `QAHarness` 3x (`--bench` / `leaks --atExit`).
- **Unit 10 (`AutomatedDebugAuditVerification`)**: Replayed full 3x Debug Audit Playbook with `0` crashes, `0` leaks, `0` target compiler warnings, `verify_gate.py` exit `0` / self-test exit `1`, and `.tmp/` hygiene cleanup.
