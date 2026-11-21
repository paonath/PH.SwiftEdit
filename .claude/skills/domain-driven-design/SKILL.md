---
name: domain-driven-design
description: Progressive-disclosure Domain-Driven Design (DDD) modelling skill governing the 8-step DDD Starter Modelling Process (Understand, Discover, Decompose, Strategize, Connect, Organise, Define, Code), EventStorming, Core Domain Charts, Context Mapping, Bounded Context Canvas v5, Aggregate Design Canvas v1.1, and SAP DDD Kata inside-out TDD workflows.
---

# Domain-Driven Design Skill (`domain-driven-design`)

Progressive-disclosure DDD architecture, socio-technical boundary modelling, and TDD specification bridge distilled from the DDD Crew Starter Modelling Process and SAP DDD Kata.

## 1. Progressive-Disclosure Loading Rules (`Single-Reference Lock`)

- Load this router (`SKILL.md`) first to classify the active modelling step or architectural question.
- **Single-Reference Lock**: Load at most **1** reference file from `references/` per active step into context (`<= 2` only when combining Step 7/8 with OpenSpec 6-artifact synthesis). Never bulk-load all reference files simultaneously.
- Mask any discovered credentials or personal data literals (`***REDACTED***`) per the `security-secrets-policy` rule and perform zero external runtime HTTP fetches.

## 2. The 8-Step DDD Starter Modelling Loop

Execute or re-enter the iterative modelling loop at the step matching the current design gap:

1. **Understand**: Align business goals, user impact, and value chain evolution (Business Model Canvas, Impact Mapping, Wardley Mapping).
2. **Discover**: Map domain events, commands, policies, hotspots, and scenarios collaboratively (EventStorming, Domain Storytelling, Example Mapping).
3. **Decompose**: Slice problem space into low-coupling Subdomains using Pivotal Events and Independent Service Heuristics (`ISH`).
4. **Strategize**: Plot Subdomains on a Core Domain Chart (`Business Differentiation` vs `Model Complexity`) to classify `Core`, `Supporting`, and `Generic` investments.
5. **Connect**: Design cross-context use cases via Domain Message Flow Modelling (`Command`, `Event`, `Query`; orchestration vs choreography).
6. **Organise**: Map socio-technical team topologies (`Mutually Dependent`, `Upstream/Downstream`, `Free`) and 9 Context Map patterns (`OHS`, `PL`, `CF`, `ACL`, `SK`, `Partnership`, `Customer/Supplier`, `Separate Ways`, `BBoM`).
7. **Define**: Specify each Bounded Context contract using the Bounded Context Canvas v5 (10 sections) and 15 Model Traits / Domain Roles.
8. **Code**: Model transactional consistency boundaries using the Aggregate Design Canvas v1.1 (9 sections), Vernon's 4 Rules, Value Objects, Domain Events, Hexagonal rings, and inside-out TDD.

## 3. Progressive-Disclosure Reference Catalog

