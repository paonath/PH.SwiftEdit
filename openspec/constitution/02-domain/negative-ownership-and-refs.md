---
area: "02-domain"
file: "negative-ownership-and-refs.md"
rules: ["BC-005", "BC-006", "BC-007", "BC-008"]
---

# 02-domain/negative-ownership-and-refs (BC-005..BC-008)

## Context
- forbidden_capabilities: `LSP daemons, embedded PTY terminals, recursive SQL/ORM indexing DBs, Git/3-way merge clients, plugin runtimes, network I/O`
- value_object_types: `DocumentID, BufferRevision, TextEncoding, LineEnding, ByteCount, TextRange, DiffHunk, BracketPairSpan`

## Rules
- **BC-005**: IF a proposed capability introduces Language Server Protocol (`LSP`) clients, embedded terminals, recursive workspace indexing databases, Git clients, 3-way merge tools, dynamic plugin runtimes, or network access, THEN `PH.SwiftEdit` SHALL reject the capability as forbidden negative ownership.
- **BC-006**: Cross-context `MarkdownLintAndFormat`, `SearchDiffAndBracketEngine`, and `WorkspaceAndTabSession` workflows SHALL reference documents exclusively via immutable `DocumentID` and `BufferRevision` values rather than shared mutable buffer references.
- **BC-007**: WHEN inbound file bytes, shallow dotfile-inclusive folder entries, pasteboard payloads, recovery blobs, or `UserDefaults` values enter `SwiftEditCore`, an Anti-Corruption Layer (`ACL`) adapter SHALL translate raw `Foundation` inputs into validated `Sendable` Value Objects.
- **BC-008**: `WorkspaceAndTabSession` SHALL restrict persistent tab manifests, pinned tabs, startup restoration, and `SessionRecovery` autosaves exclusively to text documents (excluding binary files) with immediate blob purge upon tab close and orphan garbage collection at startup.
