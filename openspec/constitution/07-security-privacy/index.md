---
area: "07-security-privacy"
prefix: "SEC"
status: "active"
owners: ["cyber-security-expert"]
---

# macOS App Sandbox Security, STRIDE & Zero-Telemetry Privacy Mini-Index (`07-security-privacy/`)

## Micro-Files

| Micro-File | Rule IDs | Scope & Inspection Triggers |
| :--- | :--- | :--- |
| `authn-authz-and-boundaries.md` | `SEC-001..SEC-004` | Least-privilege `.entitlements`, balanced security-scoped bookmarks, symlink/TOCTOU confinement, 100% offline isolation |
| `secrets-and-supply-chain.md` | `SEC-005..SEC-008` | Zero plaintext secrets (`CWE-798`), `.private` `os.Logger` redaction, zero subprocess execution, pinned `Package.resolved` |
| `stride-and-gdpr-privacy.md` | `SEC-009..SEC-012` | 6-category STRIDE table, `Rule G3` non-waiver gate, zero-telemetry GDPR minimization & bookmark purge, fail-closed `Codable` |
