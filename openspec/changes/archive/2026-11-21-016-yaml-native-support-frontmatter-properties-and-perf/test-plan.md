# Test Plan: Native YAML Files, Frontmatter Key/Value Properties & Post-Implementation 3-Pass Performance Refactor

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `DocumentLanguage` | P1: `.md`/untitled → markdown, `.yml`/`.YAML` → yaml, `.txt` → plain; status bar label | N1: `.yml.bak`, `.yamllint`, `yml`, `notes.yaml.md`, binary `.yml` never enable YAML features |
| `YAMLLineTokenizer` | P2: key/quoted string with `#`/`:`/comment/list dash/URL/flow list tokens | N2 (security): `4097`-unit line skipped, unterminated quote, 10-level alias bomb linear and unexpanded |
| `YAMLSyntaxHighlighter` | P3: viewport-only spans in `.yml`; frontmatter key/value spans in `.md` with GFM body intact | N3: `.txt`, binary, degraded, line-2 `---` block yield zero YAML spans |
| `MarkdownSyntaxHighlighter` (modified REQ-001) | P10: frontmatter lines YAML-only spans, body GFM spans | N12: non-line-1 or unterminated frontmatter keeps GFM `thematicBreak` |
| `YAMLStructureLinter` | P4: `YML001..YML004` on exact lines | N4 (security): valid file clean, `1000` cap, depth `32` cap reported once as `YML005`, values never in messages |
| `ActiveLintStatus` (modified REQ-003) | P7: YAML tab `.active(count: 2)` | N8: `.swift` and binary `.yml` → `.off`, popover dismissed |
| `YAMLOutlineEngine` + Navigator | P5: top-level keys listed, jump to line 5 | N5: nested, comment, list item, block-scalar body excluded; stale offset clamped |
| `YAMLSmartIndentEngine` | P6: `key:` → +2, list continuation, `Tab` → 2 spaces | N6: `.txt`/MD body `.notApplicable`, empty marker exit, quoted colon no indent |
| `FrontmatterPropertyParser` | P7: scalars and block/flow lists editable with line ranges | N7 (security): nested map, block scalar, alias, tag read-only; unterminated → whole model read-only |
| `FrontmatterPropertyWriter` | P8: edit/rename/add/remove single minimal `TextEdit`, round-trip stable, comments preserved | N8 (security): newline injection quoted, invalid/duplicate keys `.rejected`, stale revision `.staleRevision` |
| `PropertiesPanelView` + workbench | P9: edit → revision `+1`, dirty, single `Cmd+Z` restores | N9: hidden for `.yml`/`.txt`/binary/no-frontmatter; read-only row locked with VoiceOver label |
| `PurpleThemePalette` YAML tokens | P10: key `>= 4.5:1` Light/Black, lighter weight | N10: values never tinted; appearance switch keeps buffer/revision |
| `PerfPass1..3` | P11: each benchmark `>= 20%` or `UI-012` budget, suite green | N11: golden equivalence fails on behavior change; N12 (security): no stale shared index after same-length edit |

Note: `P7`/`N8` in the modified `comprehensive-markdown-linter-and-diagnostics-ui` delta and `P10`/`N12` in the modified `textkit2-gfm-editor-and-native-preview` delta are numbered in those capabilities' own path namespaces.

## 2. Test Automation Strategy & Commands
- Unit test runner command: `swift test --parallel`
- Targeted filter command: `swift test --filter "DocumentLanguage|YAML|FrontmatterProperty|PropertiesPanel|YAMLPalette|ActiveLintStatus|GFMHighlight"`
- Security trait filter command: `swift test --filter "Security|Abuse"` (suites tagged `.tags(.security)` via Swift Testing `Tag`)
- Benchmark command (Wave 5): `swift test -c release --filter "PerfPass"` (median of 15 `ContinuousClock` samples; thresholds asserted with `#expect`)
- Golden equivalence command (Wave 5): `swift test --filter "PerfGoldenEquivalence"`

## 3. Testability Seams & Test Doubles
- Real collaborators: `DocumentSnapshot`, `DocumentSession`, `MarkdownLineIndex`, `YAMLLineTokenizer`, `FrontmatterPropertyParser`/`Writer`, `PurpleThemePalette` — pure `Sendable` value types, mock-free Given-When-Then (`TEST-002`, `TEST-003`).
- Isolation seams: `FileSystemProviding` in-memory fake for fixture loading, `InMemoryKeyValueStore` `PreferencesProviding`, `ContinuousClock` for benchmarks only (never `Task.sleep`, `TEST-004`); headless `SwiftEditWorkbenchModel` for panel/undo tests; per-tab `PerTabUndoManagerRegistry`.
- Golden fixtures: `Tests/SwiftEditTests/Fixtures/perf-016/` (`large.md`, `large.yml`, captured `golden-*.json` produced before pass 1).

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | Given/When/Then scenarios defined for REQ-001..REQ-011 and both MODIFIED requirements |
| Path coverage completeness | Verified | All 13 units have P# and N# paths |
| Security traits tagged | Verified | N2, N4, N7, N8, N12 tagged `security`; STRIDE in `threat-model.md` |
| Constitutional traceability | Verified | Every artifact cites `[<PREFIX>-###]`; tasks use `[Const: ...]` |
