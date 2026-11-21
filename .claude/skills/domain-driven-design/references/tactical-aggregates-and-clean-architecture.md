---
module: tactical-aggregates-and-clean-architecture
ddd_steps: Step 8 (Code)
sources: aggregate-design-canvas, event-modeling, model-exploration-whirlpool, clean-hexagonal-architecture
---

# Tactical Aggregates, Aggregate Design Canvas v1.1 & Clean Architecture

Self-contained progressive-disclosure reference for Step 8 (`Code`).

## 1. Aggregate Design Canvas v1.1 — 9 Mandatory Sections

Model every transactional consistency boundary using all 9 sections before writing tactical domain code:

| Section # | Section Header | Required Content & Validation Rule |
| :--- | :--- | :--- |
| **1** | `Name` | Aggregate Root Ubiquitous Language noun + temporal lifespan |
| **2** | `Description` | Core responsibility and transactional consistency rationale |
| **3** | `State Transitions` | Mermaid `stateDiagram-v2` showing valid lifecycle transitions and terminal states |
| **4** | `Enforced Invariants` | Immediate transactional rules (`TRUE` at the end of every command transaction) |
| **5** | `Corrective Policies` | Eventual consistency handlers and compensating actions for cross-aggregate or async anomalies |
| **6** | `Handled Commands` | Imperative commands validated, accepted, or rejected by the Aggregate Root |
| **7** | `Created Events` | Past-tense immutable Domain Events emitted on state transition (pseudonymous `SubjectId` only; zero raw PII) |
| **8** | `Throughput` | Expected read:write ratio, concurrency contention profile, and optimistic/pessimistic locking rule |
| **9** | `Size` | Upper bound on child entities and event stream length (forbid unbounded collections) |

## 2. Vernon's 4 Rules of Aggregate Design & Tactical Building Blocks

- **Rule 1 (Model True Invariants in Consistency Boundaries)**: Group entities/value objects into an Aggregate only when a business invariant must hold `TRUE` within a single atomic commit.
- **Rule 2 (Design Small Aggregates)**: Target `~70%` of Aggregates as a single `Aggregate Root` Entity containing immutable `Value Objects` (`0` child entities) to minimise memory footprint and lock contention.
- **Rule 3 (Reference Other Aggregates by Identity Only — AR-005)**: Never hold direct object/ORM navigation references to another Aggregate; reference external Aggregates strictly by typed `Value Object` ID (`OrderId`, `CustomerId`).
- **Rule 4 (Use Eventual Consistency Outside the Boundary)**: Modify at most **1** Aggregate instance per transaction; coordinate cross-Aggregate updates asynchronously via **Domain Events** and **Corrective Policies**.

| Tactical Block | Identity & Mutability | Responsibility |
| :--- | :--- | :--- |
| **Value Object** | Identity-free; defined by structural equality; `100%` immutable | Self-validating domain concept (`Money`, `EmailAddress`, `DateRange`); encapsulates pure calculation logic |
| **Entity** | Unique continuity ID (`Value Object`); controlled state mutation via methods | Tracks lifecycle state inside an Aggregate boundary |
| **Aggregate Root** | Globally addressable Entity entry point | Enforces all transactional invariants, handles Commands, emits Domain Events |
| **Domain Event** | Immutable past-tense record with timestamp, Aggregate ID, and correlation ID | Notifies internal/external subscribers of completed state transitions |
| **Domain Service** | Stateless operation across multiple Aggregates or external policy ports | Expresses domain calculations that do not naturally belong to a single Aggregate |
| **Repository** | Collection-oriented persistence port (`GetById`, `Save`) per Aggregate Root | Abstracts storage; never expose Repositories for internal child entities |

## 3. Event Modeling, Evans Whirlpool & Hexagonal Dependency Rings

- **Event Modeling (`Given-When-Then`)**: Specify vertical slices along a horizontal timeline using 4 patterns: **State Change** (`UI -> Command -> Event`), **State View** (`Event -> Read Model -> UI`), **Automation** (`Event -> Todo Read Model -> Processor Command -> Event`), and **Translation** (`External Event -> ACL Command -> Internal Event`).
- **Evans Model Exploration Whirlpool**: Iterate continuously across `Scenario -> Ubiquitous Language -> Model -> Code Spike -> Challenge` whenever tactical edge cases surface.
- **Hexagonal / Clean Architecture Rings (Inward Dependency Rule)**:
  - **Ring 1 (`Domain Model`)**: Pure Aggregates, Entities, Value Objects, Domain Events, Domain Services (`0` framework, ORM, or I/O dependencies).
  - **Ring 2 (`Application / Use Cases`)**: Command/Query handlers, transaction unit-of-work, Repository/ACL port interfaces.
  - **Ring 3 (`Infrastructure / Adapters`)**: EF Core/SQL repositories, HTTP/Minimal API controllers, message bus publishers, `ACL` adapters.

## 4. Prohibited Anti-Patterns & `oop-design-patterns__oop-design-patterns` Handoff

- **Prohibited Anti-Patterns**: Forbid Anemic Domain Models (public setters + service-layer scripts), **Cross-Aggregate Object References**, Multi-Aggregate Transactions, ORM-Driven Domain Pollution in Ring 1, and Patternitis Inside Aggregates (`< 3` branches).
- **Bidirectional Handoff with `oop-design-patterns__oop-design-patterns` (`oop-architecture-expert`)**: Delegate GoF pattern mechanics (`Strategy` for pluggable policies, `State` for complex state machines, `Factory`/`Builder` for Aggregate assembly, `Adapter`/`Decorator` for `ACL` ports under the Rule of Three) to `oop-design-patterns__oop-design-patterns`.

## 5. Physical Module Topology & Coordinator Non-Authority Rules (`AR-###`)

- **`AR-MOD-001` (Explicit Module Boundary Placement)**: Every in-scope Bounded Context authority (`BC-###`) maps to an explicit physical module/ring boundary (`Discovery-First`); never collapse a peer authority into a consumer module's internal namespace.
- **`AR-MOD-002` (Contract Ownership)**: Strongly-typed IDs, Commands, and Integration Events belong to the owning module's contract ring (`<Context>.Contracts` / `Ring 1–2`); consumers depend only on published contracts or an `Anticorruption Layer` (`ACL`).
- **`AR-MOD-003` (Aggregate Reference Purity — AR-005)**: Cross-module references store only immutable **External Decision & Identity Reference IDs** (`BC-REF-001`), never foreign ORM entities or domain objects (extending Vernon's Rule 3 across Bounded Contexts).
- **`AR-SAGA-001` (`AR-018` Coordinator / Saga Non-Authority)**: A Saga, Process Manager, or Coordinator (`Controller` trait) may subscribe to integration events, collect External Decision References, and dispatch commands, but MUST NEVER execute domain calculations, mutate Aggregate state directly, or steal decision authority from an owning Bounded Context.

## 6. Event-Sourced Aggregate Specification Pattern (`Given -> When -> Expect`)

Test and specify Aggregate state transitions purely in-memory through event state diffs with zero external infrastructure mocks:
- **Given(PastEvents)**: Load the history of domain events that reconstitute current aggregate state.
- **When(Command)**: Execute the imperative command method on the aggregate root.
- **Expect(NewEvents)**: Assert the sequence of newly published domain events emitted (`P#`), or assert the expected domain exception if business invariants fail (`N#`).
