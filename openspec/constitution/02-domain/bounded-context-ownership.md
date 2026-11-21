---
area: "02-domain"
file: "bounded-context-ownership.md"
rules: ["BC-001", "BC-002", "BC-003", "BC-004"]
---

# 02-domain/bounded-context-ownership (BC-001..BC-004)

## Context
- bounded_contexts: `DocumentCore (Core), MarkdownLintAndFormat (Core), SearchDiffAndBracketEngine (Supporting), WorkspaceAndTabSession (Supporting)`
- subdomain_tiers: `Core | Supporting | Generic`

## Rules
- **BC-001**: Every domain state transition and editing policy in `SwiftEditCore` SHALL belong to a single authoritative Bounded Context among `DocumentCore`, `MarkdownLintAndFormat`, `SearchDiffAndBracketEngine`, or `WorkspaceAndTabSession`.
- **BC-002**: Every OpenSpec `design.md` artifact SHALL classify each affected Bounded Context as `Core`, `Supporting`, or `Generic` while keeping `SwiftEditCore` free of `AppKit`, `UIKit`, `SwiftUI`, and `WebKit` imports across `.macOS(.v26)` and `.iOS(.v26)`.
- **BC-003**: The `DocumentSession` Aggregate Root SHALL enforce text buffer edits, newline-preserving line or selection duplication (`Cmd+D`), `TextEncoding`, `LineEnding`, and read-only binary inspection invariants exclusively through mutating methods returning immutable `DomainEvent` values.
- **BC-004**: WHEN an edit, `Cmd+D` duplication, Markdown `Format Section` or `Format Document` batch, or search replacement executes, `DocumentCore` SHALL mutate at most one `DocumentSession` value synchronously while publishing immutable `BufferRevision` snapshots to downstream contexts.
