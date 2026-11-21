---
area: "02-domain"
file: "bounded-context-ownership.md"
rules: ["BC-001", "BC-002", "BC-003", "BC-004"]
---

# 02-domain/bounded-context-ownership (BC-001..BC-004)

## Context
- context_map: `{{BOUNDED_CONTEXT_MAP}}`
- subdomain_tiers: `Core | Supporting | Generic`

## Rules
- **BC-001**: Every business decision and state transition SHALL belong to exactly one authoritative Bounded Context in `{{BOUNDED_CONTEXT_MAP}}`.
- **BC-002**: Each Bounded Context SHALL declare its `Core`, `Supporting`, or `Generic` tier in `design.md` before module scaffolding (`AR-004`).
- **BC-003**: Each Aggregate Root SHALL act as a transactional consistency boundary mutating state strictly via domain methods and emitted `DomainEvents`.
- **BC-004**: A single command transaction SHALL mutate at most one Aggregate Root instance; cross-aggregate updates SHALL use eventual consistency.
