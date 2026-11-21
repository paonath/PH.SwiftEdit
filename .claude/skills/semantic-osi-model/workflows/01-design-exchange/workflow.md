# Workflow 01: Design Semantic Exchange Across OSI Layers (`semantic-osi-model`)

## Core Principles

1. **Layer Separation** — Each OSI layer handles a distinct concern (transport, syntax, semantics). Do not mix concerns across layers.
2. **Semantic Contracts** — Define explicit contracts that describe what data means, not just its shape.
3. **Interoperability First** — Design for heterogeneous consumers; avoid assuming shared internal models.
4. **Progressive Enrichment** — Lower layers carry raw data; higher layers add meaning and context.

## Layer Model

Apply each layer when designing or reviewing a semantic exchange:

| Layer | Concern | Artefact |
|---|---|---|
| Transport | Delivery (HTTP, AMQP, gRPC) | Protocol config |
| Syntactic | Format (JSON, XML, Protobuf) | Schema (JSON Schema, XSD) |
| Semantic | Meaning (ontology, vocabulary) | Ontology / vocabulary file |
| Pragmatic | Intent & context (why, for whom) | Semantic contract / API spec |

## Design Decision Sequence

1. Define **Transport** layer first (protocol + reliability guarantees).
2. Define **Syntactic** layer (format + schema).
3. Define **Semantic** layer (ontology or controlled vocabulary).
4. Define **Pragmatic** layer (contract: intent + consumer context).

## Common Patterns

### Semantic Contract (Pragmatic Layer)
Define what data means in context for a given consumer:
```yaml
semantic-contract:
  producer: order-service
  consumer: billing-service
  entity: Order
  vocabulary: https://open-semantic-interchange.org/vocab/order
  intent: trigger-invoice
  version: "1.0"
```

### Vocabulary Mapping
When consumers use different terms, provide an explicit mapping:
```json
{
  "source_term": "customer_id",
  "target_term": "client_ref",
  "vocabulary": "https://open-semantic-interchange.org/vocab/crm",
  "equivalence": "exact"
}
```

## Phase Requirements (EARS)

- The exchange design workflow SHALL define Transport, Syntactic, Semantic, and Pragmatic layers in sequential order without mixing layer concerns.
- WHEN producer and consumer schemas use distinct domain identifiers, the exchange design workflow SHALL declare explicit vocabulary mappings with equivalence semantics.
