---
area: "04-data-persistence"
prefix: "DATA"
status: "{{STATUS_DATA}}"
owners: ["dotnet-expert", "python-expert", "cyber-security-expert"]
---

# Data Persistence, Migrations & CQRS Mini-Index (`04-data-persistence/`)

## Micro-Files

| Micro-File | Rule IDs | Scope & Inspection Triggers |
| :--- | :--- | :--- |
| `storage-and-migrations.md` | `DATA-001..DATA-004` | Human-gated DDL via `sql-schema-planner`, per-module table/collection isolation, persistence ignorance, `CWE-89` safety |
| `write-read-separation.md` | `DATA-005..DATA-008` | Single-aggregate write transactions, read-only query projections, idempotent event/outbox handlers, `CancellationToken` |
