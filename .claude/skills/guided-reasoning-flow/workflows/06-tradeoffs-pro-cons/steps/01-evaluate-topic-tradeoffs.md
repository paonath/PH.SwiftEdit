# Step 01: Evaluate Topic Decisions, Pros & Risks

## Actions
1. Inspect `brief/topic-[id]-consensus.md` and extract every key architectural decision, constraint, or unresolved option for `TOPIC-NN`.
2. For each item, evaluate:
   - **Decision / Option**: The concrete architectural choice.
   - **Pros**: Operational benefits, simplicity, alignment with requirements.
   - **Cons / Risks**: Architectural complexity (KISS vs over-engineering via the `kiss-and-solid-principles` skill), SOLID coupling, performance overhead, or STRIDE security exposure.
3. Conduct **Pre-Mortem Failure Stress-Testing**: simulate why the proposed design could fail in 6 months, identify blind spots, and formulate definitive architectural mitigations.
