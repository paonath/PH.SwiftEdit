# Workflow 03: Distill Specification from Existing Code (`allium`)

Progressive-disclosure wrapper around [skills/distill/SKILL.md](../../skills/distill/SKILL.md) and [worked-examples.md](../../skills/distill/references/worked-examples.md). Load one step at a time (`Single-Reference Lock`):

1. [01-map-territory.md](steps/01-map-territory.md): Survey modules, entry points, and boundaries.
2. [02-identify-entities.md](steps/02-identify-entities.md): Extract domain entities, value types, sum types, and state lifecycles.
3. [03-extract-rules.md](steps/03-extract-rules.md): Distill behavioural rules (`when`, `requires`, `ensures`) from handlers and services.
4. [04-extract-surfaces.md](steps/04-extract-surfaces.md): Capture boundary `surface` and `contract` definitions (`exposes`, `provides`, `contracts:`).
5. [05-extract-invariants.md](steps/05-extract-invariants.md): Formulate expression-bearing `invariant` blocks and `config`/`default` parameters.
6. [06-abstract-and-clean.md](steps/06-abstract-and-clean.md): Strip framework/ORM mechanics using the abstraction tests in [02-abstraction-tests.md](../02-elicit-spec/steps/02-abstraction-tests.md).
7. [07-validate.md](steps/07-validate.md): Validate syntax and surface completeness, recording unresolved questions as `open question`.
