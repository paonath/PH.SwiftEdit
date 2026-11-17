---
area: "02-domain"
file: "bounded-context-ownership.md"
rules: ["BC-001", "BC-002", "BC-003", "BC-004"]
---

# 02-domain/bounded-context-ownership (BC-001..BC-004)

## Context
- bounded_contexts: `DocumentCore (Core), SyntaxAndMarkdownProjection (Core), SearchAndReplace (Supporting), EditorPreferences (Generic)`
- subdomain_tiers: `Core | Supporting | Generic`

## Rules
- **BC-001**: Every domain state transition and editing policy SHALL belong to a single authoritative Bounded Context among `DocumentCore`, `SyntaxAndMarkdownProjection`, `SearchAndReplace`, or `EditorPreferences`.
- **BC-002**: Every OpenSpec `design.md` artifact SHALL classify each affected Bounded Context as `Core`, `Supporting`, or `Generic` prior to modifying `SwiftEditCore` namespaces.
- **BC-003**: The `DocumentSession` Aggregate Root SHALL enforce text buffer, `TextEncoding`, and `LineEnding` invariants exclusively through explicit mutating methods returning immutable `DomainEvent` values.
- **BC-004**: WHEN an editing command executes, `DocumentCore` SHALL mutate at most one `DocumentSession` value synchronously while publishing immutable `BufferRevision` snapshots for asynchronous projections.
