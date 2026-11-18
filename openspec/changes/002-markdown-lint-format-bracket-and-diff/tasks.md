# Tasks: Implement MarkdownLintAndFormat (swift-markdown AST) and SearchDiffAndBracketEngine (() {} [] & Myers Diff)

## 1. Unit: MarkdownAstLintAndFormatEngine
<!-- Governing rules: AR-004, AR-007, AR-011, AR-013, BC-003, BC-004, BC-006, BC-011, BC-012, SEC-004, SEC-012, TEST-001, TEST-004, TEST-005, SDD-002, SDD-003 -->

- [ ] 1.0 [SETUP] TASK-000-SETUP: Create `Sources/SwiftEditCore/MarkdownLintAndFormat` and `Sources/SwiftEditCore/SearchDiffAndBracketEngine` directories and shared `ElapsedTimeProviding` / `EngineEvaluationOutcome` primitives before behavioral TDD triads [Const: SDD-003 (08-sdd-governance/artifact-traceability.md)]
  - paths: [P1, P2, P3]
- [ ] 1.1 [RED] TASK-001-RED: Write failing `Swift Testing` `@Suite("MarkdownLintAndFormatTests")` tests in `Tests/SwiftEditTests/MarkdownLintAndFormatTests.swift` for `P1` (`swift-markdown` AST linting, `formatDocument`, `formatSection` preserving fenced code blocks, and atomic `DocumentSession.applyTextEdits`) and `N1` (`DomainError.staleBufferRevision` and overlapping/invalid `TextEdit` range rejection); verify failure on assertions [Const: AR-011 (01-architecture/host-and-sagas.md)]
  - paths: [P1, N1]
- [ ] 1.2 [GREEN] TASK-001-GREEN: Implement `MarkdownLintAndFormatEngine` (`lint`, `formatDocument`, `formatSection`) using `swiftlang/swift-markdown` and `DocumentSession.applyTextEdits(_:expectedRevision:)` so `P1` and `N1` pass [Const: BC-004 (02-domain/bounded-context-ownership.md)]
  - paths: [P1, N1]
- [ ] 1.3 [REFACTOR] TASK-001-REFACTOR: Extract AST `MarkupWalker` visitor and fenced-code-block line state helpers in `MarkdownLintAndFormatEngine` while keeping `P1` and `N1` green [Const: BC-006 (02-domain/negative-ownership-and-refs.md)]
  - paths: [P1, N1]
- [ ] 1.4 [DOC] TASK-001-DOC: Write concise English Swift Markup (`///`) documentation on `MarkdownLintAndFormatEngine`, `MarkdownLintDiagnostic`, `TextEdit`, and `DocumentSession.applyTextEdits`
  - paths: [P1, N1]
- [ ] 1.5 [RED] [SECURITY] TASK-002-RED: Write failing security tests in `Tests/SwiftEditTests/MarkdownLintAndFormatTests.swift` for `N2` covering `javascript:`/`file:`/`data:` `unsafeLinkScheme` diagnostics, AST nesting depth `> 128`, `isDegradedPlainText` / `isBinaryReadOnly` snapshots, and `> 250 ms` `DeterministicClockFake` timeout; verify failure on assertions [Const: BC-011 (02-domain/ubiquitous-language-and-policy.md)]
  - paths: [P1, N2] · tags: security · priority: critical
