# Workflow 03: Task Execution Loop with Strict TDD Enforcement (`myspec-apply`)

## Path A: OpenSpec Change Execution (`tasks.md`)
Execute each task in `tasks.md` strictly in sequential order:
1. **For TDD Test Tasks (`[RED]` / `[PHASE: RED]`)**:
   - Write the failing test only (unit, integration, or governance test), enforcing `the kiss-and-solid-principles skill` (`references/kiss-testing-and-technical-docs.md`: linear `Arrange -> Act -> Assert` / `GIVEN-WHEN-THEN`, zero branching or loops in test bodies, real domain objects and lightweight fakes over brittle mock choreography).
   - Run the test validation command using `dotnet-test-suite__run-tests` for .NET or native test runners.
   - Verify the test **FAILS** for the expected assertion reason. If it passes prematurely or fails with a syntax/import error, fix the test before proceeding.
   - Once verified failing, update the task checkbox in `tasks.md` from `- [ ] X.Y ...` to `- [x] X.Y ...`.
2. **For TDD Code Tasks (`[GREEN]` / `[PHASE: GREEN]`)**:
   - Write the minimum **KISS**-compliant production code necessary to pass the preceding RED test while adhering to **SOLID** OOP boundaries (`1:1` DI service/repository interfaces permitted; no DTO/Entity interfaces; Rule of Three `>= 3` for multi-class GoF hierarchies; Non-Simplification Security Floor).
   - Run the test validation command.
   - Verify the test **PASSES** (Green).
   - **TDD Retry Limit**: If the test remains RED after 3 implementation attempts, STOP and ask the human for guidance via `qa`.
   - Once verified green, update the checkbox in `tasks.md` to `- [x] X.Y ...`.
3. **For TDD Refactor Tasks (`[REFACTOR]` / `[PHASE: REFACTOR]`)**:
   - Refactor code and test structure (naming, deduplication, readability, removing accidental complexity per **KISS** and verifying **SOLID** cohesion) without altering external behavior.
   - Re-run the test suite and ensure all tests remain **GREEN**.
   - Once verified, update the checkbox in `tasks.md` to `- [x] X.Y ...`.
4. **For In-Code Documentation Tasks (`[DOC]` / `[PHASE: DOC]`)**:
   - Executed immediately following the completion of the `[REFACTOR]` phase for the unit's coding tasks.
   - Author or update in-code documentation directly within the implemented source and test files according to language-specific standards:
     - Per language, follow the `csharp-coding-standards`, `angular-coding-standards`, `python-coding-standards`, or `shell-scripting-standards` rules.
   - Enforce the 6 mandatory quality criteria (and `the kiss-and-solid-principles skill` *Minimum Viable Documentation*):
     1. **Concise**: Direct, compact explanations without fluff.
     2. **English Language**: Written entirely in standard technical English.
     3. **Formally Valid**: Conforming strictly to target language documentation specifications.
     4. **Exhaustive**: Comprehensively documents contracts, parameters, return types, exceptions, error conditions.
     5. **Development-Oriented Only**: Zero conversational preambles, marketing, or tutorials.
     6. **Non-Trivial**: Strictly avoid tautological comments (e.g. `// gets id`); explain *why* (invariants, edge cases) rather than restating *what*.
   - Validate documentation syntax and ensure the project linter/compiler passes with zero doc warnings.
   - Once verified, update the checkbox in `tasks.md` to `- [x] X.Y ...`.
5. **For Manual User Operations Tasks (`[MANUAL]` / `[PHASE: MANUAL]`) - MANDATORY HUMAN QA CONFIRMATION**:
   - When reaching a `[MANUAL]` task in `tasks.md`, **PAUSE EXECUTION IMMEDIATELY**.
   - Read `<changes_dir>/<change-id>/manual-steps.md` and display a clear, numbered summary reminder of the manual operations for the human user.
   - Await explicit human confirmation via `the qa skill` (`AskUserQuestion`) confirming that the manual operations have been executed before marking the checkbox `- [x]`.
   - Never auto-check a `[MANUAL]` task without positive human confirmation.
6. **For Database/SQL Tasks (`type: sql` / `type: schema`) - HUMAN GATING**:
   - If the task requires applying SQL modifications to a database, **PAUSE EXECUTION IMMEDIATELY**.
   - Generate the SQL script or migration commands and ask for explicit human confirmation before proceeding.
7. **Adaptive Stack Sub-Agent Delegation**:
   - Delegate complex stack-specific implementation or architectural verification to the matching stack expert agent (`dotnet-expert` via `dotnet-architect`, `angular-expert` via `angular-architect`, `python-expert` via `python-architect`, `shell-expert` via `shell-architect`, each operating under `Single-Reference Lock`).

## Path B: Legacy Specification Execution (Section 12 YAML Tasks)
Execute each task in Section 12 (Task Breakdown for Implementation) strictly in order:
- Execute `type: test` tasks (RED) -> verify assertion failure.
- Execute `type: code` tasks (GREEN) -> verify test passes green.
- Execute `type: refactor` tasks (REFACTOR) -> verify suite remains green.
- Follow human gating for SQL tasks and adaptive sub-agent delegation (`dotnet-expert`, `angular-expert`, `python-expert`, `shell-expert`).

## Normative Requirements (EARS)
- WHEN executing `[RED]` and `[GREEN]` tasks, the Task Execution Loop SHALL verify the failing assertion before implementation and halt for human guidance after 3 failed implementation attempts.
- WHEN encountering a `[MANUAL]` task, the Task Execution Loop SHALL pause and await explicit human confirmation via `AskUserQuestion` before marking the checkbox complete.

## Behavioral Contract (BDD)
```gherkin
Feature: MySpec Apply TDD Execution Loop

  @REQ-APPLY-003
  Scenario: Retry limit halts implementation after three consecutive failures
    Given a failing RED test with an active GREEN implementation task
    When three consecutive implementation attempts fail to turn the test green
    Then the Task Execution Loop halts and asks the human operator for guidance

  @REQ-APPLY-004
  Scenario: Manual task requires explicit human confirmation
    Given a change containing a MANUAL task and a manual-steps runbook
    When the execution loop reaches the MANUAL task
    Then the executor displays the runbook summary and waits for human confirmation before marking complete
```
