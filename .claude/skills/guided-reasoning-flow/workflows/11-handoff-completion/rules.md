# Rules: Workflow 11 — Session Audit, Conclusion & Handoff

1. **Absolute Ban on Direct Source Code Execution**:
   - The guided-reasoning-flow skill SHALL never modify project source code or invoke `myspec-apply` internally.
2. **Planning Handoff Only (`myspec-tdd-spec-reasoning`)**:
   - IF project file changes are required, THEN the Guided Reasoning Orchestrator SHALL route planning exclusively to `myspec-tdd-spec-reasoning` after explicit human confirmation via `AskUserQuestion`.
3. **Restricted Mirror Sync**:
   - The Guided Reasoning Orchestrator SHALL obtain explicit human approval before executing `sync-agents-to-claude.sh` or `my-agent-global-sync.sh`.
