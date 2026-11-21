# Workflow 04: Planning & Interactive Resolution Choice (`debug-session-orchestrator`)

1. **Scope Guardrails (Priority, Not Exclusion):** Prioritize investigating files linked to the error and uncommitted changes from Phase 1 without excluding latent bugs in committed code.
2. **STRICT ARCHITECTURAL & SAFETY GUARDRAIL:**
   - IF the proposed fix alters architecture, core logic, or test-covered modules, THEN the Debug Session Orchestrator SHALL stop, explain impact to the human user, and obtain MANDATORY CONFIRMATION before proceeding.
3. **Report & Propose:**
   - The Debug Session Orchestrator SHALL summarize root cause and affected files from `debug_session_memory.md` before requesting resolution mode.
4. **MANDATORY INTERACTIVE PROMPT:** Assuming architectural clearance, ask the user to choose and wait for their reply:
   - **Option A:** "Should I directly edit the source code to apply the fix and retest?"
   - **Option B:** "Should I write a separate Markdown file (`debug_solution.md`) detailing the bug, the affected lines, and the proposed code changes for you to review manually?"
