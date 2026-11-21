# Tasks: Linter-Governed Adaptive Markdown List Indentation (Tab / Shift+Tab / Return)

## 1. Unit: MarkdownSmartListEngine
<!-- Governing rules: AR-002, AR-009, BC-004, BC-011, DATA-003, SEC-012, TEST-001, TEST-002, TEST-005 -->

- [x] 1.1 [RED] TASK-001-RED: Write failing `Swift Testing` tests in `Tests/SwiftEditTests/MarkdownSmartListEngineTests.swift` for `P1`, `P2`, `P4`, and `N1` (`Tab` nests by four spaces and `Shift+Tab` outdents with parent numbering, multi-line selection and inherited markers, valid deep list, and root-item no-op or not-applicable inputs); verify failure on assertions [Const: TEST-005 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P1, P2, P4, N1]
- [x] 1.2 [GREEN] TASK-001-GREEN: Implement `SmartListOutcome`, `SmartListEdit`, and `MarkdownSmartListEngine.evaluateIndent` in `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownSmartListEngine.swift` so `P1`, `P2`, `P4`, and `N1` pass [Const: BC-004 (02-domain/bounded-context-ownership.md)]
  - paths: [P1, P2, P4, N1]
- [x] 1.3 [REFACTOR] TASK-001-REFACTOR: Share line-bounds and fence helpers between `MarkdownSmartListEngine` and `MarkdownSmartNewlineEngine` while `MarkdownSmartNewlineEngineTests` stay green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [P1, P2, P4, N1]
- [x] 1.4 [DOC] TASK-001-DOC: Write concise English Swift Markup (`///`) documentation on `MarkdownSmartListEngine`, its outcome types, and the Parent-Ceiling rule
  - paths: [P1, P2, P4, N1]
- [x] 1.5 [RED] [SECURITY] TASK-002-RED: Write failing tests for `N2` (binary, degraded, `4097`-unit line, level `32` cap, and `999999999.` overflow return no edit); verify failure on assertions [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [N2] · tags: security · priority: critical
- [x] 1.6 [GREEN] [SECURITY] TASK-002-GREEN: Enforce the bounds in `MarkdownSmartListEngine.evaluateIndent` so `N2` passes [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [N2] · tags: security · priority: critical
- [x] 1.7 [REFACTOR] [SECURITY] TASK-002-REFACTOR: Centralize the limit constants and keep the full suite green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [N2] · tags: security
- [x] 1.8 [DOC] [SECURITY] TASK-002-DOC: Document the `CWE-400` bounds and `DATA-003` rejection in `///` comments
  - paths: [N2]

## 2. Unit: SmartNewlineContinuationAndOutlineLint
<!-- Governing rules: BC-004, BC-006, BC-011, SEC-012, TEST-001, TEST-002, TEST-005 -->

- [x] 2.1 [RED] TASK-003-RED: Write failing tests for `P3` (`Return` continues `b.` and `1.2` and exits nested empty items in two stages) and `N3` (`.nonStandardOutlineMarker` flags `a.`/`1.1` outside fences only); verify failure on assertions [Const: TEST-005 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P3, N3]
- [x] 2.2 [GREEN] TASK-003-GREEN: Extend `MarkdownSmartNewlineEngine` and add `MarkdownLintRuleID.nonStandardOutlineMarker` detection in `MarkdownLintAndFormatEngine` so `P3` and `N3` pass [Const: BC-004 (02-domain/bounded-context-ownership.md)]
  - paths: [P3, N3]
- [x] 2.3 [REFACTOR] TASK-003-REFACTOR: Deduplicate marker parsing across the newline engine, list engine, and lint rule while all Markdown suites stay green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [P3, N3]
- [x] 2.4 [DOC] TASK-003-DOC: Write concise English Swift Markup (`///`) documentation on pseudo-outline continuation, the two-stage exit, and `.nonStandardOutlineMarker`
  - paths: [P3, N3]

## 3. Unit: WorkbenchListIndentationWiring
<!-- Governing rules: AR-003, BC-006, DATA-003, SEC-012, TEST-004, UI-005, UI-007, UI-012 -->

- [x] 3.1 [RED] TASK-004-RED: Write failing tests for `P5` (`applyListIndentation(outdent:)` yields `+1` `BufferRevision` and translated caret) and `N4` (binary or non-Markdown tab not mutated); verify failure on assertions [Const: UI-007 (03-ui-ux/component-state-and-forms.md)]
  - paths: [P5, N4] · tags: security · priority: critical
- [x] 3.2 [GREEN] TASK-004-GREEN: Implement `SwiftEditWorkbenchModel.applyListIndentation(outdent:)` and route `insertTab:` / `insertBacktab:` in `TextKit2EditorView.Coordinator.doCommandBy` so `P5` and `N4` pass [Const: UI-005 (03-ui-ux/component-state-and-forms.md)]
  - paths: [P5, N4] · tags: security · priority: critical
- [x] 3.3 [REFACTOR] TASK-004-REFACTOR: Reuse the existing programmatic-update caret path and keep the full parallel suite green [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
  - paths: [P5, N4] · tags: security
- [x] 3.4 [DOC] TASK-004-DOC: Write concise English Swift Markup (`///`) documentation on `applyListIndentation` and the Coordinator routing invariants
  - paths: [P5, N4]

## 4. Unit: LivingSpecificationReconciliation

- [x] 4.1 [SYNC] TASK-005-SYNC: Execute `/myspec-sync 011-adaptive-markdown-lists-tab-indentation` to reconcile delta changes into `openspec/specs/adaptive-markdown-lists-tab-indentation/spec.md`, `openspec/specs/editor-ux-highlighting-sidebar-pin-tabs-and-about/spec.md`, and `openspec/specs/markdown-lint-format-bracket-and-diff/spec.md` [Const: SDD-003 (08-sdd-governance/artifact-traceability.md)]
