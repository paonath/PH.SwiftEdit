# Changelog Sources Comparison

Analysis behind the `changelog-write` skill. Sources: Openchangelog guide "Everything you need to know about CHANGELOG.md", Semantic Versioning 2.0.0, Common Changelog, plus the existing `changelog-format` rule and `changelog-reconciler` skill.

## 1. External sources

| Topic | Openchangelog guide | Common Changelog | SemVer 2.0.0 |
|-------|--------------------|------------------|--------------|
| Nature | Informal best practices, "no standardized format" | Strict style guide, subset of Keep a Changelog | Versioning specification |
| Title / file | `CHANGELOG.md`, root | `CHANGELOG.md`, first heading `# Changelog` | n/a |
| Release heading | `## [1.2.0] - 2023-09-15` | `## [VERSION] - YYYY-MM-DD`, ISO 8601, no `v` prefix, matches a git tag | `MAJOR.MINOR.PATCH[-prerelease][+build]` |
| Categories | Added, Changed, Fixed, Deprecated, Removed, Security | Only Changed, Added, Removed, Fixed (in that order) | n/a |
| Unreleased section | Recommended | Not used: one entry per released version | n/a |
| Entry style | Short bullets | Imperative mood, one line, self-describing, references required | n/a |
| Breaking changes | Highlight them | `**Breaking:**` prefix, listed first | MAJOR bump |
| Links | Link issues and PRs | Commit reference mandatory, PR or issue recommended | n/a |
| Noise | Not addressed | Remove noise, merge related, skip no-ops, never copy git log verbatim | n/a |
| Audience | Match tone to audience | Humans who need the impact of a release | Consumers of a public API |
| Notices | Not addressed | One italic sentence per release (upgrade guide, yanked, first release) | n/a |

Key SemVer rules used by the skill: a public API must be declared; a released version is immutable; `0.y.z` is initial development and anything may change; PATCH for backward compatible fixes, MINOR for backward compatible additions or deprecations, MAJOR for incompatible changes; pre-release versions carry a hyphen suffix and sort before the normal version.

## 2. Existing repository assets

| Aspect | `changelog-format` rule | `changelog-reconciler` skill |
|--------|-------------------------|------------------------------|
| Type | Always-available rule (`model_decision`, glob `**/CHANGELOG.md`) | Skill, triggered on request |
| Base standard | Keep a Changelog 1.0.0 | Keep a Changelog (via the rule) |
| Header | `## [Unreleased] - YYYY-MM-DD UTC` plus `Branch: ... \| Commit: ...` | Same |
| Categories | Six: Added, Changed, Fixed, Removed, Security, Deprecated | Five: `Deprecated` missing |
| Source of facts | `git log`, `git diff --name-only HEAD~1` | `git log --oneline -10` |
| Curation | Not specified | Group commit messages, past-tense bullets |
| Commit | `docs(changelog): ...`, no push, no destructive git | Not specified |
| Guardrails | Only `CHANGELOG.md`, no version bump without instruction | None stated |
| Referenced by | Both skills | Nothing |

## 3. Gaps found

1. `myspec-archive` delegates to a `changelog-write` skill that did not exist.
2. The rule has no guidance on writing quality: impact, noise removal, merging, breaking prefix, references, notices.
3. The reconciler drafts from the last 10 commits only, drops `Deprecated`, does not filter noise and stops before commit.
4. No asset covers SemVer proposals or release-mode renaming of `[Unreleased]`.
5. The repository has no git tags, so Common Changelog's "one entry per tagged release" cannot apply as is.

## 4. Decisions

| Decision | Rationale |
|----------|-----------|
| Keep the project header (`[Unreleased]` + Branch/Commit line) | Established in `CHANGELOG.md` and required by the rule; no tags exist yet |
| Keep six categories in the rule's order | Rule is the format authority; Common Changelog's four categories lose Security and Deprecated information |
| Adopt Common Changelog writing principles | Humans first, impact, sort by importance, skip noise, link changes |
| Adopt `**Breaking:**` and `**Deprecated:**` prefixes | Cheap, scannable signal compatible with the rule's categories |
| Keep the existing tense (past) instead of imperative | Consistency with 100% of existing entries beats a style switch |
| SemVer used for proposals only | The rule forbids bumping without explicit instruction |
| Reconciler stays the mechanical drafter | Avoid duplicating its job; `changelog-write` calls it for gaps |
| Rule stays untouched | Skill defers to it; suggested future edit: add `Deprecated` to the reconciler and reference `changelog-write` from it |
