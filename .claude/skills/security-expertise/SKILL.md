---
name: "security-expertise"
description: "Progressive-disclosure cybersecurity reference catalog and AI-to-AI specialist contract for Code, SQL/Database, Network, Data/Crypto, GDPR Compliance, and Security TDD."
---

# Security Expertise Skill

## Scope and Progressive Disclosure

- The security-expertise skill SHALL enforce **Single-Reference Lock** by directing each spawned sub-agent to load exclusively the single `references/<domain>.md` file assigned in its `[SEC_DELEGATION v1]` envelope via `Read`.
- The security-expertise skill SHALL enforce **Strict Read-Only Sub-Agent Execution** so hydrated sub-agents create, edit, or delete zero repository files.
- WHEN credentials, tokens, keys, or personal data literals appear in findings, the security-expertise skill SHALL mask each discovered literal with `***REDACTED***`.
- IF a sub-agent attempts to load multiple `references/*.md` files simultaneously, THEN the security-expertise skill SHALL reject the multi-reference delegation.

## Domain Reference Routing Index

| Domain ID | Reference File | Trigger Signals | Pre-Loaded Assets |
| :--- | :--- | :--- | :--- |
| `code-security` | `references/code-security.md` | Source files (`.cs`, `.ts`, `.html`, `.py`, `.sh`, `.ps1`), API endpoints, DTOs, validators, CLI scripts, auth flows | `security-secrets-policy.md`, `csharp-coding-standards.md`, `csharp-record-patterns.md`, `dotnet-minimal-api.md`, `dotnet-logging.md`, `fluent-validation-csharp.md`, `angular-coding-standards.md`, `angular-component-patterns.md`, `python-coding-standards.md`, `shell-scripting-standards.md` |
| `sql-database-security` | `references/sql-database-security.md` | SQL scripts, migrations, stored procedures, EF Core `FromSql*`, Dapper, RLS | `sql-schema-planner`, `security-secrets-policy` |
| `network-security` | `references/network-security.md` | TLS, CORS, CSP/HSTS headers, Kestrel/IIS/nginx, reverse proxy, OIDC/Entra ID | `security-secrets-policy` |
| `data-security` | `references/data-security.md` | AES-GCM, Argon2id, Key Vault, Data Protection key ring, TDE, Always Encrypted, backups | `security-secrets-policy` |
| `gdpr-compliance` | `references/gdpr-compliance.md` | PII fields, erasure/retention, audit logs, consent, RoPA, DPIA, cross-border transfers | `security-secrets-policy`, `dotnet-logging` |
| `security-testing-tdd` | `references/security-testing-tdd.md` | Unit/integration test suites, security TDD triads, abuse-case assertions, CRAP/coverage | `dotnet-test-suite` plugin (`dotnet-test-suite__test-tagging`, `dotnet-test-suite__assertion-quality`, `dotnet-test-suite__test-anti-patterns`, `dotnet-test-suite__test-gap-analysis`, `dotnet-test-suite__find-untested-sources`, `dotnet-test-suite__coverage-analysis`, `dotnet-test-suite__crap-score`) |

## ORM and Persistence Seam Partition

- WHEN a target scope touches EF Core, Dapper, ADO.NET, or SQL migrations, the security-expertise skill SHALL enroll `code-security` and `sql-database-security` in parallel.
- The code-security domain SHALL evaluate exclusively the application boundary including endpoint authorization (`BOLA`/`BOPLA`), immutable `record` DTO projection (`ToDto`/`ToEntity`), and `FluentValidation` input rules.
- The sql-database-security domain SHALL evaluate exclusively the persistence boundary including raw query sinks (`FromSqlRaw`, `ExecuteSqlRaw`, Dapper interpolation), `sp_executesql` parameterization, `QUOTENAME` with `sys.columns` allowlists, first-order and second-order SQLi, `WITH EXECUTE AS`, RLS predicates, and DB role permissions.

## AI-to-AI Wire Protocol

### Outbound Delegation Envelope (`[SEC_DELEGATION v1]`)

```yaml
[SEC_DELEGATION v1]
role: "security-<domain>-analyst"
load_reference: "references/<domain>.md"
preload_rules: ["<rule-or-skill-1>", "<rule-or-skill-2>"]
target_scope: ["<path_or_symbol_1>", "<path_or_symbol_2>"]
threat_focus: ["<STRIDE_or_CWE_or_GDPR_focus>"]
constraints: "READ_ONLY | SINGLE_REFERENCE_ONLY | NO_PROSE | MAX_400_WORDS"
```

### Inbound Specialist Verdict (`[SEC_FINDINGS v1]`)

```yaml
[SEC_FINDINGS v1]
domain: "<domain>"
status: "PASS | FAIL | CONDITIONAL"
findings:
  - id: "SEC-<DOM>-01"
    sev: "CRITICAL | HIGH | MEDIUM | LOW"
    cwe_or_reg: "<CWE-ID | OWASP-ID | GDPR-Art>"
    verdict_class: "VULNERABILITY_EVIDENCE | NON_COMPLIANT_EVIDENCE | UNVERIFIABLE_IN_CODE_REQUIRES_PROCESS | REQUIRES_DPO_LEGAL_VALIDATION"
    loc: "<file:line_start-line_end>"
    sink: "<taint_source -> sink_expression>"
    fix: "<single-line remediation requirement>"
    test_contract: "GIVEN <precondition> WHEN <attack_or_input> THEN <expected_rejection>"
    cascades_to: ["<other-domain-if-any>"]
```

### Discrepancy Re-Evaluation Query (`[SEC_CONVERGENCE_QUERY v1]`)

```yaml
[SEC_CONVERGENCE_QUERY v1]
iteration: 2 # max 3
tension_id: "TENSION-01"
conflicting_findings: ["SEC-CODE-01", "SEC-GDPR-02"]
question: "<single atomic reconciliation question>"
constraint: "MAX_120_TOKENS | HARD_CONSTRAINT_PRECEDENCE"
```

## Behavioral Scenarios

```gherkin
Feature: Security Expertise Progressive Disclosure
  @REQ-SEC-EXP-001
  Scenario: Parallel persistence routing redacts sensitive findings
    Given an audit scope modifies an EF Core query and database migration
    When the orchestrator delegates domain checks under Single-Reference Lock
    Then code-security and sql-database-security evaluate boundaries in parallel with ***REDACTED*** masking

  @REQ-SEC-EXP-002
  Scenario: Multi-reference loading or file mutation is denied
    Given a sub-agent envelope targets multiple domain references or edits a source file
    When the security-expertise contract enforces Single-Reference Lock and Read-Only execution
    Then the multi-reference load and file mutation are denied
```
