---
area: "04-data-persistence"
file: "write-read-separation.md"
rules: ["DATA-005", "DATA-006", "DATA-007", "DATA-008"]
---

# 04-data-persistence/write-read-separation (DATA-005..DATA-008)

## Context
- write_model: `{{WRITE_MODEL_PATTERN}}`
- read_model: `{{READ_MODEL_PATTERN}}`

## Rules
- **DATA-005**: Command write paths (`{{WRITE_MODEL_PATTERN}}`) SHALL enforce optimistic concurrency tokens/versions on every Aggregate save.
- **DATA-006**: Read-side queries (`{{READ_MODEL_PATTERN}}`) SHALL project directly to immutable DTOs/ReadModels with no-tracking execution and bounded pagination.
- **DATA-007**: Event-driven ReadModel projectors SHALL be idempotent so replaying duplicate `DomainEvent` deliveries yields identical state.
- **DATA-008**: Immutable event streams and audit logs SHALL store only pseudonymized `ExternalIdentityId` references (`GDPR Art. 5/17`), never raw PII.
