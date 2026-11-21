# Workflow 01: Context Gathering, Workspace State & Continuity (`debug-session-orchestrator`)

Do not assume tech stack, ports, protocols, or logging mechanisms. Reuse established facts already recorded in memory.

1. **Read Project Convention Files:**
   - The Debug Session Orchestrator SHALL read root convention files (`AGENTS.md`, `GEMINI.md`, `CLAUDE.md`) and log project rules, architectural guidelines, and commands into memory.
2. **Extract Configuration:**
   - The Debug Session Orchestrator SHALL inspect environment and build manifests (`.env`, framework configs, dependency manifests) to identify Base URL, Port, Protocol, and logging targets.
3. **Locate the Logging Mechanism:** Determine from convention files and run configurations whether server output writes to disk files or streams to dev-server stdout/stderr.
   - IF the logging source remains ambiguous, THEN the Debug Session Orchestrator SHALL ask the user once or inspect both targets during Phase 3.
4. **Secrets Redaction Rule:** When persisting any extracted configuration to memory, you MUST NOT write actual secret values.
   - WHILE writing to `debug_session_memory.md`, the Debug Session Orchestrator SHALL omit credential literals and record only variable names with file paths (for example, `DB_CONNECTION_STRING -> see .env, line 4`).
5. **Analyze Workspace State (Unsaved & Uncommitted Files):**
   - The Debug Session Orchestrator SHALL inspect open unsaved files and uncommitted Git changes (`git status`/`git diff`) and log findings into memory.
6. **Persist Context:**
   - The Debug Session Orchestrator SHALL write redacted configuration and workspace state findings into `specs/debug/<session_name>/debug_session_memory.md` before Phase 2.
