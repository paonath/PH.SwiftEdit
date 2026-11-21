---
name: agent-self-learning
description: "Manages durable project knowledge via Lessons (.agents/Lessons) and Memories (.agents/Memories) using versioned, deduplicated, governable patterns. Triggers: agent-self-learning, lesson, learn, record lesson, memory, retro, mistake."
---

# Agent Self-Learning System (`agent-self-learning` — Progressive Disclosure Router)

Maintains versioned, deduplicated project learning artifacts under `.agents/Lessons/` and `.agents/Memories/`.
Enforces `Single-Reference Lock`: read [rules.md](rules.md) plus only the single active `workflows/NN-*/workflow.md` for the current operation.

## Artifact Types

| Type | Location | Trigger |
|---|---|---|
| Lesson | `.agents/Lessons/` | A mistake was made and corrected |
| Memory | `.agents/Memories/` | Durable architectural fact or constraint discovered |

## Decision Tree & Workflow Routing Table

1. Was a mistake made and corrected? -> [01-record-lesson](workflows/01-record-lesson/workflow.md)
2. Was a durable architectural constraint confirmed? -> [02-record-memory](workflows/02-record-memory/workflow.md)
3. Reusing patterns or resolving conflicts? -> [03-reuse-and-conflict-resolution](workflows/03-reuse-and-conflict-resolution/workflow.md)
4. Delegating to or consolidating subagents? -> [04-subagent-contract](workflows/04-subagent-contract/workflow.md)

| Resource | Path | Scope |
|---|---|---|
| **Rules** | [rules.md](rules.md) | `PatternId`, `PatternVersion`, `Status` (`active`/`deprecated`/`blocked`), Safety Gate, file naming. |
| **01** | [01-record-lesson](workflows/01-record-lesson/workflow.md) | Lesson triggers, dedupe check, required sections, `examples/lesson-template.md`. |
| **02** | [02-record-memory](workflows/02-record-memory/workflow.md) | Memory triggers, dedupe check, required sections, `examples/memory-template.md`. |
| **03** | [03-reuse-and-conflict-resolution](workflows/03-reuse-and-conflict-resolution/workflow.md) | Reuse priority, `Supersedes` conflict handling, `Status: blocked` confirmation gate. |
| **04** | [04-subagent-contract](workflows/04-subagent-contract/workflow.md) | `LessonsSuggested`/`MemoriesSuggested`/`ReasoningSummary` block and orchestrator consolidation. |

## Core Requirements (EARS)

- The agent-self-learning skill SHALL enforce `Single-Reference Lock` by loading `rules.md` and one active workflow file per operation.
- WHEN recording a lesson or memory, the agent-self-learning skill SHALL deduplicate against existing artifacts before writing a versioned pattern.
- IF an artifact carries `Status: blocked`, THEN the agent-self-learning skill SHALL forbid applying or recommending it without validation evidence and explicit user confirmation.
- WHEN delegating to subagents, the agent-self-learning skill SHALL require the `LessonsSuggested`, `MemoriesSuggested`, and `ReasoningSummary` output block.

## Behavioral Scenarios

```gherkin
Feature: Versioned Project Lessons and Memories

  @REQ-ASL-001
  Scenario: Deduplicate and version a corrected defect into a lesson artifact
    Given an existing active lesson covers a closely related root cause
    When a mistake is corrected and lesson recording runs
    Then the existing lesson artifact updates in place with an incremented PatternVersion

  @REQ-ASL-002
  Scenario: Block application of unsafe blocked patterns
    Given an existing pattern artifact carries Status blocked
    When pattern reuse evaluation runs without explicit user confirmation
    Then the agent-self-learning skill rejects applying or recommending the blocked pattern
```
