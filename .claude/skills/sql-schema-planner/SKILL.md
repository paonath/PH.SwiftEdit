---
name: sql-schema-planner
description: |
  Plan and generate SQL DDL scripts for new schema objects (tables, views, stored procedures)
  following project naming conventions. Use when: (1) a user needs to design or plan new
  database tables or entities, (2) a user asks to model a new SQL schema, (3) another skill
  needs database planning support. DO NOT USE for queries, SELECT statements, reporting SQL,
  or any DML (INSERT/UPDATE/DELETE).
---

# SQL Schema Planner (`sql-schema-planner` — Progressive Disclosure Router)

Plans and generates static SQL DDL (`CREATE TABLE`, `CREATE INDEX`, `CREATE VIEW`, `CREATE PROCEDURE` skeletons, `CREATE DATABASE`) following project naming conventions.
Enforces `Single-Reference Lock`: load one `workflows/NN-*/workflow.md` phase file (and at most one `references/*.md` or `examples/*.md` file) at a time.

## Critical Rules (Hard Boundaries)

1. **Planning Only**:
   - The sql-schema-planner skill SHALL design static DDL for new tables, views, indexes, databases, and stored procedure skeletons (`/* TODO: implement logic */` only).
   - IF a user requests `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `ALTER TABLE`, or reporting queries, THEN the sql-schema-planner skill SHALL decline and explain the DDL scope boundary.
2. **Never Execute SQL**:
   - The sql-schema-planner skill SHALL emit static Markdown or `.sql` output without connecting to a database or executing SQL commands.

## Skill-to-Skill Interface

Accepts `Tables`, `Server` (`sql-server` default | `postgresql` | `mariadb` | `mysql`), `Output` (`markdown` default | `sql`), `Schema` (`dbo` / `public`), and `Relationships` from peer skills (`dotnet-architect`, `myspec-pipeline`).

## Workflow Routing Table

Execute the 3 steps sequentially (one workflow file in context at a time):

| Phase | Workflow / Reference | Scope |
|---|---|---|
| **01** | [01-validate-and-disambiguate](workflows/01-validate-and-disambiguate/workflow.md) | Step 1: Hard scope boundary check, target server selection (default SQL Server 2016 Express), max-3-iteration `qa` disambiguation. |
| **02** | [02-apply-naming-and-model](workflows/02-apply-naming-and-model/workflow.md) | Step 2: `ASSIGNED` `varchar(128)` PKs, `Utc` temporal suffix, `-- Note:` self-correction ([naming-conventions.md](references/naming-conventions.md)). |
| **03** | [03-generate-ddl-and-format](workflows/03-generate-ddl-and-format/workflow.md) | Step 3: Dialect DDL generation ([server-syntax-matrix.md](references/server-syntax-matrix.md)), Markdown/`.sql` templates, `Suggestions Policy`. |
| **Ex** | [example-mssql-library.md](examples/example-mssql-library.md) · [example-postgres-library.md](examples/example-postgres-library.md) | Reference DDL examples for SQL Server 2016 and PostgreSQL 12. |

## Behavioral Scenarios

```gherkin
Feature: SQL Schema Planner DDL Governance
  @REQ-SQL-001
  Scenario: New entity planning generates dialect-compliant static DDL
    Given a request to model a new Book entity with default server settings
    When the sql-schema-planner executes workflows 01 through 03 sequentially
    Then static CREATE TABLE DDL is emitted with application-assigned varchar(128) PK and Utc timestamps

  @REQ-SQL-002
  Scenario: DML or reporting query requests are declined without database execution
    Given a request asks for SELECT reporting queries or INSERT DML statements
    When the sql-schema-planner validates the input scope
    Then the planner declines the request, explains the DDL boundary, and executes zero SQL commands
```
