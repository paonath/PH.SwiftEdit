---
id: "brief-log-tail-terminal-panel-lint-hover-and-help"
change_id: "019-log-tail-terminal-panel-lint-hover-and-help"
capability: "log-tail-terminal-panel-lint-hover-and-help"
branch: "main"
mode: "myspec-quick"
modifies_specs: "none"
status: "implemented"
date: "2026-11-22"
---

# Quick Brief: Log Function, Terminal Panel, Lint Hover, Navigator Jump and In-App Help

## 1. Disambiguated Prompt

1. **Log function**:
   - level highlighting always on for `.log` (VS Code `log` grammar mapping: trace/verbose grey, debug cyan, info green, warn amber, error red, critical white on red; timestamps, GUIDs, strings, exceptions and stack frames);
   - `Cmd+L` live tail *direct*, `Shift+Cmd+L` *inverse* (newest first); Toggle Task Checkbox moved to `Option+Cmd+L`;
   - in-editor Log panel: Stop/Resume, Direct/Inverse, line count (default 80, 1…10,000), Close;
   - the read-only tail view never touches the document;
   - background `tail -F` engine: kqueue `DispatchSource` on an event-only descriptor plus a 1 s timer, positional `pread`, no locks, bounded 8 MiB window, truncation/rotation restart;
   - `.log` files above the 64 MiB open gate open as tail-only tabs that cannot be saved.
2. **Terminal panel** (`Cmd+J`):
   - bottom panel with multiple sessions, each launching the preferred allowlisted external terminal in the current folder (real user home when no folder is open) via `NSWorkspace`;
   - launch failures and terminal quits/crashes are reported on the session, never crash the app;
   - `SEC-001`/`SEC-004` preserved: no shell process inside SwiftEdit (QA decision, no Security-Waiver).
3. **Lint hover**: the gutter dot shows an English popover/tooltip with rule code, message and a per-rule explanation (`MarkdownLintRuleID.explanation`).
4. **Navigator jump**:
   - full-row hit shape on navigator rows (clicks on empty row space previously did nothing);
   - `revealSelection` selects, scrolls and, if TextKit 2 estimation missed the target, lays out only the target fragment and scrolls again.
5. **Help**:
   - English, GitHub-ready `README.md` with the logo, app name `SwiftEdit` (install and quarantine commands target `SwiftEdit.app`);
   - bundled copy shown offline by Help → SwiftEdit Help (`Shift+Cmd+?`), kept identical by test.
6. **Dev tool**: `Scripts/dev/log-writer.py` (stdlib), with NLog default/JSON/CSV, Serilog, log4net, syslog, JSON and mixed formats, bulk and live writing, rotation and truncation.

## 2. QA Decision Log

| Item | Decision |
| :--- | :--- |
| Terminal inside the app (SEC-004 zero subprocess, App Sandbox) | Launcher panel, existing security controls preserved |
| `Shift+Cmd+L` already used by Toggle Task Checkbox | Task checkbox moved to `Option+Cmd+L`; `Shift+Cmd+L` = Log inverse |
| Log mode presentation and huge files | Read-only tail view; files above 64 MiB open tail-only |
| Colors, NLog formats, hover, navigator, help, dev tool | Recommended defaults |

## 3. STRIDE

| Category | Threat | Mitigation |
| :--- | :--- | :--- |
| Spoofing | A file named `*.log` used to trigger a different engine | Language by final extension only; log tabs get highlighting only, no lint/format |
| Tampering | Tail-only tab saved over a multi-GB log (data loss) | Save blocked for tail-only tabs; tail view is read-only and separate from the document |
| Repudiation | Unreported terminal failures | Failures and terminal quits recorded on the session with a readable message |
| Information Disclosure | Log contents leaked to logs/telemetry | Tail stays in memory, bounded; zero telemetry unchanged |
| Denial of Service | Huge or fast-growing logs, single giant lines | 8 MiB read window, 10,000-line ring, 1 MiB partial-line cap, background queue, viewport-only highlighting, 4096-unit line cap |
| Elevation of Privilege | Embedded shell escaping the sandbox | No subprocess; allowlisted terminal handoff via `NSWorkspace` only (`SEC-004`); no entitlement changes |

- Security Review: approved

## 4. Verification (P/N)

- **Log highlighter and tail**:
  - P: NLog, Serilog, log4net, JSON and syslog levels and timestamps; GUIDs, strings, exceptions and stack frames; buffer projection; incremental reads; real file with a concurrent writer;
  - N: prose and plural false positives, overlong lines, mid-line windows, the 10k cap, truncation, rotation, growth beyond the window.
- **Workbench Log**:
  - P: direct/inverse, line count, stop, other tab editable meanwhile, lint off for logs;
  - N: untitled tab refused, tail-only open for a 200 MB virtual log, save blocked, tab close stops the tail.
- **Terminal panel**:
  - P: home vs folder, multiple sessions, quit detection, close;
  - N: launch failure reported while editing continues.
- **Lint hover**: P: code + message + explanation per line; N: every rule explained (ASCII English), empty list maps to no text.
- **Navigator**: P: far target revealed down and up, full-row click shape; N: out-of-range clamp.
- **Help**: P: bundled README equals the repository README, `SwiftEdit.app` quarantine command; N: no legacy `PH.SwiftEdit.app` name.
- **Integration**:
  - `log-writer.py` produced 2,000,000 NLog lines (235 MB) in 7.6 s;
  - `LogTailSession` read the initial tail in 24 ms, live polls took at most 1.6 ms while the writer appended at 50 lines/s, and the rotation was detected;
  - all 20 mixed-format samples were classified.
- **Totals**: full suite 318/318 green, Debug app build succeeded, secret scan clean.

## Metadata
- Branch: main

## 5. Follow-up Refactor Passes (2026-11-22)

| Pass | Kind | Change | Evidence (release) |
| :--- | :--- | :--- | :--- |
| 1 | Performance | Programmatic editor updates replace only the differing middle range (memcmp common prefix/suffix on scalar boundaries) instead of the whole text; read-only views (log tail) bypass undo explicitly | 10k-line tail + appended line, update + viewport layout: 3.31 ms → 0.81 ms (−76%); exact text and single undo verified for prefix/suffix/middle/Unicode/empty edits |
| 2 | Bugs | Tail deliveries carry a monotonic sequence and stale snapshots are discarded (main-actor `Task`s are not strictly FIFO); the kqueue watch is re-armed on every poll until the log file exists again (missing at start or recreated after rotation) | Regression tests `nOutOfOrderDeliveriesAreIgnored`, `nVnodeRearmsAfterRecreation` |
| 3 | Performance | Lint render projections (underlines, gutter severities, hover details) keyed by a diagnostics generation counter instead of comparing up to 1000 diagnostics per read; hover details cached | 10 renders with 1000 diagnostics: 2.31 ms → 0.0046 ms; invalidation on new diagnostics and caret moves verified |

Note: the suspected undo accumulation in the read-only tail view was not reproducible (`shouldChangeText` already refuses non-editable views); the test `nReadOnlyUpdatesRegisterNoUndo` keeps it as a regression guard.
