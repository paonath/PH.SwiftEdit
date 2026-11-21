# Workflow 06: Schema Conformance Gate (`myspec-tdd-spec-reasoning` — MANDATORY, EVERY run)

1. **Artifact checklist** (against `schema.yaml` `artifacts[].generates`): `proposal.md`, `threat-model.md`, `specs/<capability>/spec.md` (>= 1), `design.md`, `test-plan.md`, `tasks.md` all exist and are non-empty; every template heading is present.
2. **Validation engine**:
   ```bash
   python3 ../myspec-validate/scripts/myspec_validate.py --change <change-id> --strict
   ```
3. **Auto-repair loop**: on any error (schema discrepancy, delta grammar, missing STRIDE category, broken triad sequence, stray checkbox, missing/unapproved Security Review verdict) fix the artifacts and re-run, up to 3 iterations.
4. **Fail-closed**: if the gate still fails after 3 iterations, do NOT declare the change ready; report remaining errors and stop. Never skip the gate, even for small changes or when started from an existing brief.
5. Present the validated change summary, path matrix, and change location to the user.

## Normative Requirements (EARS)
- WHEN all 6 artifacts are written, the Schema Validation Gate SHALL execute `myspec_validate.py --change <change-id> --strict` with up to 3 auto-repair iterations.
- IF validation errors persist after 3 auto-repair iterations, THEN the Schema Validation Gate SHALL halt fail-closed without declaring readiness.

## Behavioral Contract (BDD)
```gherkin
Feature: MySpec Schema Validation Fail-Closed Gate

  @REQ-REASON-005
  Scenario: Strict validation passes on complete schema-conformant change artifacts
    Given all six OpenSpec change artifacts authored in dependency order
    When the validation gate executes myspec_validate with strict mode enabled
    Then the change passes schema validation and displays the apply handoff guidance

  @REQ-REASON-006
  Scenario: Persistent schema errors trigger fail-closed halt after three repairs
    Given change artifacts with unresolved validation errors across three repair iterations
    When the validation gate executes the final validation pass
    Then the gate reports remaining errors and halts fail-closed without handoff approval
```

---
> [!TIP]
> **Recommended Next Step**: `/myspec-apply @<changes_dir>/<change-id>`
> **Rationale**: Validated OpenSpec change is ready for TDD implementation via `/myspec-apply`.
---
