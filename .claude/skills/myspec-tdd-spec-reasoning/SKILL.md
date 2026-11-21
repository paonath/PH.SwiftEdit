---
name: myspec-tdd-spec-reasoning
description: >-
  Central specification engine of the entire MySpec suite. Conducts interactive TDD interviews or ingests requirements/briefs, performs deep codebase inspection with domain experts, generates structured briefs in <briefs_dir>/, scaffolds 6-artifact OpenSpec changes under <changes_dir>/, authors RED-GREEN-REFACTOR triads and STRIDE threat models adhering to schema.yaml, and executes automated validation. Always runs end to end (reasoning, brief, 6 schema-conformant artifacts, validation); never stops at the brief. Strictly forbids direct source code modification (deferred exclusively to myspec-apply).
---

# TDD Spec Reasoning Skill (`myspec-tdd-spec-reasoning` — Progressive Disclosure Router)

`myspec-tdd-spec-reasoning` is the **central specification engine of the MySpec suite**. It ALWAYS runs the full 6-phase pipeline from requirement reasoning and `<briefs_dir>/brief-[slug].md` (`openspec/briefs/`, fallback `specs/briefs/`) to a validated 6-artifact OpenSpec change under `openspec/changes/<change-id>/` conforming to `tdd-spec-driven` (`schema.yaml` + `templates/`).

## Mandatory Global Invariants

1. **Zero Direct Source Code Modifications**:
   - Create/edit ONLY specification files (`openspec/briefs/`, `<spec_root>/agents/`, `openspec/changes/<change-id>/`, `<spec_root>/index.yml`). NEVER modify production or test source files; code changes are executed exclusively via `/myspec-apply`.
2. **Progressive Disclosure (`Single-Reference Lock`) & Standards**:
   - Load one `workflows/NN-*/workflow.md` (and at most one `steps/NN-*.md` or `<spec_root>/Constitution.md` Level-2 micro-file) at a time.
   - Enforce `the ears-syntax-standards skill`, `the bdd-gherkin-specifications skill`, and `the kiss-and-solid-principles skill` (`KISS`-First architecture and `SOLID` OOP boundaries).
   - Consult `<spec_root>/index.yml` and every `always_read` document first; dynamically orchestrate `dotnet-expert`, `angular-expert`, `python-expert`, `shell-expert`, `ddd-expert`, `domain-expert`, and `cyber-security-expert`.
3. **Mandatory Path Coverage & QA Gate**:
   - Every unit under test MUST define `>= 1` positive path (`P1..Pn`) and `>= 1` negative path (`N1..Nm`) exercised across `[RED]` -> `[GREEN]` -> `[REFACTOR]` triads.
   - The interactive human `qa` interview (`AskUserQuestion`, 1 question/turn) in Phase 2 is **mandatory and unskippable**.

## Workflow Routing Table

Execute all 6 workflows sequentially in every run (loading one workflow file at a time):

| Phase | Workflow | Scope |
|---|---|---|
| **01** | [01-index-experts-inspection](workflows/01-index-experts-inspection/workflow.md) | Read `index.yml`, `always_read`, `Constitution.md`, living specs; enroll stack/domain experts; silent `tokensave` inspection. |
| **02** | [02-tdd-interview](workflows/02-tdd-interview/workflow.md) | Unskippable `AskUserQuestion` QA gate (1-question confirmation, write-in restart, or 4-pillar interview + runbook language). |
| **03** | [03-generate-brief](workflows/03-generate-brief/workflow.md) | Write `<briefs_dir>/brief-[slug].md` (`openspec/briefs/` + `specs/briefs/`) with branch, `doc-align`, and P/N matrix. |
| **04** | [04-scaffold-change-index](workflows/04-scaffold-change-index/workflow.md) | Allocate `NNN-slug` via `myspec_index.py --next-prefix`, scaffold `openspec/changes/<id>/`, prepend draft to `index.yml`. |
| **05** | [05-author-artifacts](workflows/05-author-artifacts/workflow.md) | Author `proposal.md` (+ `manual-steps.md`), `spec.md`, `design.md`, `threat-model.md`, `test-plan.md`, `tasks.md` via `steps/01..04`. |
| **06** | [06-schema-validation-gate](workflows/06-schema-validation-gate/workflow.md) | Run `myspec_validate.py --change <id> --strict`, up to 3 auto-repair loops, fail-closed stop, and `/myspec-apply` handoff. |

## Normative Requirements (EARS)

- The TDD Spec Reasoning Engine SHALL read `<spec_root>/index.yml`, every `always_read` entry, and `<spec_root>/Constitution.md` before scanning source code.
- The TDD Spec Reasoning Engine SHALL run the interactive `qa` interview in Phase 2 and restart the interview whenever write-in free text is supplied.
- WHEN authoring capability delta specs and tasks in Phase 5, the TDD Spec Reasoning Engine SHALL enforce EARS syntax, BDD path scenarios, and `[RED]`-`[GREEN]`-`[REFACTOR]` triads without modifying source code.
- IF `myspec_validate.py --strict` continues to fail after 3 auto-repair iterations, THEN the TDD Spec Reasoning Engine SHALL halt fail-closed without declaring readiness.
