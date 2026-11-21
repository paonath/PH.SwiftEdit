# Step 04: Topic Consensus & Backward Reconciliation (Max 3 Iterations)

## Actions
1. Synthesize all specialist briefs and activator QA answers for `TOPIC-NN` into `brief/topic-[id]-consensus.md` using `GIVEN-WHEN-THEN` specifications.
2. **Cross-Expert & Cross-Topic Tension Check**:
   - If experts within `TOPIC-NN` disagree, run a focused cross-review round (bounded to **max 3 iterations**).
   - **Backward Reconciliation**: If `TOPIC-NN` introduces an architectural change that modifies or contradicts a previously completed `TOPIC-M` (`M < N`), immediately re-open all briefs (`brief/topic-*`) impacted by the change and re-run convergence (bounded to **max 3 iterations**).
3. Update `brief/consensus-matrix.md` and `design.md` (ADR table), then mark `TOPIC-[id]-WF05` as `[x]` in `task.md`.
