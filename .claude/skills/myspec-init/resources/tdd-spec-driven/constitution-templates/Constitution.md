---
project_name: "{{PROJECT_NAME}}"
version: "{{CONSTITUTION_VERSION}}"
ratified: "{{RATIFIED_DATE}}"
last_amended: "{{LAST_AMENDED_DATE}}"
primary_stack: "{{PRIMARY_STACK}}"
spec_root: "{{SPEC_ROOT}}"
single_reference_lock: true
---

# Constitution: {{PROJECT_NAME}}

## Routing Matrix

| Area | Prefix | Status | Index | Owners | Scope & Core Tenet |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `01-architecture/` | `AR` | `{{STATUS_ARCHITECTURE}}` | `constitution/01-architecture/index.md` | `dotnet-expert`, `python-expert`, `shell-expert` | Module topology, inward dependencies, `KISS-Lite`, DI, `TimeProvider` (`AR-001..014`) |
| `02-domain/` | `BC` | `{{STATUS_DOMAIN}}` | `constitution/02-domain/index.md` | `ddd-expert`, `spec-sdlc-expert`, `domain-expert` | Decision authority, negative ownership, opaque refs, `[NEEDS CLARIFICATION]` (`BC-001..012`) |
| `03-ui-ux/` | `UI` | `{{STATUS_UI_UX}}` | `constitution/03-ui-ux/index.md` | `angular-expert` | Design tokens, Standalone Signals, `WCAG 2.2 AA`, Core Web Vitals (`UI-001..012`) |
| `04-data-persistence/` | `DATA` | `{{STATUS_DATA}}` | `constitution/04-data-persistence/index.md` | `dotnet-expert`, `python-expert` | Isolated storage, parameterized queries (`CWE-89`), human-gated DDL (`DATA-001..008`) |
| `05-api-contracts/` | `API` | `{{STATUS_API}}` | `constitution/05-api-contracts/index.md` | `dotnet-expert`, `angular-expert` | Versioned endpoints, immutable DTOs, RFC 9457 `ProblemDetails`, ACL (`API-001..008`) |
| `06-testing-fitness/` | `TEST` | `active` | `constitution/06-testing-fitness/index.md` | All stack experts, `test-quality-auditor` | `[RED]->[GREEN]->[REFACTOR]` triads, mock-free domain tests, fitness checks (`TEST-001..008`) |
| `07-security-privacy/` | `SEC` | `active` | `constitution/07-security-privacy/index.md` | `cyber-security-expert` | AuthN/AuthZ (`BOLA`/`BOPLA`), `CWE-798`, 6-category STRIDE, `Rule G3`, GDPR (`SEC-001..012`) |
| `08-sdd-governance/` | `SDD` | `active` | `constitution/08-sdd-governance/index.md` | `spec-sdlc-expert`, `qa-agent` | 6-artifact `[<PREFIX>-###]` traceability, SemVer amendments, `--converge` (`SDD-001..010`) |

## Sync Impact Report

| Version | Date | Touched Rules | Sync Status |
| :--- | :--- | :--- | :--- |
| `{{CONSTITUTION_VERSION}}` | `{{LAST_AMENDED_DATE}}` | `{{SYNC_IMPACT_SUMMARY}}` | `{{SYNC_IMPACT_STATUS}}` |
