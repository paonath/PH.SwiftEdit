---
name: "sql-database-security"
description: "SQL and database security reference aligned with sql-schema-planner covering 1st/2nd-order SQLi (CWE-89), ORM raw query sinks (CWE-564), dynamic T-SQL, RLS, and DB privilege hardening."
---

# SQL and Database Security Reference

## Scope and `sql-schema-planner` Alignment

- Evaluate SQL DDL/DML scripts, database migrations, stored procedures, views, functions, and ORM persistence layers (EF Core, Dapper, ADO.NET).
- Align all schema and stored-procedure reviews with the `sql-schema-planner` skill conventions (`tb_`/`vw_`/`usp_` naming, explicit types, constraints, and least-privilege execution contexts).
- Partition ORM audits with `code-security`: `code-security` audits application DTOs and validators, while `sql-database-security` audits query construction, raw SQL sinks, database objects, and execution permissions.

## SQL Injection and ORM Sink Audit Matrix

| Vector | CWE ID | Vulnerable Pattern | Mandatory Secure Pattern |
| :--- | :--- | :--- | :--- |
| EF Core Raw SQL Sinks | `CWE-564`, `CWE-89` | `FromSqlRaw($"SELECT * FROM Users WHERE Name = '{name}'")` or `ExecuteSqlRaw("..." + input)` | Use `FromSql` / `FromSqlInterpolated` / `ExecuteSqlInterpolated` (FormattableString parameterization) or explicit `SqlParameter` |
| Dapper / ADO.NET Interpolation | `CWE-89` | `connection.QueryAsync($"SELECT ... WHERE Id = {id}")` or `SqlCommand` string concatenation | Pass anonymous parameter object `new { Id = id }` or typed `DynamicParameters` with explicit `DbType` and `size` |
| Dynamic `ORDER BY` / Column / Table Names | `CWE-89` | Concatenating `sortBy` or `tableName` directly into SQL because identifiers cannot be bound as `@params` | Validate identifier against a strict C# enum/dictionary allowlist or `sys.columns` metadata check, AND wrap in `QUOTENAME(@col)` |
| Stored Procedure Dynamic SQL | `CWE-89` | `EXEC('SELECT * FROM dbo.Orders WHERE Code = ''' + @code + '''')` or `EXEC(@sql)` with concatenated strings | Use `EXEC sys.sp_executesql @stmt = N'...', @params = N'@code NVARCHAR(50)', @code = @code` |
| Second-Order SQL Injection | `CWE-89` | Storing parameterized user input in a table and later concatenating that column value inside a stored procedure or batch job `EXEC(@sql)` | Treat database-stored strings as untrusted inside every downstream T-SQL procedure; parameterize with `sp_executesql` or `QUOTENAME` |
| `LIKE` Wildcard Injection & DoS | `CWE-89`, `CWE-400` | Unescaped `%`, `_`, `[` in user search terms causing full-table regex scans or predicate bypass | Escape `[`, `%`, `_` (`REPLACE`) and specify an explicit `ESCAPE '\'` clause with minimum search length |
| SQL Truncation & Collation Smuggling | `CWE-130`, `CWE-176` | Implicit silent truncation (`ANSI_WARNINGS OFF` or mismatched `VARCHAR(N)`) and homograph bypass across case/accent-insensitive collations | Match `NVARCHAR(N)` lengths across DTO validator (`MaximumLength`), parameter `size`, and column definition; enforce `ANSI_WARNINGS ON` |

## Database Engine & Schema Hardening Checklist

| Control Area | Vulnerable Configuration | Required Hardening Standard |
| :--- | :--- | :--- |
| Stored Procedure Context (`WITH EXECUTE AS`) | `WITH EXECUTE AS OWNER` combined with dynamic SQL (`EXEC`), granting caller full schema owner privileges | Default to `WITH EXECUTE AS CALLER`; if `EXECUTE AS` is required, prohibit dynamic SQL or validate every identifier via `QUOTENAME` + `sys.columns` |
| Row-Level Security (`RLS`) & Multi-Tenancy | Application-only `.Where(x => x.TenantId == tenantId)` without database enforcement or missing `WITH SCHEMABINDING` | Enforce EF Core Global Query Filters AND database `CREATE SECURITY POLICY` with `FILTER PREDICATE` and `BLOCK PREDICATE` bound to `SESSION_CONTEXT(N'TenantId')` |
| Dangerous Extended Procedures | Enabled `xp_cmdshell`, `Ole Automation Procedures`, `Ad Hoc Distributed Queries` (`OPENROWSET` / `OPENDATASOURCE`), or untrusted `CLR` assemblies | Keep `xp_cmdshell`, `Ole Automation Procedures`, and ad-hoc `OPENROWSET` disabled (`0`); require signed assemblies with `PERMISSION_SET = SAFE` |
| Connection Identity & Least Privilege | Application connecting as `sa`, `db_owner`, or `postgres` superuser at runtime | Separate migration identity (DDL privileges in CI/CD) from runtime identity (`db_datareader`, `db_datawriter`, and `EXECUTE` on specific schemas) |

## Secure Dynamic T-SQL Reference Pattern

```sql
CREATE OR ALTER PROCEDURE dbo.usp_SearchCustomers
    @SearchTerm NVARCHAR(100),
    @SortColumn SYSNAME = N'CreatedAt'
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.Customers')
          AND name = @SortColumn
          AND name IN (N'CreatedAt', N'CompanyName', N'CustomerCode')
    )
    BEGIN
        THROW 50001, 'Invalid sort column.', 1;
    END;

    DECLARE @SafeSort NVARCHAR(258) = QUOTENAME(@SortColumn);
    DECLARE @Sql NVARCHAR(MAX) = N'
        SELECT CustomerId, CustomerCode, CompanyName, CreatedAt
        FROM dbo.Customers
        WHERE CompanyName LIKE @Pattern ESCAPE N''\''
        ORDER BY ' + @SafeSort + N' DESC;';

    DECLARE @EscapedPattern NVARCHAR(110) =
        REPLACE(REPLACE(REPLACE(@SearchTerm, N'\', N'\\'), N'%', N'\%'), N'_', N'\_') + N'%';

    EXEC sys.sp_executesql
        @stmt = @Sql,
        @params = N'@Pattern NVARCHAR(110)',
        @Pattern = @EscapedPattern;
END;
```

## Cross-Domain Cascade Signals

- Emit `cascades_to: ["data-security"]` when sensitive or PII columns lack encryption (`Always Encrypted` / `TDE`) or least-privilege role separation.
- Emit `cascades_to: ["gdpr-compliance"]` when schema tables store personal data without retention/erasure foreign-key cascade or crypto-shredding support.
- Emit `cascades_to: ["security-testing-tdd"]` with negative payload contracts (`' OR 1=1 --`, `; DROP TABLE`, invalid `sortBy` column) for every SQL sink.

## Verification Checklist

- [X] Zero string concatenation or interpolation inside `FromSqlRaw`, `ExecuteSqlRaw`, Dapper, or `SqlCommand`
- [X] All dynamic T-SQL uses `sys.sp_executesql` with typed `@params`
- [X] All dynamic identifiers validated against an explicit allowlist/`sys.columns` and wrapped in `QUOTENAME()`
- [X] Second-order SQLi checked across all stored procedures reading persisted user strings
- [X] Runtime database user restricted from DDL, `db_owner`, `xp_cmdshell`, and `OPENROWSET`
