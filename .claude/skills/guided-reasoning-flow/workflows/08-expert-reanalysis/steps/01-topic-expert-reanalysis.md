# Step 01: Per-TOPIC Technical Re-Analysis & Topic Loop Dispatch

## Actions
1. Inspect `brief/topic-[id]-human-review.md` and `brief/tradeoffs-pro-cons.md` for `TOPIC-NN`.
2. If the activator modified a decision, rejected a mitigation, or added constraints:
   - Dispatch an English `GIVEN-WHEN-THEN` re-analysis request to the impacted `TOPIC-NN` experts and `cyber-security-expert`.
   - Update `brief/topic-[id]-[expert]-brief.md` (`## Post-Review Verdict`), `brief/tradeoffs-pro-cons.md`, and `brief/topic-[id]-consensus.md`.
   - If the change impacts an earlier `TOPIC-M`, reconcile the affected earlier briefs (max 3 iterations).
3. Mark `TOPIC-[id]-WF08` as `[x]` in `task.md` and execute memory compaction (`/compact`).
4. **Routing Check**:
   - If there is an unprocessed `TOPIC-(N+1)` in `proposal.md`, transition back to `workflows/04-domain-expert-enrollment/` for `TOPIC-(N+1)`.
   - If all TOPICs have completed Step 01, proceed to `steps/02-global-cross-topic-signoff.md`.
