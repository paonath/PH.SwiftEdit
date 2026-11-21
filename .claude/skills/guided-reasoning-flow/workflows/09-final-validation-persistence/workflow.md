# Workflow 09: Final Conscious Validation & Domain Expert Persistence Gate

## Purpose
Present the consolidated multi-topic architecture and verified mitigations to the human/activator for conscious final validation, and execute the mandatory human-verified persistence proposal gate if reusable `domain-expert` knowledge was formulated.

## Progressive Disclosure Step Index
Load and execute one step file at a time under `Single-Reference Lock`:

| Step | File | Description | Condition |
|---|---|---|---|
| **01** | `steps/01-conscious-final-validation.md` | Request conscious final sign-off & optional legacy/preference declaration via `AskUserQuestion`. | Always |
| **02** | `steps/02-domain-expert-persistence-gate.md` | Evaluate reusable `domain-expert` invariants & propose persistence to `<active_spec_root>/agents/` via `AskUserQuestion`. | When polymorphic `domain-expert` was enrolled |

## Exit Criteria & Memory Compaction
- The Workflow 09 Orchestrator SHALL record conscious final validation in `brief/consensus-matrix.md`.
- Any human-approved `<active_spec_root>/agents/<domain-slug>.agent.md` persisted (`< 400` words).
- Tasks `T09-01` and `T09-02` checked `[x]` in `task.md`.
- Execute context compaction (`/compact`) and transition to `workflows/10-twin-deliverables/`.
