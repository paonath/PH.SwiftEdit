---
area: "08-sdd-governance"
file: "artifact-traceability.md"
rules: ["SDD-001", "SDD-002", "SDD-003", "SDD-004"]
---

# 08-sdd-governance/artifact-traceability (SDD-001..SDD-004)

## Context
- openspec_artifacts: `proposal.md, design.md, specs/<cap>/spec.md, tasks.md, test-plan.md, threat-model.md`
- lock_mode: `Single-Reference Lock (Root + 1 Area Index + 1 Micro-File)`

## Rules
- **SDD-001**: WHILE `<spec_root>/Constitution.md` exists, all 6 OpenSpec artifacts (`proposal.md`, `design.md`, `spec.md`, `tasks.md`, `test-plan.md`, `threat-model.md`) SHALL cite active `[<PREFIX>-###]` rule IDs.
- **SDD-002**: Every `[RED]`, `[GREEN]`, and `[REFACTOR]` task in `tasks.md` SHALL cite its governing rule and micro-file (`[Const: <PREFIX>-### (<NN-area>/<file>.md)]`).
- **SDD-003**: Agents in `myspec-*` and `guided-reasoning-flow` SHALL enforce `Single-Reference Lock` by loading at most 1 Level-2 micro-file per active task or topic.
- **SDD-004**: Constitution files SHALL contain zero preambles, zero blockquotes (`>`), zero `## Purpose` sections, and strictly single-line `- **<ID>**: ... SHALL ...` rules.
