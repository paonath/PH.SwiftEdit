# Tasks: Native YAML Files, Frontmatter Key/Value Properties & Post-Implementation 3-Pass Performance Refactor

## 1. Unit: StructuralScaffoldAndFixtures
<!-- Wave 1 structural setup first (SDD-003) -->

- [x] 1.1 [PHASE: RED] TASK-001-RED: Write failing fitness tests asserting `Sources/SwiftEditCore/MarkdownLintAndFormat/YAMLSupport/` exists, `swift package dump-package` still lists only `swift-markdown`, `SwiftEditCore` YAML sources import no `AppKit`/`UIKit`/`SwiftUI`/`WebKit`, and `Tests/SwiftEditTests/Fixtures/yaml-016/` fixtures load via `FileSystemProviding`; verify they fail on assertions (`paths: [P1, N1]`) [Const: SDD-003 (08-sdd-governance/artifact-traceability.md)]
- [x] 1.2 [PHASE: GREEN] TASK-001-GREEN: Create the `YAMLSupport/` folder, empty public namespaces, fixture files (`config.yml`, `frontmatter.md`, `alias-bomb.yml`, `deep-nesting.yml`) and fixture loader helper; verify path tests pass (`paths: [P1, N1]`) [Const: AR-006 (01-architecture/dependency-and-layering.md)]
- [x] 1.3 [PHASE: REFACTOR] TASK-001-REFACTOR: Align fixture naming and extend `ArchitectureImportScanner` coverage to the new folder without duplicating scanner logic; verify suite remains green (`paths: [P1, N1]`) [Const: TEST-005 (06-testing-fitness/architecture-fitness-and-quality.md)]
- [x] 1.4 [PHASE: DOC] TASK-001-DOC: Document the `YAMLSupport` folder ownership and fixture conventions in English Swift Markup (`paths: [P1, N1]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 2. Unit: DocumentLanguage
<!-- REQ-001 -->

- [x] 2.1 [PHASE: RED] TASK-002-RED: Write failing `@Test(arguments:)` cases for `DocumentLanguage.resolve(filename:isBinary:isDegraded:)` and status bar label covering `P1` and `N1` (`README.md`, `Untitled`, `config.yml`, `Deploy.YAML`, `notes.txt`, `config.yml.bak`, `.yamllint`, `yml`, `notes.yaml.md`, binary `data.yml`); verify they fail on assertions (`paths: [P1, N1]`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 2.2 [PHASE: GREEN] TASK-002-GREEN: Implement `enum DocumentLanguage` in `DocumentCore`, cache it on `WorkspaceTabSession` tabs (recomputed on open/rename/save-as), expose `activeDocumentLanguage` and status bar label, and keep `isMarkdownFilename` as a thin delegating wrapper; verify path tests pass (`paths: [P1, N1]`) [Const: BC-001 (02-domain/bounded-context-ownership.md)]
- [x] 2.3 [PHASE: REFACTOR] TASK-002-REFACTOR: Replace the 6 `isMarkdownFilename(activeTabTitle)` call sites in `SwiftEditRootView` with `activeDocumentLanguage` and confirm suite green; verify suite remains green (`paths: [P1, N1]`) [Const: AR-009 (01-architecture/dependency-and-layering.md)]
- [x] 2.4 [PHASE: DOC] TASK-002-DOC: Document why language is resolved once per tab and why binary forces `.plainText` (`paths: [P1, N1]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 3. Unit: YAMLLineTokenizer
<!-- REQ-002 -->

- [x] 3.1 [PHASE: RED] TASK-003-RED: Write failing tokenizer tests covering `P2` (key, colon, quoted string containing `#`/`:`, comment, list dash, URL value, flow list); verify they fail on assertions (`paths: [P2]`) [Const: TEST-001 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 3.2 [PHASE: GREEN] TASK-003-GREEN: Implement zero-regex linear `YAMLLineTokenizer.tokens(line:)` over `ArraySlice<UInt16>`; verify path tests pass (`paths: [P2]`) [Const: BC-004 (02-domain/bounded-context-ownership.md)]
- [x] 3.3 [PHASE: REFACTOR] TASK-003-REFACTOR: Share quote/escape scanning helpers and remove duplicated whitespace loops; verify suite remains green (`paths: [P2]`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 3.4 [PHASE: DOC] TASK-003-DOC: Document token grammar subset and its explicit non-goals (`paths: [P2]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]
- [x] 3.5 [PHASE: RED] [SECURITY] TASK-003-SEC-RED: Write failing abuse tests covering `N2` (`4097`-unit line, unterminated quote, 10-level alias bomb completing in linear time with only `alias` tokens); verify they fail on assertions (`paths: [N2] · tags: security · priority: critical`) [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
- [x] 3.6 [PHASE: GREEN] [SECURITY] TASK-003-SEC-GREEN: Enforce `4096` line cap, unterminated-quote termination at end of line, and inert anchor/alias/tag tokens; verify path tests pass (`paths: [N2] · tags: security · priority: critical`) [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
- [x] 3.7 [PHASE: REFACTOR] [SECURITY] TASK-003-SEC-REFACTOR: Audit tokenizer for any recursion or allocation proportional to alias fan-out; verify suite remains green (`paths: [N2] · tags: security`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 3.8 [PHASE: DOC] [SECURITY] TASK-003-SEC-DOC: Document billion-laughs immunity and bounded-work invariants (`paths: [N2]`) [Const: SDD-002 (08-sdd-governance/artifact-traceability.md)]

## 4. Unit: YAMLSyntaxHighlighterAndGFMDelegation
<!-- REQ-003 + modified textkit2 REQ-001 -->

- [x] 4.1 [PHASE: RED] TASK-004-RED: Write failing span tests covering `P3`, `N3` and the modified-capability paths `P10`/`N12` of `textkit2-gfm-editor-and-native-preview` (YAML viewport-only spans, frontmatter delegation, GFM body intact, line-2 and unterminated `---` stay GFM); verify they fail on assertions (`paths: [P3, N3, P10, N12]`) [Const: TEST-001 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 4.2 [PHASE: GREEN] TASK-004-GREEN: Add `MarkdownSyntaxKind.yamlKey/.yamlValue/.yamlPunctuation/.yamlComment`, implement `YAMLSyntaxHighlighter.spans(index:visibleRange:frontmatterLineCount:)`, and dispatch in `MarkdownSyntaxHighlighter` and the TextKit 2 validator by `DocumentLanguage`; verify path tests pass (`paths: [P3, N3, P10, N12]`) [Const: BC-004 (02-domain/bounded-context-ownership.md)]
- [x] 4.3 [PHASE: REFACTOR] TASK-004-REFACTOR: Unify the validator's span-to-attribute mapping into one switch shared by GFM and YAML kinds and confirm suite green; verify suite remains green (`paths: [P3, N3, P10, N12]`) [Const: AR-010 (01-architecture/dependency-and-layering.md)]
- [x] 4.4 [PHASE: DOC] TASK-004-DOC: Document dispatch order (frontmatter → YAML, body → GFM) and viewport bounds (`paths: [P3, N3, P10, N12]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 5. Unit: YAMLKeyValuePaletteTokens
<!-- REQ-010 -->

- [x] 5.1 [PHASE: RED] TASK-005-RED: Write failing palette fitness tests covering `P10` and `N10` (`yamlKeyForeground` contrast `>= 4.5:1` in Light/Black, lighter key font weight, no `foregroundColor` on `yamlValue`, appearance switch keeps buffer and revision); verify they fail on assertions (`paths: [P10, N10]`) [Const: UI-009 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 5.2 [PHASE: GREEN] TASK-005-GREEN: Add `yamlKeyForeground` (`#6B7280`/`#9CA3AF`) to `PurpleThemePalette`, cache a `.light` monospaced key font per zoom in the coordinator, and map comments/punctuation to `secondaryForeground`; verify path tests pass (`paths: [P10, N10]`) [Const: UI-002 (03-ui-ux/design-system-and-tokens.md)]
- [x] 5.3 [PHASE: REFACTOR] TASK-005-REFACTOR: Fold the YAML key font into `updateGFMFontsIfNeeded` caching to avoid per-fragment font creation; verify suite remains green (`paths: [P10, N10]`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 5.4 [PHASE: DOC] TASK-005-DOC: Document why values keep canvas text (21:1) and keys are grey and lighter (`paths: [P10, N10]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 6. Unit: YAMLStructureLinterAndLintStatus
<!-- REQ-004 + modified linter REQ-003 -->

- [x] 6.1 [PHASE: RED] TASK-006-RED: Write failing lint tests covering `P4` and the modified-capability paths `P7`/`N8` of `comprehensive-markdown-linter-and-diagnostics-ui` (`YML001..YML004`, YAML tab `.active(count: 2)`, `.swift` and binary `.yml` `.off`); verify they fail on assertions (`paths: [P4, P7, N8]`) [Const: TEST-001 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 6.2 [PHASE: GREEN] TASK-006-GREEN: Implement `YAMLStructureLinter.lint(snapshot:frontmatterOnly:)`, change `ActiveLintStatus.classify` to take `DocumentLanguage`, and dispatch `refreshDiagnosticsForActiveDocument` by language with the existing `4096`-byte sync/async threshold and revision guard; verify path tests pass (`paths: [P4, P7, N8]`) [Const: BC-004 (02-domain/bounded-context-ownership.md)]
- [x] 6.3 [PHASE: REFACTOR] TASK-006-REFACTOR: Reuse the Markdown diagnostic pipeline (underlines, gutter badges, popover) for YAML without per-language branches in views; verify suite remains green (`paths: [P4, P7, N8]`) [Const: AR-009 (01-architecture/dependency-and-layering.md)]
- [x] 6.4 [PHASE: DOC] TASK-006-DOC: Document rule catalog `YML001..YML004` and lint status mapping (`paths: [P4, P7, N8]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]
- [x] 6.5 [PHASE: RED] [SECURITY] TASK-006-SEC-RED: Write failing abuse tests covering `N4` (valid file clean, `5000` duplicate keys → `1000` diagnostics, `40`-level nesting capped at `32`, `s3cr3t` absent from every message); verify they fail on assertions (`paths: [N4] · tags: security · priority: critical`) [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
- [x] 6.6 [PHASE: GREEN] [SECURITY] TASK-006-SEC-GREEN: Enforce diagnostic and depth caps and key-only diagnostic messages; verify path tests pass (`paths: [N4] · tags: security · priority: critical`) [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
- [x] 6.7 [PHASE: REFACTOR] [SECURITY] TASK-006-SEC-REFACTOR: Audit off-`@MainActor` YAML lint cancellation and stale-revision discard; verify suite remains green (`paths: [N4] · tags: security`) [Const: TEST-003 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 6.8 [PHASE: DOC] [SECURITY] TASK-006-SEC-DOC: Document caps and value-redaction policy in diagnostics (`paths: [N4]`) [Const: SDD-002 (08-sdd-governance/artifact-traceability.md)]

## 7. Unit: YAMLOutlineNavigator
<!-- REQ-005 -->

- [x] 7.1 [PHASE: RED] TASK-007-RED: Write failing outline and Navigator tests covering `P5` and `N5` (top-level keys, jump to line 5, nested/comment/list/block-scalar exclusion, stale offset clamp, `5000` cap); verify they fail on assertions (`paths: [P5, N5]`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 7.2 [PHASE: GREEN] TASK-007-GREEN: Implement `YAMLOutlineEngine.outline(index:)` and feed it to `DocumentNavigatorOverlayView` when the active language is `.yaml`; verify path tests pass (`paths: [P5, N5]`) [Const: BC-004 (02-domain/bounded-context-ownership.md)]
- [x] 7.3 [PHASE: REFACTOR] TASK-007-REFACTOR: Generalize the Navigator entry model so Markdown headings and YAML keys share one row type and jump path; verify suite remains green (`paths: [P5, N5]`) [Const: AR-009 (01-architecture/dependency-and-layering.md)]
- [x] 7.4 [PHASE: DOC] TASK-007-DOC: Document outline scope (top-level keys only) and cap (`paths: [P5, N5]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 8. Unit: YAMLSmartIndentEngine
<!-- REQ-006 -->

- [x] 8.1 [PHASE: RED] TASK-008-RED: Write failing smart Enter/Tab tests covering `P6` and `N6`; verify they fail on assertions (`paths: [P6, N6]`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 8.2 [PHASE: GREEN] TASK-008-GREEN: Implement `YAMLSmartIndentEngine.evaluateNewline/evaluateTab` and wire it into the editor Enter/Tab chain for `.yaml` tabs and frontmatter lines before Markdown engines, as one undoable `shouldChangeText` transaction; verify path tests pass (`paths: [P6, N6]`) [Const: BC-003 (02-domain/bounded-context-ownership.md)]
- [x] 8.3 [PHASE: REFACTOR] TASK-008-REFACTOR: Share indentation-measurement helpers with `MarkdownSmartListEngine` where identical and confirm suite green; verify suite remains green (`paths: [P6, N6]`) [Const: AR-009 (01-architecture/dependency-and-layering.md)]
- [x] 8.4 [PHASE: DOC] TASK-008-DOC: Document 2-space policy and Enter/Tab dispatch precedence (`paths: [P6, N6]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 9. Unit: FrontmatterPropertyParser
<!-- REQ-007 -->

- [x] 9.1 [PHASE: RED] TASK-009-RED: Write failing parser tests covering `P7` (scalars, block and flow lists, exact line ranges); verify they fail on assertions (`paths: [P7]`) [Const: TEST-001 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 9.2 [PHASE: GREEN] TASK-009-GREEN: Implement `FrontmatterPropertyParser.parse(snapshot:)` returning `FrontmatterPropertyModel` (immutable `Sendable`, tagged with `BufferRevision`) on top of `YAMLLineTokenizer` and `YAMLFrontmatterScanner`; verify path tests pass (`paths: [P7]`) [Const: AR-008 (01-architecture/dependency-and-layering.md)]
- [x] 9.3 [PHASE: REFACTOR] TASK-009-REFACTOR: Consolidate entry classification into one table-driven function; verify suite remains green (`paths: [P7]`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 9.4 [PHASE: DOC] TASK-009-DOC: Document editable vs read-only kinds (`paths: [P7]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]
- [x] 9.5 [PHASE: RED] [SECURITY] TASK-009-SEC-RED: Write failing abuse tests covering `N7` (nested map, block scalar, anchor, alias, `!!python/object` tag read-only; unterminated block fully read-only; `500`-entry cap); verify they fail on assertions (`paths: [N7] · tags: security · priority: critical`) [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
- [x] 9.6 [PHASE: GREEN] [SECURITY] TASK-009-SEC-GREEN: Enforce fail-closed classification and entry cap with zero alias expansion; verify path tests pass (`paths: [N7] · tags: security · priority: critical`) [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
- [x] 9.7 [PHASE: REFACTOR] [SECURITY] TASK-009-SEC-REFACTOR: Audit parser for any path that could mark an unsupported construct editable; verify suite remains green (`paths: [N7] · tags: security`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 9.8 [PHASE: DOC] [SECURITY] TASK-009-SEC-DOC: Document fail-closed policy for unsupported YAML (`paths: [N7]`) [Const: SDD-002 (08-sdd-governance/artifact-traceability.md)]

## 10. Unit: FrontmatterPropertyWriter
<!-- REQ-008 -->

- [x] 10.1 [PHASE: RED] TASK-010-RED: Write failing writer tests covering `P8` (edit, rename, add, remove; single minimal `TextEdit`; comments and body byte-identical; round-trip re-parse); verify they fail on assertions (`paths: [P8]`) [Const: TEST-005 (06-testing-fitness/architecture-fitness-and-quality.md)]
- [x] 10.2 [PHASE: GREEN] TASK-010-GREEN: Implement `FrontmatterPropertyWriter.edit(_:in:revision:) -> FrontmatterWriteResult` (`.edit(TextEdit)`, `.rejected(reason)`, `.staleRevision`) with plain/double-quoted scalar emission; verify path tests pass (`paths: [P8]`) [Const: BC-003 (02-domain/bounded-context-ownership.md)]
- [x] 10.3 [PHASE: REFACTOR] TASK-010-REFACTOR: Extract the quoting/escaping policy into one pure function shared by flow-list emission; verify suite remains green (`paths: [P8]`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 10.4 [PHASE: DOC] TASK-010-DOC: Document minimal-edit and round-trip guarantees (`paths: [P8]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]
- [x] 10.5 [PHASE: RED] [SECURITY] TASK-010-SEC-RED: Write failing injection tests covering `N8` (`x\n---\nmalicious: true` value, `a: b` key, `k\u{7}` key, duplicate rename, stale revision `6`); verify they fail on assertions (`paths: [N8] · tags: security · priority: critical`) [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
- [x] 10.6 [PHASE: GREEN] [SECURITY] TASK-010-SEC-GREEN: Enforce key validation, escaping, duplicate detection and revision check before emitting any edit; verify path tests pass (`paths: [N8] · tags: security · priority: critical`) [Const: BC-004 (02-domain/bounded-context-ownership.md)]
- [x] 10.7 [PHASE: REFACTOR] [SECURITY] TASK-010-SEC-REFACTOR: Audit that no code path emits a `TextEdit` spanning beyond the owned entry or the closing delimiter; verify suite remains green (`paths: [N8] · tags: security`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 10.8 [PHASE: DOC] [SECURITY] TASK-010-SEC-DOC: Document CWE-74 injection mitigations and stale-revision refusal (`paths: [N8]`) [Const: SDD-002 (08-sdd-governance/artifact-traceability.md)]

## 11. Unit: PropertiesPanelView
<!-- REQ-009 -->

- [x] 11.1 [PHASE: RED] TASK-011-RED: Write failing headless workbench and view-model tests covering `P9` and `N9` (edit → revision `+1`, dirty, single `Cmd+Z`; hidden for `.yml`/`.txt`/binary/no-frontmatter; read-only row label `meta, read-only nested mapping`); verify they fail on assertions (`paths: [P9, N9]`) [Const: UI-010 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 11.2 [PHASE: GREEN] TASK-011-GREEN: Implement `PropertiesPanelView` (collapsible, under `EditorTabStrip`, hidden in distraction-free), workbench `isPropertiesPanelVisible`, `applyPropertyEdit(_:)` through `DocumentSession.applyTextEdits` + per-tab undo, re-parse on revision; verify path tests pass (`paths: [P9, N9]`) [Const: UI-005 (03-ui-ux/design-system-and-tokens.md)]
- [x] 11.3 [PHASE: REFACTOR] TASK-011-REFACTOR: Isolate panel state in a dedicated `@Observable` sub-model to avoid invalidating the editor on panel typing; verify suite remains green (`paths: [P9, N9]`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 11.4 [PHASE: DOC] TASK-011-DOC: Document panel lifecycle, keyboard navigation and VoiceOver labels (`paths: [P9, N9]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 12. Unit: PerfAnalysisReportAndBaselines
<!-- REQ-011 analysis (runs only after units 1-11 are green) -->

- [x] 12.1 [PHASE: RED] TASK-012-RED: Write failing benchmark harness and golden-capture tests (`PerfBaselineTests`, `PerfGoldenEquivalenceTests`) asserting presence of `20,000`-line MD/YAML fixtures, golden JSON for spans/diagnostics/outline/smart edits, and `docs/qa/perf-analysis-016.md` with `>= 3` ranked bottlenecks; verify they fail on assertions (`paths: [P11, N11]`) [Const: TEST-005 (06-testing-fitness/architecture-fitness-and-quality.md)]
- [x] 12.2 [PHASE: GREEN] TASK-012-GREEN: Run a full read-only analysis of `Sources/` (hot paths per keystroke, per revision, per render), measure `PERF-C1..PERF-C4` plus any discovered hotspot, write the ranked report with baselines, and commit fixtures and goldens; verify path tests pass (`paths: [P11, N11]`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 12.3 [PHASE: REFACTOR] TASK-012-REFACTOR: Deduplicate benchmark helpers into one `measureMedian(runs:)` utility; verify suite remains green (`paths: [P11, N11]`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 12.4 [PHASE: DOC] TASK-012-DOC: Document benchmark methodology (release build, median of 15, thresholds) in the report and helper (`paths: [P11, N11]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 13. Unit: PerfPass1
<!-- REQ-011 pass 1 (default target: PERF-C1 / top-ranked bottleneck) -->

- [x] 13.1 [PHASE: RED] TASK-013-RED: Write failing benchmark for the pass-1 bottleneck requiring `>= 20%` improvement over baseline (default: `PERF-C1` per-render language derivation and related per-keystroke recomputation in `SwiftEditRootView`) plus golden equivalence; verify they fail on assertions (`paths: [P11, N11]`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 13.2 [PHASE: GREEN] TASK-013-GREEN: Apply the minimal refactor removing the bottleneck; verify path tests pass (`paths: [P11, N11]`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 13.3 [PHASE: REFACTOR] TASK-013-REFACTOR: Clean up and confirm full suite and goldens green; verify suite remains green (`paths: [P11, N11]`) [Const: TEST-001 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 13.4 [PHASE: DOC] TASK-013-DOC: Record before/after timings in `docs/qa/perf-analysis-016.md` and document the invariant in code (`paths: [P11, N11]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 14. Unit: PerfPass2
<!-- REQ-011 pass 2 (default target: PERF-C2 shared per-revision text index) -->

- [x] 14.1 [PHASE: RED] TASK-014-RED: Write failing benchmark for pass 2 (default: `PERF-C2` duplicate `Array(text.utf16)` copies and UTF-8 frontmatter re-scan per revision) plus `N12` same-length-edit staleness test; verify they fail on assertions (`paths: [P11, N11, N12] · tags: security`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 14.2 [PHASE: GREEN] TASK-014-GREEN: Introduce `DocumentTextIndexCache` keyed strictly by `(DocumentID, BufferRevision)` consumed by highlighter, outline, linter mask, preview and YAML engines; remove the UTF-8 duplicate detector; verify path tests pass (`paths: [P11, N11, N12] · tags: security`) [Const: AR-008 (01-architecture/dependency-and-layering.md)]
- [x] 14.3 [PHASE: REFACTOR] TASK-014-REFACTOR: Remove dead per-consumer index construction and confirm suite and goldens green; verify suite remains green (`paths: [P11, N11, N12]`) [Const: TEST-001 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 14.4 [PHASE: DOC] TASK-014-DOC: Record before/after timings and document cache keying and invalidation (`paths: [P11, N11, N12]`) [Const: SDD-002 (08-sdd-governance/artifact-traceability.md)]

## 15. Unit: PerfPass3
<!-- REQ-011 pass 3 (default target: PERF-C3 text sync, else PERF-C4 observation split) -->

- [x] 15.1 [PHASE: RED] TASK-015-RED: Write failing benchmark for pass 3 (default: `PERF-C3` `O(N)` `textView.string != text` compare and `textView.string` bridging in `TextKit2EditorView`; alternative `PERF-C4` broad `@Observable` invalidation) plus golden equivalence; verify they fail on assertions (`paths: [P11, N11]`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [x] 15.2 [PHASE: GREEN] TASK-015-GREEN: Replace full-string comparison with revision/identity-based sync and strict index invalidation (or split observation sub-models for `PERF-C4`); verify path tests pass (`paths: [P11, N11]`) [Const: AR-010 (01-architecture/dependency-and-layering.md)]
- [x] 15.3 [PHASE: REFACTOR] TASK-015-REFACTOR: Clean up and confirm full suite, goldens and `UI-012` keystroke budget green; verify suite remains green (`paths: [P11, N11]`) [Const: TEST-001 (06-testing-fitness/tdd-and-unit-testing.md)]
- [x] 15.4 [PHASE: DOC] TASK-015-DOC: Record final timings and close the report with residual bottlenecks for future work (`paths: [P11, N11]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 16. Unit: LivingSpecificationReconciliation
<!-- Required: MODIFIED requirements in textkit2-gfm-editor-and-native-preview (REQ-001) and comprehensive-markdown-linter-and-diagnostics-ui (REQ-003) -->

- [x] 16.1 [SYNC] TASK-016-SYNC: Execute `/myspec-sync 016-yaml-native-support-frontmatter-properties-and-perf` to reconcile delta changes into `openspec/specs/<capability>/spec.md` [Const: SDD-010 (08-sdd-governance/convergence-and-gates.md)]
