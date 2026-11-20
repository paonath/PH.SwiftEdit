# Tasks: Two-Speed GFM TextKit 2 Editor, Markdown CommandMenu, GFM Table Tab and Cmd+P Zero-WebKit Native Preview

## 1. Unit: MarkdownSyntaxHighlighter
<!-- Governing rules: AR-002, BC-004, SEC-012, TEST-001, TEST-002, TEST-005 -->

- [x] 1.1 [RED] TASK-001-RED: Write failing `Swift Testing` tests in `Tests/SwiftEditTests/MarkdownSyntaxHighlighterTests.swift` for `P1`, `N1` (12 constructs for the visible range only; fenced interior, non-Markdown, empty range); verify failure on assertions [Const: TEST-005 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P1, N1]
- [x] 1.2 [GREEN] TASK-001-GREEN: Implement `MarkdownSyntaxSpan` and `MarkdownSyntaxHighlighter.spans` with an `O(log F)` fence index and zero-regex UTF-16 scanner in `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownSyntaxHighlighter.swift` so `P1` and `N1` pass [Const: BC-004 (02-domain/bounded-context-ownership.md)]
  - paths: [P1, N1]
- [x] 1.3 [REFACTOR] TASK-001-REFACTOR: Share fence and line-bound helpers with `MarkdownSmartListEngine` while Markdown suites stay green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [P1, N1]
- [x] 1.4 [DOC] TASK-001-DOC: Write concise English Swift Markup (`///`) documentation on the span model and the viewport-only rationale
  - paths: [P1, N1]
