# Step 01: Semantic Graph Probe (`tokensave`)

## Actions
1. Check semantic graph health and freshness via `tokensave_status`.
2. Execute targeted queries based on the trigger prompt keywords:
   - `tokensave_context` to inspect relevant modules and domain boundaries.
   - `tokensave_files` to locate architectural components, configurations, and test suites.
   - `tokensave_search` to identify existing contracts, services, or skills.
3. Extract evident project facts (stack versions, conventions, patterns) so they are excluded from disambiguation questions in Workflow 03.
4. **Constitution Inspection & Bootstrap Discovery**:
   - In standard sessions, read `<spec_root>/Constitution.md` (if present on disk) and record active constitutional prefixes and version in `design.md`.
   - In `--constitution-bootstrap` mode, inspect project code (`tokensave`), data schemas, and existing specs (`<spec_root>/specs/**`, `specs/**`) to classify which of the 8 constitutional subfolders (`01-architecture..08-sdd-governance`) are `active` vs `not-applicable`.
