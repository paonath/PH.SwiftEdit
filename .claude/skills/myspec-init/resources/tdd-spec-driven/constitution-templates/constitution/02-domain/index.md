---
area: "02-domain"
prefix: "BC"
status: "{{STATUS_DOMAIN}}"
owners: ["ddd-expert", "spec-sdlc-expert", "domain-expert"]
---

# Domain Governance & Bounded Contexts Mini-Index (`02-domain/`)

## Micro-Files

| Micro-File | Rule IDs | Scope & Inspection Triggers |
| :--- | :--- | :--- |
| `bounded-context-ownership.md` | `BC-001..BC-004` | Positive Decision Authority, Subdomain classification (`Core`/`Supporting`/`Generic`), `Brain Context` split, `KISS-Lite` |
| `negative-ownership-and-refs.md` | `BC-005..BC-008` | `Forbidden Responsibilities`, `External Decision References` (`<Outcome>Id`), Saga non-ownership, pseudonymized `CustomerId` |
| `ubiquitous-language-and-policy.md` | `BC-009..BC-012` | Context-scoped Ubiquitous Language glossary, `[NEEDS CLARIFICATION]` policy gate, Aggregate invariants & single-aggregate tx |
