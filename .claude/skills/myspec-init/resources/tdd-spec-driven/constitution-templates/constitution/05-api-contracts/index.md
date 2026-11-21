---
area: "05-api-contracts"
prefix: "API"
status: "{{STATUS_API}}"
owners: ["dotnet-expert", "angular-expert", "python-expert", "cyber-security-expert"]
---

# API Contracts, DTO Boundaries & Integration Mini-Index (`05-api-contracts/`)

## Micro-Files

| Micro-File | Rule IDs | Scope & Inspection Triggers |
| :--- | :--- | :--- |
| `endpoints-and-versioning.md` | `API-001..API-004` | Versioned endpoint groups, input validation pipeline, immutable DTO `ToDto`/`ToEntity` outside Domain, `ProblemDetails` |
| `integration-and-events.md` | `API-005..API-008` | Anti-Corruption Layer (`ACL`), backward-compatible contract evolution, W3C `traceparent`/`CorrelationId` propagation |
