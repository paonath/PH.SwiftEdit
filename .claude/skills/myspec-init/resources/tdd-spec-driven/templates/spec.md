# Spec Delta: [Capability Name]

## Purpose
[Describe what this capability achieves in 1-2 sentences (50+ characters).]

## ADDED Requirements
<!-- When <spec_root>/Constitution.md exists (SDD-001), cite active [<PREFIX>-###] rule IDs (e.g. [AR-001][BC-001][SEC-001]). -->

### Requirement: REQ-001 [Requirement Name]
The system SHALL [normative statement of behavior under 500 characters].

#### Scenario: P1 [Nominal Scenario Name]
- **Path**: P1
- **Trait**: positive
- **GIVEN** [precondition]
- **WHEN** [action]
- **THEN** [expected result]

#### Scenario: N1 [Negative Boundary Scenario]
- **Path**: N1
- **Trait**: negative
- **GIVEN** [invalid input or state]
- **WHEN** [action]
- **THEN** [rejection or error response]

## MODIFIED Requirements
<!-- When modifying an existing requirement, existing scenarios are preserved additively by default.
     Use optional directives in the requirement body (stripped upon merge):
     - **REMOVED-SCENARIO**: `<Scenario Title>` — **Reason**: <justification>
     - **RENAMED-SCENARIO**: FROM `<Old Title>` TO `<New Title>` -->

## REMOVED Requirements
<!-- When removing a requirement, provide ### Requirement: <Title> and **Reason**: <justification> -->

## RENAMED Requirements
<!-- When renaming a requirement, provide bullet pairs:
     - FROM: `### Requirement: <Old Title>`
     - TO: `### Requirement: <New Title>` -->
