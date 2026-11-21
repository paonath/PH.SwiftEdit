---
description: "Splits a large Markdown document into atomic OpenSpec change stubs under <changes_dir>/ (default: openspec/changes/) ready for myspec-tdd-spec-reasoning.\nUse when: (1) a user attaches a large requirements doc and asks to split it into changes,\n(2) a user says \"split this document into specs\", (3) a complex analysis document needs\ndecomposing into separate implementable areas before change generation."
argument-hint: "<path-to-document>"
disable-model-invocation: true
---
Invoke the `myspec-split` skill with: $ARGUMENTS
