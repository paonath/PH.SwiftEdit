# Step 02: Abstraction Tests (`allium` — Elicit)

- **Swap-the-Stack Test**: Would this statement still hold if the database, framework, or transport protocol changed? If not, exclude or move to `@guidance`.
- **Observable-Outcome Test**: Does the rule change domain state, create/remove an entity, or emit a trigger?
- **Domain-Vocabulary Test**: Use domain nouns and state transitions rather than HTTP verbs, SQL tables, or UI widget names.
