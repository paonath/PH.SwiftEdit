---
name: tokensave-memory-bridge
description: "Cross-session persistent memory bridge using TokenSave tools (record_decision, record_code_area, session_recall, session_start, session_end). Triggers: tokensave-memory-bridge, session memory, recall decision, record decision, project memory."
---

# Tokensave Memory Bridge (`tokensave-memory-bridge` — Progressive Disclosure Router)

## Why This Skill

Persists project-specific technical decisions and touched code areas across sessions in `.tokensave/tokensave.db`:

| Tool | Purpose |
|---|---|
| `tokensave_record_decision` | Persists design/architecture decision (rationale, affected files, tags) |
| `tokensave_record_code_area` | Marks touched code area (counter + timestamp of last modification) |
| `tokensave_session_recall` | Queries (FTS5) saved decisions; exponential decay ranking if query is omitted |
| `tokensave_session_start` | Saves code health baseline + returns recent `memory_delta` |
| `tokensave_session_end` | Compares current metrics against baseline to display improvements |

**Scope & Safety Gate**: Records technical code decisions only. Never store personal user preferences, chat history, secrets, API credentials, or non-project data. Enforces `Single-Reference Lock`: load only the active workflow or reference file at a time.

## Trigger Scenarios

1. **Session Start**: Project contains `.tokensave/` (`tokensave_status`).
2. **Post Architectural Decision**: Library choice, design pattern, schema, trade-off, or module structure agreed.
3. **Pre Code Modification**: Before editing an unfamiliar area, check prior decisions.
4. **Explicit User Requests**: "what did we decide...", "resume where we left off", "save this decision".
5. **Session Completion**: Closing a session where `tokensave_session_start` ran.

## Procedure

| Phase | Workflow / Reference | Scope |
|---|---|---|
| **01** | [01-session-startup](workflows/01-session-startup/workflow.md) | `tokensave_session_start`, `memory_delta` review, and targeted `tokensave_session_recall`. |
| **02** | [02-execution-memory](workflows/02-execution-memory/workflow.md) | Pre-edit recall, `tokensave_record_decision` granularity/hygiene, and `tokensave_record_code_area`. |
| **03** | [03-session-wrap-up](workflows/03-session-wrap-up/workflow.md) | `tokensave_session_end` baseline comparison and metric summary. |
| **Ref** | [memory-tools-reference](references/memory-tools-reference.md) | Tool parameter schemas and End-to-End Workflow Example. |

## Tool Availability Fallback

If `tokensave_*` tools are unavailable, follow the `tokensave-first` rule ("When TokenSave Is Not Available"); never improvise custom text files for memory persistence.

## Core Requirements (EARS)

- The tokensave-memory-bridge skill SHALL enforce `Single-Reference Lock` and persist only technical architecture decisions and touched code areas in `.tokensave/tokensave.db`.
- The tokensave-memory-bridge skill SHALL forbid recording personal user preferences, chat history, secrets, or API credentials.
- IF `tokensave_*` MCP tools are unavailable, THEN the tokensave-memory-bridge skill SHALL defer to the `tokensave-first` rule fallback without writing custom persistence files.

## Behavioral Scenarios

```gherkin
Feature: Cross-Session TokenSave Memory Bridge

  @REQ-TSMB-001
  Scenario: Start session and record granular architecture decision
    Given the workspace has an initialized TokenSave memory database
    When the agent starts a session and finalizes an architectural choice
    Then tokensave_session_start returns memory_delta context
    And tokensave_record_decision stores one granular technical decision without secrets

  @REQ-TSMB-002
  Scenario: Fall back safely when TokenSave MCP tools are absent
    Given TokenSave MCP tools are unavailable in the session
    When persistent memory tracking is requested
    Then the skill follows the tokensave-first unavailability guidance without creating custom text files
```

## Black-Box Execution

- **Do not read** script source before running it; the script is a tested black box.
- Run commands from the skill base directory (the folder containing this `SKILL.md`).
- Read the source only after a non-zero exit that stderr does not explain.

| Command | Parameters | Stdout | Exit codes |
|---|---|---|---|
| `bash ./scripts/check-tokensave.sh "<project-dir>"` | Optional project directory, default `.` | Index status text | 0 indexed, 1 not indexed, 2 tokensave not installed |
