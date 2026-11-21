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
- **SDD-008**: WHEN `myspec-init` runs where `<spec_root>/Constitution.md` is absent, it SHALL propose creation and, if accepted, launch `guided-reasoning-flow --constitution-bootstrap`.
- **SDD-009**: WHILE executing `myspec-apply` or `myspec-verify`, agents SHALL load the task's cited micro-file and verify code and test compliance before checking `[x]`.
- **SDD-010**: Before `myspec-sync` or `myspec-archive` completes, `myspec_validate.py` SHALL verify 0 constitutional violations, 100% citation parity, and `Sync Impact Report` sync.
