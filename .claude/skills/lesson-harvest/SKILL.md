---
name: lesson-harvest
description: Extracts lessons, bug fix resolutions, and user corrections from the current conversation and updates .agents/Lessons/ using agent-self-learning.
---

# Lesson Harvest

## Procedure

1. Review current conversation history for bug resolutions, user corrections, or new architectural insights.
2. Activate the `agent-self-learning` skill.
3. Format identified lessons into standardized lesson files under `.agents/Lessons/`.
4. Register architectural decisions in TokenSave memory using `tokensave_record_decision`.

## Requirements (EARS)

- WHEN lesson harvesting starts, the lesson-harvest skill SHALL review conversation history for bug resolutions, user corrections, and architectural insights.
- The lesson-harvest skill SHALL delegate lesson creation and deduplication to the `agent-self-learning` skill.
- WHEN a repeatable defect resolution or user correction is identified, the lesson-harvest skill SHALL record a standardized lesson under `.agents/Lessons/`.
- WHERE a durable architectural decision is confirmed, the lesson-harvest skill SHALL persist that decision using `tokensave_record_decision`.
- IF no repeatable defect, user correction, or architectural insight occurred, THEN the lesson-harvest skill SHALL skip file creation and report zero new lessons.

## Behavioral Scenarios

```gherkin
Feature: Session Lesson Harvesting

  @REQ-LHRV-001
  Scenario: Harvest resolved defect into a versioned lesson
    Given the conversation contains a resolved defect and a confirmed architectural decision
    When the agent runs lesson harvesting
    Then a deduplicated lesson artifact is saved under .agents/Lessons/ via agent-self-learning
    And the confirmed architectural decision is persisted via tokensave_record_decision

  @REQ-LHRV-002
  Scenario: Skip lesson creation when no learning event occurred
    Given the conversation contains only routine queries without defects or architectural decisions
    When the agent runs lesson harvesting
    Then no new lesson artifact is written
    And the empty harvest outcome is reported
```
