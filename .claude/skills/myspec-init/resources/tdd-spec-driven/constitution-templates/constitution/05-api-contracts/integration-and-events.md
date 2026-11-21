---
area: "05-api-contracts"
file: "integration-and-events.md"
rules: ["API-005", "API-006", "API-007", "API-008"]
---

# 05-api-contracts/integration-and-events (API-005..API-008)

## Context
- messaging_fabric: `{{MESSAGING_TRANSPORT}}`
- compatibility_policy: `Additive Backward-Compatible Evolution`

## Rules
- **API-005**: State-mutating command endpoints and integration consumers SHALL enforce idempotency via command/message IDs (`Idempotency-Key` / deduplication).
- **API-006**: Published REST and Integration Event schemas SHALL evolve additively; breaking field removals or renames SHALL require a new schema version.
- **API-007**: External third-party HTTP/gRPC clients SHALL use resilient timeouts, bounded retries with jitter, and Anti-Corruption Layer (`ACL`) mapping.
- **API-008**: Integration events published on `{{MESSAGING_TRANSPORT}}` SHALL carry `correlationId`, `causationId`, `occurredOnUtc`, and schema version metadata.
