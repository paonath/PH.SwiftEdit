# Step 01: Proactive Expert Scanning & Enrollment (Per TOPIC)

## Actions
1. Inspect agent profiles across `specs/agents/*.agent.md` and `openspec/agents/*.agent.md` (via dual-directory discovery with active spec_root precedence) frontmatter (`name`, `domain_family`, `version`, `source_briefs`) and `## Purpose`.
2. Semantically match against the active `TOPIC-NN`:
   - **Existing Match**: Enroll the saved profile via cache-recall, bypassing redundant web lookups for pre-verified invariants.
   - **New Discipline**: Instantiate the polymorphic `domain-expert` agent with a concise `GIVEN-WHEN-THEN` domain initialization envelope.
3. Enroll matching repository stack experts (`dotnet-expert`, `angular-expert`, `python-expert`, `shell-expert`, `ddd-expert`, `oop-architecture-expert`) and mandatory `cyber-security-expert` (if IT/software). Ensure at least one domain expert is enrolled excluding `cyber-security-expert` ($N_{domain} \ge 1$).
4. When `<spec_root>/Constitution.md` exists, route each enrolled expert to its matching `<spec_root>/constitution/<NN-area>/index.md` and at most 1 atomic micro-file under `Single-Reference Lock`.
5. Record the enrolled experts for `TOPIC-NN` in `plan.md`.
