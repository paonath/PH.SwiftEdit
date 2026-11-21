---
name: changelog-reconciler
description: "Automates drafting and updating CHANGELOG.md entries from git commit history following Keep a Changelog conventions. Triggers: changelog-reconciler, update changelog, reconcile changelog, generate changelog, changelog."
---

# Changelog Reconciler

## Purpose

Parses recent git commits and repository diffs to produce structured, compliant entries in `CHANGELOG.md` following `changelog-format.md` conventions.

This skill produces the mechanical draft from git history. For the final curated entry (noise removal, merged bullets, breaking-change prefixes, references, verification and the `docs(changelog)` commit), use the `changelog-write` skill.

## Procedure

1. **Git Commit History Extraction**:
   - Inspect recent commits using `git log --oneline -10`, branch name via `git branch --show-current`, and short hash via `git rev-parse --short HEAD`.
2. **Category Classification**:
   - Group commits into `Added`, `Changed`, `Fixed`, `Removed`, `Security`, and `Deprecated`.
3. **Format and Write**:
   - Insert new `## [Unreleased] - YYYY-MM-DD UTC` header at top of `CHANGELOG.md` with branch name, short hash, and past-tense bullets.

## Requirements (EARS)

- The changelog-reconciler skill SHALL extract recent commit metadata using `git log --oneline -10`, `git branch --show-current`, and `git rev-parse --short HEAD`.
- The changelog-reconciler skill SHALL classify commits into the six `changelog-format` categories: `Added`, `Changed`, `Fixed`, `Removed`, `Security`, and `Deprecated`.
- WHEN drafting a mechanical changelog entry, the changelog-reconciler skill SHALL prepend a `## [Unreleased] - YYYY-MM-DD UTC` section at the top of `CHANGELOG.md` with past-tense descriptions.
- IF curated rewriting or an isolated `docs(changelog)` commit is required, THEN the changelog-reconciler skill SHALL hand off final publishing to the `changelog-write` skill.

## Behavioral Scenarios

```gherkin
Feature: Mechanical Changelog Reconciliation

  @REQ-CHGR-001
  Scenario: Draft unreleased changelog entries from recent git commits
    Given a git branch contains recent commits missing from CHANGELOG.md
    When changelog reconciliation executes
    Then a dated Unreleased section with branch and short commit hash is drafted at the top of CHANGELOG.md
    And entries are grouped under Added, Changed, Fixed, Removed, Security, or Deprecated

  @REQ-CHGR-002
  Scenario: Defer curated entry publishing to changelog-write
    Given drafted changelog bullets require human curation and an isolated changelog commit
    When mechanical reconciliation completes
    Then final curation and isolated commit execution are delegated to changelog-write
```
