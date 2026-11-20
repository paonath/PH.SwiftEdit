# Tasks: 26-Rule All-Construct Markdown Linter, Idempotent Quick-Fix and Fix All, Triple Diagnostics UI and Shift+Cmd+M Popover

## 1. Unit: MarkdownAllConstructsLintCatalog
<!-- Governing rules: AR-002, BC-004, SEC-012, TEST-001, TEST-002, TEST-005 -->

- [ ] 1.1 [RED] TASK-001-RED: Write failing `Swift Testing` tests in `Tests/SwiftEditTests/MarkdownAllConstructsLintTests.swift` for `P1`, `N1` and `N7` (frontmatter immunity with `MD018`/`MD045`/`MD056`, default profile and tight sublists, legacy call unchanged); verify failure on assertions [Const: TEST-005 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P1, N1, N7]
- [ ] 1.2 [GREEN] TASK-001-GREEN: Implement `MarkdownLintProfile`, the `.allConstructs` rules, `YAMLFrontmatterScanner` and `MarkdownSourceLineTable` in `MarkdownLintAndFormatEngine.swift` and `MarkdownSourceLineTable.swift` so `P1`, `N1` and `N7` pass [Const: BC-004 (02-domain/bounded-context-ownership.md)]
  - paths: [P1, N1, N7]
- [ ] 1.3 [REFACTOR] TASK-001-REFACTOR: Deduplicate shared helpers and keep the full parallel suite green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [P1, N1, N7]
- [ ] 1.4 [DOC] TASK-001-DOC: Write concise English Swift Markup (`///`) documentation on the contracts, bounds and invariants
  - paths: [P1, N1, N7]
