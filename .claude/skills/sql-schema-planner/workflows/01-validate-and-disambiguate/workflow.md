# Workflow 01: Validate Input & Disambiguate (`sql-schema-planner`)

## Step 1 — Validate Input

Before generating any output, verify scope, server, entities, relationships, and columns:

1. IF a request asks for `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `ALTER TABLE`, or stored procedure business logic, THEN the sql-schema-planner workflow SHALL decline and redirect immediately.
2. WHERE the target database server is unspecified, the sql-schema-planner workflow SHALL default to **SQL Server 2016 Express** and state the assumption in output.
3. IF entity names are non-English, foreign key relationships are unclear, or required columns cannot be inferred from entity purpose, THEN the sql-schema-planner workflow SHALL start a `qa` checklist using `the qa skill`.
4. WHILE disambiguating schema requirements, the sql-schema-planner workflow SHALL enforce a maximum of **3 clarification iterations** (via `the qa skill`) before proceeding with documented assumptions.
