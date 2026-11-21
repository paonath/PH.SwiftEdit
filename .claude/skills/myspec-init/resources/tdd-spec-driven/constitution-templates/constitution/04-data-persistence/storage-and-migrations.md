---
area: "04-data-persistence"
file: "storage-and-migrations.md"
rules: ["DATA-001", "DATA-002", "DATA-003", "DATA-004"]
---

# 04-data-persistence/storage-and-migrations (DATA-001..DATA-004)

## Context
- storage_engines: `{{STORAGE_ENGINES}}`
- migration_gate: `sql-schema-planner + Human Approval`

## Rules
- **DATA-001**: Each module SHALL own an isolated database schema, table prefix, or collection namespace with zero cross-module table sharing.
- **DATA-002**: Every SQL DDL or schema migration SHALL be planned via `sql-schema-planner` and require explicit human approval before execution.
- **DATA-003**: All database queries and commands SHALL use parameterized statements or typed ORM expressions (`CWE-89`); string-concatenated SQL is forbidden.
- **DATA-004**: Every I/O repository or store call SHALL bound execution with a `CancellationToken` and explicit connection timeout.
