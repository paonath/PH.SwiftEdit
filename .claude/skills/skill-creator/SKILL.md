---
name: skill-creator
description: |
  Create, validate, package, and distribute AI Agent Skills for Antigravity, Claude, AI Agent, and other agent frameworks.
  Use when: (1) designing new agent skills, (2) validating skill structure,
  (3) organizing skill resources, (4) packaging and distributing skills,
  (5) sharing skills via repositories, (6) ensuring Agent Skills standard compliance
---

# AI Agent Skill Creator (`skill-creator` — Progressive Disclosure Router)

Creates, validates, packages, and distributes production-ready Agent Skills across Antigravity, Claude, and other AI coding assistants.
Enforces `Single-Reference Lock`: load one `workflows/NN-*/workflow.md` phase file (or one `references/*.md` / `examples/*.md` file) at a time.

## Core Principles

- **Progressive Disclosure**: Keep `SKILL.md` concise (`<= 90` lines for routers, `< 500` lines max) and delegate detailed references, examples, and multi-phase workflows to subdirectories.
- **Deterministic CLI Scripts**: Any helper script under `scripts/` MUST use `argparse` (`--help`, exit `2` on invalid options, JSON stdout, exit `0`/`1`) and include a `## Black-Box Execution` table in `SKILL.md`.
- **Security Hygiene**: Zero embedded credentials, API keys, or physical skill paths; validate before packaging via `validate_skill.py`.

## Workflow Routing Table

Execute the 4 phases sequentially (one workflow file in context at a time):

| Phase | Workflow | Scope |
|---|---|---|
| **01** | [01-design-and-pattern](workflows/01-design-and-pattern/workflow.md) | Steps 1–2: Define purpose, triggers, scope, and choose Pattern 1/2/3 ([design-patterns.md](references/design-patterns.md)). |
| **02** | [02-scaffold-and-author](workflows/02-scaffold-and-author/workflow.md) | Steps 3–4: Scaffold directories, frontmatter, Pattern 1/2/3 skeletons, `Black-Box Execution` template ([workflow-guide.md](references/workflow-guide.md)). |
| **03** | [03-scripts-and-validation](workflows/03-scripts-and-validation/workflow.md) | Steps 5–6: Author `argparse` scripts, run `validate_skill.py`, and troubleshoot ([validation-rules.md](references/validation-rules.md)). |
| **04** | [04-package-and-distribute](workflows/04-package-and-distribute/workflow.md) | Steps 7–8: Package `.skill` archive via `package_skill.py` and distribute to project/personal/community registries. |

## Bundled References & Examples

- References: [validation-rules.md](references/validation-rules.md), [design-patterns.md](references/design-patterns.md), [workflow-guide.md](references/workflow-guide.md)
- Examples: [minimal-skill.md](examples/minimal-skill.md), [medium-skill.md](examples/medium-skill.md), [complex-skill.md](examples/complex-skill.md)

## Formal Requirements (EARS)

- The skill-creator router SHALL load one workflow phase file or reference guide per active step under Single-Reference Lock.
- WHEN a created skill includes executable scripts, the skill-creator workflow SHALL require an `argparse` CLI interface and a `Black-Box Execution` table.
- IF a candidate skill contains embedded credentials, invalid frontmatter, or broken relative links, THEN the skill-creator validator SHALL fail validation with exit code 1.

## BDD Scenarios

```gherkin
Feature: Agent Skill Creation and Validation

  @REQ-SKL-001
  Scenario: Valid skill passes structural and black-box validation
    Given a skill directory with compliant frontmatter and relative workflow links
    When the skill validation workflow executes
    Then the validator reports pass status with zero errors

  @REQ-SKL-002
  Scenario: Skill containing embedded credentials fails validation
    Given a skill directory containing a hardcoded API token literal
    When the skill validation workflow executes
    Then the validator rejects the artifact with exit code 1
```

## Black-Box Execution

- **Do not read** script source before running it; the scripts are tested black boxes.
- Run commands from the skill base directory (the folder containing this `SKILL.md`).
- Run the script with `--help` for options not listed below.
- Read the source only after a non-zero exit that stderr does not explain.

| Command | Parameters | Stdout | Exit codes |
|---|---|---|---|
| `python3 ./scripts/validate_skill.py "<skill-dir>"` | Positional skill directory | JSON report | 0 pass, 1 fail or error, 2 invalid option |
| `python3 ./scripts/package_skill.py "<skill-dir>" "<output-dir>"` | Skill directory; output directory optional | JSON report | 0 success, 1 failure, 2 invalid option |
