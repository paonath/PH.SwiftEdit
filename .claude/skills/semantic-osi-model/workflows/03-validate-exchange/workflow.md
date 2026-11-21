# Workflow 03: Validate Semantic Exchange (`semantic-osi-model`)

## Layer Validation Flow

1. Check **Transport** — is delivery guaranteed?
2. Check **Syntactic** — does the schema validate?
3. Check **Semantic** — is the vocabulary shared or mapped?
4. Check **Pragmatic** — is the consumer context preserved?

## Validation Checklist

When designing or reviewing a semantic exchange, verify:
- [ ] Transport layer is defined and reliable
- [ ] Syntactic schema is machine-readable and versioned
- [ ] Semantic vocabulary is published and referenced by URI
- [ ] Semantic contract documents intent and consumer context
- [ ] Vocabulary mappings cover all cross-system term differences
- [ ] Breaking changes are versioned (never modify a published vocabulary URI)

## Phase Requirements (EARS)

- The exchange validation workflow SHALL verify transport reliability, machine-readable syntactic schemas, URI-referenced vocabularies, and pragmatic consumer contracts.
- IF a model change alters existing term semantics, THEN the exchange validation workflow SHALL publish a new versioned URI instead of mutating an existing published vocabulary URI.
