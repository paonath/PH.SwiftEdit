---
name: changelog-write
description: "Writes a curated, human-oriented CHANGELOG.md entry for a finished unit of work (an implemented spec, a feature, a fix batch or a release) following the project changelog format, Common Changelog writing principles and Semantic Versioning guidance, then commits only CHANGELOG.md. Use for the final changelog step of myspec-archive. Triggers: changelog-write, write changelog, write changelog entry, changelog entry, close spec changelog, release notes entry."
---

# Changelog Write

## Purpose

Produce the final, reader-facing `CHANGELOG.md` entry and commit it (`changelog-write` is the **writing and publishing** step; `changelog-format` rule owns format/headers; `changelog-reconciler` skill drafts missing history). See [comparison](references/comparison.md) for source decisions.

## Hard Rules

- Edit **only** `CHANGELOG.md`. Never touch other files, never push, reset, rebase or amend.
- The changelog-write skill SHALL obey the `changelog-format` rule for headers, categories, ordering, and `[Unreleased]` or version handling.
- IF this skill and the `changelog-format` rule disagree, THEN the changelog-write skill SHALL follow the `changelog-format` rule.
- The changelog-write skill SHALL exclude secrets, tokens, absolute user paths, and internal hostnames per the `security-secrets-policy` rule.
- The changelog-write skill SHALL trace every changelog bullet to a git commit, diff, or implemented spec requirement.
- IF `CHANGELOG.md` is missing, THEN the changelog-write skill SHALL create it with `# Changelog`, a Keep a Changelog intro line, and the new entry.
- IF scope, version, or changelog-worthy impact is ambiguous or absent, THEN the changelog-write skill SHALL ask the user or write nothing instead of guessing.

## Procedure

1. **Gather facts**: Run `git branch --show-current`, `git rev-parse --short HEAD`, `git status --short`, `git log --oneline --decorate -20`, and `git diff --stat`; read top of `CHANGELOG.md` and any target spec requirements.
2. **Reconcile first**: Draft any missing commits between the newest entry's commit and `HEAD` using `changelog-reconciler` rules.
3. **Select content**: Keep noticeable consumer/contributor changes (behavior, public interfaces, workflows, security fixes); drop formatting edits, non-behavioral refactors, and merge/revert noise; merge related commits and rewrite subjects.
4. **Classify & write bullets**: Assign each one-line past-tense bullet to `Added`, `Changed`, `Fixed`, `Removed`, `Security`, or `Deprecated` (omitting empty sections). Prefix `**Breaking:**` or `**Deprecated:**`, wrap symbols/paths in backticks, cite short commit hashes and `specs/implemented/` paths.
5. **Compose section**: Prepend at top of `CHANGELOG.md` using the `changelog-format` UTC header (merge into today's matching header instead of duplicating); keep dates/versions descending.
6. **Release mode** (only on explicit user version request): Propose SemVer bump (MAJOR breaking/removal, MINOR added, PATCH fix/security; in `0.y.z` minor holds breaking changes). After confirmation, rename header to `## [X.Y.Z] - YYYY-MM-DD`, fold pre-release entries, and instruct user to create the git tag separately.
7. **Verify, commit & report**: Inspect `git diff -- CHANGELOG.md` and `git status --short`, run `git add CHANGELOG.md && git commit -m "docs(changelog): <short summary>" -- CHANGELOG.md` per `git-commit-conventions`, and report header, bullet counts, commit hash, and assumptions.

## Behavioral Scenarios

```gherkin
Feature: Curated Changelog Writing and Isolated Commit

  @REQ-CHGW-001
  Scenario: Write curated changelog entry and commit only CHANGELOG.md
    Given completed work with traceable commits and no uncommitted secret exposures
    When the agent executes the changelog-write skill
    Then CHANGELOG.md receives a curated section ordered per the changelog-format rule
    And only CHANGELOG.md is staged and committed with a docs(changelog) message

  @REQ-CHGW-002
  Scenario: Abort changelog write when scope lacks noticeable changes
    Given recent git history contains only formatting edits with no behavioral impact
    When the agent executes the changelog-write skill
    Then CHANGELOG.md remains unmodified and the empty impact is reported
```
