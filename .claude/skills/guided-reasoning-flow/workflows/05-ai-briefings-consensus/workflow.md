# Workflow 05: AI-to-AI Briefings (`GIVEN-WHEN-THEN`) & Consensus Convergence (Per TOPIC)

## Purpose
For the active `TOPIC-NN`, conduct deep targeted codebase inspection, run AI-to-AI specialist interviews strictly in English `GIVEN-WHEN-THEN` format (`brief/topic-[id]-[expert]-brief.md`), allow each expert to ask up to 3 `qa` questions to the activator (`brief/topic-[id]-expert-activator-qa.md`), and converge on topic consensus (`brief/topic-[id]-consensus.md`) with backward reconciliation across prior topics (max 3 iterations).

## Progressive Disclosure Step Index
Load and execute one step file at a time under `Single-Reference Lock`:

| Step | File | Description | Condition |
|---|---|---|---|
| **01** | `steps/01-deep-topic-codebase-research.md` | Deep, TOPIC-scoped codebase lookup on references listed in `design.md`. | When repo code is involved |
| **02** | `steps/02-ai-to-ai-gwt-briefings.md` | Interview enrolled experts in `GIVEN-WHEN-THEN` English; write `brief/topic-[id]-[expert]-brief.md`. | Always (Per TOPIC) |
| **03** | `steps/03-expert-activator-qa.md` | Up to 3 `qa` questions per expert to activator (human/AI); log in `brief/topic-[id]-expert-activator-qa.md`. | When expert needs activator input |
| **04** | `steps/04-consensus-and-backward-reconciliation.md` | Converge in `brief/topic-[id]-consensus.md`; re-evaluate all briefs (max 3 loops) if prior topics are impacted. | Always (Per TOPIC) |

## Behavioral Scenarios

```gherkin
Feature: AI-to-AI Specialist Briefings and Consensus Convergence
  @REQ-GRF-001
  Scenario: Converge multi-expert topic consensus with Intent Contract and Devil's Advocate
    Given an approved plan with enrolled domain experts and cyber-security-expert
    When the Guided Reasoning Orchestrator conducts English GIVEN-WHEN-THEN briefings and Devil's Advocate challenge
    Then the Guided Reasoning Orchestrator records topic consensus within 3 iterations

  @REQ-GRF-002
  Scenario: Enforce write isolation and trigger backward topic reconciliation on conflict
    Given a specialist brief for TOPIC-02 that invalidates an invariant from TOPIC-01
    When the Guided Reasoning Orchestrator detects cross-topic divergence without unauthorized writes
    Then the Guided Reasoning Orchestrator blocks direct edits from read-only experts and re-runs affected briefs up to 3 loops
```

## Exit Criteria & Memory Compaction
- The Workflow 05 Orchestrator SHALL confirm completion of `brief/topic-[id]-[expert]-brief.md`, `brief/topic-[id]-expert-activator-qa.md`, and `brief/topic-[id]-consensus.md`.
- Task `TOPIC-[id]-WF05` checked `[x]` in `task.md`.
- Execute context compaction (`/compact`) and transition to `workflows/06-tradeoffs-pro-cons/` for the active `TOPIC-NN`.
