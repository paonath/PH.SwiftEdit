# Workflow 05: Verification and Next Steps (`myspec-init`)

## Verification

- Verify `.myspec.config.json` and `.openspec/schemas/tdd-spec-driven/schema.yaml` exist.
- Report initialized layout and configured specification root to user.
- Recommend next steps based on configured workspace:
  - Suggest `/myspec-tdd-spec-reasoning` to author a new specification.
  - Suggest `/myspec-backfill` if legacy specifications exist in `specs/` to migrate.
  - Suggest `/myspec-status` to inspect workspace health.

## Validation Checklist

- [ ] Target directory inspected for existing `openspec/` or `specs/` trees.
- [ ] User asked via `qa` skill (`AskUserQuestion`) unless `--spec-root` explicitly provided.
- [ ] Schema `tdd-spec-driven` injected into `.openspec/schemas/tdd-spec-driven/`.
- [ ] `.myspec.config.json` created with chosen `spec_root`.
- [ ] Security exclusion rules present in `.gitignore`.

## Normative Requirements (EARS)
- WHEN scaffolding finishes, the Verification Handoff SHALL confirm `.myspec.config.json` and `schema.yaml` exist before recommending `/myspec-tdd-spec-reasoning` or `/myspec-status`.
