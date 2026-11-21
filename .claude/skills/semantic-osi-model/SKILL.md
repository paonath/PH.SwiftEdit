---
name: semantic-osi-model
description: |
  Apply the Open Semantic Interchange (OSI) model to design, validate, and document
  semantic data exchange between systems. Use when: (1) designing semantic interoperability
  between heterogeneous systems, (2) modelling data exchange using OSI layers,
  (3) validating semantic compatibility of data formats, (4) documenting semantic contracts
  between services, (5) asked about open semantic interchange or OSI semantic model.
---

# Semantic OSI Model (`semantic-osi-model` — Progressive Disclosure Router)

Applies the Open Semantic Interchange (OSI) model to structure, validate, and document semantic data exchange across Transport, Syntactic, Semantic, and Pragmatic layers.
Enforces `Single-Reference Lock`: load only the active `workflows/NN-*/workflow.md` file for the current task.

## Overview

The Open Semantic Interchange (OSI) model defines a 4-layer framework (`Transport -> Syntactic -> Semantic -> Pragmatic`) enabling heterogeneous systems to exchange both data syntax and explicit business meaning.
Official specification: https://open-semantic-interchange.org/

## Workflow Routing Table

| Phase | Workflow | Scope |
|---|---|---|
| **01** | [01-design-exchange](workflows/01-design-exchange/workflow.md) | 4-layer OSI model, Core Principles, Semantic Contract YAML, and Vocabulary Mapping JSON patterns. |
| **02** | [02-author-semantic-model](workflows/02-author-semantic-model/workflow.md) | Official OSI `semantic_model` YAML schema (`datasets`, `fields`, `relationships`, `metrics`, `ai_context`). |
| **03** | [03-validate-exchange](workflows/03-validate-exchange/workflow.md) | 4-layer validation flow and 6-point immutability/URI validation checklist. |

## Formal Requirements (EARS)

- The semantic-osi-model skill SHALL enforce strict separation across Transport, Syntactic, Semantic, and Pragmatic layers in every interchange design.
- WHEN authoring an OSI semantic model definition, the semantic-osi-model workflow SHALL declare version metadata, dataset schemas, dialect expressions, and `ai_context` synonyms.
- IF a semantic update introduces breaking term meanings, THEN the semantic-osi-model validator SHALL require a new versioned contract without modifying any published vocabulary URI.

## BDD Scenarios

```gherkin
Feature: Open Semantic Interchange Modeling

  @REQ-OSI-001
  Scenario: Complete four-layer semantic model passes validation
    Given a semantic interchange specification covering transport, syntactic, semantic, and pragmatic layers
    When the semantic validation workflow checks schema, URI references, and vocabulary mappings
    Then the exchange passes all six validation checklist items

  @REQ-OSI-002
  Scenario: Breaking change mutating a published vocabulary URI is rejected
    Given a proposed schema update that alters the definition of an existing published vocabulary URI
    When the semantic validation workflow evaluates backward compatibility
    Then the validator rejects the mutation and requires a new versioned URI
```
