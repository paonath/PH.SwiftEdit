---
name: move-to-second-brain
description: "Moves selected reasoning/[NNN]_[slug]/ sessions or arbitrary repository notes verbatim into the Git-backed Obsidian SecondBrain vault with SHA-256 verification, prefix continuity in reasoning/.second-brain-state.json, Hub MOC updates, and scoped dual Git commits. Triggers: move-to-second-brain, second brain, move reasoning, sposta reasoning, archivia nel second brain."
user-invocable: true
argument-hint: "[--session <id> | --status <status> | --all | --source <path>]"
---

# Move To Second Brain (`move-to-second-brain`)

## Purpose and Scope

- The move-to-second-brain skill SHALL move selected `reasoning/[NNN]_[slug]/` workspaces or arbitrary `--source` paths into the Obsidian SecondBrain vault (`50-Projects/<ProjectName>/`).
- The move-to-second-brain skill SHALL verify `SHA-256` checksums before deleting any local file without secret scanning or redaction.
- The move-to-second-brain skill SHALL persist monotonic `[NNN]` numbering in `reasoning/.second-brain-state.json` so `the guided-reasoning-flow skill` continues without prefix resets.

## Interactive Disambiguation Workflow

1. IF the user omits `--session`, `--status`, `--all`, and `--source`, THEN the move-to-second-brain skill SHALL list existing `reasoning/[NNN]_[slug]/` sessions (`plan.md` `status`) and prompt via `AskUserQuestion` (`the qa skill`).
2. WHERE `--all`, `--source`, or `--overwrite` is requested, the move-to-second-brain skill SHALL execute `move_reasoning_to_second_brain.py --dry-run --json` before mutating files.
3. The move-to-second-brain skill SHALL execute `move_reasoning_to_second_brain.py` targeting `50-Projects/<ProjectName>/reasoning/<session>/` or `notes/<name>` (`--dest-folder` override) while excluding `.git`, `bin`, `obj`, `node_modules`, `__pycache__`, and `.DS_Store`.
4. WHEN a move completes, the move-to-second-brain skill SHALL verify `50-Projects/<ProjectName>.md` Hub MOC links and scoped Git commits (unless `--no-vault-commit` or `--no-repo-commit` is set).

## Security and Confinement Invariants

- IF a source segment, destination segment, or `reasoning/.second-brain-state.json` contains `..` traversal (`CWE-22`) or symbolic links (`CWE-59`), THEN the move-to-second-brain skill SHALL exit with code 2.
- IF `--source` targets `.git`, `.agents`, `.claude`, `openspec/Constitution.md`, `specs/Constitution.md`, or `.myspec.config.json` without `--force`, THEN the move-to-second-brain skill SHALL exit with code 2 (`.git` remains unconditionally blocked).
- IF destination `SHA-256` differs without `--overwrite`, THEN the move-to-second-brain skill SHALL abort with exit code 1 without deleting any local file.
- The move-to-second-brain skill SHALL invoke all Git commands via `subprocess.run(..., shell=False)` with `--` pathspec separators (`CWE-78`).

## Behavioral Scenarios

```gherkin
Feature: Verbatim Move to SecondBrain Vault
  @REQ-MSB-001
  Scenario: Move completed reasoning session with SHA-256 verification
    Given a completed reasoning session and a valid SecondBrain vault path
    When the user moves the session by identifier
    Then the vault stores byte-identical copies and updates the prefix state file

  @REQ-MSB-002
  Scenario: Reject path traversal in source or destination segments
    Given a move request containing a parent directory traversal segment
    When the move engine validates path segments
    Then the move engine exits with code 2 without modifying files
```

## Black-Box Execution

- **Do not read** script source before running it; the scripts are tested black boxes.
- Run commands from the skill base directory with `--repo-root "<dir>"`, or from repository root when `cwd` is the project root.
- Read script source only after a non-zero exit code that stderr does not explain.

| Command | Parameters | Stdout | Exit codes |
|---|---|---|---|
| `python3 ./scripts/move_reasoning_to_second_brain.py` | `--session "<id>" [--session "<id>"] [--repo-root "<dir>"] [--vault-path "<dir>"] [--dry-run] [--json]` | Move summary or JSON MoveReport | `0` OK, `1` hash/collision, `2` arg/security |
| `python3 ./scripts/move_reasoning_to_second_brain.py` | `--status "<status>" [--repo-root "<dir>"] [--vault-path "<dir>"] [--dry-run] [--json]` | Filtered session move summary or JSON | `0` OK, `1` hash/collision, `2` arg/security |
| `python3 ./scripts/move_reasoning_to_second_brain.py` | `--all [--no-vault-commit] [--no-repo-commit] [--overwrite] [--repo-root "<dir>"] [--dry-run] [--json]` | Full reasoning move summary or JSON | `0` OK, `1` hash/collision, `2` arg/security |
| `python3 ./scripts/move_reasoning_to_second_brain.py` | `--source "<rel_path>" [--dest-folder "<vault_rel>"] [--force] [--overwrite] [--repo-root "<dir>"] [--dry-run] [--json]` | Arbitrary path move summary or JSON | `0` OK, `1` hash/collision, `2` arg/security |
