# Workflow 02: Select and Author Diagram

## Choosing the right diagram type

| Use case | Diagram type | Keyword to open with |
|---|---|---|
| Ordered steps, decisions, branches | Flowchart | `flowchart TD` (or `LR` for wide/short flows) |
| Interactions between actors/systems over time, request/response | Sequence diagram | `sequenceDiagram` |
| An entity moving through distinct states | State diagram | `stateDiagram-v2` |
| Data/entity relationships, schema | Entity-relationship diagram | `erDiagram` |
| Types, classes, inheritance, object structure | Class diagram | `classDiagram` |
| Chronology of events/releases | Timeline / Gantt | `timeline` / `gantt` |

When a flow doesn't cleanly fit one type (e.g., it's part sequence, part decision tree), pick the type that captures the *dominant* structure and let the prose cover the rest — don't force one diagram to do everything.

### Quick syntax reference

**Flowchart** — steps and branches:
```
flowchart TD
    A[Receive request] --> B{Valid token?}
    B -->|yes| C[Process request]
    B -->|no| D[Return 401]
```

**Sequence diagram** — who talks to whom, in order:
```
sequenceDiagram
    participant Client
    participant Server
    Client->>Server: Request
    Server-->>Client: Response
```

**State diagram** — lifecycle of an entity:
```
stateDiagram-v2
    [*] --> Draft
    Draft --> Submitted
    Submitted --> Approved
    Submitted --> Rejected
    Rejected --> Draft
    Approved --> [*]
```

**ER diagram** — data relationships:
```
erDiagram
    NODE ||--o{ NODE_CLOSURE : "has ancestors/descendants"
    NODE ||--o{ ACL_ENTRY : "has permissions"
```

**Class diagram** — types and structure:
```
classDiagram
    class NodeId {
        +Guid Value
    }
    class Node {
        +NodeId Id
        +string Name
    }
    Node --> NodeId
```

## Writing good labels

Use descriptive node and participant names — `ValidateToken`, not `A`; `AuthService`, not `S2`. A diagram with generic single-letter labels loses most of its value: the reader (or the AI parsing it later) has to cross-reference a legend instead of reading the graph directly. Keep labels short but meaningful, matching the actual names used in the codebase or spec where possible (e.g., real class names, real service names) so the diagram stays traceable to the real system.

## Phase Requirements (EARS)

- The authoring workflow SHALL select the Mermaid diagram type matching the dominant structural pattern (`flowchart`, `sequenceDiagram`, `stateDiagram-v2`, `erDiagram`, `classDiagram`, or `timeline`).
- WHEN naming diagram nodes or participants, the authoring workflow SHALL use domain identifiers matching codebase or specification names instead of single-letter aliases.
