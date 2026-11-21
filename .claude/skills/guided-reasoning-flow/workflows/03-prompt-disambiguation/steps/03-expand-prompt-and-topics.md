# Step 03: Write Disambiguated Prompt & Initialize TOPICs

## Actions
1. Synthesize the original prompt, attachment requirements, and `qa` clarifications into the **Expanded Disambiguated Prompt** and write it under `## Disambiguated Prompt (Central Reasoning Anchor)` in `proposal.md`.
2. Decompose the disambiguated prompt into atomic, cohesive topics (`TOPIC-01`, `TOPIC-02`, ...) and document each topic's scope in `proposal.md` under `## Topic Breakdown`.
3. Invoke `scripts/scaffold_reasoning.py` to expand `task.md` with per-TOPIC sub-checklists and generate the initial per-topic files in `brief/`:
   ```bash
   python3 <skill-dir>/scripts/scaffold_reasoning.py \
     --session-dir "reasoning/[NNN]_[slug]" \
     --init-topics "TOPIC-01:<Concise Topic 1 Title>" \
     --init-topics "TOPIC-02:<Concise Topic 2 Title>" \
     --json
   ```
4. Mark `T03-03` and `T03-04` as `[x]` in `task.md`.
