---
name: "gdpr-compliance"
description: "Technical GDPR engineering reference (Regulation EU 2016/679 & EDPB) mapping Articles 5-49 to code, schema, log, and backup controls with tri-state compliance verdicts."
---

# GDPR Technical Compliance Reference

## Scope and Tri-State Compliance Verdict Contract

- Evaluate data models, API payloads, database schemas, retention jobs, deletion handlers, audit logs, and third-party integrations against Regulation (EU) 2016/679 (`GDPR`) and EDPB Guidelines 4/2019 (Data Protection by Design and by Default).
- Classify every GDPR finding using one of three deterministic `verdict_class` values in `[SEC_FINDINGS v1]`:
  - `NON_COMPLIANT_EVIDENCE`: Objective technical violation proven directly in source code, schema, or configuration (such as raw PII in logs, missing deletion cascade, or `IsDeleted = 1` retention without purge).
  - `UNVERIFIABLE_IN_CODE_REQUIRES_PROCESS`: Control depends on external operational infrastructure or runbooks not visible in the repository (such as backup WORM policy or SIEM 72-hour alert routing).
  - `REQUIRES_DPO_LEGAL_VALIDATION`: Legal or organizational determination outside software engineering authority (such as lawful basis selection under Art. 6, Art. 28 DPA execution, or Art. 35 DPIA sign-off).

## GDPR Article-to-Code Verification Matrix

| GDPR Article | Technical Principle | Verification Target | Violation Condition |
| :--- | :--- | :--- | :--- |
| `Art. 5(1)(b)-(c)` | Purpose Limitation & Data Minimization | DTO records (`CreateDto`/`EntityDto`), EF Core `.Select()` projections, API responses | Returning full database entities (`SELECT *`) or collecting unrequired PII fields not bound to the operation |
| `Art. 5(1)(e)` | Storage Limitation | Scheduled purge/TTL background jobs (`IHostedService` / Hangfire / SQL Agent) and `ExpiresAtUtc` columns | Storing personal data, session tokens, or audit trails indefinitely without an automated TTL purge job |
| `Art. 6` & `Art. 9` | Lawfulness & Special Categories | Consent ledger tables (`PolicyVersion`, `GrantedAtUtc`, `PurposeId`, `WithdrawnAtUtc`) and Art. 9 sensitive data isolation | Boolean-only `HasConsented = true` without version/timestamp/purpose provenance, or unencrypted Art. 9 health/biometric data |
| `Art. 12`, `Art. 15`, `Art. 20` | Access (`DSAR`) & Data Portability | Machine-readable export endpoints (`JSON`) scoped strictly to authenticated `SubjectId` | Missing subject-scoped export query or cross-tenant data leakage during DSAR aggregation |
| `Art. 17` | Right to Erasure (Right to be Forgotten) | Erasure command handlers, foreign-key cascades, search indexes, caches, and backup restore hooks | Setting `IsDeleted = 1` (soft-delete trap) while retaining plaintext PII in tables, logs, or search indexes |
| `Art. 25` | Data Protection by Design and by Default | Default privacy settings in entity constructors, DTO defaults, and telemetry opt-in flags | Pre-ticked marketing/tracking flags (`OptIn = true` by default) or public profile visibility by default |
| `Art. 28` & `Art. 44`-`49` | Processors & Cross-Border Transfers | Outbound `HttpClient` endpoints, AI/LLM SDK calls, cloud region settings, and telemetry sinks | Sending unredacted PII to external third-party APIs or non-EEA endpoints without pseudonymization and transfer configuration |
| `Art. 30` | Records of Processing Activities (`RoPA`) | Data classification attributes/annotations on PII entity properties and service data-flow inventories | Undocumented PII columns added in migrations without classification metadata |
| `Art. 32` | Security of Processing | Pseudonymization, encryption at rest/in transit (`AES-256-GCM`, `TLS 1.3`), and RBAC/ABAC | Plaintext PII storage, missing authorization policies on PII endpoints, or unmasked PII in test fixtures |
| `Art. 33` & `Art. 34` | 72-Hour Breach Notification Readiness | Structured security audit events (`dotnet-logging`) for mass export, auth anomalies, and privilege escalation | Swallowing unauthorized access exceptions or lacking structured audit telemetry to determine affected subjects within 72 hours |
| `Art. 35` | Data Protection Impact Assessment (`DPIA`) | Automated profiling, scoring, biometric processing, or large-scale systematic monitoring modules | Deploying automated profiling/AI scoring over personal data without a recorded DPIA gate (`REQUIRES_DPO_LEGAL_VALIDATION`) |

## Mandatory Technical Reconciliation Patterns

### 1. Art. 17 Erasure vs Point-in-Time Backups (Crypto-Shredding & Suppression Tombstones)

- **Soft-Delete Prohibition**: Never accept `IsDeleted = 1` alone as GDPR Art. 17 compliance; require either physical row deletion/anonymization (`UPDATE ... SET Email = NULL, Name = 'REDACTED'`) or per-subject key destruction (**crypto-shredding**).
- **Backup Resurrection Guard**: Because immutable WORM backups (`data-security`) cannot be mutated in place, require a minimal `ErasureTombstones` table storing only `Sha256(SubjectId)` and `ErasedAtUtc` (zero plaintext PII) plus a mandatory post-restore scrub hook that re-applies erasure for all tombstoned hashes before a restored database goes online.

### 2. Art. 5(1)(c) & Art. 17 vs STRIDE Repudiation (KMS-Peppered HMAC-SHA256 Audit Logs)

- **Zero Raw PII in Logs**: Never log raw email addresses, usernames, national IDs, or full IPv4/IPv6 addresses in application or security logs (`CWE-532`).
- **Pseudonymized Correlation**: Log a deterministic pseudonym `HmacSha256(SubjectId, KmsRotatingPepper)` (or truncate IP addresses to `/24` IPv4 and `/48` IPv6) so security incident responders can correlate brute-force or abuse events without persisting raw PII in immutable log sinks.

## Cross-Domain Cascade Signals

- Emit `cascades_to: ["data-security"]` when Art. 9/32 PII columns or crypto-shredding keys require KMS/Always Encrypted protection.
- Emit `cascades_to: ["sql-database-security"]` when Art. 17 erasure cascades or RLS tenant boundaries touch SQL tables and procedures.
- Emit `cascades_to: ["security-testing-tdd"]` to enforce automated tests verifying that erased subjects return zero PII across APIs, DB tables, and logs.

## Verification Checklist

- [X] Every finding assigned an explicit tri-state `verdict_class`
- [X] Soft-delete (`IsDeleted = 1`) on PII rejected unless paired with anonymization/crypto-shredding and `Sha256(SubjectId)` backup tombstones
- [X] Audit and error logs verified free of raw PII (`HmacSha256(SubjectId, KmsRotatingPepper)` enforced)
- [X] DTOs and EF Core projections verified for Art. 5(1)(c) data minimization
