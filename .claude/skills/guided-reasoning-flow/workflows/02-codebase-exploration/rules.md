# Rules: Workflow 02 — Silent Codebase Exploration

1. **Tokensave-First Mandate**:
   - The Guided Reasoning Orchestrator SHALL follow `the tokensave-first rule` (`tokensave_status`, `tokensave_context`, `tokensave_search`, `tokensave_files`) before manual file inspection.
2. **Strictly Minimal `design.md`**:
   - The Guided Reasoning Orchestrator SHALL record only symbol names, module paths, interface identifiers, and investigation notes in `design.md` without pasting raw source code.
3. **Golden Rule (No Questions on Evident Facts)**:
   - The Guided Reasoning Orchestrator SHALL pre-fill framework versions, folder structures, active dependencies, and database conventions silently without questioning the activator.
4. **Read-Only Execution**:
   - The Guided Reasoning Orchestrator SHALL make zero modifications to repository files outside `reasoning/[NNN]_[slug]/`.
5. **Ignore Superseded and Old Files**:
   - WHILE exploring reasoning sessions, the Guided Reasoning Orchestrator SHALL exclude `superseded/` directories and `.old` files.
