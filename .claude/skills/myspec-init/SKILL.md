---
name: "myspec-init"
description: "Scaffolds specification workspace, prompts for openspec or specs compatibility layer via qa, injects custom tdd-spec-driven schema, and updates .gitignore."
---

# MySpec Init (`myspec-init` — Progressive Disclosure Router)

## Scope & Directives

- Scaffolds specification workspace (`openspec/` or `specs/` compatibility layer), injects the `tdd-spec-driven` schema into `.openspec/schemas/tdd-spec-driven/`, writes `.myspec.config.json`, and updates `.gitignore` security exclusions.
- Enforces `Single-Reference Lock`: load one `workflows/NN-*/workflow.md` at a time.
- Uses `the qa skill` (`AskUserQuestion`, 1 question/turn) when `--spec-root` is not provided and proposes opt-in Bare-Bones Constitution creation (`--scaffold-constitution` + `the guided-reasoning-flow skill` `--constitution-bootstrap`) when `<spec_root>/Constitution.md` is absent.

## Workflow Routing Table

Execute each phase's `workflow.md` sequentially (one workflow file in context at a time):

| Phase | Workflow | Scope |
|---|---|---|
| **01** | [01-workspace-inspection](workflows/01-workspace-inspection/workflow.md) | Inspect `--target`, `.myspec.config.json`, and count existing `openspec/` vs `specs/` markdown docs. |
| **02** | [02-select-spec-root](workflows/02-select-spec-root/workflow.md) | `--spec-root` bypass or 1-question `AskUserQuestion` root selection with `(Recommended)` guidance. |
| **03** | [03-scaffold-workspace](workflows/03-scaffold-workspace/workflow.md) | Run `myspec_init.py`, scaffold folders/schema/`index.yml`, write `.myspec.config.json`, update `.gitignore`. |
| **04** | [04-constitution-bootstrap](workflows/04-constitution-bootstrap/workflow.md) | Opt-in `Constitution.md` proposal (`--scaffold-constitution` + `guided-reasoning-flow --constitution-bootstrap`). |
| **05** | [05-verify-and-handoff](workflows/05-verify-and-handoff/workflow.md) | Verify generated files against checklist and recommend `/myspec-tdd-spec-reasoning`, `/myspec-backfill`, `/myspec-status`. |

## Normative Requirements (EARS)

- The MySpec Init Router SHALL load one workflow file at a time under Single-Reference Lock.
- WHEN `--spec-root` is omitted, the MySpec Init Router SHALL invoke `AskUserQuestion` via `the qa skill` with one question per turn to choose `openspec` or `specs`.
- WHERE `<spec_root>/Constitution.md` does not exist, the MySpec Init Router SHALL propose opt-in Bare-Bones Constitution creation via `--scaffold-constitution` and `--constitution-bootstrap`.
- IF the target path contains traversal segments or fails directory creation, THEN the MySpec Init CLI SHALL abort with a non-zero exit code.

## Black-Box Execution

- **Do not read** script source before running it; the scripts are tested black boxes.
- Run commands from the skill base directory (the folder containing this `SKILL.md`).
- Run the script with `--help` for options not listed below.
- Read the source only after a non-zero exit that stderr does not explain.

| Command | Parameters | Stdout | Exit codes |
|---|---|---|---|
| `python3 ./scripts/myspec_init.py --target "<dir>"` | `--target`, `--spec-root` (openspec or specs), `--pure-python`, `--force`, `--json` optional | Text or JSON with `--json` | 0 success, non-zero error (stderr explains) |
| `python3 ./scripts/myspec_index.py --next-prefix` | `--target`, `--init`, `--backfill`, `--validate`, `--next-prefix`, `--json` optional | Text or JSON with `--json` | 0 success |
| `python3 ./scripts/myspec_legacy_ingest.py --list` | `--repo`, `--list`, `--spec`, `--archive`, `--capability`, `--json` optional | Text or JSON with `--json` | 0 success |

| Module | Import | Public API | Notes |
|---|---|---|---|
| `myspec_config` | Load from `scripts/` of this skill | `MySpecConfigManager.get_instance`, `get_spec_root`, `get_specs_dir`, `get_changes_dir`, `get_archive_dir`, `get_briefs_dir`, `get_index_file`, `init_config`; `get_config` | Library, not a CLI; never run directly |
