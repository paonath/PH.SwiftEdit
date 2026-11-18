---
area: "07-security-privacy"
prefix: "SEC"
status: "active"
owners: ["cyber-security-expert"]
---

# App Sandbox Security, Protected SessionRecovery, Binary Quarantine & Privacy Mini-Index (`07-security-privacy/`)

## Micro-Files

| Micro-File | Rule IDs | Scope & Inspection Triggers |
| :--- | :--- | :--- |
| `authn-authz-and-boundaries.md` | `SEC-001..SEC-004` | Least-privilege `.entitlements`, balanced bookmarks, symlink confinement, 100% offline zero-subprocess, directory-only `Finder`/`Terminal`/`iTerm2` |
| `secrets-and-supply-chain.md` | `SEC-005..SEC-008` | Zero plaintext secrets (`CWE-798`), `.private` dotfile log redaction, `0700`/`0600` `SessionRecovery` (`<= 64 MiB`), pinned `Package.resolved` |
| `stride-and-gdpr-privacy.md` | `SEC-009..SEC-012` | 6-category STRIDE table, `Rule G3` non-waiver gate, zero telemetry + close/startup GC + binary non-retention, fail-closed `Codable` |
