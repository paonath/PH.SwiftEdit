---
area: "04-data-persistence"
prefix: "DATA"
status: "active"
owners: ["swift-macos-expert", "cyber-security-expert"]
---

# Atomic File Persistence & Preferences Mini-Index (`04-data-persistence/`)

## Micro-Files

| Micro-File | Rule IDs | Scope & Inspection Triggers |
| :--- | :--- | :--- |
| `storage-and-migrations.md` | `DATA-001..DATA-004` | Flat-file-only persistence (zero SQL/CoreData/SwiftData), `10 MiB`/`64 MiB` stat gate, BOM/CRLF round-trip fidelity |
| `write-read-separation.md` | `DATA-005..DATA-008` | Explicit `Cmd+S` `.atomic` writes (`autosavesInPlace = false`), `NSFilePresenter` conflict safety, scoped bookmarks, `UserDefaults` |
