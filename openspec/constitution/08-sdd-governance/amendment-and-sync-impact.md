---
area: "08-sdd-governance"
file: "amendment-and-sync-impact.md"
rules: ["SDD-005", "SDD-006", "SDD-007"]
---

# 08-sdd-governance/amendment-and-sync-impact (SDD-005..SDD-007)

## Context
- versioning: `SemVer 2.0.0 (MAJOR: incompatible removal/redefinition, MINOR: new rule or area activation, PATCH: wording)`
- proposal_metadata: `- Amends-Constitution: <PREFIX>-### (MAJOR|MINOR|PATCH)`

## Rules
- **SDD-005**: Constitutional amendments SHALL declare `- Amends-Constitution: <PREFIX>-### (MAJOR|MINOR|PATCH)` under `## Metadata` in `proposal.md` with explicit human approval.
- **SDD-006**: WHEN a constitutional rule or area status changes, the author SHALL increment `version`, update `last_amended`, and append a row to `## Sync Impact Report` in `openspec/Constitution.md`.
- **SDD-007**: Areas `06-testing-fitness/`, `07-security-privacy/`, and `08-sdd-governance/` SHALL remain `status: "active"` while enforcing Scope Guard halts on any unapproved `Package.swift` dependency or `.entitlements` expansion during `myspec-apply`.
