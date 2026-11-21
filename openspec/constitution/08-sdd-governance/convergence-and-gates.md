---
area: "08-sdd-governance"
file: "convergence-and-gates.md"
rules: ["SDD-008", "SDD-009", "SDD-010"]
---

# 08-sdd-governance/convergence-and-gates (SDD-008..SDD-010)

## Context
- validator_cli: `myspec_validate.py --validate-constitution`
- bootstrap_flow: `myspec-init -> guided-reasoning-flow (--constitution-bootstrap)`

## Rules
- **SDD-008**: IF any OpenSpec change artifact contains an unresolved `[NEEDS CLARIFICATION]` marker, THEN `myspec-validate` and `myspec-apply` SHALL quarantine the change and block implementation until resolved.
- **SDD-009**: WHILE executing `myspec-apply`, `myspec-verify`, or `--converge`, agents SHALL load each task's cited micro-file and enforce one-way `Spec > Code` authority before checking `[x]`.
- **SDD-010**: Before `myspec-sync` or `myspec-archive` completes, `myspec_validate.py` SHALL verify zero constitutional violations, 100% citation parity, living-spec delta merge, and `openspec/index.yml` synchronization.
