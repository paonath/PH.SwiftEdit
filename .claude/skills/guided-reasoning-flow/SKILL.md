---
name: guided-reasoning-flow
description: >-
  Conducts guided, spec-oriented in-depth AI reasoning and planning with progressive disclosure workflows,
  dual-track language protocol, multi-topic deconstruction, silent codebase inspection, AI-to-AI briefings
  in GIVEN-WHEN-THEN syntax, systematic Pro/Con trade-off evaluation, and twin deliverable generation
  (human-ready concise README and AI-ready README with an updatable spec task list and progressive disclosure
  tree map). Can be initiated directly by the user or invoked autonomously by peer agents (e.g. myspec-apply,
  dotnet-expert, angular-expert, debug-orchestrator, myspec-pipeline). Natively supports new sessions and
  rework/revision modes. Triggers: guided-reasoning-flow, guided-reasoning, deep-reasoning, ragionamento guidato,
  ragionamento approfondito, rework reasoning.
---

# Guided Reasoning Flow Skill (Progressive Disclosure Architecture)

Governed by the `orchestrator` main agent, this skill executes structured multi-agent reasoning through atomic, repeatable workflows (`workflows/NN-*/`), progressive disclosure sub-steps (`steps/*.md`), and a spec-oriented workspace (`reasoning/[NNN]_[slug]/`) without ever modifying project source code directly.

## Core Architectural Directives

1. **Full Progressive Disclosure & No Hardcoded Physical Paths**:
   - The Guided Reasoning Flow Skill SHALL reference skills (`qa`, `kiss-and-solid-principles`), rules (`tokensave-first`, `markdown-style-ai`), and agents (`domain-expert`, `cyber-security-expert`) exclusively by logical identifiers.
   - The Guided Reasoning Flow Skill SHALL enforce `Single-Reference Lock` by loading one `workflows/NN-*/workflow.md`, its `rules.md`, and one `steps/NN-*.md` at a time while applying `the kiss-and-solid-principles skill` for KISS and SOLID boundaries and `/compact` after every workflow and TOPIC cycle.
2. **Dual-Track Language & Spec-Oriented AI-to-AI Protocol**:
   - **Human Interaction & Final `README.md`**: Italian (Default) or English using EARS and BDD behavioral schemas without rigid lexical word-locking.
   - WHEN conducting AI-to-AI interactions or authoring `brief/*` and `README.ai.md`, the Guided Reasoning Flow Skill SHALL load `the ears-syntax-standards skill` and `the bdd-gherkin-specifications skill` to enforce English canonical EARS and declarative `GIVEN-WHEN-THEN` syntax.
3. **Automated Workspace Scaffolding (`scripts/scaffold_reasoning.py`)**:
   - WHEN creating or reworking a `reasoning/[NNN]_[slug]/` session, the Guided Reasoning Flow Skill SHALL invoke `scripts/scaffold_reasoning.py` directly from `orchestrator`.
4. **Strict Write Boundary, Scoped Write Delegation & Zero Direct Code Edits**:
   - The Guided Reasoning Flow Skill SHALL confine writes to `reasoning/[NNN]_[slug]/` and human-confirmed `<active_spec_root>/agents/<slug>.agent.md` in Workflow 09 while permitting **Scoped Context-Aware Write Delegation** only to `cyber-security-expert` for security briefs in `brief/`.
   - **Absolute Ban on Source Code Edits**:
   - IF application code changes are needed, THEN the Guided Reasoning Flow Skill SHALL plan them via `myspec-tdd-spec-reasoning` on human confirmation and defer execution to `myspec-apply`.
5. **Autonomous Agent Invocation, Hybrid Mode & Dynamic Enrollment**:
   - Callable by humans or peer AI agents (`myspec-apply`, `dotnet-expert`, `angular-expert`, `python-expert`, `shell-expert`, `debug-orchestrator`, `myspec-pipeline`).
   - The Guided Reasoning Flow Skill SHALL enroll at least one domain expert per topic excluding `cyber-security-expert` and permit Dynamic On-Demand Enrollment Seam additions across workflows 01-11.
   - WHERE Hybrid Mode reaches decision checkpoints (Wf 03, Wf 07, Wf 09, Wf 11), the Guided Reasoning Flow Skill SHALL prompt via `AskUserQuestion` (`qa` mode, 1 question/turn).
