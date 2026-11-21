# Workflow 03: Reuse and Conflict Resolution (`agent-self-learning`)

## Pattern Reuse & Conflict Governance

1. **Reuse Priority**:
   - The reuse-and-conflict-resolution workflow SHALL prefer the newest validated `Status: active` pattern matching the current module or problem domain.
   - IF confidence in pattern applicability is low, THEN the reuse-and-conflict-resolution workflow SHALL ask the user before applying the pattern.
2. **Conflict Deprecation / Blocking**:
   - WHEN new evidence contradicts an `active` pattern, the reuse-and-conflict-resolution workflow SHALL mark the older artifact `Status: deprecated` (or `Status: blocked` if unsafe).
   - WHEN superseding a contradictory artifact, the reuse-and-conflict-resolution workflow SHALL author the replacement with `Supersedes: <OLD-PATTERN-ID>` and notify the user.
3. **Blocked Pattern Safety Gate**:
   - The reuse-and-conflict-resolution workflow SHALL never apply or recommend any pattern with `Status: blocked`.
   - WHEN reactivating a `Status: blocked` pattern, the reuse-and-conflict-resolution workflow SHALL require fresh `ValidationEvidence` and **explicit user confirmation**.
