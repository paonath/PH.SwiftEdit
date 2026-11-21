# Workflow 04: Propagate Tests from `.allium` Specifications (`allium`)

Progressive-disclosure wrapper around [skills/propagate/SKILL.md](../../skills/propagate/SKILL.md) and [test-generation.md](../../references/test-generation.md):

1. **Mode Selection**:
   - **Surface Mode**: Generate boundary integration/E2E tests verifying `exposes` field contracts and `provides` operations (`when` guards).
   - **Spec Mode**: Generate rule-chain, transition-graph, and invariant tests across domain workflows.
2. **Output Kinds**:
   - Scenario assertion tests (`requires` rejection + `ensures` verification).
   - Property-Based Testing (`PBT`) generators from `invariant` and `@invariant` blocks.
   - State-machine transition tests from `transitions` graphs (`terminal:` states and illegal transitions).
3. **Implementation Bridge**:
   - Discover project test runner, fixtures, and domain entry points before emitting runnable test suites.
