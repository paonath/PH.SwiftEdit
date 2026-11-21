---
module: ddd-to-tdd-and-myspec-bridge
ddd_steps: Cross-Step Synthesis (SAP DDD Kata & MySpec 6-Artifact TDD Bridge)
sources: SAP/curated-resources-for-domain-driven-design, myspec-tdd-spec-reasoning, security-expertise
---

# SAP DDD Kata Inside-Out TDD & MySpec 6-Artifact Bridge

Self-contained progressive-disclosure reference bridging Strategic/Tactical DDD into `myspec-tdd-spec-reasoning` and `myspec-apply`.

## 1. SAP DDD Kata: Inside-Out Domain-First TDD Loop

Execute Tactical DDD implementation strictly from the innermost pure domain layer outward so business invariants are verified in-memory with zero I/O mocks:

| TDD Ring Order | Target Building Block | `[RED]` Failing Test Contract | `[GREEN]` Minimum Implementation | `[REFACTOR]` & `[DOC]` Gate |
| :--- | :--- | :--- | :--- | :--- |
| **1. Value Objects** | `Money`, `OrderId`, `Quantity`, `TaxRate` | Assert construct-time rejection of invalid/boundary inputs (`N#`) and structural value equality (`P#`) | Immutable `readonly record struct` / `@dataclass(frozen=True)` with guard clauses | Extract pure operators/formatters; document invariants |
| **2. Aggregate Root** | `Order`, `LoanApplication`, `Subscription` | `Given(Events) -> When(Command) -> Expect(Events)`: assert state transition + emitted Domain Event (`P#`) or domain exception (`N#`) | Private state mutation, `Enforced Invariants` checks, and `Created Events` list (`0` database/HTTP mocks) | Simplify branch guards; delegate `>= 3` policy variants to `oop-design-patterns__oop-design-patterns` |
| **3. Domain Services & Policies** | Cross-aggregate calculators, `Corrective Policies` | Assert policy reaction (`Whenever [Event] Then [Command]`) and compensation idempotency | Pure stateless domain service or policy handler | Verify zero infrastructure leakage |
| **4. ACL & Repository Ports** | `Anticorruption Layer` translators, Repository fakes/adapters | Assert `ACL` rejects malformed/unauthorized upstream payloads (`N#`, `tags: security`) and maps valid DTOs to internal Value Objects (`P#`) | Adapter translating external contracts to Ring 1 Value Objects/Aggregates | Verify transactional atomicity (1 Aggregate per commit) |

## 2. Deterministic Mapping into `myspec-tdd-spec-reasoning` (6 OpenSpec Artifacts)

Translate DDD Starter Modelling outputs directly into the 6 schema-conformant artifacts validated by `myspec_validate.py`:

| OpenSpec Artifact | DDD Modelling Source | Mandatory Mapping Contract |
| :--- | :--- | :--- |
| **`<briefs_dir>/brief-<id>.md`** | Steps 1–2 (`Understand` + `Discover`: EventStorming, Domain Storytelling, Example Mapping) | Capture Ubiquitous Language glossary, Pivotal Events, resolved Hotspots, and 4-Pillar `P1..Pn` / `N1..Nm` path inventory |
| **`proposal.md`** | Steps 3–4 (`Decompose` + `Strategize`: Subdomains, Core Domain Chart) | Map each target Bounded Context to a `kebab-case` capability slug, state strategic classification (`Core`/`Supporting`/`Generic`), and record `- Branch:` + `- Modifies-Specs:` metadata |
| **`threat-model.md`** | Steps 6–8 (`Context Map` + `BCC v5` + `ADC v1.1`) | Map `ACL`/`GI`/`OHS`/`PL` to Asset Boundaries, populate all 6 STRIDE rows (`Spoofing`..`Elevation of Privilege`), list `N#` Abuse Cases, and set `- Verdict: approved` |
| **`specs/<cap>/spec.md`** | Steps 2, 7, 8 (Example Mapping Blue/Green cards + BCC v5 decisions + ADC v1.1 invariants) | Author canonical EARS requirements (`REQ-NNN`, canonical EARS syntax, `<= 500` chars via `the ears-syntax-standards skill`) and Gherkin scenarios (`#### Scenario:`, `- **Path**: P#/N#`, `- **Trait**: positive/security`, `GIVEN`/`WHEN`/`THEN` via `the bdd-gherkin-specifications skill`) |
| **`design.md`** | Steps 5–8 (Context Map, Bounded Context Canvas v5, Aggregate Design Canvas v1.1) | Embed Mermaid Context Map / Aggregate `stateDiagram-v2`, document Hexagonal ring boundaries, and set `## Security Review` `- Verdict: approved` |
| **`test-plan.md` & `tasks.md`** | Step 8 + SAP DDD Kata inside-out order | List `P#`/`N#` Path Coverage Matrix in `test-plan.md` and group `tasks.md` units in inside-out order (`[RED] -> [GREEN] -> [REFACTOR] -> [DOC]`, plus `[SYNC]` if modifying consolidated specs) |

