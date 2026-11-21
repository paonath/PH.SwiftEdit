# Workflow 03: Generate DDL, Format Output & Suggestions (`sql-schema-planner`)

## Step 3 — Generate and Validate SQL

Generate DDL for the target server using the Server Syntax Matrix ([server-syntax-matrix.md](../../references/server-syntax-matrix.md)) and reference examples ([example-mssql-library.md](../../examples/example-mssql-library.md), [example-postgres-library.md](../../examples/example-postgres-library.md)):

- WHERE the target server is SQL Server, the sql-schema-planner workflow SHALL emit `GO` batch separators after each statement and use `sp_addextendedproperty` for junction table column descriptions.
- WHERE the target server is PostgreSQL, the sql-schema-planner workflow SHALL omit `GO` separators, emit `COMMENT ON COLUMN` descriptions, and use `text` instead of `varchar(max)`.
- WHERE the target server is MySQL or MariaDB, the sql-schema-planner workflow SHALL omit `GO` separators, use inline `COMMENT 'text'` on column definitions, use `text` instead of `varchar(max)`, and use `tinyint(1)` for booleans.

### Inline Comments Policy

- The sql-schema-planner workflow SHALL add `--` comments only when column purpose is non-obvious and describe all FK columns in junction tables while omitting redundant comments such as `-- Primary key` on `Id`.

## Output Format

### Default — Markdown with embedded DDL

````markdown
## Schema: [EntityName(s)]

**Server**: SQL Server 2016 Express | **Strategy**: ASSIGNED PKs

```sql
-- [table DDL here]
```

> 💡 Suggestions
> - FieldName (type) — reason
````

### On explicit `.sql` request

Plain `.sql` file containing DDL only, with a file-header comment block:
```sql
-- Schema: [EntityName(s)]
-- Server: [target]
-- Generated: [date]
-- PK strategy: ASSIGNED (application-assigned varchar(128))
```

## Suggestions Policy

- The sql-schema-planner workflow SHALL omit unrequested fields from generated DDL.
- WHEN useful omitted fields exist, the sql-schema-planner workflow SHALL end output with a `> 💡 Suggestions` blockquote (`FieldName (type) — reason`, maximum 5 items).
