---
area: "02-domain"
prefix: "BC"
status: "active"
owners: ["ddd-expert", "swift-macos-expert", "spec-sdlc-expert"]
---

# Domain Governance & Bounded Contexts Mini-Index (`02-domain/`)

## Micro-Files

| Micro-File | Rule IDs | Scope & Inspection Triggers |
| :--- | :--- | :--- |
| `bounded-context-ownership.md` | `BC-001..BC-004` | `DocumentCore` (`Cmd+D`), `MarkdownLintAndFormat`, `SearchDiffAndBracketEngine`, `WorkspaceAndTabSession` |
| `negative-ownership-and-refs.md` | `BC-005..BC-008` | Anti-IDE/LSP/DB negative ownership, immutable `(DocumentID, BufferRevision)` refs, `SessionRecovery` & binary exclusion |
| `ubiquitous-language-and-policy.md` | `BC-009..BC-012` | Ubiquitous Language glossary, `[NEEDS CLARIFICATION]`, diff/lint/regex caps, `DomainError.binaryFileSaveForbidden` |
