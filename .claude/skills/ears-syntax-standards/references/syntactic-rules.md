# EARS Syntactic Rules & Banned Phrasing Catalog

## 1. Single-SHALL Rule (Atomicity)
- Every requirement statement must contain exactly **ONE** `SHALL`.
- **Violation**: `WHEN the user submits, the system SHALL save the record AND SHALL send an email.`
- **Remedy**: Split into two distinct atomic requirements:
  - `REQ-001`: `WHEN the user submits the form, the System SHALL save the record to the database.`
  - `REQ-002`: `WHEN a new record is saved, the Notification Service SHALL dispatch a confirmation email.`

## 2. Active Voice Rule
- The system component executing the action must be the grammatical subject.
- **Banned**: `... a loading spinner SHALL be displayed.`
- **Compliant**: `... the Web Client SHALL display a loading indicator.`

## 3. Banned Words & Vague Qualifiers Catalog

| Banned Term | Reason for Rejection | Concrete Remedy |
|---|---|---|
| `fast`, `quickly` | Untestable subjective speed | Specify explicit latency threshold (`within 250 milliseconds`) |
| `robust`, `reliable` | Vague quality attribute | State fault-tolerance invariant (`retry 3 times with exponential backoff`) |
| `user-friendly` | Unquantifiable UX opinion | State concrete interaction behavior or WCAG 2.2 AA accessibility target |
| `and/or`, `etc.` | Multiple ambiguous paths | Explicitly enumerate all supported options across separate requirements |
| `gracefully` | Undefined error behavior | Explicitly specify status code, logging, and fallback return value |
| `should`, `may` | Non-normative / optional ambiguity | Use `SHALL` for mandatory requirements, `WHERE` for optional features |
