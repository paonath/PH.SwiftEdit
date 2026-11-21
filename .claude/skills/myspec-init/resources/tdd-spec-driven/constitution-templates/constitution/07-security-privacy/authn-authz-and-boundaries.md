---
area: "07-security-privacy"
file: "authn-authz-and-boundaries.md"
rules: ["SEC-001", "SEC-002", "SEC-003", "SEC-004"]
---

# 07-security-privacy/authn-authz-and-boundaries (SEC-001..SEC-004)

## Context
- authn_authz: `{{AUTHN_AUTHZ_MECHANISM}}`
- transport_policy: `{{TRANSPORT_CORS_POLICY}}`

## Rules
- **SEC-001**: Every endpoint, gRPC service, and hub SHALL enforce authentication and policy authorization (`{{AUTHN_AUTHZ_MECHANISM}}`) unless justified in `design.md`.
- **SEC-002**: Handlers SHALL verify resource ownership against authenticated claims (`BOLA`), enforce role policies (`BFLA`), and compute prices/privileges server-side (`BOPLA`).
- **SEC-003**: IF an endpoint accepts both a route `{id}` and a body identifier, THEN it SHALL reject mismatches with `400 Bad Request` or bind exclusively from `{id}`.
- **SEC-004**: The host SHALL enforce `{{TRANSPORT_CORS_POLICY}}` and reject wildcard CORS origins combined with `.AllowCredentials()` (`CWE-942`).
