---
name: allium
description: "An LLM-native language for sharpening intent alongside implementation. Velocity through clarity. Use when working with files matching **/*.allium or when the user mentions: allium, allium spec, allium specification, .allium file."
version: 3
---

# Allium (`allium` v3 — Progressive Disclosure Router)

Allium is a formal, implementation-agnostic language for capturing software behaviour at the domain level (entities, value/sum types, rules, triggers, surfaces, contracts, transition graphs, and invariants) without prescribing framework, database, or UI details.
Enforces `Single-Reference Lock`: load one `workflows/NN-*/workflow.md` (and at most one `steps/NN-*.md` or `references/*.md` file) at a time.

## Key Principles

- Describes observable domain behaviour, not implementation mechanics
- Forces ambiguities into the open (`open question "..."`) before coding
- Drives integration, state-machine, and property-based tests

## Workflow & Tool Routing Table

| Phase / Task | Workflow / Sub-Skill | When to Load |
|---|---|---|
| **01 · Author & Read** | [01-author-and-read-spec](workflows/01-author-and-read-spec/workflow.md) | Writing, reading, or verifying `.allium` v3 syntax (`entity`, `rule`, `surface`, `contract`, `transitions`). |
| **02 · Elicit** | [02-elicit-spec](workflows/02-elicit-spec/workflow.md) ([elicit](skills/elicit/SKILL.md)) | Building a new `.allium` spec from user conversation (`steps/01-scope.md` .. `04-refinement.md`). |
| **03 · Distill** | [03-distill-from-code](workflows/03-distill-from-code/workflow.md) ([distill](skills/distill/SKILL.md)) | Extracting a domain `.allium` spec from existing code (`steps/01-map-territory.md` .. `07-validate.md`). |
| **04 · Propagate** | [04-propagate-tests](workflows/04-propagate-tests/workflow.md) ([propagate](skills/propagate/SKILL.md)) | Generating assertion, PBT, or state-machine tests from an `.allium` spec. |
| **05 · Migrate** | [05-migrate-spec-version](workflows/05-migrate-spec-version/workflow.md) | Upgrading legacy `.allium` specs (`v1 -> v2` or `v2 -> v3`). |
| **Agents** | `tend` / `weed` | Targeted `.allium` edits (`tend`) or spec-to-code divergence checks (`weed`). |

## References

- [language-reference.md](references/language-reference.md) — full normative syntax and validation rules
- [patterns.md](references/patterns.md) — 9 worked domain patterns (auth, RBAC, invitations, soft delete, notifications, limits, comments, library/framework contracts)
- [test-generation.md](references/test-generation.md) — test generation guide
- [migration-v1-to-v2.md](references/migration-v1-to-v2.md) · [migration-v2-to-v3.md](references/migration-v2-to-v3.md) — version migration guides
