---
name: "security-testing-tdd"
description: "Security-oriented TDD and test suite verification reference integrating the dotnet-test-suite plugin, deterministic testability seams, and Given/When/Then abuse contracts."
---

# Security Testing and TDD Reference

## Scope and Conditional `dotnet-test-suite` Integration

- Evaluate unit, integration, and governance test suites covering authentication, authorization, input validation, SQL parameterization, cryptography, and GDPR erasure/minimization controls.
- Load and invoke the `dotnet-test-suite` plugin skills whenever a security task involves test auditing, test planning, or security TDD verification:
  - `dotnet-test-suite__test-tagging`: Categorize and audit tests with the `security`, `negative`, `boundary`, and `critical-path` traits.
  - `dotnet-test-suite__assertion-quality`: Detect weak, shallow, assertion-free, or tautological assertions in security tests (such as asserting only `result != null` instead of HTTP `401`/`403`/`400` and zero database mutation).
  - `dotnet-test-suite__test-anti-patterns`: Flag swallowed exceptions (`try/catch` hiding security failures), coverage-touching tests without assertions, and nondeterministic `DateTime.Now` / `Thread.Sleep` usage.
  - `dotnet-test-suite__test-gap-analysis`: Perform boundary and pseudo-mutation reasoning on authentication guards, role checks, validator rules, and cryptographic tag checks to find survived security mutants.
  - `dotnet-test-suite__find-untested-sources`: Identify endpoints, validators, authorization handlers, or repositories lacking corresponding test files.
  - `dotnet-test-suite__coverage-analysis` and `dotnet-test-suite__crap-score`: Identify high-complexity, low-coverage security hotspots (`CRAP > 30`) requiring immediate negative test coverage.

## Security TDD Triad Contract (`RED -> GREEN -> REFACTOR`)

| Triad Phase | Task ID Format | Mandatory Execution Rule |
| :--- | :--- | :--- |
| `RED` | `TASK-xxx-RED` | Author a failing automated test targeting the exact abuse case or boundary violation (`401`, `403`, `400`, `SqlException` prevention, or PII redaction) and verify it fails for the expected assertion reason |
| `GREEN` | `TASK-xxx-GREEN` | Implement the minimum production security control (policy, validator, `sp_executesql`, `AES-256-GCM`, or PII scrubber) required to make the `RED` test pass |
| `REFACTOR` | `TASK-xxx-REFACTOR` | Deduplicate security helpers, centralize policies/constants, and re-run the test suite via `dotnet-test-suite__run-tests` to guarantee zero regressions |

## Deterministic Security Testability Seams

- Replace ambient static clocks (`DateTime.UtcNow` / `DateTime.Now`) with injectable `TimeProvider` (`FakeTimeProvider`) to deterministically test JWT expiration, clock skew, account lockout windows, and GDPR retention TTL jobs (`dotnet-test-suite__detect-static-dependencies`, `dotnet-test-suite__migrate-static-to-wrapper`).
- Replace direct `System.IO.File` / `Directory` calls with `IFileSystem` to deterministically test path traversal (`CWE-22`) rejection without touching the host disk.
- Verify that every negative security test asserts both:
  1. The explicit rejection outcome (HTTP `401 Unauthorized`, `403 Forbidden`, `400 Bad Request`, or domain validation error).
  2. The **zero side-effect invariant** (target database row, file, or audit state remains unmodified).

## Abuse-Case Test Contract Catalog

| Security Domain | Abuse Scenario | Required Assertion Depth |
| :--- | :--- | :--- |
| `code-security` (`BOLA` / `IDOR`) | `GIVEN` authenticated `UserA` `WHEN` requesting or mutating `UserB` resource ID `THEN` return `403 Forbidden` or `404 NotFound` | Assert HTTP status code AND verify `UserB` entity state in database is unchanged |
| `sql-database-security` (`CWE-89`) | `GIVEN` adversarial payload `' OR 1=1 --` or invalid `sortBy = "Id; DROP TABLE Users"` `WHEN` passed to repository/procedure `THEN` treat as literal or throw allowlist validation error | Assert exact row count (`0` matches for literal injection) or `ArgumentException`/SQL error `50001` |
| `network-security` (`JWT` / `CORS`) | `GIVEN` expired, wrong-audience, or `alg: none` token `WHEN` calling protected endpoint `THEN` reject with `401 Unauthorized` | Assert `WWW-Authenticate` header and zero handler execution |
| `data-security` (`AES-GCM` Tamper) | `GIVEN` ciphertext with a 1-bit flipped authentication tag `WHEN` decryption executes `THEN` throw `AuthenticationTagMismatchException` | Assert exact exception type and verify zero plaintext bytes are returned |
| `gdpr-compliance` (Art. 17 & Logs) | `GIVEN` erased subject `WHEN` querying tables, DSAR exports, or auth failure logs `THEN` return zero plaintext PII and record `Sha256(SubjectId)` tombstone | Assert PII columns are purged/null, tombstone hash exists, and log sink contains only `HmacSha256` pseudonym |

## Verification Checklist

- [X] All security tests tagged with `security` and `negative` traits (`dotnet-test-suite__test-tagging`)
- [X] Every security test verifies both explicit rejection status and zero side-effect state mutation (`dotnet-test-suite__assertion-quality`)
- [X] Time-dependent security controls (JWT expiry, lockout, GDPR TTL) tested via `TimeProvider`
- [X] Zero swallowed exceptions or assertion-free security tests (`dotnet-test-suite__test-anti-patterns`)
