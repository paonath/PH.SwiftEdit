# Workflow 02: Apply Naming Conventions & Data Model Rules (`sql-schema-planner`)

## Step 2 — Apply Naming Conventions

Self-validate and self-correct before generating. Consult [naming-conventions.md](../../references/naming-conventions.md) for the complete naming catalog (`PascalCase` singular tables/views, `Id` PK first, `{ReferencedTable}Id` FK, `{Table}_pk`, `{Table}_{RefTable}_Id_fk`, `IX_{Table}_{Column}`, `UX_{Table}_{Column}`, `dbo`/`public`/none schema).

- The sql-schema-planner workflow SHALL default primary keys to `varchar(128) NOT NULL` (`ASSIGNED` without `DEFAULT NEWID()` or sequences) and use `int IDENTITY`, `SERIAL`, or `AUTO_INCREMENT` only on explicit user request with a `-- Note: PK override requested` comment.
- The sql-schema-planner workflow SHALL name all date/time columns with a `Utc` suffix (`CreateDateUtc`, `UpdateDateUtc`, `DeleteDateUtc`) using `datetime2 not null` (MSSQL), `timestamp not null` (PostgreSQL), or `datetime not null` (MySQL/MariaDB), using `LocalTime` only when the user explicitly requests local time.
- The sql-schema-planner workflow SHALL mark columns `NOT NULL` by default and add `null` only when the user marks a field optional.
- WHEN generating the first table in any DDL script, the sql-schema-planner workflow SHALL prepend `-- PK is application-assigned (varchar 128, GUID-compatible)`.
- IF a naming convention check fails during validation, THEN the sql-schema-planner workflow SHALL self-correct silently and note the change with a `-- Note:` SQL comment.
