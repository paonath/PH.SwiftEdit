# Workflow 10: Conditional Additional Deliverables & Twin Deliverables Generation

## Purpose
Co-create any conditional additional deliverables requested by the caller (`plan.md`), then generate the two standalone final documents in the session root: the Human-Oriented `README.md` and the AI-Oriented `README.ai.md`.

## Progressive Disclosure Step Index
Load and execute one step file at a time under `Single-Reference Lock`:

| Step | File | Description | Condition |
|---|---|---|---|
| **01** | `steps/01-conditional-additional-deliverables.md` | Co-create caller-requested deliverables (ADR, blueprint, skill folder, etc.) inside the session. | When `additional_deliverables` present in `plan.md` |
| **02** | `steps/02-generate-human-readme.md` | Generate `README.md` (Human-Oriented even if caller is AI, max 3-4 lines/para, zero meta-narrative). | Standard sessions (Optional/Skipped in `constitution-bootstrap` mode) |
| **03** | `steps/03-generate-ai-readme.md` | Generate `README.ai.md` (Strictly English AI-Oriented, zero preamble, git baseline, spec task list, tree map). | Standard sessions (Optional/Skipped in `constitution-bootstrap` mode) |

## Constitution-Bootstrap Scoped Write-Boundary Exception (`CWE-22` / `SDD-008`)
- WHERE `operational_mode: "constitution-bootstrap"` is active in `plan.md`, the Workflow 10 Orchestrator SHALL skip twin `README` generation when `twin_readme_required: false`, write `<spec_root>/Constitution.md` and `<spec_root>/constitution/<NN-area>/<slug>.md` in Bare-Bones syntax under `CWE-22` path confinement without editing source or test files, and validate via `myspec_validate.py --validate-constitution`.

## Exit Criteria & Memory Compaction
- Any requested `additional_deliverables` are created inside `reasoning/[NNN]_[slug]/`.
- `README.md` and `README.ai.md` are generated and verified against all formatting rules.
- Tasks `T10-01`..`T10-03` checked `[x]` in `task.md`.
- Execute context compaction (`/compact`) and transition to `workflows/11-handoff-completion/`.
