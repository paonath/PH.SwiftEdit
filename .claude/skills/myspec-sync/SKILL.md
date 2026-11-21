---
name: myspec-sync
description: Merges delta specifications from an active OpenSpec change into living capability specifications without archiving the change directory.
---

# MySpec Sync Skill (myspec-sync)

Merges delta specifications from an active change (`<changes_dir>/<change-id>/specs/**/spec.md`) into living capability specifications (`<specs_dir>/<capability>/spec.md`) honoring `.myspec.config.json` paths without archiving the change directory.

## Execution Workflow

1. **Target Identification**: Resolve `spec_root`, `changes`, and `specs` via `.myspec.config.json` and verify delta files under `<changes_dir>/<change-id>/specs/**/spec.md`.
2. **Execute Living Spec Merger**: Run `python3 ./scripts/myspec_sync.py --change <change-id>` (add `--cli-parity` if matched `openspec` CLI is present).
3. **Verify Output**: Confirm `ADDED`, `MODIFIED`, and `REMOVED` requirements update `<specs_dir>/<capability>/spec.md`, living `## Purpose` stays intact, and `## Sync Impact Report` updates in `<spec_root>/Constitution.md` when `- Amends-Constitution:` is declared.

## Requirements

- The myspec-sync skill SHALL remain runtime-neutral across host environments and resolve workspace paths via .myspec.config.json without archiving the change directory.
- WHEN merging delta specifications into living specifications, the myspec-sync skill SHALL preserve living ## Purpose sections and update ## Sync Impact Report when - Amends-Constitution: is declared.
- IF delta specifications are missing or fail normative validation, THEN the myspec-sync skill SHALL abort with exit code 1 and leave living specifications unmodified.

## Black-Box Execution

- **Do not read** script source before running it; the scripts are tested black boxes.
- Run commands from the skill base directory (the folder containing this `SKILL.md`).
- Run the script with `--help` for options not listed below.
- Read the source only after a non-zero exit that stderr does not explain.

| Command | Parameters | Stdout | Exit codes |
|---|---|---|---|
| `python3 ./scripts/myspec_sync.py --change "<change-id>"` | `--change` required; `--target`, `--archive`, `--cli-parity`, `--json` optional | Text summary or JSON with `--json` | 0 success, 1 failure |

## Behavioral Scenarios

```gherkin
Feature: MySpec Living Specification Sync

  @REQ-SYNC-001
  Scenario: Merge valid delta requirements into a living specification
    Given an active OpenSpec change with valid delta requirements for a capability
    When living specification sync runs for the change identifier
    Then the capability living specification incorporates the delta updates while the change stays active

  @REQ-SYNC-002
  Scenario: Abort sync when a delta requirement fails normative validation
    Given an active OpenSpec change whose delta specification lacks normative keywords
    When living specification sync runs for the change identifier
    Then the merge aborts with exit code 1 and leaves the living specification intact
```

## Next-Step Guidance (Decision D10)

---
> [!TIP]
> **Recommended Next Step**: `/myspec-verify <change-id>` (Claude Code: `/myspec:verify <change-id>`)
> **Rationale**: Delta requirements merged into living specs; proceed to verify task and test compliance.
---
