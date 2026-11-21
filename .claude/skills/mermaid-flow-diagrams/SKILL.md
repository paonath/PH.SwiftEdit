---
name: mermaid-flow-diagrams
description: Use whenever producing a markdown (.md) document — for human readers, other AI agents/skills, or both — that describes a complex flow, such as a multi-step process, branching logic, state transitions, a sequence of interactions between actors/systems/services, or structured relationships (data/entity models, class/type structures, ACL/permission hierarchies). Applies to any skill or agent writing README files, architecture docs, ADRs, workflow/runbook descriptions, API/integration docs, or AI-readable context files. Trigger this even if the calling skill or user didn't explicitly ask for a "diagram" — words like flow, workflow, sequence, pipeline, state machine, architecture, process, or descriptions of how components/systems interact are enough. Do NOT trigger for simple linear explanations, single-step instructions, or documents with no structural complexity to convey.
---

# Mermaid Flow Diagrams — Progressive Disclosure Router

Author explicit, diffable Mermaid flow diagrams alongside prose in Markdown documents when documenting multi-step processes, branching logic, actor interactions, state machines, or entity/class relationships.

## Single-Reference Lock

Enforce **Single-Reference Lock**: load only the active workflow `workflow.md` required for the current diagramming phase. Do not load all workflow files simultaneously.

## Core Principles

- **Aid, not replacement**: Every Mermaid diagram MUST sit alongside prose (prose carries the *why*; the diagram carries the *shape*).
- **Genuine structural complexity**: Only add diagrams for branching flows, `> 3` sequential steps, multi-actor sequences, state machines, or entity/class graphs — never for trivial linear lists.
- **Traceable labels & safe syntax**: Use real domain/class/service identifiers (`ValidateToken`, `AuthService`) instead of single letters (`A`, `S2`), and quote labels containing special characters (`()`, `{}`, `"`, `:`, `#`).

## Workflow Routing Table

| Phase | Trigger / Intent | Workflow Entry |
|---|---|---|
| **01. Scope & Placement** | Decide whether a flow warrants a diagram and place it inline with surrounding prose | [workflows/01-scope-and-placement/workflow.md](workflows/01-scope-and-placement/workflow.md) |
| **02. Select & Author Diagram** | Pick the right Mermaid type (`flowchart TD`, `sequenceDiagram`, `stateDiagram-v2`, `erDiagram`, `classDiagram`) and write traceable labels | [workflows/02-select-and-author-diagram/workflow.md](workflows/02-select-and-author-diagram/workflow.md) |
| **03. Validate Diagram** | Verify fencing, quoted special characters, node budget (`<= 25`), and completion checklist | [workflows/03-validate-diagram/workflow.md](workflows/03-validate-diagram/workflow.md) |

## Formal Requirements (EARS)

- The mermaid-flow-diagrams skill SHALL place every Mermaid block alongside explanatory prose rather than substituting prose.
- WHEN documenting branching workflows, multi-actor sequences, state machines, or entity models, the mermaid-flow-diagrams workflow SHALL author a bounded diagram up to 25 nodes using descriptive domain labels.
- IF a diagram label contains parentheses, braces, colons, hashes, or quotes, THEN the mermaid-flow-diagrams validator SHALL enforce double-quoted label syntax before completion.

## BDD Scenarios

```gherkin
Feature: Mermaid Flow Diagram Authoring

  @REQ-MRM-001
  Scenario: Branching workflow receives a well-formed Mermaid diagram alongside prose
    Given a technical document describing a multi-actor authentication flow
    When the authoring workflow pairs explanatory prose with a quoted sequence diagram
    Then the resulting document satisfies syntax, label, and node-budget checks

  @REQ-MRM-002
  Scenario: Diagram with unquoted special characters in node labels fails validation
    Given a Mermaid diagram containing unquoted parentheses and colons inside node text
    When the diagram validation checklist executes
    Then the validator flags the unquoted label syntax for correction before finalizing
```
