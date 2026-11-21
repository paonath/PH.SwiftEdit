# Workflow 02: Elicit Specification Through Conversation (`allium`)

Progressive-disclosure wrapper around [skills/elicit/SKILL.md](../../skills/elicit/SKILL.md). Load one step at a time (`Single-Reference Lock`):

1. [01-scope.md](steps/01-scope.md): Define domain boundary, actors, and observable outcomes.
2. [02-abstraction-tests.md](steps/02-abstraction-tests.md): Apply domain-vs-implementation abstraction tests and [library-spec-signals.md](../../skills/elicit/references/library-spec-signals.md).
3. [03-discovery-interview.md](steps/03-discovery-interview.md): Conduct the 4-phase discovery interview (entities, rules/triggers, surfaces/contracts, edge cases & open questions).
4. [04-refinement.md](steps/04-refinement.md): Draft `.allium` file, verify invariants/transitions, and validate with `allium` CLI or [language-reference.md](../../references/language-reference.md).
