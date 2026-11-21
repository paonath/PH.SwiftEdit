# Workflow 03: Validate Diagram

## Avoiding broken diagrams

A diagram that fails to render is worse than no diagram — it's dead weight in the file. Before finalizing:

- Every fenced block opens and closes with matching triple-backtick + `mermaid` / triple-backtick
- Special characters in labels that can break parsing (`()`, `{}`, `"`, `:`, `#`) are quoted, e.g. `A["Check (retry < 3)"]`
- Sequence diagrams don't use `style` directives — they're not supported inside `sequenceDiagram`
- Diagrams stay reasonably sized (roughly under ~20-25 nodes/participants); if a flow is bigger than that, split it into two focused diagrams rather than one sprawling one that's hard to read at a glance
- If you have a way to render/preview Mermaid in your current environment, do a quick check before finishing — otherwise, keep the syntax to the well-established patterns in this file, which are known to render cleanly on GitHub, GitLab, VS Code-family editors, and Obsidian

## Summary checklist

Before finishing a document that includes a Mermaid diagram, confirm:

- [ ] The diagram documents something with genuine structure (branches, multiple actors, states, or relationships) — not a trivial linear list
- [ ] The same flow is also explained in prose — the diagram supplements, never substitutes
- [ ] The diagram type matches the content (sequence vs. flowchart vs. state vs. ER vs. class)
- [ ] Node/participant labels are descriptive, not generic letters
- [ ] The fenced block and syntax are well-formed

## Phase Requirements (EARS)

- The diagram validation workflow SHALL verify matching fenced code delimiters, quoted special characters, absence of `style` directives inside `sequenceDiagram`, and a cap of 25 nodes per diagram.
- IF a diagram exceeds 25 nodes or participants, THEN the diagram validation workflow SHALL split the representation into focused diagrams before finalizing.
