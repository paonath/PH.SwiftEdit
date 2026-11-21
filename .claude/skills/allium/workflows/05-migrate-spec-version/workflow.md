# Workflow 05: Migrate `.allium` Specification Version (`allium`)

Load only the migration reference matching the source specification version (`Single-Reference Lock`):

- **Allium v1 -> v2**: Read [migration-v1-to-v2.md](../../references/migration-v1-to-v2.md) to upgrade v1 entity/rule/surface constructs to v2 syntax.
- **Allium v2 -> v3**: Read [migration-v2-to-v3.md](../../references/migration-v2-to-v3.md) to adopt v3 `transitions` graphs, state-dependent field presence (`when status = ...`), and contract clauses.
- After migration, validate the upgraded `.allium` file via [01-author-and-read-spec](../01-author-and-read-spec/workflow.md).
