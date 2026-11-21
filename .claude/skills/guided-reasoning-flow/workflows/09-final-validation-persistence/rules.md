# Rules: Workflow 09 — Final Validation & Domain Expert Persistence Gate

1. **Zero Silent Persistence (`<active_spec_root>/agents/`)**:
   - The Guided Reasoning Orchestrator SHALL obtain explicit human confirmation via `AskUserQuestion` before creating or updating any profile inside the active `<active_spec_root>/agents/` directory.
2. **Strict `< 400` Words Agent Profile Standard**:
   - WHEN the human approves persistence, the Guided Reasoning Orchestrator SHALL write `<active_spec_root>/agents/<domain-slug>.agent.md` under 400 words with YAML frontmatter (`name`, `domain_family`, `version`, `source_briefs`) and the 4 standard sections (`Purpose`, `Invariants and Constraints`, `Verification and Seams`, `Domain Boundaries`).
3. **Strict `qa` Mode (1 Question / Turn)**:
   - The Guided Reasoning Orchestrator SHALL ask final validation and persistence confirmation questions one per turn via `AskUserQuestion`.
