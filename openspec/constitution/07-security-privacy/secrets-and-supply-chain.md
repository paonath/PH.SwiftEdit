---
area: "07-security-privacy"
file: "secrets-and-supply-chain.md"
rules: ["SEC-005", "SEC-006", "SEC-007", "SEC-008"]
---

# 07-security-privacy/secrets-and-supply-chain (SEC-005..SEC-008)

## Context
- secrets_source: `Zero Embedded Secrets and Externalized Xcode Code-Signing Configuration`
- path_exec_guard: `Atomic Safe-Save Confinement + Committed Package.resolved + Zero Subprocess Execution`

## Rules
- **SEC-005**: Source files, `Package.swift`, Xcode project configurations, tests, and specs SHALL NOT contain plaintext passwords, API tokens, Apple signing certificates, private keys, or unmasked developer PII (`CWE-798`).
- **SEC-006**: Diagnostic `os.Logger` calls and error payloads SHALL mark dynamic interpolations `.private` by default without recording raw document contents, security-scoped bookmark blobs, `NSPasteboard` text, or unredacted home-directory paths (`CWE-532`).
- **SEC-007**: Persistence adapters SHALL commit user documents exclusively via atomic safe-save transactions within the granted target directory while forbidding `Foundation.Process`, `posix_spawn`, `dlopen`, and shell invocation (`CWE-78`).
- **SEC-008**: External SwiftPM packages SHALL require explicit constitutional allowlisting, exact version and revision pinning in a committed `Package.resolved` manifest, and macOS Hardened Runtime code-signing enforcement.
