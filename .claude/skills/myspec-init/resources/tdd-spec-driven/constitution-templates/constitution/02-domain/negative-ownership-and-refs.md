---
area: "02-domain"
file: "negative-ownership-and-refs.md"
rules: ["BC-005", "BC-006", "BC-007", "BC-008"]
---

# 02-domain/negative-ownership-and-refs (BC-005..BC-008)

## Context
- forbidden_matrix: `{{NEGATIVE_OWNERSHIP_SUMMARY}}`
- external_ref_types: `{{EXTERNAL_DECISION_REFS}}`

## Rules
- **BC-005**: Bounded Contexts SHALL enforce negative ownership (`{{NEGATIVE_OWNERSHIP_SUMMARY}}`) and reject logic belonging to peer authorities.
- **BC-006**: Cross-context workflows SHALL store only immutable opaque reference IDs (`{{EXTERNAL_DECISION_REFS}}`) rather than foreign aggregate state.
- **BC-007**: Inbound external or legacy payloads SHALL pass through an Anti-Corruption Layer (`ACL`) before entering `Domain` handlers.
- **BC-008**: Cross-boundary identifiers, money, quantities, and codes SHALL use validated immutable Value Objects instead of primitive types.
