---
area: "02-domain"
file: "ubiquitous-language-and-policy.md"
rules: ["BC-009", "BC-010", "BC-011", "BC-012"]
---

# 02-domain/ubiquitous-language-and-policy (BC-009..BC-012)

## Context
- glossary_source: `design.md (## Glossario & Convenzioni)`
- safety_caps: `> 10 MiB Plain-Text Degraded Mode, > 64 MiB DomainError.fileTooLarge, <= 128 AST depth, <= 250 ms regex, <= 4096 UTF-16 cols`

## Rules
- **BC-009**: All Swift domain types, command methods, domain events, and test identifiers SHALL match the context-scoped Ubiquitous Language glossary defined in `design.md`.
- **BC-010**: IF an encoding fallback rule, external file conflict policy, or bounded context boundary is underspecified, THEN the specification author SHALL emit a `[NEEDS CLARIFICATION]` marker rather than inventing domain policy.
- **BC-011**: IF a user regex query exceeds `250` milliseconds, a source line exceeds `4096` UTF-16 code units, or a Markdown AST exceeds `128` nesting levels, THEN `SwiftEditCore` SHALL return a typed timeout or plain-text fallback outcome.
- **BC-012**: IF a command violates a domain invariant or targets a Markdown URI outside `https`, `http`, `mailto`, or symlink-verified granted scope, THEN the owning context SHALL return a typed `DomainError` or inert blocked-resource descriptor without mutating `DocumentSession`.
