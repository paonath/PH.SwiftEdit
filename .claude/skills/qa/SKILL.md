---
name: 'qa'
description: 'Runs interactive Q&A sessions. Use for human or agent-to-agent requirement gathering and clarification.'
---

# Q&A Skill

## Scope

- The QA Skill SHALL conduct step-by-step interactive Q&A sessions for human-agent and agent-agent interactions.

## Principle 1: Build the Checklist First

- WHEN a Q&A session starts, the QA Skill SHALL output a checklist of all required question areas.
- WHEN a user or sub-agent answers an item, the QA Skill SHALL update the checklist state (`[X]`, `[ ]`, `[~]`).

```markdown
**Checklist** (items to cover):
- [ ] 1. <Question area 1>
- [ ] 2. <Question area 2>
```

## Principle 2: Strict Single Question Per Turn

- The QA Skill SHALL ask exactly one question per turn without bundling multiple questions.
- The QA Skill SHALL include multiple-choice options, an open free-text option, and a skip escape hatch in every question.

## Principle 3: Interaction Formats

- WHERE `AskUserQuestion` is available for human interaction, the QA Skill SHALL present questions and options through `AskUserQuestion`.
- WHERE agent-to-agent interaction runs over `SendMessage`, the QA Skill SHALL format questions in markdown and require option-letter or clear free-text replies:

```markdown
**[Context / Why this matters]**
<1-2 sentence explanation of why this information is needed>
**Question N / TOTAL: <question text>**
Suggested answers:
A) <option 1>
B) <option 2>
C) Skip for now / I do not know
Free answer: Type your own response
```

## Principle 4: Handling Answers and Ambiguity

- WHEN an answer is unambiguous, the QA Skill SHALL mark the checklist item `[X]` and advance to the next item.
- IF a human or sub-agent provides an ambiguous answer, THEN the QA Skill SHALL ask targeted follow-up questions until resolved.
- IF a new answer contradicts earlier assumptions, THEN the QA Skill SHALL reopen affected checklist items.
- WHEN all checklist items reach `[X]`, the QA Skill SHALL summarize resolved answers and confirm before closing.

## Principle 5: Enrich Questions When Needed

- The QA Skill SHALL inspect attached documents, codebase files, or specialist skills before asking questions.
- IF local context is insufficient, THEN the QA Skill SHALL run web searches and cite the source.

## Principle 6: Pre-Send Validation

- WHEN preparing an outgoing question, the QA Skill SHALL verify a question mark, multiple-choice options, a free-text option, and single-question count.
- IF pre-send validation detects any violation, THEN the QA Skill SHALL fix the draft before dispatching.

## Behavioral Scenarios

```gherkin
Feature: Interactive Q&A Clarification Protocol
  @REQ-QA-001
  Scenario: Single question per turn with checklist tracking
    Given a user prompt with two unresolved configuration choices
    When the QA Skill initiates the clarification session
    Then the QA Skill outputs a two-item checklist and asks only the first question

  @REQ-QA-002
  Scenario: Reject bundled questions during pre-send validation
    Given a draft message containing two distinct questions
    When the QA Skill executes pre-send validation
    Then the QA Skill removes the extra question before sending the prompt
```

## Notes

- Keep explanations brief and mark obvious questions `[X]` in the checklist without asking them.
- Adhere to `tmp-files-policy` if temporary context files become strictly necessary.
