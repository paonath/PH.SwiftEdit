# Step 02: Final Summary Output & `myspec-*` Handoff Gate

## Actions
1. Output a concise markdown summary containing:
   - Clickable links to `README.md` and `README.ai.md` (or to `<spec_root>/Constitution.md` and `<spec_root>/constitution/**` in `constitution-bootstrap` mode).
   - Key architectural decisions, active `Constitutional-Rules` (`[<PREFIX>-###]`), any `- Amends-Constitution:` metadata, and the count of tasks ready for specification.
2. Present a final prompt via `AskUserQuestion` (`qa` mode) with options:
   - **(Recommended) Conclude and close the reasoning session.**
   - **Hand off `TASK-01` from `README.ai.md` to `myspec-tdd-spec-reasoning` for TDD specification planning** *(planning only; code execution via `myspec-apply` remains strictly external)*.
   - **Re-open a specific TOPIC or workflow for further refinement.**
3. Mark `T11-02` as `[x]` in `task.md`.
