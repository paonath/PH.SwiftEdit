---
name: release-notes
description: Generate human-readable release or hotfix notes from branch diff against trunk, execute QA gate, and commit to docs/.
---

# Release Notes Workflow (`release-notes` — Progressive Disclosure Router)

Generates English, human-readable release (`docs/releases/<version>/RELEASE-<version>.md`) or hotfix (`docs/hotfixes/<version>/HOTFIX-<version>.md`) notes by diffing `release/*` or `hotfix/*` against trunk, gated by a blocking human QA confirmation before writing or committing.
Enforces `Single-Reference Lock`: load one `workflows/NN-*/workflow.md` phase file at a time.

## Hard Safety Rules

- **Execute documentation tasks only.**
- **NEVER** run `git merge`, `git rebase`, `git flow release/hotfix finish`, `git tag`, `git push`, `gh release create`, or `gh pr merge`.
- **NEVER** switch, delete, or rename git branches; decline any request to automate merges, tags, or branch closures.

## Workflow Routing Table

Execute the 4 phases sequentially (one workflow file in context at a time):

| Phase | Workflow | Scope |
|---|---|---|
| **01** | [01-preconditions-and-diff](workflows/01-preconditions-and-diff/workflow.md) | `release/*` or `hotfix/*` branch guard, dirty tree warning, Step 1 (`merge-base`), Step 2 (read-only git log/diff). |
| **02** | [02-classification-and-versioning](workflows/02-classification-and-versioning/workflow.md) | Step 3 (`CHANGELOG.md` alignment), Step 4 (6-category classification + hotfix feature anomaly flag), Step 5 (7-rule version detection). |
| **03** | [03-qa-gate-and-generation](workflows/03-qa-gate-and-generation/workflow.md) | Step 6 (**BLOCKING** Human QA Gate) and Step 7 (`git check-ignore`, overwrite confirmation, plain-Markdown template). |
| **04** | [04-commit-and-report](workflows/04-commit-and-report/workflow.md) | Step 8 (isolated `docs(release|hotfix):` commit, no push/tag) and Step 9 (summary report & reuse instructions). |

## Core Requirements (EARS)

- The release-notes skill SHALL execute documentation tasks only without running git merges, rebases, tags, pushes, or branch switches.
- WHILE executing phases 01 through 04, the release-notes skill SHALL enforce `Single-Reference Lock` by loading one workflow file per phase.
- IF the checked-out branch does not match `release/*` or `hotfix/*`, THEN the release-notes skill SHALL halt immediately and report the active branch.
- WHILE waiting for Step 6 human QA confirmation, the release-notes skill SHALL block creating or committing release notes files.

## Behavioral Scenarios

```gherkin
Feature: Release and Hotfix Notes Generation

  @REQ-RNTS-001
  Scenario: Generate and commit release notes after human QA approval
    Given the active branch is a release branch with committed changes against main
    When the agent executes phases 01 through 04 and the user confirms Step 6 QA summary
    Then RELEASE notes are generated under docs/releases/ and committed locally without pushing or tagging

  @REQ-RNTS-002
  Scenario: Abort execution on non-release and non-hotfix branch
    Given the active branch is a feature branch outside release/* and hotfix/*
    When release-notes preconditions run
    Then the workflow halts immediately and reports the active branch without modifying files
```
