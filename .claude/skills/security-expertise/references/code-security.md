---
name: "code-security"
description: "Application and API code security checklist covering OWASP Top 10:2021, OWASP API Top 10:2023, CWE taint analysis, and stack-selective repository coding rules."
---

# Code Security Reference

## Scope and Stack-Selective Rule Pre-Loading

- Evaluate application source code, API endpoints, DTO contracts, validators, CLI/automation scripts, authentication/authorization flows, and dependency manifests.
- Load active repository coding and security rules selectively by stack before evaluating code (10 rules in `.agents/rules/`):
  - Always enforce `security-secrets-policy` (`security-secrets-policy.md`: zero plaintext passwords, API keys, JWT signing keys, or private RSA keys).
  - For C#/.NET targets (`**/*.cs`), load `csharp-coding-standards` (`csharp-coding-standards.md`), `csharp-record-patterns` (`csharp-record-patterns.md`), `dotnet-minimal-api` (`dotnet-minimal-api.md`), `dotnet-logging` (`dotnet-logging.md`), and `fluent-validation-csharp` (`fluent-validation-csharp.md`).
  - For Angular/TypeScript targets (`**/*.ts`, `**/*.html`), load `angular-coding-standards` (`angular-coding-standards.md`) and `angular-component-patterns` (`angular-component-patterns.md`).
  - For Python targets (`**/*.py`), load `python-coding-standards` (`python-coding-standards.md`).
  - For Shell/PowerShell/CMD targets (`**/*.sh`, `**/*.bash`, `**/*.zsh`, `**/*.ps1`, `**/*.cmd`), load `shell-scripting-standards` (`shell-scripting-standards.md`).
- Delegate ORM raw SQL execution sinks (`FromSqlRaw`, `ExecuteSqlRaw`, Dapper interpolation) and stored procedure audits to `references/sql-database-security.md` when enrolled in parallel.

## Repository Rule Security Mapping

| Rule Identifier | Security Control Enforced | Failure Severity |
| :--- | :--- | :--- |
| `security-secrets-policy` (`security-secrets-policy.md`) | Reject hardcoded credentials, JWT keys, connection strings, and `.env` commits | `CRITICAL` (`CWE-798`) |
| `csharp-record-patterns` (`csharp-record-patterns.md`) | Require immutable `record` DTOs (`ToDto`/`ToEntity`) to prevent mass assignment (`BOPLA`) | `HIGH` (`API3:2023`) |
| `dotnet-minimal-api` (`dotnet-minimal-api.md`) | Enforce `.RequireAuthorization(policy)`, typed `Results<T1, T2>`, and `CancellationToken` | `HIGH` (`API1:2023` / `API5:2023`) |
| `fluent-validation-csharp` (`fluent-validation-csharp.md`) | Require boundary allowlist, length, format, and role/ownership rules before service execution | `HIGH` (`CWE-20`) |
| `dotnet-logging` (`dotnet-logging.md`) | Enforce structured NLog properties and mask tokens, passwords, and raw PII | `HIGH` (`CWE-532`) |
| `csharp-coding-standards` (`csharp-coding-standards.md`) | Enforce `async`/`await` cancellation, null-safety, `Span<T>` bounds, and sealed/scoped lifetimes | `MEDIUM` (`CWE-400`) |
| `angular-coding-standards` (`angular-coding-standards.md`) | Enforce strict TypeScript types, WCAG 2.2 AA semantics, and prohibit `bypassSecurityTrust*`, `eval`, or `innerHTML` | `HIGH` (`CWE-79`) |
| `angular-component-patterns` (`angular-component-patterns.md`) | Enforce standalone signal state isolation and reactive form validators | `MEDIUM` (`CWE-20`) |
| `python-coding-standards` (`python-coding-standards.md`) | Enforce `subprocess.run(..., shell=False)`, `pathlib.Path` root confinement, and forbid `eval`/`exec`/`pickle` | `HIGH` (`CWE-78` / `CWE-22`) |
| `shell-scripting-standards` (`shell-scripting-standards.md`) | Enforce `set -euo pipefail`, `$ErrorActionPreference = 'Stop'`, quoted expansions, and guarded `rm -rf` | `HIGH` (`CWE-78`) |

