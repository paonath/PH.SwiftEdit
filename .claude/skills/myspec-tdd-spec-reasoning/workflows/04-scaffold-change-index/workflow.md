# Workflow 04: Change ID Allocation, Index Prepend & Scaffolding (`myspec-tdd-spec-reasoning`)

1. Read `.myspec.config.json` at project root to resolve `changes` directory (default: `openspec/changes/`).
2. Determine change ID as `NNN-slug` (e.g. `025-proposal-rewrite`) using `python3 ../myspec-init/scripts/myspec_index.py --next-prefix` (taking the next sequential 3-digit prefix across `<spec_root>/index.yml`, `<changes_dir>/`, `<archive_dir>/`, and legacy `specs/`).
3. Scaffold `<changes_dir>/<change-id>/` and `<changes_dir>/<change-id>/specs/<capability>/`.
4. Prepend the new `draft` specification entry at the top of `<spec_root>/index.yml` (preserving `always_read:` and recording only minimal AI fields: `id`, `status: "draft"`, `date`, `capabilities`, `path`, `summary` <= 120 chars; NEVER write `branch` in `index.yml`).

## Normative Requirements (EARS)
- WHEN scaffolding a new change, the Change Scaffolder SHALL allocate the next `NNN-slug` prefix via `myspec_index.py --next-prefix` and prepend a `draft` entry to `<spec_root>/index.yml` without a `branch` field.
