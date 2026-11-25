# Test Plan: YAML Outline Empty-Line Crash Fix and Tokenizer Bounds Hardening

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `YAMLOutlineAndTokenizerBoundsFix` (`MODIFIED REQ-002`, `MODIFIED REQ-005`) | `P5`: `YAMLOutlineEngine.outline(index:)` extracts all column-0 top-level keys with exact UTF-16 offsets from `.yml` files containing leading, middle, consecutive, and trailing blank lines across `LF` and `CRLF` endings, and Document Navigator jumps cleanly to the selected key | `N5`: Empty (`""`), blank-line-only (`"\n\n\r\n\r"`), and whitespace-only YAML files return `[]` cleanly without crashing; `N2` (`Trait: security`): `YAMLLineTokenizer.keyEnd`, `quotedEnd`, and `inspectStructure` fail closed without `Index out of bounds` traps on empty `ArraySlice<UInt16>`, `i >= end`, `i < startIndex`, `end > endIndex`, `indent > line.count`, and negative `indent` (`CWE-125`, `CWE-129`, `SEC-012`) |

## 2. Test Automation Strategy & Commands
- Targeted unit test command: `swift test --filter "YAMLOutlineNavigatorTests|YAMLLineTokenizerTests"`
- Full regression & modularity check: `swift test --parallel`

## 3. Testability Seams & Test Doubles
- Real collaborators: `MarkdownLineIndex`, `YAMLOutlineEngine`, `YAMLLineTokenizer`, and `YAMLWorkbenchHarness` (`[TEST-005]`).
- Zero mocks required; pure `Foundation` value-type tests execute deterministically in `< 5 ms`.

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | Modified EARS requirements `REQ-002` and `REQ-005` and Given/When/Then scenarios authored |
| Path coverage completeness | Verified | Unit covers positive (`P5`) and negative/security (`N5`, `N2`) paths |
| Security traits tagged | Verified | Out-of-bounds / empty-slice crash vector `N2` tagged `- **Trait**: security` |
