---
module: context-mapping-and-message-flow
ddd_steps: Step 5 (Connect), Step 6 (Organise)
sources: domain-message-flow-modelling, context-mapping, TeamTopologies
---

# Domain Message Flow Modelling, Context Mapping & Team Topologies

Self-contained progressive-disclosure reference for Step 5 (`Connect`) and Step 6 (`Organise`).

## 1. Step 5 (`Connect`): Domain Message Flow Modelling

Model concrete cross-context scenarios by tracing directed messages between Bounded Contexts, Actors, and External Systems:

| Message Type | Intent & Ownership | Coupling & Failure Semantics |
| :--- | :--- | :--- |
| **Command** | Imperative request (`ReserveInventory`) sent to a specific target context | Sender knows receiver; target context may reject command if invariants fail |
| **Event** | Immutable past-tense fact (`OrderPaid`) published by the authoritative context | Publisher is oblivious to consumers; promotes loose coupling and eventual consistency |
| **Query** | Side-effect-free data retrieval (`GetCustomerCreditScore`) | Synchronous read dependency; minimise on critical write paths |

### Orchestration vs Choreography & Saga Non-Authority (AR-018)
- **Choreography (Event-Driven)**: Contexts react autonomously to published Events (`Context A -> Event -> Context B -> Event -> Context C`). Prefer when steps are few (`<= 3`), independent, and rarely reorder.
- **Orchestration (`Process Manager` / Saga Coordinator)**: Dedicated coordinator context sending Commands and listening to Events when workflows require complex branching, timeouts, or compensating actions, keeping core execution contexts decoupled.
- **Saga and Coordinator Non-Authority (`AR-018`)**:
  - A Saga or Process Manager is exclusively a stateful workflow coordinator. It gathers external decision evidence (`PaymentAuthorizationId`, `StockReservationId`) and dispatches commands.
  - **Zero Domain Authority (`BC-FORBID-002`)**: Sagas MUST NEVER evaluate business invariants, MUST NEVER calculate domain rules (pricing, discounts), and MUST NEVER mutate aggregate state directly. All business decisions remain inside the owning Bounded Context Aggregates.
  - **Compensating Actions**: When a workflow step fails, the Saga dispatches compensating Commands (e.g. `ReleaseStockReservation`, `CancelOrder`) to downstream contexts; it never forces state rollbacks.

## 2. Step 6 (`Organise`): Three Socio-Technical Team Relationships

| Team Relationship | Power & Dependency Dynamic | Compatible Context Map Patterns |
| :--- | :--- | :--- |
| **Mutually Dependent** | Two teams share fate; neither can succeed without coordinated delivery | `Partnership`, `Shared Kernel` (`SK`) |
| **Upstream/Downstream** | Upstream (`U`) changes impact Downstream (`D`); `U` may or may not prioritise `D`'s needs | `Customer/Supplier`, `Conformist` (`CF`), `Anticorruption Layer` (`ACL`), `Open-Host Service` (`OHS`), `Published Language` (`PL`) |
| **Free** | No technical or organisational dependency between the two contexts | `Separate Ways` |

## 3. Nine Canonical Context Map Patterns & STRIDE Boundary Mapping

| Pattern | Polarity | When to Apply | STRIDE & Architectural Guardrail |
| :--- | :--- | :--- | :--- |
| **Open-Host Service (`OHS`)** | `U` | Upstream serves multiple consumers via a stable public API/event contract | Map to **Trusted -> External Boundary**: enforce authz (`E`), rate-limiting (`D`), and DTO allowlisting (`I`) |
| **Published Language (`PL`)** | `U` | Shared, versioned industry or enterprise schema paired with `OHS` | Sign/version schemas (`T`, `R`) and forbid leaking internal domain entities |
| **Anticorruption Layer (`ACL`)** | `D` | Downstream protects its Ubiquitous Language from a messy, volatile, or external Upstream | Map to **Hard Untrusted -> Trusted Ingress Boundary**: enforce schema validation, Value Object parsing, mTLS/auth (`S`), and payload sanitization (`T`) |
| **Customer/Supplier (`C/S`)** | `U/D` | Cooperative teams where Downstream can negotiate priorities and SLAs with Upstream | Validate upstream contracts via automated consumer-driven contract tests |
| **Conformist (`CF`)** | `D` | Downstream adopts Upstream's model verbatim (Upstream has no motivation to adapt, model is good enough) | Never use `CF` for a `Core Domain` consuming a `Big Ball of Mud`; still validate transport/identity (`S`, `T`) |
| **Shared Kernel (`SK`)** | Symmetric | Co-owned subset of domain model/code with a single team or tightly synchronised pair | Keep kernel tiny and run unified CI tests on every commit |
| **Partnership** | Symmetric | Two teams coordinate roadmaps and evolve integration bi-directionally | Synchronise release schedules; replace with `OHS`/`C/S` as org scales |
| **Separate Ways** | Free | Integration cost exceeds business value; duplicating simple logic/data is cheaper | Prefer over forced coupling for low-value `Supporting` needs |
| **Big Ball of Mud (`BBoM`)** | Legacy Hazard | Entangled system lacking clear boundaries and Ubiquitous Language | **Mandatory Security Gate**: Quarantine behind a strict `ACL`; never let `BBoM` models leak into `Core` contexts |

## 4. Team Topologies Alignment

Align Bounded Context ownership with the 4 **Team Topologies** (`Stream-Aligned`, `Platform`, `Enabling`, `Complicated-Subsystem`) and 3 interaction modes (`Collaboration` for rapid discovery, `X-as-a-Service` for `OHS`/`PL` boundaries, `Facilitating` for coaching), ensuring no Bounded Context is co-owned by multiple unaligned teams.
