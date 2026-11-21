# Workflow 03: Prompt Disambiguation, Topic Breakdown & Plan Approval

## Purpose
Read all attached/linked documents, conduct a focused 4-6 question `qa` interview with the skill activator (human or AI) recorded in `brief/00-prompt-disambiguation-qa.md`, register the expanded disambiguated prompt as the central reasoning node in `proposal.md`, decompose it into `TOPIC-NN` units, and obtain formal approval of `plan.md`.

## Progressive Disclosure Step Index
Load and execute one step file at a time under `Single-Reference Lock`:

| Step | File | Description | Condition |
|---|---|---|---|
| **01** | `steps/01-read-attachments-and-links.md` | Read all files in `attachments/` and referenced repository links before asking questions. | Always |
| **02** | `steps/02-activator-qa-interview.md` | Confirm languages & ask 4-6 `qa` questions (1/turn); log in `brief/00-prompt-disambiguation-qa.md`. | Always |
| **03** | `steps/03-expand-prompt-and-topics.md` | Write Disambiguated Prompt & `TOPIC-NN` in `proposal.md`; run `scaffold_reasoning.py --init-topics`. | Always |
| **04** | `steps/04-finalize-and-approve-plan.md` | Update `plan.md` (experts, additional deliverables) & request activator approval via `AskUserQuestion`. | Always |

## Exit Criteria & Memory Compaction
- `brief/00-prompt-disambiguation-qa.md` records all questions and answers.
- `proposal.md` contains the Disambiguated Prompt and `TOPIC-01..NN` breakdown.
- `task.md` contains expanded per-TOPIC sub-checklists.
- WHEN `plan.md` receives activator approval, the Workflow 03 Orchestrator SHALL execute `/compact` and transition to `workflows/04-domain-expert-enrollment/` for `TOPIC-01`.
