# Workflow 02: Specification Root Selection via `qa` Skill (`myspec-init`)

- If user explicitly provided `--spec-root <openspec|specs>` in command arguments or prompt, adopt that selection directly without asking.
- Otherwise, **MANDATORY**: use the `qa` skill to ask the user to select the specification root / compatibility layer:
  - Ask exactly **one question per turn** using the `AskUserQuestion` tool.
  - Present structured multiple-choice options with `(Recommended)` prefix on the preferred choice.
  - Recommend `openspec` for greenfield projects or when `openspec/` already has equal or more documents.
  - Recommend `specs` when target project contains legacy sequential specifications in `specs/`.
  - Format options as the user's direct response:
    - `(Recommended) Use 'openspec' as specification root (modern OpenSpec atomic living specs: openspec/changes, openspec/specs)`
    - `Use 'specs' as specification root (legacy compatibility layer: specs/changes, specs/implemented)`
  - Wait for user choice before proceeding to scaffolding.

## Normative Requirements (EARS)
- WHERE `--spec-root` is explicitly supplied, the Root Selector SHALL adopt the supplied root without prompting.
- WHEN `--spec-root` is omitted, the Root Selector SHALL ask one multiple-choice `AskUserQuestion` prompt with `(Recommended)` on the preferred root.

## Behavioral Contract (BDD)
```gherkin
Feature: MySpec Init Specification Root Selection

  @REQ-INIT-001
  Scenario: Interactive selection defaults to openspec on greenfield repositories
    Given an uninitialized repository without a specification root configuration
    When the initialization workflow runs without an explicit spec root option
    Then the initialization workflow presents one single-question prompt recommending openspec
```
