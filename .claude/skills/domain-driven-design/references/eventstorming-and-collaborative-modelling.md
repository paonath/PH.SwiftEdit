---
module: eventstorming-and-collaborative-modelling
ddd_steps: Step 2 (Discover)
sources: ddd-starter-modelling-process, eventstorming-glossary-cheat-sheet, domain-storytelling, example-mapping
---

# EventStorming & Collaborative Domain Modelling

Self-contained progressive-disclosure reference for Step 2 (`Discover`).

## 1. EventStorming sticky Grammar & Visual Causality

Enforce the canonical sticky colour grammar and causal flow (`Actor -> Command -> System/Aggregate -> Domain Event -> Policy -> Read Model / HotSpot`):

| Sticky Element | Canonical Colour | Linguistic Form | Modelling Invariant |
| :--- | :--- | :--- | :--- |
| **Domain Event** | Orange | Past-tense verb (`OrderPlaced`, `PaymentFailed`) | Observable state fact relevant to domain experts |
| **Command** | Blue | Imperative verb (`PlaceOrder`, `ApproveLoan`) | User or system intention that may be accepted or rejected |
| **Actor / Persona** | Small Yellow | Specific role noun (`Buyer`, `RiskOfficer`) | Role initiating a Command within a concrete scenario |
| **Policy / Process** | Lilac / Purple | Reactive rule (`Whenever [Event] Then [Command]`) | Automated or manual reaction bridging two events/contexts |
| **Aggregate / System** | Pale Yellow / Pink | Noun (`Order` Aggregate, `StripeGateway` External System) | Consistency boundary or third-party dependency |
| **Read Model / UI** | Green | Noun phrase (`CheckoutSummaryView`) | Projected data required by an Actor to make a decision |
| **Hotspot (`HotSpot`) / Question** | Red / Magenta | Conflict, ambiguity, or bottleneck note | High-value risk or unresolved business rule requiring attention |

## 2. Three EventStorming Workshop Scopes

| Workshop Scope | Goal & Participants | Primary Sticky Focus | Output Artefact |
| :--- | :--- | :--- | :--- |
| **1. Big Picture** | Align business & tech across the entire value stream | Domain Events, Actors, External Systems, HotSpots, Pivotal Events | End-to-end timeline + candidate Subdomains |
| **2. Process Modelling** | Map cross-context causal workflows and policies | Commands, Events, Policies (`Whenever/Then`), Read Models | Verified causal flow ready for Step 5 (`Connect`) |
| **3. Software Design** | Model transactional invariants inside a single Bounded Context | Aggregates, Commands, Events, Enforced Invariants | Candidate Aggregate roots ready for Step 8 (`Code`) |

## 3. Pivotal Events, Swimlanes & Boundary Discovery Heuristics

- **Pivotal Events**: Identify the 3–7 major Domain Events that mark irreversible business phase transitions (e.g., `QuoteAccepted`, `OrderShipped`, `ClaimSettled`). Vertical lines drawn through Pivotal Events define natural Subdomain and Bounded Context boundaries.
- **Temporal Milestones & Swimlanes**: Group parallel activities into horizontal swimlanes by department, actor persona, or lifecycle stage; look for terminology changes across swimlanes to detect polysemic Ubiquitous Language boundaries.
- **HotSpot Triage**: Cluster Red HotSpots around specific Pivotal Events or Policies to locate hidden model complexity before Step 4 (`Strategize`).

## 4. Domain Storytelling, Example Mapping & User Story Mapping

Combine EventStorming with targeted collaborative discovery techniques when scenarios or rules require deeper disambiguation:

| Technique | When to Use | Core Mechanics & Timebox | Output to Spec / TDD |
| :--- | :--- | :--- | :--- |
| **Domain Storytelling** | Stakeholders think in concrete actor-to-actor narratives rather than abstract events | Record numbered pictographic sentences: `Actor A --[verb: work object]--> Actor B via Medium` | Concrete happy-path and exception narratives + Ubiquitous Language nouns/verbs |
| **Example Mapping** | A user story or Policy has complex, ambiguous business rules | **25-minute timebox** with 4 card colours: **Yellow** (`Story`), **Blue** (`Rule` in EARS syntax via `the ears-syntax-standards skill`), **Green** (`Concrete Example` in Gherkin BDD via `the bdd-gherkin-specifications skill`), **Red** (`Question` / unknown). If `> 3-4` Blue rules or many Red questions remain at 25 min, split the story | Blue cards -> canonical EARS requirements (`ears-syntax-standards`); Green cards -> Gherkin `GIVEN`/`WHEN`/`THEN` (`P#`/`N#`) scenarios |
| **User Story Mapping** | Slicing an end-to-end process into thin vertical release increments | Horizontal backbone = User Activities & Tasks; Vertical slices = `Walking Skeleton` (MVP) -> subsequent releases | Prioritised implementation slices for `tasks.md` |
