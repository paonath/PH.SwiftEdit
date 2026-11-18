---
area: "04-data-persistence"
file: "storage-and-migrations.md"
rules: ["DATA-001", "DATA-002", "DATA-003", "DATA-004"]
---

# 04-data-persistence/storage-and-migrations (DATA-001..DATA-004)

## Context
- storage_engines: `Flat Filesystem Documents, Application Support/PH.SwiftEdit/SessionRecovery/, 10-Entry MRU Bookmarks, and Codable UserDefaults`
- binary_and_size_guards: `8 KiB 0x00 Binary Probe (DomainError.binaryFileSaveForbidden), > 10 MiB Degraded Mode, > 64 MiB DomainError.fileTooLarge`

## Rules
- **DATA-001**: The `SwiftEditCore` persistence layer SHALL store user documents as flat filesystem files and session state inside `Application Support/PH.SwiftEdit/SessionRecovery/` without importing `SQLite`, `CoreData`, or `SwiftData`.
- **DATA-002**: WHEN inspecting a file prior to buffer allocation, the `SwiftEditCore` loader SHALL throw `DomainError.fileTooLarge` for files above `64 MiB` and activate plain-text degraded mode (disabling full-buffer AST, lint, and diff passes) for files above `10 MiB` up to `64 MiB`.
- **DATA-003**: IF a file contains a `0x00` NUL byte within its first `8 KiB` or resolves to a non-text `UTType`, THEN the `SwiftEditCore` persistence layer SHALL classify the file as binary, throw `DomainError.binaryFileSaveForbidden` on any save attempt, exclude it from `SessionRecovery` and tab pinning, and release its buffer immediately on tab close.
- **DATA-004**: WHEN executing an explicit user Save command or recording recent files, the `SwiftEditCore` persistence layer SHALL preserve original character encoding, byte-order mark, and 3-way `LF` (`\n`), `CRLF` (`\r\n`), or Classic Mac `CR` (`\r`) line endings via atomic `NSFileCoordinator` sibling replacement without implicit autosave-in-place mutation while capping deduplicated security-scoped MRU bookmarks at `10` existing non-binary files.
