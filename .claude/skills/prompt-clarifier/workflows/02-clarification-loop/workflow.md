# Workflow 02: Phase 2B — Unclear Prompt Clarification Loop (`prompt-clarifier`)

## Step 1: Create clarification file
- WHEN entering Phase 2B for a non-trivial prompt, the Prompt Clarifier SHALL create one `clarification-{topic}.md` file in the workspace root (or `_clarifications/`) using [template.md](template.md).

## Step 2: Ask the user
- The Prompt Clarifier SHALL ask one focused question per iteration targeting the highest-impact ambiguity without bundling questions.

## Step 3: Incorporate the response
- WHEN the user replies, the Prompt Clarifier SHALL edit the existing `clarification-{topic}.md` file to fill `### User Response`, `### Re-engineered Prompt`, and `### Status`.

## Step 4: Re-evaluate
- WHEN the re-engineered prompt passes Phase 1 criteria, the Prompt Clarifier SHALL mark `[x] Clear` and transition to [01-clear-prompt-proceed](../01-clear-prompt-proceed/workflow.md).
- IF the re-engineered prompt stays unclear before round 3, THEN the Prompt Clarifier SHALL append a new `## Iteration N` section in the same file and repeat Step 2.

## Rules

- **Never create a new clarification file per iteration** — always edit the existing `clarification-{topic}.md` file.
- **One question per iteration** — do not bundle multiple questions.
- **Preserve the original prompt verbatim** in the file; edit only `### Re-engineered Prompt`.
- **Stop iterating after 3 rounds** — halt clarification after round 3 and document assumptions.
- IF ambiguity persists after 3 iterations, THEN the Prompt Clarifier SHALL document the chosen interpretation under `## Assumptions` and proceed.
- **Do not create a clarification file for trivial prompts** — simple single-action queries require no clarification file.

## Clarification File Naming

| Prompt topic | File name |
|---|---|
| "add a login endpoint" | `clarification-add-login-endpoint.md` |
| "refactor the service layer" | `clarification-refactor-service-layer.md` |
| "generate DTO for User" | `clarification-generate-user-dto.md` |
