---
name: create-agentsmd
description: 'Prompt for generating an AGENTS.md file for a repository'
---

# Create High-Quality `AGENTS.md` File (`create-agentsmd` — Progressive Disclosure Router)

Creates a complete, accurate `AGENTS.md` at the root of the repository (or monorepo subprojects) following public guidance at https://agents.md/ and the `markdown-style-ai` rule.
Enforces `Single-Reference Lock`: load one `workflows/NN-*/workflow.md` phase file (and [templates.md](references/templates.md) only during drafting) at a time.

## What is AGENTS.md?

`AGENTS.md` is an open Markdown format that serves as a "README for agents" — a predictable place for detailed technical context, build/test commands, and conventions that coding agents need without cluttering a human-focused `README.md`.

## Key Principles

- **Agent-focused**: Detailed, executable technical instructions for automated coding tools.
- **Complements `README.md`**: Adds agent-specific workflow context rather than duplicating human docs.
- **Standardized location**: Placed at repository root (or subproject roots for monorepos, where the closest `AGENTS.md` wins).
- **Ecosystem compatibility**: Works across 20+ AI coding tools and agents.

## Workflow Routing Table

Execute the 3 phases sequentially (one workflow file in context at a time):

| Phase | Workflow / Reference | Scope |
|---|---|---|
| **01** | [01-analyze-repository](workflows/01-analyze-repository/workflow.md) | `tokensave-first` repository discovery, build/CI/script extraction, and root vs monorepo scoping. |
| **02** | [02-author-agentsmd](workflows/02-author-agentsmd/workflow.md) | Required setup, essential & optional sections, drafting with [templates.md](references/templates.md). |
| **03** | [03-verify-and-finalize](workflows/03-verify-and-finalize/workflow.md) | Command execution verification, best practices, and `markdown-style-ai` quality audit. |
| **Ref** | [templates.md](references/templates.md) | Starting `AGENTS.md` template and real-world monorepo working example. |

## Formal Requirements (EARS)

- The create-agentsmd skill SHALL author repository instructions adhering to the `tokensave-first` rule and the `markdown-style-ai` rule.
- WHERE a repository contains multiple subprojects, the create-agentsmd workflow SHALL scope root and nested `AGENTS.md` files so the closest file governs each directory.
- IF a candidate command fails execution verification or lacks repository evidence, THEN the create-agentsmd workflow SHALL replace or remove that command before finalizing.

## BDD Scenarios

```gherkin
Feature: Repository AGENTS.md Generation

  @REQ-AMD-001
  Scenario: Verified repository discovery produces compliant AGENTS.md
    Given an indexed project repository with build and test scripts
    When the create-agentsmd workflow completes discovery, authoring, and verification
    Then the generated AGENTS.md file documents verified commands under markdown-style-ai rules

  @REQ-AMD-002
  Scenario: Unverified build command is rejected during audit
    Given a draft AGENTS.md containing an unverified shell command
    When the verification workflow executes command validation
    Then the validator flags the unverified command for correction before completion
```
