---
name: myspec-validate
description: Validates OpenSpec changes against the tdd-spec-driven schema, STRIDE security tables, and TDD triads using scripts/myspec_validate.py.
---

# MySpec Validate

Validates changes in `<changes_dir>/<change-id>/` (via `.myspec.config.json`, default: `openspec/changes/`) against `tdd-spec-driven` (`proposal.md`, `specs/`, `design.md`, `tasks.md`), delta grammar (`## ADDED/MODIFIED/REMOVED Requirements`, `### Requirement:`, `#### Scenario:`), `[RED]`/`[GREEN]`/`[REFACTOR]` triads, six-category STRIDE tables, approved Security Review verdicts, secret hygiene, Rule G3 security waivers (`AR`, `BC`, `UI`, `DATA`, `API`, `TEST`, `SEC`, `SDD`), and `--validate-constitution` (`45`/`25`/`40` line caps, zero prose, `[<PREFIX>-###]` traceability).

## Usage

```bash
python3 ./scripts/myspec_validate.py [--change <change-id-or-path> | --all | --validate-constitution] [--strict] [--json] [--cli-parity]
```

- `--change`: Target change directory or identifier; `--all`: validate every active change and `index.yml`.
- `--validate-constitution`: Verify Bare-Bones 2-level `<spec_root>/Constitution.md` tree limits and rules.
- `--strict`: Treat warnings as fatal errors; `--json`: emit JSON; `--cli-parity`: compare against external OpenSpec CLI.

## Requirements

- The myspec-validate skill SHALL verify tdd-spec-driven artifacts, delta spec grammar, TDD triads, six-category STRIDE tables, approved Security Review verdicts, secret hygiene, and Rule G3 security waivers.
- WHEN validating delta specifications, the myspec-validate skill SHALL enforce requirement line lengths of at most 500 characters and explicit RFC 2119 normative keywords.
- WHERE <spec_root>/Constitution.md exists or --validate-constitution is supplied, the myspec-validate skill SHALL verify Bare-Bones line caps and 6-artifact [<PREFIX>-###] traceability.
- IF schema, triad, secret, waiver, or constitutional violations occur, THEN the myspec-validate skill SHALL exit with code 1 and report every violation.

## Black-Box Execution

- **Do not read** script source before running it; the scripts are tested black boxes.
- Run commands from the skill base directory (the folder containing this `SKILL.md`).
- Run the script with `--help` for options not listed below.
- Read the source only after a non-zero exit that stderr does not explain.

| Command | Parameters | Stdout | Exit codes |
|---|---|---|---|
| `python3 ./scripts/myspec_validate.py --change "<change-id>"` | `--change` required unless `--all`; `--strict`, `--json`, `--cli-parity`, `--all`, `--repo-root` optional | Text status or JSON with `--json` | 0 pass, 1 fail |

## Behavioral Scenarios

```gherkin
Feature: MySpec OpenSpec Change Validation

  @REQ-VALIDATE-001
  Scenario: Validate a schema-compliant OpenSpec change
    Given an OpenSpec change with valid delta grammar, TDD triads, STRIDE table, and approved security verdict
    When strict validation runs for the change identifier
    Then the validation report confirms compliance with exit code 0

  @REQ-VALIDATE-002
  Scenario: Reject a change with secret leaks or missing security approval
    Given an OpenSpec change containing a credential token or unapproved security verdict
    When strict validation runs for the change identifier
    Then validation fails with exit code 1 and reports the security violation
```

---
> [!TIP]
> **Recommended Next Step**: `/myspec-apply <change-id>` (Claude Code: `/myspec:apply <change-id>`)
> **Rationale**: OpenSpec change successfully validated; proceed to TDD task implementation via `/myspec-apply`.
---
