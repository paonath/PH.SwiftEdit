# Step 02: AI-to-AI `GIVEN-WHEN-THEN` Specialist Briefings

## Actions
1. WHEN dispatching a briefing prompt to an enrolled expert on `TOPIC-NN`, the Guided Reasoning Orchestrator SHALL request an **Intent Contract** (Primary Hypothesis, Falsification Criteria, Boundary Invariants) in concise English `GIVEN-WHEN-THEN` syntax:
   ```text
   GIVEN [Disambiguated Prompt & TOPIC-NN Scope + Codebase Baseline from design.md]
   WHEN [Formulating Intent Contract (Hypothesis, Falsification, Invariants) and KISS/SOLID solutions]
   THEN [Return verified Hard Constraints (2-source cited), GIVEN-WHEN-THEN verification seams, and up to 3 QA questions for the activator]
   ```
2. The Guided Reasoning Orchestrator SHALL record each expert response in `brief/topic-[id]-[expert]-brief.md` (with YAML frontmatter: `session`, `topic_id`, `expert`, `status`), loading at most 1 `<spec_root>/constitution/<NN-area>/<micro-file>.md` per expert under `Single-Reference Lock` and citing `[<PREFIX>-###]` rule IDs.
3. WHERE `--constitution-bootstrap` mode is active, the Guided Reasoning Orchestrator SHALL author Bare-Bones single-line `<PREFIX>-<NNN>` EARS rules with zero preambles, zero blockquotes, and zero `## Purpose` prose.
4. WHERE TOPIC-NN touches IT or software domains, the cyber-security-expert agent SHALL write or provide STRIDE security analysis in `brief/topic-[id]-cyber-security-expert-brief.md`.
