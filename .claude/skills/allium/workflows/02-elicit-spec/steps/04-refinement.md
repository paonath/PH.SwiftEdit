# Step 04: Refinement & Validation (`allium` — Elicit)

- Assemble the `.allium` specification and check every rule and surface against [language-reference.md](../../../references/language-reference.md).
- Ensure temporal triggers carry a `requires:` guard against re-firing and all entity creations use `.created()`.
- Run the `allium` CLI validator when installed and resolve all diagnostics before handoff.