## OWASP and CWE Taint Audit Matrix

| Category | CWE / OWASP | Vulnerable Sinks | Required Remediation |
| :--- | :--- | :--- | :--- |
| Broken Access Control (`BOLA`/`BFLA`/`BOPLA`) | `A01:2021`, `API1:2023`, `API3:2023`, `API5:2023`, `CWE-639` | Direct entity binding without resource-owner predicate (`userId == resource.OwnerId`), missing `.RequireAuthorization()` | Bind immutable `CreateDto`/`UpdateDto` records and verify ownership/tenant claim inside handler or validator |
| Command and Code Injection | `A03:2021`, `CWE-78`, `CWE-94`, `CWE-89` | `Process.Start` with shell concatenation, `eval()`, `Function()`, dynamic LINQ string expressions | Use argument arrays (`ProcessStartInfo.ArgumentList`), static expressions, and parameterized queries |
| Cross-Site Scripting (`XSS`) | `A03:2021`, `CWE-79` | `DomSanitizer.bypassSecurityTrustHtml`, `ElementRef.nativeElement.innerHTML`, unencoded server HTML | Rely on Angular template context encoding and strict CSP without `unsafe-inline` |
| Insecure Deserialization | `A08:2021`, `CWE-502` | `BinaryFormatter`, `NetDataContractSerializer`, `TypeNameHandling.All` / `Auto` in Newtonsoft.Json | Use `System.Text.Json` with strict polymorphic type discriminators (`[JsonDerivedType]`) |
| Server-Side Request Forgery (`SSRF`) | `A10:2021`, `API7:2023`, `CWE-918` | `HttpClient.GetAsync(userProvidedUrl)` without scheme, host allowlist, and RFC 1918/link-local (`169.254.169.254`) block | Validate URI against scheme (`https`) and explicit host allowlist before outbound call |
| Path Traversal | `A01:2021`, `CWE-22` | `Path.Combine(baseDir, userFileName)` without canonical `Path.GetFullPath` prefix verification | Resolve `Path.GetFullPath` and verify `fullPath.StartsWith(canonicalRoot + Path.DirectorySeparatorChar)` |
| Race Conditions and TOCTOU | `A04:2021`, `CWE-362` | Check-then-act balance, quota, or coupon redemption without row version (`[Timestamp]` / `xmin`) or serializable lock | Enforce optimistic concurrency token (`RowVersion`) or atomic database `UPDATE ... WHERE` predicate |
| XML External Entities (`XXE`) | `A05:2021`, `CWE-611` | `XmlReaderSettings` or `XmlDocument` with `DtdProcessing.Parse` and non-null `XmlResolver` | Set `DtdProcessing = DtdProcessing.Prohibit` and `XmlResolver = null` |

## Cross-Domain Cascade Signals

- Emit `cascades_to: ["sql-database-security"]` when taint reaches an EF Core, Dapper, or ADO.NET persistence call.
- Emit `cascades_to: ["gdpr-compliance"]` when endpoints, DTOs, or logs process personal data (`Email`, `TaxId`, `IpAddress`, `HealthData`).
- Emit `cascades_to: ["security-testing-tdd"]` for every `CRITICAL` or `HIGH` finding so a negative Given/When/Then abuse test is generated.

## Verification Checklist

- [X] Stack-matching repository coding rules loaded prior to review
- [X] Every endpoint verified for authentication, policy authorization, and `BOLA`/`BOPLA` ownership checks
- [X] Every taint source traced to sink with `file:line` evidence
- [X] Copy-ready secure code fix and Given/When/Then `test_contract` emitted per finding
