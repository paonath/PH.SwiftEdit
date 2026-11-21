---
id: "brief-comprehensive-markdown-linter-and-diagnostics-ui"
change_id: "013-comprehensive-markdown-linter-and-diagnostics-ui"
capability: "comprehensive-markdown-linter-and-diagnostics-ui"
branch: "feature/FirstStub"
modifies_specs: "markdown-lint-format-bracket-and-diff (REQ-001)"
status: "approved-via-qa"
date: "2026-11-20"
owners:
  - "swift-macos-expert"
  - "oop-architecture-expert"
  - "spec-sdlc-expert"
  - "cyber-security-expert"
---

# TDD Specification Brief: `013-comprehensive-markdown-linter-and-diagnostics-ui`

## 1. Context & Source Traceability

- **Originating Reasoning Session**: `reasoning/003_theming-header-menu-and-markdown-editor/README.ai.md` (`TASK-05`, `TOPIC-05`, approved in full).
- **Scope Resolution (QA)**: `TASK-05` of `reasoning/001_project-constitution` (`SwiftEditUI` Purple/Zed shell) is already implemented (change `004`, archived), so only the `003_theming...` `TASK-05` is specified.
- **Core Problem**: the linter has `5` rules, shows only a count in the status bar (even for non-Markdown files), has no per-diagnostic surfacing, and offers no safe automated fixes.
- **Active Git Branch**: `feature/FirstStub` (baseline SHA `f58860e`; uncommitted `011`/`012` source is present in the working tree).
- **Approved Scope**: `.allConstructs` profile with `26` rules in one shared pass (`legacyBaseline` stays the default parameter), YAML frontmatter masking, UTF-8 to UTF-16 line table, `1000`-diagnostic cap (errors first), idempotent revision-pinned Quick-Fix and Fix All, `ActiveLintStatus`, `ActiveLineLintSuppressionPolicy`, TextKit 2 dotted underlines, gutter badges, `MarkdownDiagnosticsPopoverView` with `⇧⌘M`.
- **Consolidated Specs Modified**: `markdown-lint-format-bracket-and-diff` (`REQ-001`, additive).
- **Governing Rules (`v1.3.0`)**: `AR-002`, `AR-003`, `BC-004`, `BC-006`, `BC-011`, `DATA-003`, `SEC-004`, `SEC-009`, `SEC-012`, `TEST-001..005`, `UI-002`, `UI-005`, `UI-007`, `UI-012`, `SDD-001..003`.

## 2. Domain, Architecture & Security Expert Notes

- **Rules**: headings `MD001/018/019/022`; lists `MD004/005/007(4)/029/030/032(root only)` + `.nonStandardOutlineMarker` + `.malformedTaskCheckbox`; tables `MD055/056/058`; links/images `MD042/045` + `.unsafeLinkScheme` + `.unsafeImagePath` (decoded, stripped, protocol-relative aware); fences/whitespace `.unbalancedFencedCodeBlock`, `MD031/040/027/009/010/012`.
- **Immunity**: Line-1 YAML frontmatter (`<= 200` lines) masked with line-preserving blanks; byte columns converted to scalar-aligned UTF-16 ranges.
- **Quick-Fix**: blank-line fixes anchored at the lower block's first line; two bounded passes; `expectedRevision == session.revision`; `quickFix == nil` on `.unsafeLinkScheme`, `.unsafeImagePath`, `.emptyLinkTarget`, excess-column `MD056`.
- **UI**: `ActiveLintStatus` = Off (non-Markdown), Paused (degraded), Active(N); transient `MD009/040/055/056/042/045` suppressed on the caret line only, security errors never suppressed.
- **Bounds**: `<= 250 ms`, `1000` diagnostics, `.error` retained before `.warning`, `isTruncated`.

## 3. Path Coverage Matrix

| Unit | Path ID | Trait | Scenario Summary |
| :--- | :--- | :--- | :--- |
| `MarkdownLintRuleCatalog` | `P1` | `positive` | Frontmatter clean; `#Heading`, `![](flow.png)`, mismatched table row yield `MD018`, `MD045`, `MD056` |
| `MarkdownLintRuleCatalog` | `N1` | `negative` | Default profile unchanged; tight nested sublist not flagged by `MD032` |
| `MarkdownLintRuleCatalog` | `N2` | `security` | Obfuscated `javascript%3A`, traversal and SVG images are errors; cap keeps errors |
| `MarkdownQuickFixResolver` | `P2` | `positive` | Fix All idempotent, no double blank lines, one batch |
| `MarkdownQuickFixResolver` | `N3` | `negative` | Stale `expectedRevision` rejected |
| `MarkdownQuickFixResolver` | `N4` | `security` | `quickFix == nil` on security rules |
| `ActiveLintStatus` | `P3` | `positive` | Off / Paused / `Lint: N` classification |
| `ActiveLintStatus` | `N5` | `security` | Active-line suppression never hides security errors |
| `DiagnosticsUIWiring` | `P4` | `positive` | `⇧⌘M` popover, gutter badges, underlines, Jump-to-Range, one-Undo Fix All |
| `DiagnosticsUIWiring` | `N6` | `security` | Binary and non-Markdown tabs: Lint Off, no fix applied |
| `MarkdownLintAndFormatEngine` (modified) | `N7` | `negative` | Default `lint(snapshot:)` call keeps the `legacyBaseline` rule set |
