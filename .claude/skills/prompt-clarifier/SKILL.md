---
name: prompt-clarifier
description: |
  Pre-analyzes every user prompt before execution to ensure it is actionable. Use when: (1) starting to process any user request in chat, (2) a prompt is ambiguous, incomplete, or has multiple valid interpretations, (3) clarification is needed before taking an irreversible or complex action, (4) re-engineering an unclear prompt iteratively with user feedback.
---

# Prompt Clarifier (`prompt-clarifier` — Progressive Disclosure Router)

- The Prompt Clarifier SHALL pre-analyze every incoming prompt against Goal, Scope, and Constraints before execution.
- The Prompt Clarifier SHALL enforce `Single-Reference Lock` by loading only the active `workflows/NN-*/workflow.md` branch for the current decision.

## Phase 1: Quick Analysis (Always First)

- WHERE a prompt is a trivial single-action query ("what is X?", "list files in Y"), the Prompt Clarifier SHALL proceed directly without creating a clarification file.
- WHEN all three criteria (**Goal**, **Scope**, **Constraints**) pass, the Prompt Clarifier SHALL execute `workflows/01-clear-prompt-proceed/workflow.md`.
- IF any criterion fails, THEN the Prompt Clarifier SHALL enter `workflows/02-clarification-loop/workflow.md`.

| Criterion | Question to ask |
|---|---|
| **Goal** | Is there a single, unambiguous desired outcome? |
| **Scope** | Are the affected files, projects, or systems clear? |
| **Constraints** | Are there conflicting requirements or missing context that block execution? |

## Workflow Routing Table

| Condition | Workflow | Scope |
|---|---|---|
| All 3 criteria pass (**CLEAR**) | [01-clear-prompt-proceed](workflows/01-clear-prompt-proceed/workflow.md) | Deep intent/risk analysis, relevant skill loading, and execution. |
| Any criterion fails (**UNCLEAR**) | [02-clarification-loop](workflows/02-clarification-loop/workflow.md) | Single `clarification-{topic}.md` file, 1 question/iteration, verbatim prompt preservation, max 3 rounds (`## Assumptions` fallback). |

## Behavioral Scenarios

```gherkin
Feature: Prompt Disambiguation and Clarification Routing
  @REQ-PC-001
  Scenario: Unclear prompt converges through single-file clarification loop
    Given an ambiguous user prompt lacking target scope
    When the Prompt Clarifier conducts one focused clarification round and receives scope details
    Then the Prompt Clarifier updates the re-engineered prompt and advances to Phase 2A

  @REQ-PC-002
  Scenario: Terminate clarification loop after three rounds with documented assumptions
    Given an unresolved prompt after three consecutive clarification rounds
    When the Prompt Clarifier evaluates the third response
    Then the Prompt Clarifier stops iterating and records assumptions under Assumptions
```
