# Workflow 02: Context, Scope & Guards (`myspec-apply`)

1. **Load Context & Tools**:
   - Read the target specification or OpenSpec change artifacts.
   - Locate target code areas following the `tokensave-first` rule.
   - Read local `AGENTS.md` in all affected project folders.
   - Load the `dotnet-test-suite` plugin whenever the change defines test tasks, test execution, or test quality requirements.
2. **Strict Scope & Constitutional Implementation Gate (`Single-Reference Lock`, `SDD-009`)**:
   - Implement ONLY what is explicitly specified. Any out-of-scope requirement requires human approval via `qa`.
   - **Mandatory Constitutional Implementation Gate**: When `<spec_root>/Constitution.md` exists on disk, before executing or marking `[x]` on any `[RED]`, `[GREEN]`, or `[REFACTOR]` task in `tasks.md`, the executing agent and any delegated sub-agent (`dotnet-expert`, `angular-expert`, `python-expert`, `shell-expert`, `ddd-expert`, `cyber-security-expert`) MUST load the cited `<spec_root>/constitution/<NN-area>/<micro-file>.md` under `Single-Reference Lock` and verify that the authored test and code satisfy every cited `<PREFIX>-###` rule. `<spec_root>/Constitution.md` and `<spec_root>/constitution/**` are strictly read-only during `myspec-apply` unless `- Amends-Constitution:` is explicitly declared in `proposal.md`.
   - **CRITICAL PROHIBITION**: Except for the single mandatory initial `wip: <spec-name>` commit in Phase 1, intermediate task Git commits during the TDD execution loop (`[RED]`, `[GREEN]`, `[REFACTOR]`, `[DOC]`) are strictly prohibited in `myspec-apply`. Change folder relocation and `CHANGELOG.md` edits remain strictly prohibited. Archiving and changelog updates are delegated exclusively to `myspec-archive`.
3. **Fail-Closed Doc-Align Guard (REQ-003)**:
   - Check if the target change has `mode: doc-align` (in `proposal.md` or prompt).
   - If in `doc-align` mode:
     - STRICTLY FORBID editing any source or test files outside `spec_root` (e.g. `openspec/` or `specs/`).
     - ZERO CODE REWRITING ALLOWED. Alignment is strictly limited to documentation, briefs, and living specifications.
     - Any attempted file modification outside `spec_root` MUST BE BLOCKED IMMEDIATELY unless the user explicitly provided an override authorization (e.g. `override-doc-align`, `allow-code-rewrite`) in their prompt.
     - Use `DocAlignGuard` (from `doc_align_guard.py`) to enforce write permissions.

## Normative Requirements (EARS)
- WHILE executing in `doc-align` mode without an explicit override token, the Context Guard SHALL invoke `DocAlignGuard` to reject any file write outside `spec_root`.

## Behavioral Contract (BDD)
```gherkin
Feature: MySpec Apply Scope and Doc-Align Guards

  @REQ-APPLY-001
  Scenario: Doc-align mode blocks writes outside specification root
    Given an active change configured with doc-align mode and no user override
    When the executor checks write permission for a production source file
    Then the Fail-Closed Doc-Align Guard rejects the write outside spec_root

  @REQ-APPLY-002
  Scenario: Constitutional gate verifies cited rules before checking off a task
    Given a workspace containing a project Constitution and an active TDD task
    When the executor evaluates task completion under Single-Reference Lock
    Then the executor verifies every cited constitutional rule before marking the task complete
```
