---
area: "08-sdd-governance"
file: "amendment-and-sync-impact.md"
rules: ["SDD-005", "SDD-006", "SDD-007"]
---

# 08-sdd-governance/amendment-and-sync-impact (SDD-005..SDD-007)

## Context
- versioning: `SemVer 2.0.0 (MAJOR: incompatible removal/redefinition, MINOR: new rule, PATCH: wording)`
- proposal_metadata: `- Amends-Constitution: <PREFIX>-### (MAJOR|MINOR|PATCH)`

## Rules
- **SDD-005**: Constitutional amendments SHALL declare `- Amends-Constitution: <PREFIX>-### (MAJOR|MINOR|PATCH)` under `## Metadata` in `proposal.md` with human approval.
- **SDD-006**: WHEN a constitutional rule is added or amended, `<spec_root>/Constitution.md` SHALL bump `version`, update `last_amended`, and record the row in `## Sync Impact Report`.
- **SDD-007**: Areas `06-testing-fitness/`, `07-security-privacy/`, and `08-sdd-governance/` SHALL remain `status: active` in all projects (`Rule G3` floor).
