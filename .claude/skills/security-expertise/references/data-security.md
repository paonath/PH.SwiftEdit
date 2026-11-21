---
name: "data-security"
description: "Data protection and cryptography reference covering AES-256-GCM, Argon2id, Azure Key Vault, ASP.NET Core Data Protection, TDE, Always Encrypted, and WORM backups."
---

# Data and Cryptography Security Reference

## Scope and Cryptographic Baseline

- Evaluate encryption at rest and in transit, password hashing, key management, ASP.NET Core Data Protection key rings, database column/storage encryption, secret rotation, and backup immutability.
- Enforce `security-secrets-policy`: prohibit hardcoded cryptographic keys, initialization vectors (`IV`), salts, connection strings, or SAS tokens in source code or configuration files.

## Cryptography, Key Management, and Storage Audit Matrix

| Control Area | Standard / CWE | Vulnerable Pattern | Mandatory Hardening Standard |
| :--- | :--- | :--- | :--- |
| Symmetric Encryption | `NIST SP 800-38D`, `CWE-327`, `CWE-329` | Using `DES`, `3DES`, `RC4`, `AES-ECB`, or `AES-CBC` without HMAC (vulnerable to padding oracle `CWE-649`), or reusing nonces | Use authenticated encryption (`AES-256-GCM` via `AesGcm` or `ChaCha20-Poly1305`) with a unique 96-bit CSPRNG nonce (`RandomNumberGenerator.Fill`) per encryption operation |
| Password & Secret Hashing | `OWASP ASVS v4.0`, `CWE-916` | Hashing passwords or API keys with `MD5`, `SHA1`, unsalted `SHA256`, or low-iteration `Rfc2898DeriveBytes` | Use `Argon2id` ($m \ge 19\text{ MiB}$, $t \ge 2$, $p = 1$) or `PBKDF2-HMAC-SHA512` ($\ge 310,000$ iterations) with a unique 128-bit CSPRNG salt |
| Key Management & Rotation | `NIST SP 800-57`, `CWE-320` | Storing master keys in `appsettings.json`, environment files, or unencrypted disk volumes without rotation | Store master keys in HSM/KMS (`Azure Key Vault`, `AWS KMS`, `HashiCorp Vault`) accessed via Managed Identity with automated key rotation and versioned key identifiers (`kid`) |
| ASP.NET Core Data Protection | `CWE-311`, `CWE-320` | Default ephemeral in-memory key ring in multi-instance deployments or unencrypted XML keys persisted to shared disk | Configure `PersistKeysToAzureBlobStorage` / `PersistKeysToDbContext` AND `ProtectKeysWithAzureKeyVault` (or X.509 certificate in OS store) |
| Database Encryption (`TDE` & Column-Level) | `CWE-311`, `CWE-312` | Storing high-risk secrets, national IDs, health data, or payment tokens in plaintext database columns | Enable Transparent Data Encryption (`TDE`) for storage media AND `Always Encrypted` (or application-level `AES-256-GCM` envelope encryption) for high-sensitivity columns |
| Backup Security & WORM Immutability | `ISO 27001 A.8.13`, `CWE-530` | Unencrypted database dumps, publicly readable blob containers, or mutable backup targets deletable by compromised runtime credentials | Encrypt backups with KMS customer-managed keys, enforce immutable WORM retention policies, and isolate backup credentials from runtime roles |

## Cross-Domain Cascade Signals

- Emit `cascades_to: ["gdpr-compliance"]` when personal data or special-category data (GDPR Art. 9/32) lacks encryption, pseudonymization, or crypto-shredding key lifecycle support.
- Emit `cascades_to: ["sql-database-security"]` when database roles or `Always Encrypted` column master keys are accessible to untrusted ad-hoc queries.
- Emit `cascades_to: ["security-testing-tdd"]` for cryptographic round-trip, tamper-tag (`AuthenticationTagMismatchException`), and key-rotation regression test contracts.

## Verification Checklist

- [X] Zero deprecated algorithms (`MD5`, `SHA1`, `DES`, `3DES`, `RC4`, `AES-ECB`) used for security controls
- [X] Authenticated encryption (`AES-256-GCM`) enforced with unique CSPRNG nonces
- [X] Passwords hashed with `Argon2id` or high-iteration `PBKDF2-HMAC-SHA512`
- [X] ASP.NET Core Data Protection key ring persisted and encrypted at rest
- [X] Master keys managed in KMS/Key Vault with zero plaintext secrets in repository files