| Reference Module | DDD Steps | Trigger Scope |
| :--- | :--- | :--- |
| `references/strategic-discovery-and-subdomains.md` | Step 1 (`Understand`), Step 3 (`Decompose`), Step 4 (`Strategize`) | Business Model Canvas, Impact Mapping, Wardley Mapping, Subdomains (`Core`/`Supporting`/`Generic`), Core Domain Charts, 6 Portfolio Archetypes, Independent Service Heuristics (`ISH`). |
| `references/eventstorming-and-collaborative-modelling.md` | Step 2 (`Discover`) | EventStorming (Big Picture, Process, Software Design), sticky color grammar, Pivotal Events, Hotspots, Domain Storytelling, Example Mapping (25-min rule/example cards), User Story Mapping. |
| `references/context-mapping-and-message-flow.md` | Step 5 (`Connect`), Step 6 (`Organise`) | Domain Message Flow (`Command`/`Event`/`Query`), 3 Team Relationships, 9 Context Map patterns (`OHS`, `PL`, `CF`, `ACL`, `SK`, `Partnership`, `C/S`, `Separate Ways`, `BBoM`), Intermediary Contexts (`Process Manager` vs `Choreography`), Team Topologies. |
| `references/bounded-context-canvas-and-roles.md` | Step 7 (`Define`) | Bounded Context Canvas v5 (10 mandatory sections), Use-Case Swimlanes (`Message In -> Decision -> Message Out`), 15 Model Traits (`Specification`, `Execution`, `Audit`, `Approver`, `Enforcer`, `Gateway`, etc.), `Brain Context` splitting, Ubiquitous Language. |
| `references/tactical-aggregates-and-clean-architecture.md` | Step 8 (`Code`) | Aggregate Design Canvas v1.1 (9 mandatory sections), Vernon's 4 Rules, Entities vs Value Objects vs Domain Events, `Corrective Policies`, Event Modeling (`Given-When-Then`), Evans Whirlpool, Hexagonal/Onion rings, `oop-design-patterns__oop-design-patterns` boundary. |
| `references/ddd-to-tdd-and-myspec-bridge.md` | Cross-Step Synthesis (`MySpec` & `TDD`) | SAP DDD Kata inside-out TDD loop (Value Objects -> Aggregate Root without I/O mocks -> ACL/Repository ports), 1:1 mapping into the 6 OpenSpec artifacts of `myspec-tdd-spec-reasoning`, STRIDE trust boundaries (`ACL`/`OHS`/`PL`), GDPR Domain Event pseudonymization. |

## 4. Specialist Handoff Contracts

- **`oop-design-patterns__oop-design-patterns` / `oop-architecture-expert` Boundary**: `domain-driven-design` defines *where* consistency boundaries lie (Subdomains, Bounded Contexts, Aggregates) and *what* domain invariants/events exist; delegate GoF creational/structural/behavioral pattern mechanics (`Strategy`, `State`, `Factory`, `Adapter`) and Rule of Three checks (`>= 3` variants) to `oop-design-patterns__oop-design-patterns`.
- **`security-expertise` / `cyber-security-expert` Boundary**: Map `Anticorruption Layer` (`ACL`), `Open-Host Service` (`OHS`), and `Published Language` (`PL`) directly to STRIDE Trust Boundaries, and enforce GDPR Art. 5/17/25 pseudonymization (`SubjectId` or KMS-peppered HMAC-SHA256, zero raw PII) in immutable Domain Events.
- **EARS & BDD Integration (`the ears-syntax-standards skill` & `the bdd-gherkin-specifications skill`)**: In AI-to-AI workflows, obligatorily load `the ears-syntax-standards skill` and `the bdd-gherkin-specifications skill`. Map Ubiquitous business rules to canonical EARS patterns and concrete scenarios to declarative Gherkin BDD (Given-When-Then), using behavioral schemas in human discussions.

## 5. Behavioral Contracts (EARS & BDD)

- The domain-driven-design skill SHALL enforce Single-Reference Lock by loading at most one reference module per modelling step.
- WHEN modelling cross-context contracts or domain rules in AI-to-AI workflows, the domain-driven-design skill SHALL enforce canonical EARS syntax via ears-syntax-standards and declarative Gherkin via bdd-gherkin-specifications.
- IF an immutable Domain Event contains raw PII or direct cross-aggregate object references, THEN the domain-driven-design skill SHALL reject the model and require pseudonymous SubjectId identifiers.

```gherkin
Feature: Domain-Driven Design Progressive Disclosure and Modelling Guards
  @REQ-DDD-001
  Scenario: Model a Bounded Context using EARS and BDD contracts
    Given a Core subdomain identified through EventStorming and Core Domain Charts
    When the modeller defines Bounded Context invariants and Aggregate state transitions
    Then at most one reference module is loaded per active step
    And domain rules map to EARS requirements and declarative Gherkin scenarios

  @REQ-DDD-002
  Scenario: Reject raw PII in Domain Events and cross-aggregate object links
    Given a proposed Domain Event containing unredacted personal email attributes
    When the STRIDE and GDPR boundary guard evaluates the event schema
    Then the event schema is rejected in favor of pseudonymous SubjectId references
```
