---
module: strategic-discovery-and-subdomains
ddd_steps: Step 1 (Understand), Step 3 (Decompose), Step 4 (Strategize)
sources: ddd-starter-modelling-process, core-domain-charts, Independent-Service-Heuristics
---

# Strategic Discovery, Subdomains & Core Domain Charts

Self-contained progressive-disclosure reference for Step 1 (`Understand`), Step 3 (`Decompose`), and Step 4 (`Strategize`).

## 1. Step 1 (`Understand`): Business & Value Chain Alignment

Select the alignment technique matching the strategic uncertainty before slicing technical boundaries:

| Tool | Primary Question Answered | Key Artefacts & Axes | Output to Step 2/3 |
| :--- | :--- | :--- | :--- |
| **Business Model Canvas** | How does the organisation create, deliver, and capture value? | 9 blocks: Customer Segments, Value Propositions, Channels, Relationships, Revenue, Resources, Activities, Partners, Costs | Value-generating capabilities vs cost centers |
| **Impact Mapping** | Which actor behaviour changes achieve the business goal? | `Goal (Why) -> Actors (Who) -> Impacts (How) -> Deliverables (What)` | Prioritised behavioural outcomes |
| **Wardley Mapping** | How do value-chain components evolve from Genesis to Commodity? | Y-axis: Value Chain visibility; X-axis: `Genesis -> Custom Built -> Product -> Commodity` | Buy/build/outsource boundaries |
| **Business Capability Modeling** | What stable functions (`What`, not `How`) does the business perform? | Hierarchical capability tree independent of current org-chart silos | Candidate Subdomain boundaries |

## 2. Step 3 (`Decompose`): Subdomain Slicing & Independent Service Heuristics (`ISH`)

Decompose the discovered domain into cohesive **Subdomains** using Pivotal Events (phase transition boundaries) and the 8 **Independent Service Heuristics**:

| Heuristic Category | Question / Signal | Boundary Verdict |
| :--- | :--- | :--- |
| **1. Sense of Value** | Does this capability deliver a distinct, measurable customer or business outcome? | High cohesion -> valid Subdomain |
| **2. Product Decisions** | Can a single product owner make roadmap decisions without cross-team sign-off? | Independent backlog -> valid boundary |
| **3. Domain Language** | Do terms (`Account`, `Order`, `Policy`) change meaning across this boundary? | Linguistic shift -> split Subdomains |
| **4. Rules & Policies** | Do business invariants execute together transactionally or only asynchronously? | Asynchronous -> separate Subdomains |
| **5. Data Lifecycle** | Do data records have distinct creation, retention, and archival lifecycles? | Independent lifecycle -> separate storage |
| **6. Cost of Change** | Do two areas change at different velocities or for different business reasons? | Divergent change rate -> split |
| **7. Team Cognitive Load** | Can a single stream-aligned team (`5-9` engineers) own the model in working memory? | Cognitive overload -> decompose further |
| **8. Cloud / Operational Fit** | Does this area require distinct availability, scaling, or compliance controls? | Divergent SLA/compliance -> isolate |

## 3. Step 4 (`Strategize`): Core Domain Charts

Plot every Subdomain on a 2D **Core Domain Chart** (`X-axis: Business Differentiation [Low -> High]`, `Y-axis: Model Complexity [Low -> High]`) to govern architecture investment and team allocation:

| Classification | Business Differentiation | Model Complexity | Strategic Investment & Sourcing Rule |
| :--- | :--- | :--- | :--- |
| **Core Domain** | High (competitive moat, revenue/engagement driver) | High (deep rules, algorithms, rapid domain discovery) | Build in-house with top domain/engineering talent; apply full Tactical DDD, EventStorming, and continuous refactoring |
| **Supporting Domain** | Low-to-Medium (enables Core, not a market differentiator) | Low-to-Medium (CRUD or moderate workflow logic) | Keep design simple and pragmatic; avoid over-engineering; outsource or use lightweight frameworks |
| **Generic Domain** | Low (table-stakes utility: Auth, Billing, Email, CRM) | Low-to-High (standardised industry problem) | Buy SaaS/COTS or adopt open-source packages behind an `Anticorruption Layer` (`ACL`); never custom-build |

## 4. Six Core Domain Chart Portfolio Archetypes & Evolution Vectors

Track how Subdomains migrate across the chart over time using directional arrows:

- **1. Defend & Differentiate**: Invest heavily in 1–3 high-complexity `Core` domains while keeping `Supporting`/`Generic` footprints minimal.
- **2.Experiment & Discover**: Start a `Genesis` capability in `Core` with rapid hypotheses; promote or retire based on verification metrics.
- **3. Commoditise Legacy Core**: Move an aging `Core` domain left/down toward `Generic`/`Product` as competitors catch up, freeing capacity for new `Core` domains.
- **4. Elevate Supporting to Core**: Promote a `Supporting` domain to `Core` when a new business model turns an internal capability into a market differentiator.
- **5. Contain Hidden Complexity (`Bet the Company` Trap)**: When a `Supporting` or `Generic` domain exhibits extreme `Model Complexity`, decompose it or isolate it behind an `ACL` rather than letting it starve true `Core` domains.
- **6. Reject False Core Bias**: Challenge stakeholders who label every Subdomain `Core`; enforce that at most `20-30%` of portfolio Subdomains qualify as `Core`.
