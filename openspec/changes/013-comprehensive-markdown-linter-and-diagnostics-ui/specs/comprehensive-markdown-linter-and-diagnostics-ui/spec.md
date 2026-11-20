# Spec Delta: comprehensive-markdown-linter-and-diagnostics-ui

## Purpose
Defines the 26-rule all-construct Markdown linter with hardened URI and image safety, idempotent revision-pinned Quick-Fix and Fix All, lint status classification, and the non-invasive triple diagnostics surfaces including the Shift+Cmd+M popover.

## ADDED Requirements

### Requirement: REQ-001 All-Construct Rule Catalog With Frontmatter Immunity and Bounded Output
WHEN `lint` runs with the `.allConstructs` profile on a non-degraded Markdown snapshot, the engine SHALL evaluate the 26 rules in one pass, mask Line-1 YAML frontmatter of at most 200 lines, return scalar-aligned UTF-16 ranges, apply `MD032` to root and blockquote lists only, and cap output at 1000 diagnostics retaining errors before warnings [BC-004][SEC-012].

#### Scenario: P1 Frontmatter Is Clean and Heading Image and Table Rules Fire
- **Path**: P1
- **Trait**: positive
- **GIVEN** a snapshot with YAML frontmatter, `"#Heading"`, `"![](flow.png)"` and a table whose second row has fewer cells than the header
- **WHEN** `lint(snapshot:profile: .allConstructs)` runs
- **THEN** the frontmatter lines produce no diagnostics and `MD018`, `MD045` and `MD056` are reported on their lines

#### Scenario: N1 Default Profile Unchanged and Tight Nested Sublists Not Flagged
- **Path**: N1
- **Trait**: negative
- **GIVEN** `"- a\n    - b\n    - c"` and a call to `lint(snapshot:)` without a profile on `"#Heading"`
- **WHEN** both lints run
- **THEN** `.allConstructs` reports no `MD032` for the nested items and the default call returns exactly the legacy diagnostics

#### Scenario: N2 Obfuscated Unsafe URIs Traversal and SVG Images Are Errors and Survive the Cap
- **Path**: N2
- **Trait**: security
- **GIVEN** `"[x](javascript%3Aalert(1))"`, `"![x](../../etc/passwd)"`, `"![x](pic.svg)"`, `"[y](//evil.example)"` followed by `1500` lines ending in trailing spaces
- **WHEN** `lint` runs with `.allConstructs`
- **THEN** `.unsafeLinkScheme` and `.unsafeImagePath` errors are reported for all four lines, the result holds at most `1000` entries with `isTruncated` true, and no error is dropped

### Requirement: REQ-002 Idempotent Revision-Pinned Quick-Fix and Fix All
WHEN the user requests a Quick-Fix or Fix All with an `expectedRevision`, the `MarkdownQuickFixResolver` SHALL return one non-overlapping `TextEdit` batch that is idempotent when applied twice, SHALL reject a stale revision, and SHALL provide no fix for `.unsafeLinkScheme`, `.unsafeImagePath`, `.emptyLinkTarget` and excess-column `MD056` [BC-006][BC-011][SEC-004].

#### Scenario: P2 Fix All Is Idempotent and Creates No Duplicate Blank Lines
- **Path**: P2
- **Trait**: positive
- **GIVEN** `"#Title\ntext\n- a\n- b\ntext"` at the current revision
- **WHEN** Fix All runs and is run again on the result
- **THEN** one batch resolves `MD018`, `MD022` and `MD032` fixes, the second run yields no edit, and no double blank line exists

#### Scenario: N3 Stale Revision Is Rejected
- **Path**: N3
- **Trait**: negative
- **GIVEN** a Fix All computed for revision `N` and a session now at revision `N+1`
- **WHEN** the fix is requested with `expectedRevision` `N`
- **THEN** the outcome is `.stale` and the text is unchanged

#### Scenario: N4 Security Diagnostics Offer No Quick-Fix
- **Path**: N4
- **Trait**: security
- **GIVEN** diagnostics for `.unsafeLinkScheme`, `.unsafeImagePath`, `.emptyLinkTarget` and an excess-column `MD056`
- **WHEN** Quick-Fix and Fix All are requested
- **THEN** each reports `quickFix == nil` and Fix All leaves those lines byte-identical

### Requirement: REQ-003 Lint Status Classification and Active-Line Suppression
The `ActiveLintStatus` SHALL report Off for non-Markdown tabs, Paused for degraded buffers and Active with the diagnostic count otherwise, and the `ActiveLineLintSuppressionPolicy` SHALL hide only transient `MD009`, `MD040`, `MD055`, `MD056`, `MD042` and `MD045` on the caret line and SHALL NOT hide any security error [BC-004][DATA-003].

#### Scenario: P3 Off Paused and Active Statuses
- **Path**: P3
- **Trait**: positive
- **GIVEN** a `Main.swift` tab, a degraded Markdown snapshot and a Markdown tab with `3` diagnostics
- **WHEN** `ActiveLintStatus.classify` runs for each
- **THEN** the results are `.off`, `.paused` and `.active(count: 3)`

#### Scenario: N5 Suppression Never Hides Security Errors
- **Path**: N5
- **Trait**: security
- **GIVEN** the caret on a line holding both a trailing-space warning and `[x](javascript:alert(1))`
- **WHEN** the suppression policy filters diagnostics for the caret line
- **THEN** the warning is hidden and the `.unsafeLinkScheme` error stays visible

### Requirement: REQ-004 Triple Diagnostics Surfacing and Shift+Cmd+M Popover
WHEN diagnostics exist for an Active Markdown tab, the `SwiftEditUI` SHALL render dotted underlines, gutter severity badges and the status-bar `ActiveLintStatus`, SHALL toggle the diagnostics popover with `⇧⌘M` offering Jump-to-Range, Quick-Fix and Fix All in one Undo step, and SHALL stay inert on binary and non-Markdown tabs [UI-005][UI-007][UI-012][DATA-003].

#### Scenario: P4 Popover Jump and Fix All Work in One Undo Step
- **Path**: P4
- **Trait**: positive
- **GIVEN** a Markdown tab with `"#Heading"` and `"![](a.png)"` and the diagnostics popover closed
- **WHEN** `⇧⌘M` toggles the popover, Jump-to-Range targets the first diagnostic, and Fix All is applied
- **THEN** the popover state toggles, the selection moves to the first diagnostic range, and Fix All adds exactly one `BufferRevision`

#### Scenario: N6 Binary and Non-Markdown Tabs Are Inert
- **Path**: N6
- **Trait**: security
- **GIVEN** a binary tab and a `Main.swift` tab
- **WHEN** `⇧⌘M`, Quick-Fix or Fix All is triggered
- **THEN** the status is `Lint: Off`, no fix is applied and `BufferRevision` is unchanged

## MODIFIED Requirements

## REMOVED Requirements

## RENAMED Requirements
