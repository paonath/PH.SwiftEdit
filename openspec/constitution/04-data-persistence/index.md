---
area: "04-data-persistence"
prefix: "DATA"
status: "active"
owners: ["swift-macos-expert", "cyber-security-expert"]
---

# Atomic File Persistence, SessionRecovery & Binary Guard Mini-Index (`04-data-persistence/`)

## Micro-Files

| Micro-File | Rule IDs | Scope & Inspection Triggers |
| :--- | :--- | :--- |
| `storage-and-migrations.md` | `DATA-001..DATA-004` | Flat-file-only persistence (zero SQL/ORM), `10 MiB`/`64 MiB` stat gate, `8 KiB` `0x00` binary ban, explicit `Cmd+S` (`LF`/`CRLF`/`CR`), `10` MRU bookmarks |
| `write-read-separation.md` | `DATA-005..DATA-008` | `SessionRecovery/` (`session-manifest.json` + unbacked snapshots), close unlink & startup orphan GC, scoped bookmarks, `UserDefaults` |
