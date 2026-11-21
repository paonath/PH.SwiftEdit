---
name: myspec-help
description: Displays the full MySpec lifecycle workflow, command index, and contextual micro-help.
---

# MySpec Help

Interactive navigation and reference guide for the `myspec-*` specification suite.

## Usage

- `/myspec-help`: Render complete lifecycle flowchart and command directory.
- `/myspec-help <command>`: Inspect targeted `HELP.md` micro-documentation for a specific command (e.g. `apply`, `validate`, `propose`).

```bash
python3 ./scripts/myspec_help.py [--command <name>]
```

## Requirements

- WHEN invoked without a command argument, the myspec-help skill SHALL render the complete MySpec lifecycle flowchart and command directory.
- WHEN invoked with a command name, the myspec-help skill SHALL display the targeted HELP.md micro-documentation for that command.
- IF an unknown command name is requested, THEN the myspec-help skill SHALL exit with code 1 and report the unrecognized command.

## Black-Box Execution

- **Do not read** script source before running it; the scripts are tested black boxes.
- Run commands from the skill base directory (the folder containing this `SKILL.md`).
- Run the script with `--help` for options not listed below.
- Read the source only after a non-zero exit that stderr does not explain.

| Command | Parameters | Stdout | Exit codes |
|---|---|---|---|
| `python3 ./scripts/myspec_help.py --list` | `--command` name, `--list`, `--json` optional | Text or JSON with `--json` | 0 success, 1 unknown command |

## Behavioral Scenarios

```gherkin
Feature: MySpec Help Navigation

  @REQ-HELP-001
  Scenario: Display micro-help for a registered command
    Given the canonical MySpec skill directory is installed
    When help is requested for the "validate" command
    Then the lifecycle documentation for "myspec-validate" is returned with exit code 0

  @REQ-HELP-002
  Scenario: Reject help request for an unregistered command
    Given the canonical MySpec skill directory is installed
    When help is requested for an unknown command "nonexistent"
    Then an unrecognized command diagnostic is returned with exit code 1
```

---
> [!TIP]
> **Recommended Next Step**: `/myspec-init` (Claude Code: `/myspec:init`) if uninitialized, or `/myspec-tdd-spec-reasoning` to author a specification.
> **Rationale**: `/myspec-help` provides workflow orientation; proceed by initializing workspace or eliciting feature requirements.
---
