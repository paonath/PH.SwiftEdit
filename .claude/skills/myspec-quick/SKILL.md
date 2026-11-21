---
name: myspec-quick
description: "Agile 3-workflow fast-track skill: conducts a deep-grill /qa interview (with instant STOP early-exit), executes every decided item autonomously without a 6-artifact change directory, and reconciles <spec_root> post-hoc (brief, living specs, index.yml)."
user-invocable: true
argument-hint: "[prompt]"
---

# MySpec Quick (`myspec-quick`)

Ultra-lean 3-workflow execution skill. **ONLY `Workflow 01` interacts with the user**; `Workflow 02` and `Workflow 03` run 100% autonomously without pausing.

## Core Invariants
- **Single-Reference Lock**: Load ONLY ONE `workflows/0N-*/workflow.md` file at a time; unload the prior workflow before advancing.
- **Mandatory Index & Constitution Pre-Flight**: Always inspect `<spec_root>/index.yml` (`always_read:` + `specs:`), `<spec_root>/Constitution.md` (at most 1 micro-file per step under `Single-Reference Lock`), and impacted `<specs_dir>/<cap>/spec.md` upfront.
- **Single Interactive Phase & `STOP` Kill-Switch**: `AskUserQuestion` is permitted ONLY in `Workflow 01`. Saying or selecting `STOP` immediately ends the interview, applies `(Recommended)` defaults to remaining items (fail-closed on `Rule G3`), and starts `Workflow 02`.
- **Zero `<changes_dir>/` Ceremony & Zero Auto-Commit**: Never create a 6-artifact folder in `<changes_dir>/` and never run automatic `git commit`.

## Sequential Workflow Routing Table

| Phase | Workflow File (Load 1 at a time) | Interaction | Core Responsibility |
|---|---|---|---|
| **01** | `workflows/01-interview/workflow.md` | **Interactive (`qa`)** | Silent pre-flight (`index.yml`, `Constitution.md`, living specs, `tokensave`), 1-Q/turn deep-grill `AskUserQuestion`, instant `STOP` fast-forward, emit Disambiguated Prompt. |
| **02** | `workflows/02-execute/workflow.md` | **Autonomous (`0` Qs)** | Execute every Disambiguated Prompt item directly, enforce `Constitution.md` (`SDD-009`) + 6-category STRIDE, run `P#`/`N#` self-repair loop (`<= 3` tries) to `exit 0`. |
| **03** | `workflows/03-reconcile/workflow.md` | **Autonomous (`0` Qs)** | Reconcile `<briefs_dir>/brief-<slug>.md`, `<specs_dir>/<cap>/spec.md`, and `<spec_root>/index.yml` (`status: "implemented"`), validate index, render Decision D10 Next-Steps. |

## Normative Requirements (EARS)
- The MySpec Quick Router SHALL load only one workflow file at a time under Single-Reference Lock.
- WHEN the user issues STOP during Workflow 01, the MySpec Quick Router SHALL apply Recommended defaults and enter Workflow 02 without asking extra confirmation questions.
- IF a change modifies an existing security control without an explicit Security-Waiver, THEN the MySpec Quick Executor SHALL preserve the security control unchanged.
- WHEN Workflow 02 completes verification with exit code 0, the MySpec Quick Reconciler SHALL update the brief, living spec, and index.yml without automatic git commit.
