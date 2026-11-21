---
name: myspec-status
description: Displays diagnostics on active changes, living specs, index.yml, TDD triad progress, legacy specs, and delta code changes.
---

# MySpec Status

Reports real-time specification progress across `<changes_dir>`, `<specs_dir>`, `<spec_root>/index.yml`, `<spec_root>/Constitution.md`, `<debug_dir>`, and legacy `specs/` via `.myspec.config.json` (or dynamic auto-discovery).

## Usage

```bash
python3 ./scripts/myspec_status.py [--target <dir>] [--change <id>] [--detect-delta] [--deep-scan] [--json]
```

- `--target`: Project directory to inspect (default: current working directory).
- `--change`: Inspect a specific change (e.g. `024-init-status`) for artifact presence, `[RED]`/`[GREEN]`/`[REFACTOR]` triads, and Security Review verdicts (`approved`/`pending`).
- `--detect-delta`: Compare uncommitted working tree changes and the last 3 commits against living specs, recommending `/myspec-tdd-spec-reasoning` in `doc-align` mode on drift.
- `--deep-scan`: Run full repository delta scan and record `last_deep_scan` timestamp in `.myspec.config.json` (24-hour rate-limit warning).
- `--json`: Emit machine-readable JSON diagnostics.

## Requirements

- The myspec-status skill SHALL resolve active paths via .myspec.config.json and summarize active changes, TDD triads, Security Review verdicts, living specs, index.yml, Constitution.md telemetry, and legacy specs.
- WHEN --detect-delta or --deep-scan is provided, the myspec-status skill SHALL compare uncommitted files and recent commits against living specifications and report unaligned deltas.
- IF sensitive captures or environment files appear in <debug_dir>, THEN the myspec-status skill SHALL report a security hygiene alert.

## Black-Box Execution

- **Do not read** script source before running it; the scripts are tested black boxes.
- Run commands from the skill base directory (the folder containing this `SKILL.md`).
- Run the script with `--help` for options not listed below.
- Read the source only after a non-zero exit that stderr does not explain.

| Command | Parameters | Stdout | Exit codes |
|---|---|---|---|
| `python3 ./scripts/myspec_status.py` | `--target`, `--change`, `--json`, `--detect-delta`, `--deep-scan` optional | Text report or JSON with `--json` | 0 success |

## Behavioral Scenarios

```gherkin
Feature: MySpec Workspace Status Diagnostics

  @REQ-STATUS-001
  Scenario: Report active change triads and living spec telemetry
    Given an initialized MySpec workspace with active changes and living specifications
    When workspace status is requested with JSON output enabled
    Then task completion percentages, TDD triad counts, and index telemetry are returned with exit code 0

  @REQ-STATUS-002
  Scenario: Flag unredacted artifacts inside the debug directory
    Given an initialized MySpec workspace containing a sensitive capture in the debug directory
    When workspace status is requested
    Then the status report emits a security hygiene alert naming the captured artifact
```

---
> [!TIP]
> **Recommended Next Step**: `/myspec-apply` to implement the active change, or `/myspec-validate` to audit artifact integrity.
> **Rationale**: Diagnostics highlight pending tasks and schema compliance.
---
