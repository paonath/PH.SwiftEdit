---
area: "04-data-persistence"
file: "storage-and-migrations.md"
rules: ["DATA-001", "DATA-002", "DATA-003", "DATA-004"]
---

# 04-data-persistence/storage-and-migrations (DATA-001..DATA-004)

## Context
- storage_engines: `Flat Filesystem Documents and Codable UserDefaults (Zero SQLite/CoreData/SwiftData)`
- size_guardrails: `> 10 MiB Plain-Text Degraded Mode, > 64 MiB DomainError.fileTooLarge`

## Rules
- **DATA-001**: The `SwiftEditCore` persistence layer SHALL store user documents exclusively as flat filesystem files without importing or linking `SQLite`, `CoreData`, or `SwiftData`.
- **DATA-002**: WHEN opening a document larger than `10 MiB` and at or below `64 MiB`, the `SwiftEditCore` loader SHALL activate Plain-Text Degraded Mode disabling full-document syntax lexing and Markdown AST parsing.
- **DATA-003**: IF pre-read metadata inspection reports a file size exceeding `64 MiB`, THEN the `SwiftEditCore` loader SHALL reject the read before buffer allocation with `DomainError.fileTooLarge`.
- **DATA-004**: WHEN decoding or saving a document without an explicit user conversion command, the `SwiftEditCore` text codec SHALL preserve the original `TextEncoding`, byte-order mark, and `LF` or `CRLF` line endings.
