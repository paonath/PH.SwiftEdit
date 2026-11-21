# Workflow 04: Subagent Contract & Consolidation (`agent-self-learning`)

## Subagent Contract

Every subagent brief MUST instruct the subagent to append this block at the end of its final response:

```text
LessonsSuggested:
- <title>: <reason>   (or "none")

MemoriesSuggested:
- <title>: <reason>   (or "none")

ReasoningSummary:
- <concise rationale for decisions, trade-offs, and confidence>
```

## Orchestrator Consolidation

1. The subagent-contract workflow SHALL require every subagent brief to mandate the `LessonsSuggested`, `MemoriesSuggested`, and `ReasoningSummary` response block.
2. WHEN subagents finish, the orchestrating agent SHALL consolidate and deduplicate suggested lessons and memories before finalizing artifacts in `.agents/Lessons/` and `.agents/Memories/`.
3. IF consolidation deprecates or blocks an existing pattern, THEN the orchestrating agent SHALL inform the user of the updated pattern status before task completion.
