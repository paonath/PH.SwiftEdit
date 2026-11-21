---
description: "Central specification engine of the entire MySpec suite. Conducts interactive TDD interviews or ingests requirements/briefs, performs deep codebase inspection with domain experts, generates structured briefs in <briefs_dir>/, scaffolds 6-artifact OpenSpec changes under <changes_dir>/, authors RED-GREEN-REFACTOR triads and STRIDE threat models adhering to schema.yaml, and executes automated validation. Always runs end to end (reasoning, brief, 6 schema-conformant artifacts, validation); never stops at the brief. Strictly forbids direct source code modification (deferred exclusively to myspec-apply)."
argument-hint: "<feature prompt>"
disable-model-invocation: true
---
Invoke the `myspec-tdd-spec-reasoning` skill with: $ARGUMENTS
