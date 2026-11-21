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
- **SDD-001**: WHILE `openspec/Constitution.md` exists, all 6 OpenSpec change artifacts (`proposal.md`, `design.md`, `spec.md`, `tasks.md`, `test-plan.md`, `threat-model.md`) SHALL cite governing active `[<PREFIX>-###]` rule IDs.
- **SDD-002**: Every `[RED]`, `[GREEN]`, and `[REFACTOR]` task in `tasks.md` SHALL cite its governing constitutional rule and micro-file using `[Const: <PREFIX>-### (<NN-area>/<file>.md)]`.
- **SDD-003**: Every `tasks.md` plan SHALL sequence structural `Package.swift` target, dependency, `Assets.xcassets` (`AppIcon.appiconset`), and `.entitlements` setup tasks before behavioral `[RED] -> [GREEN] -> [REFACTOR]` triads while enforcing `Single-Reference Lock` (at most 1 Level-2 micro-file per active step).
- **SDD-004**: Constitutional files SHALL contain zero conversational preambles, zero blockquotes (`>`), zero `## Purpose` sections, and strictly single-line `- **<ID>**:` atomic EARS rules.
