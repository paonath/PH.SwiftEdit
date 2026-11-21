---
area: "07-security-privacy"
file: "secrets-and-supply-chain.md"
rules: ["SEC-005", "SEC-006", "SEC-007", "SEC-008"]
---

# 07-security-privacy/secrets-and-supply-chain (SEC-005..SEC-008)

## Context
- secrets_source: `Zero Embedded Secrets and Private-by-Default Dotfile Log Redaction`
- session_and_exec_guard: `UUID SessionRecovery (0700/0600 macOS, FileProtectionType.complete iOS, <= 64 MiB, Backup-Excluded) + Zero Subprocess Execution`

## Rules
- **SEC-005**: Source files, `Package.swift`, Xcode project configurations, tests, and specs SHALL NOT contain plaintext passwords, API tokens, Apple signing certificates, private keys, or unmasked developer PII (`CWE-798`).
- **SEC-006**: Diagnostic `os.Logger` calls and error payloads SHALL mark dynamic interpolations `.private` by default without recording raw document buffers, hidden dotfile contents, security-scoped bookmark blobs, pasteboard text, or unredacted home-directory paths (`CWE-532`).
- **SEC-007**: Persistence adapters SHALL enforce atomic safe-save writes, a `64 MiB` `SessionRecovery` quota using `UUID` filenames with `0700`/`0600` macOS permissions, iOS `FileProtectionType.complete`, backup exclusion, and zero subprocess execution (`CWE-78`, `CWE-312`).
- **SEC-008**: External SwiftPM packages SHALL require explicit constitutional allowlisting, exact version and revision pinning in a committed `Package.resolved` manifest, and platform Hardened Runtime code-signing enforcement.
