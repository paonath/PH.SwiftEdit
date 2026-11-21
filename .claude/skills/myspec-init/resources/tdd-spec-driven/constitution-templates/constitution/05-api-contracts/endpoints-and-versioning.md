---
area: "05-api-contracts"
file: "endpoints-and-versioning.md"
rules: ["API-001", "API-002", "API-003", "API-004"]
---

# 05-api-contracts/endpoints-and-versioning (API-001..API-004)

## Context
- api_style: `{{API_TRANSPORT_STYLE}}`
- error_contract: `RFC 9457 ProblemDetails (application/problem+json)`

## Rules
- **API-001**: Public HTTP endpoints SHALL reside in `{{API_TRANSPORT_STYLE}}` under explicit versioned route groups (`/v1/<module>`) and `TypedResults`.
- **API-002**: Transport request/response contracts SHALL be immutable DTO `record` types; exposing `Domain` Aggregates or ORM entities is forbidden (`BOPLA`).
- **API-003**: All `4xx`/`5xx` HTTP error responses SHALL return `RFC 9457 ProblemDetails` with correlation `traceId` and zero internal stack traces (`CWE-209`).
- **API-004**: Every inbound request DTO SHALL pass deterministic schema/FluentValidation checks before invoking application command handlers (`CWE-20`).
