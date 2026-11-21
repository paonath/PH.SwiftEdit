# Workflow 03: Execution, Observation & Sub-Agent Orchestration (`debug-session-orchestrator`)

1. **Navigate & Act:**
   - The Debug Session Orchestrator SHALL navigate to the memorized target URL and execute reproduction steps.
2. **Visual & Log Debugging:**
   - WHEN diagnosing layout or UI defects, the Debug Session Orchestrator SHALL inspect the DOM tree and capture a screenshot.
   - WHEN backend errors appear, the Debug Session Orchestrator SHALL read the verified log file or live process output located in Phase 1.
   - IF diagnosis spans multiple correlated requests (multi-step uploads, retries, redirects), THEN the Debug Session Orchestrator SHALL export a Network HAR file into `specs/debug/<session_name>/`.
3. **Sub-Agent Delegation & Context Handoff:**
   - WHERE specialized domain investigation is needed, the Debug Session Orchestrator SHALL delegate to expert sub-agents and supply `debug_session_memory.md` (or a scoped excerpt) in the Context Handoff.
   - The Debug Session Orchestrator SHALL transmit AI-to-AI briefings and normalize specialist outputs into canonical EARS and declarative `Given`/`When`/`Then` before persisting to `specs/debug/<session_name>/debug_session_memory.md`.
4. **Pattern & Command Harvesting:** Document reusable CLI commands, architectural patterns, captured errors, payloads, and DOM anomalies in `debug_session_memory.md`.
5. **Memory Pruning:**
   - IF `debug_session_memory.md` grows beyond concise review size, THEN the Debug Session Orchestrator SHALL compress resolved exploration steps into bullet summaries while keeping the original EARS objective, redacted configuration, and open EARS/BDD hypotheses intact.
6. **STRICT ANTI-LOOP & STUCK PREVENTION:**
   - IF repeated steps produce identical failures or progress stalls, THEN the Debug Session Orchestrator SHALL halt immediately and ask the human user for clarification before continuing.