6. **Spec-Oriented Internal Document Hierarchy**:
   - `plan.md`: Un-numbered session plan, languages, enrolled experts, additional deliverables, and milestones.
   - `proposal.md`: Immutable raw trigger prompt (written immediately), expanded disambiguated prompt, and `TOPIC-NN` breakdown.
   - `design.md`: Strictly minimal glossary, ADR tables, conventions, and `tokensave` codebase references.
   - `task.md`: Complete enumerated checklist of all mandatory workflow steps and dynamic per-TOPIC sub-checklists.
   - `brief/`: Stores `00-prompt-disambiguation-qa.md`, `topic-[id]-[expert]-brief.md`, `topic-[id]-expert-activator-qa.md`, `topic-[id]-consensus.md`, `topic-[id]-human-review.md`, `consensus-matrix.md`, and `tradeoffs-pro-cons.md`.
   - `attachments/`: External prompt files (original name/content), web research dossiers, `INDEX.md`, and `history/rev-[REV]/`.
   - `README.md` (Human-Oriented, even if caller is AI) & `README.ai.md` (AI-Oriented, ultra-concise English, zero preamble).

## Workflow Routing Table

For each phase, read `workflows/NN-<name>/rules.md` and `workflows/NN-<name>/workflow.md`, then execute its `steps/*.md` sequentially.

| Phase | Workflow Folder | Scope & Repeatability |
|---|---|---|
| **01** | `workflows/01-operational-mode/` | Mode A (New) vs Mode B (Rework backup + `[[...]]` delta); run `scaffold_reasoning.py`. |
| **02** | `workflows/02-codebase-exploration/` | Silent `tokensave` exploration; log minimal references to investigate in `design.md`. |
| **03** | `workflows/03-prompt-disambiguation/` | Read `attachments/`; `qa` interview (4-6 Qs); write expanded prompt & TOPICs; approve `plan.md`. |
| **04** | `workflows/04-domain-expert-enrollment/` | **[Per TOPIC]** Match dual dirs, enroll >=1 domain expert; 2-source web research. |
| **05** | `workflows/05-ai-briefings-consensus/` | **[Per TOPIC]** `GIVEN-WHEN-THEN` AI briefs, deep codebase lookup, max 3 expert Qs, consensus (max 3 loops). |
| **06** | `workflows/06-tradeoffs-pro-cons/` | **[Per TOPIC]** Systematic Pro/Con & expert mitigations in `brief/tradeoffs-pro-cons.md` *before* review. |
| **07** | `workflows/07-human-review/` | **[Per TOPIC]** Interactive `qa` review validating consensus & Pro/Con in `brief/topic-[id]-human-review.md`. |
| **08** | `workflows/08-expert-reanalysis/` | **[Per TOPIC + Global]** Technical re-analysis of activator choices, backward reconciliation & sign-off. |
| **09** | `workflows/09-final-validation-persistence/` | Final conscious validation & `AskUserQuestion` gate for active root persistence. |
| **10** | `workflows/10-twin-deliverables/` | Co-create conditional additional deliverables + generate `README.md` (Human) & `README.ai.md` (AI). |
| **11** | `workflows/11-handoff-completion/` | Audit checklist, output summary links, and offer optional handoff to `myspec-tdd-spec-reasoning`. |
| **12** | `workflows/12-major-consolidation/` | Consolidate session into new major: snapshot to `superseded/<ver>/`, `.md.old` rename & delta purge. |

## Black-Box Execution

- **Do not read** script source before running it; the scripts are tested black boxes.
- Run commands from the skill base directory (the folder containing this `SKILL.md`).
- Read the source only after a non-zero exit that stderr does not explain.

| Command | Parameters | Stdout | Exit codes |
|---|---|---|---|
| `python3 ./scripts/scaffold_reasoning.py` | `--slug`, `--attachment`, `--rework-from`, `--major`, `--new-major`, `--init-topics` | Session details or JSON | 0 success |