- [ ] 1.5 [RED] [SECURITY] TASK-002-RED: Write failing tests for `N2` (obfuscated `javascript%3A`, traversal, SVG, protocol-relative links, and the `1000` cap retaining errors); verify failure on assertions [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [N2] · tags: security · priority: critical
- [ ] 1.6 [GREEN] [SECURITY] TASK-002-GREEN: Implement the hardened URI and image decoding rules and the severity-first cap so `N2` passes [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [N2] · tags: security · priority: critical
- [ ] 1.7 [REFACTOR] [SECURITY] TASK-002-REFACTOR: Deduplicate shared helpers and keep the full parallel suite green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [N2] · tags: security
- [ ] 1.8 [DOC] [SECURITY] TASK-002-DOC: Write concise English Swift Markup (`///`) documentation on the contracts, bounds and invariants
  - paths: [N2]

## 2. Unit: MarkdownQuickFixResolver
<!-- Governing rules: BC-004, BC-006, BC-011, SEC-004, TEST-001, TEST-002 -->

- [ ] 2.1 [RED] TASK-003-RED: Write failing tests in `Tests/SwiftEditTests/MarkdownQuickFixAndStatusTests.swift` for `P2` and `N3` (idempotent Fix All without duplicate blank lines, stale revision rejected); verify failure on assertions [Const: TEST-005 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P2, N3]
- [ ] 2.2 [GREEN] TASK-003-GREEN: Implement `MarkdownQuickFixResolver` in `MarkdownQuickFixResolver.swift` so `P2` and `N3` pass [Const: BC-006 (02-domain/bounded-context-ownership.md)]
  - paths: [P2, N3]
- [ ] 2.3 [REFACTOR] TASK-003-REFACTOR: Deduplicate shared helpers and keep the full parallel suite green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [P2, N3]
- [ ] 2.4 [DOC] TASK-003-DOC: Write concise English Swift Markup (`///`) documentation on the contracts, bounds and invariants
  - paths: [P2, N3]
- [ ] 2.5 [RED] [SECURITY] TASK-004-RED: Write failing tests for `N4` (`quickFix == nil` on security diagnostics and untouched lines under Fix All); verify failure on assertions [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [N4] · tags: security · priority: critical
- [ ] 2.6 [GREEN] [SECURITY] TASK-004-GREEN: Enforce the no-fix rule set in the resolver so `N4` passes [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [N4] · tags: security · priority: critical
- [ ] 2.7 [REFACTOR] [SECURITY] TASK-004-REFACTOR: Deduplicate shared helpers and keep the full parallel suite green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [N4] · tags: security
- [ ] 2.8 [DOC] [SECURITY] TASK-004-DOC: Write concise English Swift Markup (`///`) documentation on the contracts, bounds and invariants
  - paths: [N4]

## 3. Unit: ActiveLintStatusAndSuppression
<!-- Governing rules: BC-004, DATA-003, SEC-004, TEST-001, TEST-002 -->

- [ ] 3.1 [RED] TASK-005-RED: Write failing tests for `P3` (Off, Paused and Active classification); verify failure on assertions [Const: TEST-005 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P3]
- [ ] 3.2 [GREEN] TASK-005-GREEN: Implement `ActiveLintStatus.classify` so `P3` passes [Const: BC-004 (02-domain/bounded-context-ownership.md)]
  - paths: [P3]
- [ ] 3.3 [REFACTOR] TASK-005-REFACTOR: Deduplicate shared helpers and keep the full parallel suite green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [P3]
- [ ] 3.4 [DOC] TASK-005-DOC: Write concise English Swift Markup (`///`) documentation on the contracts, bounds and invariants
  - paths: [P3]
- [ ] 3.5 [RED] [SECURITY] TASK-006-RED: Write failing tests for `N5` (suppression hides transient warnings only on the caret line and never security errors); verify failure on assertions [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [N5] · tags: security · priority: critical
- [ ] 3.6 [GREEN] [SECURITY] TASK-006-GREEN: Implement `ActiveLineLintSuppressionPolicy` so `N5` passes [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [N5] · tags: security · priority: critical
- [ ] 3.7 [REFACTOR] [SECURITY] TASK-006-REFACTOR: Deduplicate shared helpers and keep the full parallel suite green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [N5] · tags: security
- [ ] 3.8 [DOC] [SECURITY] TASK-006-DOC: Write concise English Swift Markup (`///`) documentation on the contracts, bounds and invariants
  - paths: [N5]

## 4. Unit: DiagnosticsUIWiring
<!-- Governing rules: AR-003, UI-005, UI-007, UI-012, DATA-003, TEST-004 -->

- [ ] 4.1 [RED] [SECURITY] TASK-007-RED: Write failing tests in `Tests/SwiftEditTests/MarkdownQuickFixAndStatusTests.swift` for `P4` and `N6` (`⇧⌘M` popover toggle, Jump-to-Range, one-revision Fix All; binary and non-Markdown tabs inert); verify failure on assertions [Const: UI-007 (03-ui-ux/component-state-and-forms.md)]
  - paths: [P4, N6] · tags: security · priority: critical
- [ ] 4.2 [GREEN] [SECURITY] TASK-007-GREEN: Implement the model diagnostics state, `MarkdownDiagnosticsPopoverView`, underline attributes, gutter badges, status-bar `ActiveLintStatus` and the `⇧⌘M` command and CheatSheet entry so `P4` and `N6` pass [Const: UI-005 (03-ui-ux/component-state-and-forms.md)]
  - paths: [P4, N6] · tags: security · priority: critical
- [ ] 4.3 [REFACTOR] [SECURITY] TASK-007-REFACTOR: Deduplicate shared helpers and keep the full parallel suite green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [P4, N6] · tags: security
- [ ] 4.4 [DOC] [SECURITY] TASK-007-DOC: Write concise English Swift Markup (`///`) documentation on the contracts, bounds and invariants
  - paths: [P4, N6]

## 5. Unit: LivingSpecificationReconciliation

- [ ] 5.1 [SYNC] TASK-008-SYNC: Execute /myspec-sync 013-comprehensive-markdown-linter-and-diagnostics-ui to reconcile delta changes into `openspec/specs/comprehensive-markdown-linter-and-diagnostics-ui/spec.md` and `openspec/specs/markdown-lint-format-bracket-and-diff/spec.md` [Const: SDD-003 (08-sdd-governance/artifact-traceability.md)]
