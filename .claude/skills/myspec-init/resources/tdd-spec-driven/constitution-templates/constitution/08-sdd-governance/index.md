---
area: "08-sdd-governance"
prefix: "SDD"
status: "active"
owners: ["spec-sdlc-expert", "qa-agent"]
---

# Spec-Driven Development (SDD) & Amendment Governance Mini-Index (`08-sdd-governance/`)

## Micro-Files

| Micro-File | Rule IDs | Scope & Inspection Triggers |
| :--- | :--- | :--- |
| `artifact-traceability.md` | `SDD-001..SDD-004` | 6-artifact OpenSpec contract chain, `<PREFIX>-###` citation, structural tasks before behavioral tasks |
| `amendment-and-sync-impact.md` | `SDD-005..SDD-007` | SemVer (`MAJOR.MINOR.PATCH`) amendments, `Sync Impact Report` audit trail, Scope Guard during `myspec-apply` |
| `convergence-and-gates.md` | `SDD-008..SDD-010` | `[NEEDS CLARIFICATION]` quarantine, one-way `Spec > Code` `--converge` gate, living spec & `index.yml` sync |
