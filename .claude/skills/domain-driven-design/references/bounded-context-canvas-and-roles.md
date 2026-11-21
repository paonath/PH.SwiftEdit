---
module: bounded-context-canvas-and-roles
ddd_steps: Step 7 (Define)
sources: bounded-context-canvas, ddd-starter-modelling-process
---

# Bounded Context Canvas v5 & 15 Model Traits (Domain Roles)

Self-contained progressive-disclosure reference for Step 7 (`Define`).

## 1. Bounded Context Canvas v5 — 10 Mandatory Sections

Render every Bounded Context definition in Markdown using all 10 canonical sections:

| Section # | Section Header | Required Content & Validation Rule |
| :--- | :--- | :--- |
| **1** | `Name` | Ubiquitous Language noun phrase (`>= 3` chars; reject generic suffixes `Service`, `Manager`, `Module`, `Data`) |
| **2** | `Purpose` | 1–3 sentences stating business capability value (`0` technical framework or database terms) |
| **3** | `Strategic Classification` | 3-row table: `Domain` (`Core`/`Supporting`/`Generic`), `Business Model` (`Revenue`/`Engagement`/`Compliance`/`Cost Reduction`), `Evolution` (`Genesis`/`Custom Built`/`Product`/`Commodity`) |
| **4** | `Domain Roles` | 1–3 primary traits from the 15 Model Traits catalog below; flag `> 3` traits as a **Brain Context** split candidate |
| **5** | `Ubiquitous Language` | Context-scoped glossary table (`Term`, `Context-Specific Definition`, `Excluded Polysemic Synonyms`) |
| **6** | `Business Decisions` | Authoritative policy rules, state transition decisions, and invariants owned exclusively by this context |
| **7** | `Inbound & Outbound Communication` | Collaborator table (`Collaborator`, `Type: BC/External/Frontend`, `Pattern: OHS/ACL/CF/C-S`, `Messages: Command/Event/Query`) or Use-Case Swimlanes (`Message In -> Decision -> Message Out`) |
| **8** | `Assumptions` | Explicit design assumptions requiring empirical validation |
| **9** | `Verification Metrics` | Quantitative architectural and business fitness metrics |
| **10** | `Open Questions` | Unresolved domain ambiguities queued for stakeholder or `domain-expert` clarification |

## 2. Catalog of 15 Model Traits (Domain Roles)

Classify Bounded Contexts using these 15 archetypal responsibilities to expose hidden coupling:

| Model Trait | Core Responsibility | Architectural Signal |
| :--- | :--- | :--- |
| **1. Specification** | Produces blueprints, rules, or configurations telling other contexts what to do | Keep side-effect-free; pair with downstream `Execution` contexts |
| **2. Execution** | Executes real-world or operational actions driven by a `Specification` | Isolate operational failure and retry loops from pure rule calculation |
| **3. Audit** | Observes and records immutable historical facts/events across the domain | Consume published Domain Events passively (`Event -> Append-Only Log`) |
| **4. Approver** | Reviews requests and grants/denies permission before action proceeds | Map to STRIDE Elevation of Privilege (`E`) gate |
| **5. Enforcer** | Monitors ongoing processes and triggers corrective action when rules are violated | Pair with GDPR retention/erasure policies or SLA watchdogs |
| **6. Octopus Enforcer** | Central enforcer reaching into multiple contexts to enforce global compliance | High coupling risk; prefer pushing local invariants into each context |
| **7. Interchange** | Translates messages between two internal Bounded Contexts (`Format A <-> Format B`) | Keep stateless; avoid embedding core business rules inside translators |
| **8. Gateway** | Encapsulates communication with external third-party systems (`Outbound`) | Combine with `Anticorruption Layer` (`ACL`) to shield internal models |
| **9. Gateway Interchange** | Bi-directional bridge translating both inbound and outbound external protocols | Hard Untrusted <-> Trusted STRIDE Trust Boundary |
| **10. Dogfood** | Internal context using the organisation's own public product/platform capabilities | Validates `Open-Host Service` (`OHS`) usability |
| **11. Workhorse** | Performs heavy background computation, batch processing, or core domain work | Scale independently from low-latency user-facing contexts |
| **12. User-Lifecycle** | Manages onboarding, activation, retention, or offboarding journeys | Coordinate via Domain Events rather than monolithic user tables |
| **13. Storage** | Pure CRUD persistence or document vault with minimal business decision logic | Classify as `Supporting` or `Generic`; never confuse with a `Core` model |
| **14. Controller** | Orchestrates multi-step workflows across contexts (`Process Manager`) | Delegate domain calculations to `Specification`/`Execution` contexts |
| **15. Draft** | Holds incomplete, mutable work-in-progress state before formal submission | Separate relaxed validation rules of drafts from strict `Aggregate` invariants |

## 3. Refactoring Anti-Patterns

- **Brain Context (`> 3` Primary Traits)**: Split immediately (e.g., extract `Specification` from `Execution`, or extract `Draft` from `Enforcer`).
- **Pipeline Context Chain (`A -> B -> C -> D` Synchronous Calls)**: Replace temporal request chaining with asynchronous Domain Events or an explicit `Controller` context.
- **C4 Context Alignment**: Treat each Bounded Context as a C4 System/Container boundary whose `Inbound & Outbound Communication` maps 1:1 to C4 relationship arrows.

## 4. Bounded Context Authority & Negative Ownership Rules (`BC-###`)

- **Core Principle**: **Domain Carrier (`BC-###`)** answers *"Who owns the decision?"* whereas **Architecture Memory (`AR-###`)** answers *"Where must that ownership live?"*
- **`BC-OWN-001` (Positive Decision Authority)**: Each Bounded Context owns its Aggregate lifecycle, state transitions, and emitted Domain Events exclusively. *Reacting to an external event is not owning the decision that produced it.*
- **`BC-FORBID-001` (Forbidden Responsibilities / Negative Ownership)**: Every multi-context Bounded Context specification MUST explicitly declare `- **Forbidden Responsibilities**:` listing upstream/downstream calculations, state mutations, timeout interpretations, and compensations it MUST NEVER execute or embed.
- **`BC-REF-001` (External Decision & Identity References)**: Consuming Bounded Contexts MUST record upstream authority outcomes and cross-context identities strictly as immutable, strongly-typed **External Decision References** (e.g., `<Outcome>Id`, `<Subject>Id`) under `- **External Decision References**:`—never embedding foreign Entities/DTOs or raw PII (`GDPR Art. 5(1)(c)` & `Art. 17`).
- **`BC-POL-001` (`BC-011` No Silent Policy Invention)**: Never silently invent unstated business, retry, compensation, or auto-cancellation policies; resolve via `the qa skill` or fail closed on `[NEEDS CLARIFICATION]`.
- **`KISS-Lite` Profile (`kiss-and-solid-principles`)**: Single-context `Supporting`/`Generic` CRUD features may keep `BC-###`/`AR-###` template blocks commented out (`0` ceremony).