## 3. STRIDE Trust Boundary & GDPR Event Minimization Rules

- **Context Map -> STRIDE Trust Boundaries**:
  - `Anticorruption Layer` (`ACL`) and `Gateway Interchange` (`GI`) = **Untrusted -> Trusted Ingress Boundary**: require schema validation, Value Object parsing, mTLS/authentication (`S`), payload sanitization (`T`), and rate-limiting (`D`).
  - `Open-Host Service` (`OHS`) and `Published Language` (`PL`) = **Trusted -> External Multi-Consumer Boundary**: require authorization (`E`), DTO allowlisting (`I` / CWE-200), and versioned/signed schemas (`T`, `R`).
- **Aggregate `Created Events` & Saga Provenance -> GDPR Art. 5/17/25 Data Minimization**:
  - Never embed raw PII (plaintext names, emails, tax IDs, health records) inside immutable Domain Events or append-only event stores.
  - Carry only pseudonymous `SubjectId` references or KMS-peppered `HMAC-SHA256` identifiers in `Created Events`, paired with `Sha256(SubjectId)` erasure tombstones and crypto-shredding per `security-expertise` (`gdpr-compliance.md`).
  - **Saga and Event Provenance Headers**: Every command and domain event emitted in multi-context sagas MUST carry immutable `CorrelationId` (tracing originating workflow initiation) and `CausationId` (pointing to the immediate preceding event/command ID) headers for end-to-end non-repudiation and distributed auditability.

## 4. Domain Carrier (`BC-###`) & Architecture Memory (`AR-###`) Bridge Protocol

When authoring multi-context or boundary-sensitive OpenSpec changes in `myspec-tdd-spec-reasoning`, uncomment and populate the opt-in governance blocks in `proposal.md` and `design.md`:

| Governance Block | Target Artifact | Required Fields & EARS / BDD Traceability |
| :--- | :--- | :--- |
| **`## Domain Carrier & Decision Ownership (BC-###)`** | `proposal.md` | Declare `- **BC-001**:`, `- **Owned Decisions**:`, `- **Forbidden Responsibilities**:`, and `- **External Decision References**:` (`<Outcome>Id`, `<Subject>Id` or `none`). Map positive decisions to Event-Driven EARS requirements (`P#`) and forbidden responsibilities to Unwanted Behaviour rejection requirements (`N#`, `- **Trait**: negative, architecture`). |
| **`## Architecture Memory & Module Boundaries (AR-###)`** | `design.md` | Declare `- **AR-001**:` (physical module/ring placement) and `- **AR-018**:` (Saga/Coordinator non-authority invariant). Verify via `N#` / `architecture` test paths and protect consolidated living requirements `[BC-###]` / `[AR-###]` under **Rule G3** (`Security-Waiver:` required for modification/removal). |