- [ ] 1.6 [GREEN] [SECURITY] TASK-002-GREEN: Implement `unsafeLinkScheme` URI validation, `maxASTDepth = 128` guard, degraded/binary snapshot guards, and `250 ms` clock deadline checks in `MarkdownLintAndFormatEngine` so `N2` passes [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [P1, N2] · tags: security · priority: critical
- [ ] 1.7 [REFACTOR] [SECURITY] TASK-002-REFACTOR: Consolidate URI scheme allowlist (`https`, `http`, `mailto`) and pre-flight snapshot admissibility checks while keeping all suites green [Const: SEC-004 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P1, N2] · tags: security
- [ ] 1.8 [DOC] [SECURITY] TASK-002-DOC: Document `128`-level AST depth, `250 ms` timeout, and URI allowlist security invariants in English Swift Markup (`///`) comments
  - paths: [P1, N2]

## 2. Unit: BracketBalancingEngine
<!-- Governing rules: AR-004, AR-012, BC-006, BC-011, SEC-012, TEST-005 -->

- [ ] 2.1 [RED] TASK-003-RED: Write failing `Swift Testing` `@Suite("BracketBalancingEngineTests")` tests in `Tests/SwiftEditTests/BracketBalancingEngineTests.swift` for `P2` (nested `()`, `{}`, `[]` matching and active caret pair resolution) and `N3` (mismatched/unclosed bracket detection in `unbalancedBrackets`); verify failure on assertions [Const: AR-012 (01-architecture/host-and-sagas.md)]
  - paths: [P2, N3]
- [ ] 2.2 [GREEN] TASK-003-GREEN: Implement `SearchDiffAndBracketEngine.evaluateBrackets(in:caretLocation:)` and `BracketBalanceResult` value types in `Sources/SwiftEditCore/SearchDiffAndBracketEngine/BracketMatcher.swift` so `P2` and `N3` pass [Const: TEST-005 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P2, N3]
- [ ] 2.3 [REFACTOR] TASK-003-REFACTOR: Refine delimiter stack matching and caret adjacency lookup in `BracketMatcher` while keeping `P2` and `N3` green [Const: AR-004 (01-architecture/module-topology.md)]
  - paths: [P2, N3]
- [ ] 2.4 [DOC] TASK-003-DOC: Write concise English Swift Markup (`///`) documentation on `BracketPairSpan`, `UnbalancedBracket`, `BracketBalanceResult`, and `evaluateBrackets`
  - paths: [P2, N3]
- [ ] 2.5 [RED] [SECURITY] TASK-004-RED: Write failing security tests in `Tests/SwiftEditTests/BracketBalancingEngineTests.swift` for `N4` verifying that lines exceeding `4096` UTF-16 code units or binary read-only snapshots return `.degradedOrTimedOut`; verify failure on assertions [Const: BC-011 (02-domain/ubiquitous-language-and-policy.md)]
  - paths: [P2, N4] · tags: security · priority: critical
- [ ] 2.6 [GREEN] [SECURITY] TASK-004-GREEN: Enforce `maxBracketScanLineUTF16Length = 4096` and `isBinaryReadOnly` guards in `evaluateBrackets` returning `.degradedOrTimedOut` so `N4` passes [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [P2, N4] · tags: security · priority: critical
- [ ] 2.7 [REFACTOR] [SECURITY] TASK-004-REFACTOR: Optimize per-line UTF-16 length pre-scan in `BracketMatcher` and verify full test suite stays green [Const: BC-011 (02-domain/ubiquitous-language-and-policy.md)]
  - paths: [P2, N4] · tags: security
- [ ] 2.8 [DOC] [SECURITY] TASK-004-DOC: Document the `4096` UTF-16 code-unit line cap and binary guard on `evaluateBrackets` in English Swift Markup (`///`) comments
  - paths: [P2, N4]

## 3. Unit: MyersFileCompareDiffEngine
<!-- Governing rules: AR-004, AR-012, AR-013, BC-006, BC-011, SEC-012, TEST-004, TEST-005, TEST-008 -->

- [ ] 3.1 [RED] TASK-005-RED: Write failing `Swift Testing` `@Suite("MyersFileCompareDiffTests")` tests in `Tests/SwiftEditTests/MyersFileCompareDiffTests.swift` for `P3` (Myers line-level `.unchanged`, `.removed`, `.inserted` hunks and line numbers) and `N5` (identical snapshots reporting `hasDifferences == false`); verify failure on assertions [Const: AR-012 (01-architecture/host-and-sagas.md)]
  - paths: [P3, N5]
- [ ] 3.2 [GREEN] TASK-005-GREEN: Implement `SearchDiffAndBracketEngine.computeMyersDiff(lhs:rhs:clock:)` and `DiffHunk` / `FileCompareDiffResult` in `Sources/SwiftEditCore/SearchDiffAndBracketEngine/MyersDiffEngine.swift` so `P3` and `N5` pass [Const: TEST-005 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P3, N5]
- [ ] 3.3 [REFACTOR] TASK-005-REFACTOR: Extract Myers trace backtracking and common prefix/suffix trimming in `MyersDiffEngine` while keeping `P3` and `N5` green [Const: BC-006 (02-domain/negative-ownership-and-refs.md)]
  - paths: [P3, N5]
- [ ] 3.4 [DOC] TASK-005-DOC: Write concise English Swift Markup (`///`) documentation on `DiffHunkKind`, `DiffHunk`, `FileCompareDiffResult`, and `computeMyersDiff`
  - paths: [P3, N5]
- [ ] 3.5 [RED] [SECURITY] TASK-006-RED: Write failing security tests in `Tests/SwiftEditTests/MyersFileCompareDiffTests.swift` for `N6` verifying that `> 10 MiB` / degraded snapshots, binary read-only snapshots, or `> 500 ms` `DeterministicClockFake` runs return `.degradedOrTimedOut`; verify failure on assertions [Const: AR-013 (01-architecture/host-and-sagas.md)]
  - paths: [P3, N6] · tags: security · priority: critical
- [ ] 3.6 [GREEN] [SECURITY] TASK-006-GREEN: Enforce `10 MiB` byte cap, `isDegradedPlainText` / `isBinaryReadOnly` checks, and `500 ms` clock deadline checks in `computeMyersDiff` so `N6` passes [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [P3, N6] · tags: security · priority: critical
- [ ] 3.7 [REFACTOR] [SECURITY] TASK-006-REFACTOR: Verify zero compiler warnings and `>= 85%` `SwiftEditCore` line coverage across all parallel test suites [Const: TEST-008 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P3, N6] · tags: security
- [ ] 3.8 [DOC] [SECURITY] TASK-006-DOC: Document the `10 MiB` size ceiling and `500 ms` cooperative clock deadline on `computeMyersDiff` in English Swift Markup (`///`) comments
  - paths: [P3, N6]
