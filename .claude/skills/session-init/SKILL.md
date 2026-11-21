---
name: session-init
description: Bootstraps a work session by calling TokenSave session start, recalling active project decisions, checking git status, and loading recent lessons.
---

# Session Init

## Procedure

1. Activate the `tokensave-memory-bridge` skill and execute `tokensave_session_start`.
2. Recall active project decisions and recent code area modifications using `tokensave_session_recall`.
3. Check repository status with `git status` and `git branch --show-current`.
4. Scan `.agents/Lessons/` for relevant project gotchas and constraints.
5. Summarize session starting context for the user.

## Requirements (EARS)

- The session-init skill SHALL activate the `tokensave-memory-bridge` skill and execute `tokensave_session_start` at session startup.
- WHEN `tokensave_session_start` returns baseline context, the session-init skill SHALL query active decisions and code areas via `tokensave_session_recall`.
- The session-init skill SHALL inspect repository state using `git status` and `git branch --show-current`.
- WHERE `.agents/Lessons/` exists, the session-init skill SHALL scan lesson entries for applicable project constraints before summarizing context.
- IF `.tokensave/` is absent or uninitialized, THEN the session-init skill SHALL report the missing index state before summarizing git status and lessons.

## Behavioral Scenarios

```gherkin
Feature: Session Initialization

  @REQ-SINIT-001
  Scenario: Bootstrap session with initialized TokenSave memory
    Given the workspace contains an initialized TokenSave index and lesson artifacts
    When the agent executes session initialization
    Then TokenSave session tracking starts and recalls active project decisions
    And repository branch status and relevant lessons are summarized

  @REQ-SINIT-002
  Scenario: Report uninitialized TokenSave index during startup
    Given the workspace lacks a TokenSave index directory
    When the agent executes session initialization
    Then the session-init skill reports the missing TokenSave index state
    And repository git status and existing lessons remain summarized
```
