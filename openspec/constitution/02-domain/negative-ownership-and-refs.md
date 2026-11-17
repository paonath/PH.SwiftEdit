---
area: "02-domain"
file: "negative-ownership-and-refs.md"
rules: ["BC-005", "BC-006", "BC-007", "BC-008"]
---

# 02-domain/negative-ownership-and-refs (BC-005..BC-008)

## Context
- forbidden_capabilities: `LSP daemons, embedded PTY terminals, workspace SQL/ORM DBs, Git clients, plugin/script runtimes, network I/O`
- value_object_types: `DocumentID, BufferRevision, TextEncoding, LineEnding, ByteCount, TextRange`

## Rules
- **BC-005**: IF a proposed capability introduces Language Server Protocol (`LSP`) clients, embedded terminals, workspace indexing databases, Git clients, dynamic plugin runtimes, or network access, THEN `PH.SwiftEdit` SHALL reject the capability as forbidden negative ownership.
- **BC-006**: Cross-context projections and search workflows SHALL reference documents exclusively via immutable `DocumentID` and `BufferRevision` values rather than shared mutable buffer references.
- **BC-007**: WHEN inbound file bytes, pasteboard payloads, or `UserDefaults` values cross into `SwiftEditCore`, an Anti-Corruption Layer (`ACL`) adapter SHALL translate raw `Foundation` inputs into validated `Sendable` Value Objects.
- **BC-008**: Domain contracts SHALL represent document identifiers, revisions, encodings, line endings, byte counts, and UTF-16 text ranges as validated `Sendable` Value Objects (`DocumentID`, `BufferRevision`, `TextEncoding`, `LineEnding`, `ByteCount`, `TextRange`).
