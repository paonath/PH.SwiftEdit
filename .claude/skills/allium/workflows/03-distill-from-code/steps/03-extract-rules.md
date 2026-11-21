# Step 03: Extract Rules (`allium` — Distill)

- Translate command handlers, event subscribers, and scheduled jobs into `rule` blocks (`when:`, `requires:`, `let`, `ensures:`).
- Use `.created()` for all entity creation and add `requires:` guards on temporal triggers.
