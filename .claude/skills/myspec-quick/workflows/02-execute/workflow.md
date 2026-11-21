# Workflow 02: Autonomous Point-by-Point Execution (`02-execute`)

## Rules (100% Non-Interactive)
- **Zero User Prompts**: NEVER invoke `AskUserQuestion` in `Workflow 02` (this prohibition applies equally to any delegated specialist sub-agent).
- **Zero `<changes_dir>/` Artifacts**: NEVER scaffold a 6-artifact directory under `<changes_dir>/`.
- **Constitutional & Security Floor (`SDD-009`, `SEC-001..012`)**: Load at most 1 cited `<spec_root>/Constitution.md` micro-file per step under `Single-Reference Lock`. Enforce `the kiss-and-solid-principles skill` (KISS-First, SOLID OOP, and Non-Simplification Security Floor: `CWE-20`, `CWE-22`, `CWE-78` `shell=False`, `CWE-89`, `CWE-798`).
- **Fail-Closed `Rule G3` Guard**: Preserve any existing `[SEC-###]` or `- **Trait**: security` control intact unless an explicit `Security-Waiver:` was approved by the human in `Workflow 01`.

## Steps
1. **Point-by-Point Implementation**:
   - Execute EVERY item of the Disambiguated Prompt sequentially across production code, scripts, configurations, and tests (`SDD-007` scope discipline: no unrelated refactoring).
   - When touching specialized stack or security boundaries, optionally delegate scoped non-interactive work to canonical experts (`dotnet-expert`, `angular-expert`, `python-expert`, `shell-expert`, `ddd-expert`, `cyber-security-expert`) passing the finalized Disambiguated Prompt with `AskUserQuestion` strictly forbidden.
   - Perform an in-flight 6-category **STRIDE** check (`Spoofing`, `Tampering`, `Repudiation`, `Information Disclosure`, `Denial of Service`, `Elevation of Privilege`) for persistence in `Workflow 03`.
2. **Closed-Loop Build & `P#`/`N#` Test Verification**:
   - Run stack build and targeted test suites covering at least 1 positive (`P#`) and 1 negative/boundary (`N#`) path on touched logic, plus secret hygiene (`SECRET_PATTERNS`).
   - If any build or test fails, autonomously diagnose, fix, and re-run in a closed self-repair loop (up to `3` attempts; NEVER delete or weaken assertions to pass). If an external toolchain error still fails after `3` attempts, halt fail-closed before `Workflow 03` with a diagnostic report.
3. **Transition**:
   - Once build and all `P#`/`N#` tests return `exit 0`, unload this file and immediately load `workflows/03-reconcile/workflow.md`.

## Normative Requirements (EARS)
- WHILE executing Workflow 02, the Autonomous Executor SHALL invoke zero `AskUserQuestion` calls and preserve every existing security control lacking an explicit waiver.
- IF a build or test check fails during Workflow 02, THEN the Autonomous Executor SHALL iterate self-repair up to 3 attempts and halt fail-closed if errors persist.

## Behavioral Contract (BDD)
```gherkin
Feature: MySpec Quick Autonomous Execution

  @REQ-QUICK-001
  Scenario: Stop interview and execute with recommended defaults
    Given an active specification workspace with resolved index and constitution rules
    When the user selects STOP during the Workflow 01 interview
    Then the quick runner applies recommended defaults and completes autonomous verification

  @REQ-QUICK-002
  Scenario: Preserve security controls when no waiver is approved
    Given an existing security requirement in the living specification
    When a quick execution lacks an explicit human-approved Security-Waiver
    Then the quick runner rejects removal and preserves the existing security control
```
