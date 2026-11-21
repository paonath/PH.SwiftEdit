---
area: "06-testing-fitness"
prefix: "TEST"
status: "active"
owners: ["dotnet-expert", "angular-expert", "python-expert", "shell-expert", "test-quality-auditor"]
---

# Testing Discipline & Architecture Fitness Mini-Index (`06-testing-fitness/`)

## Micro-Files

| Micro-File | Rule IDs | Scope & Inspection Triggers |
| :--- | :--- | :--- |
| `tdd-and-unit-testing.md` | `TEST-001..TEST-004` | `[RED]->[GREEN]->[REFACTOR]` triads, linear AAA without branching, mock-free domain tests, bugfix repro test |
| `architecture-fitness-and-quality.md` | `TEST-005..TEST-008` | Automated fitness tests (`typeof(TMarker).Assembly`), CRAP score `<= 30`, property-based & mutation testing |
