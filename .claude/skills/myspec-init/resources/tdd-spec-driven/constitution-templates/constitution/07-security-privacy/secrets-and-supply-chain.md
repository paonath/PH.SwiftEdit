---
area: "07-security-privacy"
file: "secrets-and-supply-chain.md"
rules: ["SEC-005", "SEC-006", "SEC-007", "SEC-008"]
---

# 07-security-privacy/secrets-and-supply-chain (SEC-005..SEC-008)

## Context
- secrets_source: `Environment Variables / Secret Vault (zero plaintext in repo)`
- path_exec_guard: `Path.resolve().is_relative_to(root) + shell=False`

## Rules
- **SEC-005**: Source code, configs, tests, and specs SHALL NOT contain plaintext passwords, API keys, JWT secrets, or private keys (`CWE-798`).
- **SEC-006**: Application logs and error payloads SHALL redact credentials, tokens, session IDs, and raw PII before emission (`CWE-532`).
- **SEC-007**: Filesystem and process helpers SHALL validate canonical paths via `is_relative_to` (`CWE-22`) and execute commands with argument arrays (`shell=False`, `CWE-78`).
- **SEC-008**: Third-party dependencies SHALL be pinned to audited versions and added strictly via official package CLI tools (`dotnet add package`, `npm`, `pip`).