- [x] 1.5 [RED] [SECURITY] TASK-002-RED: Write failing tests for `N2` (binary, degraded, `4097`-unit line return no spans); verify failure on assertions [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [N2] · tags: security · priority: critical
- [x] 1.6 [GREEN] [SECURITY] TASK-002-GREEN: Enforce quarantine and line cap in `spans` so `N2` passes [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [N2] · tags: security · priority: critical
- [x] 1.7 [REFACTOR] [SECURITY] TASK-002-REFACTOR: Centralize limit constants and keep the suite green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [N2] · tags: security
- [x] 1.8 [DOC] [SECURITY] TASK-002-DOC: Document the `CWE-400` bounds in `///` comments
  - paths: [N2]

## 2. Unit: MarkdownAuthoringAndTableEngines
<!-- Governing rules: BC-004, BC-006, SEC-012, TEST-001, TEST-002, UI-007 -->

- [x] 2.1 [RED] TASK-003-RED: Write failing tests in `Tests/SwiftEditTests/MarkdownAuthoringAndTableTests.swift` for `P2`, `P3`, `N3`, `N8` (single-batch authoring, table `Tab` navigation, fence and non-table not applicable); verify failure on assertions [Const: UI-007 (03-ui-ux/component-state-and-forms.md)]
  - paths: [P2, P3, N3, N8]
- [x] 2.2 [GREEN] TASK-003-GREEN: Implement `MarkdownAuthoringCommands` and `GFMTableEditEngine` in `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownAuthoringCommands.swift` so `P2`, `P3`, `N3`, `N8` pass [Const: BC-006 (02-domain/bounded-context-ownership.md)]
  - paths: [P2, P3, N3, N8]
- [x] 2.3 [REFACTOR] TASK-003-REFACTOR: Deduplicate selection translation with the list engine and keep tests green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [P2, P3, N3, N8]
- [x] 2.4 [DOC] TASK-003-DOC: Write concise English `///` documentation on commands, `TableEditOutcome` and the Tab chain contract
  - paths: [P2, P3, N3, N8]
- [x] 2.5 [RED] [SECURITY] TASK-004-RED: Write failing tests for `N4` (`65` columns, `2001` rows, binary return no edit); verify failure on assertions [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [N4] · tags: security · priority: critical
- [x] 2.6 [GREEN] [SECURITY] TASK-004-GREEN: Enforce table caps and quarantine so `N4` passes [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [N4] · tags: security · priority: critical
- [x] 2.7 [REFACTOR] [SECURITY] TASK-004-REFACTOR: Centralize table limits and keep the suite green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [N4] · tags: security
- [x] 2.8 [DOC] [SECURITY] TASK-004-DOC: Document the table bounds in `///` comments
  - paths: [N4]

## 3. Unit: MarkdownPreviewProjectorAndResourceGate
<!-- Governing rules: BC-004, SEC-002, SEC-003, SEC-004, SEC-012, TEST-001, TEST-002 -->

- [x] 3.1 [RED] TASK-005-RED: Write failing tests in `Tests/SwiftEditTests/MarkdownPreviewProjectorAndGateTests.swift` for `P4` and `P5` (projection with `sourceLine` and inert HTML; in-scope image downsampled and https link confirmed); verify failure on assertions [Const: TEST-005 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P4, P5]
- [x] 3.2 [GREEN] TASK-005-GREEN: Implement `MarkdownPreviewProjector` and `PreviewResourceAndLinkGate` in `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownPreviewProjector.swift` so `P4` and `P5` pass [Const: SEC-003 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P4, P5]
- [x] 3.3 [REFACTOR] TASK-005-REFACTOR: Reuse the existing `swift-markdown` pass and `prepareExternalURIConfirmation`; keep suites green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [P4, P5]
- [x] 3.4 [DOC] TASK-005-DOC: Write concise English `///` documentation on projection and the 5-gate admission order
  - paths: [P4, P5]
- [x] 3.5 [RED] [SECURITY] TASK-006-RED: Write failing tests for `N5` and `N6` (hidden preview zero projections, raw HTML inert; remote, `data:`, traversal, SVG, oversize, symlink, `javascript:`, `file://` blocked with zero sockets); verify failure on assertions [Const: SEC-004 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [N5, N6] · tags: security · priority: critical
- [x] 3.6 [GREEN] [SECURITY] TASK-006-GREEN: Enforce visibility gate, scheme allowlist, scope confinement, size and pixel caps so `N5` and `N6` pass [Const: SEC-003 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [N5, N6] · tags: security · priority: critical
- [x] 3.7 [REFACTOR] [SECURITY] TASK-006-REFACTOR: Centralize limits and add a fitness scan banning `AsyncImage`, `URLSession` and `WebKit` in the preview path [Const: TEST-005 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [N5, N6] · tags: security
- [x] 3.8 [DOC] [SECURITY] TASK-006-DOC: Document the zero-socket and confinement invariants in `///` comments
  - paths: [N5, N6]

## 4. Unit: EditorPipelineWiring
<!-- Governing rules: AR-003, AR-008, DATA-003, UI-005, UI-007, UI-012, TEST-004 -->

- [x] 4.1 [RED] TASK-007-RED: Write failing tests in `Tests/SwiftEditTests/TextKit2EditorAndDiffCoordinatorTests.swift` for `P6` (`Cmd+P` toggle default OFF, Tab chain order, `500 ms` debounced recovery, `sourceLine` sync) and `N7` (binary tab disabled); verify failure on assertions [Const: UI-007 (03-ui-ux/component-state-and-forms.md)]
  - paths: [P6, N7] · tags: security · priority: critical
- [x] 4.2 [GREEN] TASK-007-GREEN: Extract `TextKit2EditorView`, add `MarkdownNativePreviewView`, `CommandMenu("Markdown")`, `renderingAttributesValidator`, `LazyVStack` gutter and debounced recovery so `P6` and `N7` pass [Const: UI-005 (03-ui-ux/component-state-and-forms.md)]
  - paths: [P6, N7] · tags: security · priority: critical
- [x] 4.3 [REFACTOR] TASK-007-REFACTOR: Remove the transient coordinator allocation from `body` and keep the full parallel suite green [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
  - paths: [P6, N7] · tags: security
- [x] 4.4 [DOC] TASK-007-DOC: Write concise English `///` documentation on the dispatch chain and preview visibility invariants
  - paths: [P6, N7]
