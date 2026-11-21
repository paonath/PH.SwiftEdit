---
name: myspec-apply
description: Executes an OpenSpec change or legacy specification file step by step with baseline health checks, dotnet-test-suite plugin integration, native TDD Red-Green-Refactor enforcement, adaptive sub-agent delegation, and memory synchronization.
---

# MySpec Apply Skill (`myspec-apply` — Progressive Disclosure Router)

## Runtime Neutrality
- This skill is agent-runtime agnostic: it MUST behave identically under any host agent runtime.
- Refer to capabilities, never to a specific product; fall back to host-native tools when optional integrations are absent.
- Express every instruction to the human in neutral wording without product-specific UI syntax.

## Hard Stops
- **No target attached or specified** -> stop and ask: *"No change or specification target specified. Please provide the change ID (under openspec/changes/) or path to the spec file under specs/ to execute."*

## Core Architectural Directives
1. **Progressive Disclosure (`Single-Reference Lock`)**:
   - Load only one `workflows/NN-*/workflow.md` at a time. Enforce `the kiss-and-solid-principles skill` (`KISS`-First architecture and `SOLID` OOP boundaries) and the `tokensave-first` rule across all phases.
2. **Dual-Mode Execution & Git Commit Boundaries**:
   - Supports OpenSpec changes (`tasks.md` checkboxes marked `- [x]`) and legacy specifications (`specs/*.md` Section 12 YAML tasks).
   - Stage ONLY pending specification markdown files for the initial `wip: <spec-name>` (`wip: <change-id>`) commit; intermediate task commits, folder moves, and `CHANGELOG.md` edits are strictly prohibited and delegated exclusively to `myspec-archive` after `/myspec-verify`.
3. **Constitutional & Security Gates**:
   - When `<spec_root>/Constitution.md` exists, enforce the Dual Mandatory Gate under `Single-Reference Lock`; `<spec_root>/Constitution.md` is read-only unless `- Amends-Constitution:` is declared in `proposal.md`.
   - Enforce `DocAlignGuard` in `doc-align` mode and pause for `qa` confirmation on `[MANUAL]` (`manual-steps.md`) or SQL tasks.
4. **Adaptive Stack Delegation**:
   - Delegate stack-specific work dynamically to `dotnet-expert`, `angular-expert`, `python-expert`, and `shell-expert` under `Single-Reference Lock`.

## Workflow Routing Table

Read and execute each phase's `workflow.md` sequentially (one workflow file in context at a time):

| Phase | Workflow | Scope |
|---|---|---|
| **01** | [01-preflight-and-health](workflows/01-preflight-and-health/workflow.md) | Dual-mode target detection, branch provenance, initial `wip:` markdown checkpoint, baseline build/test health gate. |
| **02** | [02-context-scope-and-guards](workflows/02-context-scope-and-guards/workflow.md) | Context loading, strict scope, `Constitution.md` gate, commit bans, fail-closed `DocAlignGuard`. |
| **03** | [03-tdd-execution-loop](workflows/03-tdd-execution-loop/workflow.md) | Path A (`[RED]`/`[GREEN]`/`[REFACTOR]`/`[DOC]`/`[MANUAL]`/SQL) and Path B legacy tasks with stack delegation. |
| **04** | [04-global-verification-gate](workflows/04-global-verification-gate/workflow.md) | Linting/formatting, full regression suite, and `security-secret-scanner` verification. |
| **05** | [05-summary-and-handoff](workflows/05-summary-and-handoff/workflow.md) | Execution summary (`COMPLETE`/`INCOMPLETE`) and Decision D10 handoff to `/myspec-verify` or `/myspec-archive`. |

## Normative Requirements (EARS)

- The MySpec Apply Router SHALL load one workflow file at a time under Single-Reference Lock and enforce `the tokensave-first rule`.
- WHEN pending specification markdown files exist before Phase 3, the MySpec Apply Executor SHALL create a single `wip: <spec-name>` commit and prohibit intermediate commits or `CHANGELOG.md` edits.
- WHERE `<spec_root>/Constitution.md` exists, the MySpec Apply Executor SHALL verify each task against cited rules under Single-Reference Lock without editing the Constitution unless `- Amends-Constitution:` is declared.
- IF a change sets `mode: doc-align` without explicit user override, THEN the Fail-Closed Doc-Align Guard SHALL block all file writes outside `spec_root`.

## Black-Box Execution

- **Do not read** script source before running it; the scripts are tested black boxes.
- Run commands from the skill base directory (the folder containing this `SKILL.md`).
- Read the source only after a non-zero exit that stderr does not explain.

| Module | Import | Public API | Notes |
|---|---|---|---|
| `doc_align_guard` | Load `scripts/doc_align_guard.py` from this skill | `DocAlignGuard.is_override_authorized`, `is_inside_spec_root`, `check_write_permission` | Library, not a CLI; call from agent code only |
