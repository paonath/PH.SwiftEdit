# Workflow 05: Resolution Execution — Branching (`debug-session-orchestrator`)

Depending on the user's choice in Phase 4, execute only the selected path.

## Path A (Direct Edit Selected)
1. **Apply Patch:**
   - WHEN Option A is selected, the Debug Session Orchestrator SHALL edit the target source files and log changes in `specs/debug/<session_name>/debug_session_memory.md`.
2. **Mandatory Retest:**
   - WHEN the patch is applied, the Debug Session Orchestrator SHALL run a Mandatory Retest in the browser verifying clean Console output, expected Network status codes, and expected UI behavior.
3. **Final Report:** Confirm retest success and finalize `debug_session_memory.md` (applying Memory Pruning if needed).

## Path B (Solution File Selected)
1. **Generate Solution Document:**
   - WHEN Option B is selected, the Debug Session Orchestrator SHALL create `specs/debug/<session_name>/debug_solution.md` without modifying source code.
2. **Document Fixes:**
   - The Debug Session Orchestrator SHALL formulate `debug_solution.md` and auxiliary session Markdown files using EARS root-cause and fix contracts (`the ears-syntax-standards skill`), exact file/line diffs, and declarative `Given`/`When`/`Then` retest scenarios (`the bdd-gherkin-specifications skill`).
3. **Final Report:** Notify the user that `specs/debug/<session_name>/debug_solution.md` is ready for review, finalize `debug_session_memory.md`, and stop execution.
