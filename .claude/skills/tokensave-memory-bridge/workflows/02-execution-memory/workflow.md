# Workflow 02: Execution Memory & Decision Recording (`tokensave-memory-bridge`)

## Procedure — Execution Phase

- WHEN modifying an unfamiliar module, the execution-memory workflow SHALL invoke `tokensave_session_recall` with module or symbol names and notify the user before proceeding if prior decisions conflict.
- WHEN a technical choice is agreed (`decision`, `reason`, `files`, `tags`), the execution-memory workflow SHALL call `tokensave_record_decision` immediately with one granular decision per invocation.
- WHEN non-trivial work completes on a module or directory path, the execution-memory workflow SHALL invoke `tokensave_record_code_area`.

## Decision Recording Guidelines

- **Record**: Architecture decisions, explicit trade-offs, design patterns, project conventions, technical constraints discovered during debugging, and security policies.
- **Do Not Record**: Trivial implementation details, formatting refactorings, generic TODOs (use backlog issues instead), secrets/credentials, or personal user data.
- The execution-memory workflow SHALL keep each `tokensave_record_decision` call scoped to one decision to preserve FTS5 search precision.
