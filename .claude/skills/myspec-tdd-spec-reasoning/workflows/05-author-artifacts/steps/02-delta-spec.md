# Step 02: Author Capability Delta `specs/<capability>/spec.md`

- Delta requirements (`## ADDED Requirements`, `## MODIFIED Requirements`, `## REMOVED Requirements`, `## RENAMED Requirements`).
- The Delta Spec Author SHALL formulate `ADDED` and `MODIFIED` requirements in canonical EARS syntax (`the ears-syntax-standards skill`: Ubiquitous, Event, State, Optional, Unwanted, Complex) using English RFC 2119 imperative keywords bounded to <= 500 characters (excluding reconciliation directives and `Security-Waiver:` lines).
- In `## MODIFIED Requirements`, existing scenarios from `<specs_dir>/<capability>/spec.md` are preserved additively by default; use `- **REMOVED-SCENARIO**: \`<Scenario Title>\` — **Reason**: <justification>` to remove obsolete scenarios and `- **RENAMED-SCENARIO**: FROM \`<Old Title>\` TO \`<New Title>\`` to rename scenarios (directives are automatically stripped upon merge).
- In `## REMOVED Requirements`, provide `### Requirement: <Title>` and `**Reason**: <justification>`.
- In `## RENAMED Requirements`, provide `- FROM: \`### Requirement: <Old Title>\`` and `- TO: \`### Requirement: <New Title>\`` pairs.
- Every `ADDED` requirement and every post-merge `MODIFIED` requirement must satisfy the Path Coverage Rule (`>= 1 P#` and `>= 1 N#` `#### Scenario:` with `- **Path**:`, `- **GIVEN**`, `- **WHEN**`, and `- **THEN**`) adhering to `the bdd-gherkin-specifications skill`.
- Negative boundary and abuse tests declare `- **Trait**: security`. Modifying, renaming, or removing any requirement or scenario that carries `SEC-xxx`, `BC-xxx`, `AR-xxx`, or `- **Trait**: security` in the living spec requires an explicit `Security-Waiver: <justification>` (Rule G3).
- Include `## Purpose` (>= 50 chars) and `### Requirement: REQ-NNN <Name>` headings, per template.

## Normative Requirements (EARS)
- IF a delta modifies, renames, or removes a living spec item tagged with `SEC-xxx`, `BC-xxx`, `AR-xxx`, or security trait, THEN the Delta Spec Author SHALL require an explicit `Security-Waiver:` justification.

## Behavioral Contract (BDD)
```gherkin
Feature: MySpec Delta Specification EARS and Rule G3 Compliance

  @REQ-REASON-003
  Scenario: Valid delta specification enforces EARS syntax and P and N path coverage
    Given an affected capability requiring new or modified behavior
    When the specification author drafts the delta spec artifact
    Then every requirement uses canonical EARS syntax with at least one positive and one negative scenario

  @REQ-REASON-004
  Scenario: Security requirement alteration without waiver violates Rule G3
    Given a consolidated living specification containing a security-traited requirement
    When a delta attempts to remove that requirement without a Security-Waiver line
    Then the validation rules reject the unwaived removal under Rule G3
```
