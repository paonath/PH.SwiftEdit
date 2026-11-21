# Workflow 00: Disambiguation & Session Initialization (`debug-session-orchestrator`)

Before taking action, opening code files, or starting the browser, establish context, clarity, and the workspace structure.

1. **Clarity Check & Q&A:** Evaluate whether the prompt defines Action, Expected Behavior, and Actual Behavior/Error.
   - IF the input is ambiguous or incomplete, THEN the Debug Session Orchestrator SHALL stop and ask clarifying questions before proceeding.
2. **Session Directory Creation & Collision Check:** Derive a descriptive slug in `specs/debug/`.
   - IF a matching slug folder exists in `specs/debug/` and its `debug_session_memory.md` objective matches, THEN the Debug Session Orchestrator SHALL resume that session.
   - IF an existing folder in `specs/debug/` has a conflicting objective, THEN the Debug Session Orchestrator SHALL create a new disambiguated folder suffix without overwriting history.
   - WHEN starting a new session, the Debug Session Orchestrator SHALL create `specs/debug/<session_name>/` for all session Markdown files.
3. **Memory Initialization & Inheritance:** Inspect `specs/debug/<session_name>/debug_session_memory.md`.
   - IF `debug_session_memory.md` exists, THEN the Debug Session Orchestrator SHALL read known configurations and patterns immediately.
   - IF `debug_session_memory.md` is absent, THEN the Debug Session Orchestrator SHALL create `specs/debug/<session_name>/debug_session_memory.md`.
4. **Save Final Prompt:**
   - The Debug Session Orchestrator SHALL write the unambiguous starting objective to `specs/debug/<session_name>/debug_session_memory.md` in active-voice EARS (`the ears-syntax-standards skill`) with declarative `Given`/`When`/`Then` reproduction steps (`the bdd-gherkin-specifications skill`).
