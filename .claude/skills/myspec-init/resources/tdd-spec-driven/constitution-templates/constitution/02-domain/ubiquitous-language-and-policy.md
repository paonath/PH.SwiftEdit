---
area: "02-domain"
file: "ubiquitous-language-and-policy.md"
rules: ["BC-009", "BC-010", "BC-011", "BC-012"]
---

# 02-domain/ubiquitous-language-and-policy (BC-009..BC-012)

## Context
- glossary_source: `design.md (## Glossario & Convenzioni)`
- ambiguity_marker: `[NEEDS CLARIFICATION: <question>]`

## Rules
- **BC-009**: Class, command, event, and test names SHALL match the Bounded Context Ubiquitous Language defined in `design.md`.
- **BC-010**: IF a business rule, compensation policy, or authority boundary is underspecified, THEN the agent SHALL emit `[NEEDS CLARIFICATION]` rather than inventing policy.
- **BC-011**: Every `DomainEvent` SHALL be an immutable past-tense record containing only domain Value Objects and opaque IDs.
- **BC-012**: Domain invariants SHALL reject invalid commands deterministically via explicit domain exceptions or typed `Result<T>` outcomes.
