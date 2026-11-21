# Workflow 05: Author 6 Canonical Schema Artifacts (`myspec-tdd-spec-reasoning`)

1. Read `schema.yaml` (`.openspec/schemas/tdd-spec-driven/schema.yaml`, fallback `../myspec-init/resources/tdd-spec-driven/schema.yaml`) and the matching `templates/<template>`. Copy each template's headings **verbatim**; never rename, drop, or reorder them.
2. Author artifacts in schema dependency order (`requires`): `proposal` -> `threat-model` -> `specs` -> `design` -> `test-plan` -> `tasks`.
3. Execute the 4 progressive-disclosure authoring steps one step file at a time (`Single-Reference Lock`):
   - [01-proposal-manual](steps/01-proposal-manual.md): Author `proposal.md` and conditional `manual-steps.md`.
   - [02-delta-spec](steps/02-delta-spec.md): Author `specs/<capability>/spec.md` with EARS, BDD, reconciliation directives, and Rule G3 waivers.
   - [03-design-threat-test](steps/03-design-threat-test.md): Author `design.md`, `threat-model.md` (STRIDE), and `test-plan.md`.
   - [04-tasks-triads](steps/04-tasks-triads.md): Author `tasks.md` (`## N. Unit: <UnitName>`, `[RED]`/`[GREEN]`/`[REFACTOR]`/`[DOC]`/`[SYNC]`/`[MANUAL]`).

## Normative Requirements (EARS)
- The Artifact Authoring Coordinator SHALL load one step file at a time under Single-Reference Lock and preserve `schema.yaml` template headings verbatim.
