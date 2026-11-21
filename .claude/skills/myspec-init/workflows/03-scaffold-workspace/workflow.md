# Workflow 03: Scaffolding Execution & CLI Options (`myspec-init`)

## Scaffolding Execution

- Execute initialization command with chosen specification root:
  ```bash
  python3 ./scripts/myspec_init.py --target <dir> --spec-root <chosen_root> [--pure-python] [--force] [--json]
  ```
- Scaffolding behavior for `spec_root == "openspec"`:
  - Scaffolds `openspec/` containing `changes/`, `specs/`, `briefs/`, `agents/`, and `debug/`.
  - Writes `openspec/config.yaml` specifying `schema: tdd-spec-driven`.
  - Scaffolds `openspec/index.yml` (AI-oriented YAML index with `always_read: []` and `specs: []`).
- Scaffolding behavior for `spec_root == "specs"`:
  - Scaffolds `specs/` containing `changes/`, `implemented/`, `briefs/`, `agents/`, and `debug/`.
  - Scaffolds `specs/index.yml` (AI-oriented YAML index with `always_read: []` and `specs: []`).
  - Scaffolds `openspec/` containing `config.yaml` and schema directories.
- Injects master `tdd-spec-driven` schema and templates into `.openspec/schemas/tdd-spec-driven/`.
- Injects `.myspec.config.json` specifying `{"spec_root": "<chosen_root>"}`.
- Injects security exclusion rules into `.gitignore` (`openspec/debug/**`, `specs/debug/**`, `**/*.har`, `openspec/**/.env*`, `specs/**/.env*`, `.tmp/`).

## CLI Options

- `--target`, `-t`: Target repository directory to initialize (default: current directory).
- `--spec-root`: Specification root folder: `openspec` (default) or `specs` (compatibility layer).
- `--pure-python`: Enforces pure Python standard library scaffolding without external CLI.
- `--force`, `-f`: Overwrites and refreshes master schema definitions and configuration.
- `--scaffold-constitution`: Opt-in scaffolding of the 30-file Bare-Bones `<spec_root>/Constitution.md` + `<spec_root>/constitution/**` skeleton (invoked after user accepts the `AskUserQuestion` proposal).
- `--set KEY=VALUE`: Repeatable placeholder override for `--scaffold-constitution` (validated against `CWE-77`).
- `--json`: Emits machine-readable JSON status output.

## Normative Requirements (EARS)
- WHEN the specification root is confirmed, the Workspace Scaffolder SHALL invoke `myspec_init.py` to inject `tdd-spec-driven` templates, `.myspec.config.json`, and `index.yml`.
- The Workspace Scaffolder SHALL append security exclusion entries to `.gitignore` idempotently without duplicating existing lines.

## Behavioral Contract (BDD)
```gherkin
Feature: MySpec Init Workspace Scaffolding

  @REQ-INIT-002
  Scenario: Idempotent workspace scaffolding preserves existing user changes
    Given a target directory with existing user specification changes
    When the initializer scaffolds the workspace without force override
    Then the initializer injects schema templates and gitignore rules while preserving user files

  @REQ-INIT-003
  Scenario: Reject target path traversal during scaffolding
    Given a target directory argument containing parent directory traversal segments
    When the initializer validates the target path
    Then the initializer rejects the path with an error before writing files
```
