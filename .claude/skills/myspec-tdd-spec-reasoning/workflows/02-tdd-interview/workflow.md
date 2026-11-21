# Workflow 02: Dynamic Checklist & Mandatory 4-Pillar TDD Interview (`myspec-tdd-spec-reasoning`)

> [!IMPORTANT]
> **MANDATORY INVARIANT: Human QA Interview Cannot Be Skipped**
> The interactive interview with the human operator via `AskUserQuestion` (adhering strictly to `qa` skill rules: exactly **one question per turn**, concrete options with `(Recommended)` and write-in support) is **MANDATORY and MUST NEVER be skipped**, even when invoked with an existing brief or an apparently exhaustive user prompt.

1. **Clear Prompt / Pre-Existing Brief (Single-Question Confirmation)**:
   - When the user's prompt is completely clear or accompanied by an existing brief, do NOT silently skip Phase 2.
   - Present exactly **1 confirmation question** via `AskUserQuestion` containing a **concise summary** (2-4 bullet points) of the scope, behavior, and any modifications to prior consolidated specifications (`MODIFIED` / `REMOVED` / `RENAMED` requirements and scenarios).
   - If the user selects the confirmation option (e.g. `(Recommended)`), proceed to Phase 3.
2. **Write-In Free-Text Interception & Interview Restart**:
   - If the user provides input in the free-form text field (`write-in`), IMMEDIATELY restart the interview process, combining the original prompt with the free-text clarification and re-evaluating the 4 pillars.
   - The agent is strictly prohibited from advancing to Phase 3 when write-in text is provided without restarting and re-evaluating the specification context against the user's feedback.
3. **Ambiguous or Incomplete Prompt (Full 4-Pillar Interview)**:
   - If the prompt is underspecified or leaves design choices open, conduct the full 4-pillar interview (1 question per turn via `AskUserQuestion`):
     - **Pillar 1: Public Behaviors & Nominal Scenarios**: Elicit observable public contracts from caller perspective as Given/When/Then scenarios. Enumerate all positive paths (`P1..Pn`, at least 1 mandatory per unit).
     - **Pillar 2: Edge Cases, Boundaries, Forbidden Responsibilities (`BC-###`) & Invariants**: Boundary conditions (zero, min, max, empty, malformed, null), exception types, and error codes. For multi-context or boundary-sensitive changes, elicit `Owned Decisions`, `Forbidden Responsibilities` (Negative Ownership: what this capability MUST NEVER decide, compute, or mutate), and `External Decision References` (`<Outcome>Id`, `<Subject>Id` stored as evidence rather than embedded foreign models/PII), enforcing `BC-011` (never silently invent business/compensation policies; clarify via `the qa skill` or block fail-closed on `[NEEDS CLARIFICATION]`). Enumerate all negative paths (`N1..Nm`, at least 1 mandatory per unit).
     - **Pillar 3: Testability, Dependency Seams, Architecture Memory (`AR-###`), Mocking Policy & KISS/SOLID Balance**: Apply `the kiss-and-solid-principles skill` (`Single-Reference Lock`). Favor a **KISS-First** design and real domain objects/fakes over complex mocks; isolate statics with seams (`TimeProvider`, `IFileSystem`); enforce **SOLID** in OOP (`1:1` `IFooService`/`FooService` DI service/repository interfaces permitted, no DTO/Entity interfaces, and Rule of Three `>= 3` before multi-class GoF hierarchies). For multi-module or Saga changes, elicit physical module/ring boundaries (`AR-001`) and Coordinator/Saga non-authority invariants (`AR-018`). Confirm target test project and naming patterns.
     - **Pillar 4: Abuse Cases & Negative Security (STRIDE & Non-Simplification Security Floor)**: Evaluate security risks (STRIDE). If high-risk, enroll `cyber-security-expert`. Formulate abuse Given/When/Then contracts tagged with `- **Trait**: security`—never cite KISS to omit input validation, parameterized SQL, authorization, encryption, or security tests.
     - **Manual User Operations & Language Choice**: If the procedure requires manual steps by the human user (e.g. portal configuration, credential setup outside Git), prompt the human via `AskUserQuestion` for the preferred runbook language (**Italian** or **English**).
     - **Optional Free-Form Question**: Ask if any unstated architectural constraints or legacy quirks apply.

## Normative Requirements (EARS)
- IF the user submits free-form write-in text during Phase 2, THEN the Interview Gate SHALL restart the 4-pillar evaluation before advancing to Phase 3.

## Behavioral Contract (BDD)
```gherkin
Feature: MySpec TDD Spec Reasoning Mandatory Interview Gate

  @REQ-REASON-001
  Scenario: Clear prompt requires single confirmation question before generating brief
    Given a clear user prompt or pre-existing brief in Phase 2
    When the user confirms the single-question scope summary without write-in edits
    Then the interview workflow advances to Phase 3 brief generation

  @REQ-REASON-002
  Scenario: Write-in free text forces interview restart before Phase 3
    Given a user confirmation turn during Phase 2
    When the user submits write-in clarification text
    Then the interview workflow restarts the 4-pillar evaluation instead of advancing to Phase 3
```
