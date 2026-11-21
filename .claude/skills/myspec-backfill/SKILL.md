---
name: myspec-backfill
description: Migrates legacy specifications from specs/ and specs/implemented/ into durable living capability specifications in <specs_dir>/.
---

# MySpec Backfill Skill (myspec-backfill)

Migrates legacy specifications (`specs/*.md` and `specs/implemented/*.md`) into living capability specifications (`<specs_dir>/<capability>/spec.md` via `.myspec.config.json`) preserving 100% parity across functional (REQ), non-functional (NFR), and security (SEC) requirements and Given/When/Then scenarios.

## Execution Workflow

1. **Target Discovery**: Parse `--capability <cap>`, `--spec <file>`, `--source <dir>`, `--dry-run`, `--archive` (default: discover all legacy specs in `specs/*.md` and `specs/implemented/*.md`).
2. **Execute Backfill Engine**: Run `python3 ./scripts/myspec_backfill.py [--capability <cap>] [--spec <file>] [--dry-run] [--archive]`.
3. **Verify Output**: Confirm `<specs_dir>/<capability>/spec.md` preserves every requirement, scenario, and test trait, and `--archive` relocates sources to `<archive_dir>/legacy-specs/` with provenance headers.

## Requirements

- The myspec-backfill skill SHALL remain runtime-neutral and migrate legacy specifications into living capability specifications with 100% parity across REQ, NFR, and SEC requirements and scenarios.
- WHERE --dry-run is specified, the myspec-backfill skill SHALL preview living specification transpositions without modifying workspace files.
- WHERE --archive is specified, the myspec-backfill skill SHALL relocate processed legacy specifications to <archive_dir>/legacy-specs/ with an archival provenance header.
- IF requirement parity fails, path traversal occurs, or a secret pattern is detected, THEN the myspec-backfill skill SHALL abort with a non-zero exit code without writing output files.

## Black-Box Execution

- **Do not read** script source before running it; the scripts are tested black boxes.
- Run commands from the skill base directory (the folder containing this `SKILL.md`).
- Run the script with `--help` for options not listed below.
- Read the source only after a non-zero exit that stderr does not explain.

| Command | Parameters | Stdout | Exit codes |
|---|---|---|---|
| `python3 ./scripts/myspec_backfill.py --dry-run` | `--repo`, `--capability`, `--spec`, `--source`, `--dry-run`, `--archive`, `--json` optional | Text summary or JSON with `--json` | 0 success, non-zero error (stderr explains) |

## Behavioral Scenarios

```gherkin
Feature: MySpec Legacy Specification Backfill

  @REQ-BACKFILL-001
  Scenario: Migrate legacy specifications preserving full requirement parity
    Given legacy specifications with functional, non-functional, and security requirements
    When the backfill engine runs for the target capability
    Then the living specification preserves every requirement and scenario with exit code 0

  @REQ-BACKFILL-002
  Scenario: Abort backfill on secret detection or path traversal
    Given a legacy specification containing an unredacted credential token or traversal path
    When the backfill engine processes the legacy specification
    Then the backfill aborts with a non-zero exit code without modifying living specifications
```

## Next-Step Guidance (Decision D10)

---
> [!TIP]
> **Recommended Next Step**: `/myspec-status` (Claude Code: `/myspec:status`)
> **Rationale**: Legacy specs migrated to living capability specs; verify workspace status with `/myspec-status`.
---
