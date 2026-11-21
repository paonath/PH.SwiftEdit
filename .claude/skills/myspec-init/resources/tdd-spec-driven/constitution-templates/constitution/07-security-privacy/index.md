---
area: "07-security-privacy"
prefix: "SEC"
status: "active"
owners: ["cyber-security-expert"]
---

# Security, STRIDE & GDPR Privacy Mini-Index (`07-security-privacy/`)

## Micro-Files

| Micro-File | Rule IDs | Scope & Inspection Triggers |
| :--- | :--- | :--- |
| `authn-authz-and-boundaries.md` | `SEC-001..SEC-004` | Endpoint `.RequireAuthorization()`, `BOLA`/`BFLA`/`BOPLA`, route-vs-body ID match, CORS/TLS hardening |
| `secrets-and-supply-chain.md` | `SEC-005..SEC-008` | Zero plaintext secrets (`CWE-798`), env/vault config, path traversal (`CWE-22`) & command/SQL injection (`CWE-78`/`89`) |
| `stride-and-gdpr-privacy.md` | `SEC-009..SEC-012` | 6-category STRIDE table, `Rule G3` `Security-Waiver:` gate, GDPR Art. 5/17 `ExternalIdentityId` & log redaction |
