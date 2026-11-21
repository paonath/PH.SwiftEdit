# Step 02: Domain Expert Reusability Assessment & Persistence Gate

## Actions
1. Evaluate whether any enrolled `domain-expert` formulated non-trivial, reusable domain knowledge (formal invariants, statutory rules, mathematical formulas, or `GIVEN-WHEN-THEN` verification seams).
2. If yes, present a formal proposal to the human via `AskUserQuestion`:
   - Proposed `<domain-slug>`, `domain_family`, and whether it creates a new profile or enriches an existing `<active_spec_root>/agents/<domain-slug>.agent.md` monotonically.
   - 2-3 bullet summary of the key invariants and seams.
   - Explicit options to confirm or decline persistence.
3. **On Confirmation**: Write/update `<active_spec_root>/agents/<domain-slug>.agent.md` (`< 400` words, 4 standard sections).
4. **On Decline**: Keep all findings strictly within `reasoning/[NNN]_[slug]/brief/`.
5. Mark `T09-02` as `[x]` in `task.md`.
