---
area: "02-domain"
file: "ubiquitous-language-and-policy.md"
rules: ["BC-009", "BC-010", "BC-011", "BC-012"]
---

# 02-domain/ubiquitous-language-and-policy (BC-009..BC-012)

## Context
- glossary_source: `design.md (## Glossario & Convenzioni)`
- safety_caps: `> 10 MiB Plain-Text Degraded Mode, > 64 MiB DomainError.fileTooLarge, <= 10 MiB / 500 ms Myers Diff, <= 128 AST depth, <= 250 ms regex/lint`

## Rules
- **BC-009**: All Swift domain types, command methods, domain events, and test identifiers across `SwiftEditCore` and `SwiftEditUI` SHALL match the context-scoped Ubiquitous Language glossary defined in `design.md`.
- **BC-010**: IF an encoding fallback rule, Markdown formatting rule, diff tie-breaker, external file conflict policy, or context boundary is underspecified, THEN the specification author SHALL emit a `[NEEDS CLARIFICATION]` marker rather than inventing domain policy.
- **BC-011**: IF a regex search or Markdown lint/format pass exceeds `250` milliseconds, a Myers diff input exceeds `10 MiB` or `500` milliseconds, a line exceeds `4096` UTF-16 code units, a `swift-markdown` AST exceeds `128` levels, or file size lies between `10 MiB` and `64 MiB`, THEN `SwiftEditCore` SHALL return a typed timeout or degraded plain-text outcome.
- **BC-012**: IF a command attempts to save a binary-inspected file (`DomainError.binaryFileSaveForbidden`), opens a file exceeding `64 MiB` (`DomainError.fileTooLarge`), violates a domain invariant, or targets a Markdown URI outside `https`, `http`, `mailto`, or symlink-verified granted scope, THEN the owning context SHALL return a typed `DomainError` or inert resource descriptor without mutating `DocumentSession`.
