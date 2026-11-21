# Workflow 02: Author OSI Semantic Model YAML (`semantic-osi-model`)

## Official YAML Example

Excerpt from the official OSI example ([`tpcds_semantic_model.yaml`](https://github.com/open-semantic-interchange/OSI/blob/main/examples/tpcds_semantic_model.yaml)) demonstrating a complete semantic model with datasets, fields, relationships, and metrics:

```yaml
# yaml-language-server: $schema=../core-spec/osi-schema.json
version: "0.1.1"

semantic_model:
  - name: tpcds_retail_model
    description: TPC-DS retail semantic model for sales and customer analytics
    ai_context:
      instructions: "Use this semantic model for retail analytics."

    datasets:
      - name: store_sales
        source: tpcds.public.store_sales
        primary_key: [ss_item_sk, ss_ticket_number]
        description: Fact table containing all store sales transactions
        ai_context:
          synonyms:
            - "sales transactions"
            - "retail sales"
        fields:
          - name: ss_ext_sales_price
            expression:
              dialects:
                - dialect: ANSI_SQL
                  expression: ss_ext_sales_price
            description: Extended sales price (quantity * price)
            ai_context:
              synonyms:
                - "total price"
                - "line total"

      - name: customer
        source: tpcds.public.customer
        primary_key: [c_customer_sk]
        description: Customer dimension with demographic information
        ai_context:
          synonyms:
            - "customers"
            - "buyers"
        fields:
          - name: customer_full_name
            expression:
              dialects:
                - dialect: ANSI_SQL
                  expression: c_first_name || ' ' || c_last_name
            description: Customer full name (computed field)
            ai_context:
              synonyms:
                - "full name"
                - "customer name"

    relationships:
      - name: store_sales_to_customer
        from: store_sales
        to: customer
        from_columns: [ss_customer_sk]
        to_columns: [c_customer_sk]
        ai_context:
          synonyms:
            - "who bought"

    metrics:
      - name: total_sales
        expression:
          dialects:
            - dialect: ANSI_SQL
              expression: SUM(store_sales.ss_ext_sales_price)
        description: Total sales revenue across all transactions
        ai_context:
          synonyms:
            - "total revenue"
            - "gross sales"

      - name: customer_lifetime_value
        expression:
          dialects:
            - dialect: ANSI_SQL
              expression: >
                SUM(store_sales.ss_ext_sales_price)
                / COUNT(DISTINCT customer.c_customer_sk)
        description: Average lifetime sales value per customer
        ai_context:
          synonyms:
            - "CLV"
            - "LTV"
```

## Key Structural Elements to Replicate

- `version` — always specify the OSI spec version (current: `0.1.1`)
- `semantic_model[].datasets` — logical business entities with `source`, `primary_key`, `fields`
- `fields[].expression.dialects` — multi-dialect SQL expressions (`ANSI_SQL`, Snowflake, etc.)
- `ai_context.synonyms` — natural language aliases enabling AI grounding
- `relationships` — foreign key joins between datasets
- `metrics` — KPIs defined at model level, spanning multiple datasets

## Phase Requirements (EARS)

- The model authoring workflow SHALL specify the OSI schema `version`, dataset `primary_key` columns, and typed SQL dialect expressions for each metric and field.
- WHEN grounding a semantic model for AI consumption, the model authoring workflow SHALL populate `ai_context` instructions and synonyms across datasets, fields, relationships, and metrics.
