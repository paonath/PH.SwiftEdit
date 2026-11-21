---
name: myspec-split
description: |
  Splits a large Markdown document into atomic OpenSpec change stubs under <changes_dir>/ (default: openspec/changes/) ready for myspec-tdd-spec-reasoning.
  Use when: (1) a user attaches a large requirements doc and asks to split it into changes,
  (2) a user says "split this document into specs", (3) a complex analysis document needs
  decomposing into separate implementable areas before change generation.
---

# MySpec Split (myspec-split)

Decomposes a large Markdown document into numbered OpenSpec change stubs (`<changes_dir>/<NNN-ambito>/proposal.md`, via `.myspec.config.json`, default: `openspec/changes/<NNN-ambito>/`) ready for `myspec-tdd-spec-reasoning`.

## Prerequisites

- One attached Markdown document (missing -> stop and ask) and `prompt-clarifier` SKILL read first.
- Consult `<spec_root>/index.yml`, every `always_read:` entry (including `<spec_root>/Constitution.md` with `<NN-area>/index.md` + 1 micro-file under `Single-Reference Lock`), and `specs:` to avoid overlap and pick the next `NNN` prefix.

## Requirements

- WHEN invoked, the myspec-split skill SHALL read <spec_root>/index.yml, every always_read document, and Constitution.md under Single-Reference Lock before proposing change stubs.
- IF no Markdown requirements document is attached to context, THEN the myspec-split skill SHALL stop and request the document before analyzing areas.
- WHEN the user approves the proposed split, the myspec-split skill SHALL scaffold <changes_dir>/<NNN-ambito>/proposal.md stubs and prepend draft entries to <spec_root>/index.yml.

## Workflow

1. Read `<spec_root>/index.yml` (`always_read` documents + `specs` list) and run `prompt-clarifier`.
2. Verify Markdown attachment (missing -> stop), analyze logical areas and line ranges using trigger domains (`database`, `backend`, `frontend`, `testing`, `documentation`) or content semantics.
3. Present proposed split (`N | area | lines | description`) and refine one question per turn until user approval.
4. Scaffold `<changes_dir>/<NNN-ambito>/proposal.md` per approved area, prepend draft entries to `<spec_root>/index.yml`, and summarize output.

## Change Stub Format

```markdown
# Change Stub: <NNN-ambito>
**Area**: <ambito> | **Source**: `<filename>` lines <start>–<end>
## Summary & Intent
<5–10 sentences describing the capability change extracted from source document.>
## Scope & Boundaries
- In-Scope: <Key functional contracts> / Out-of-Scope: <Deferred capabilities>
## Metadata
- Branch: <git-branch>
```

## Behavioral Scenarios

```gherkin
Feature: MySpec Requirements Document Splitting

  @REQ-SPLIT-001
  Scenario: Decompose an attached requirements document into approved change stubs
    Given an initialized MySpec workspace with index.yml and an attached Markdown requirements document
    When the user approves the proposed domain split across affected areas
    Then atomic change stub directories and prepended index entries are created for each approved area

  @REQ-SPLIT-002
  Scenario: Halt splitting when no requirements document is attached
    Given an initialized MySpec workspace without an attached Markdown requirements document
    When document splitting is requested
    Then the workflow stops immediately and requests the missing document without writing change stubs
```

---
> [!TIP]
> **Recommended Next Step**: `/myspec-tdd-spec-reasoning @<changes_dir>/<NNN-ambito>/`
> **Rationale**: Document decomposed into atomic change stubs; author specifications with central engine `/myspec-tdd-spec-reasoning`.
---
