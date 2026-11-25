# Spec Delta: yaml-native-support-frontmatter-properties-and-perf

## Purpose
Fixes the `EXC_BREAKPOINT (SIGTRAP)` `Index out of bounds` crash when opening the Document Navigator on YAML files containing blank lines (`LF`, `CRLF`, `CR`) and hardens `YAMLLineTokenizer` slice-bounds handling fail-closed.

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-002 Zero-Regex Bounded YAML Line Tokenizer
The YAMLLineTokenizer SHALL tokenize each UTF-16 line linearly without regex, skip lines over 4096 units, fail closed on empty or out-of-bounds slices, and never expand aliases or resolve tags [AR-002][BC-004][SEC-012].
Security-Waiver: Strictly additive slice-bounds hardening (`CWE-125`/`CWE-129`); preserves all prior security guarantees (approved by cyber-security-expert).

#### Scenario: P2 Keys Values Comments Lists and Quoted Strings Tokenized
- **Path**: P2
- **Trait**: positive
- **GIVEN** the lines `name: "a # not comment: x"  # real`, `  - item`, `url: http://x.y/z` and `tags: [a, b]`
- **WHEN** `YAMLLineTokenizer.tokens(line:)` runs for each
- **THEN** `name` is a `key`, the quoted string including `#` and `:` is one `quotedString`, `# real` is a `comment`, `-` is a `listDash`, `http://x.y/z` is one `value` and `[a, b]` is one `value`

#### Scenario: N2 Overlong Lines Unterminated Quotes Alias Bombs and Empty or Out-of-Bounds Slices Stay Safe
- **Path**: N2
- **Trait**: security
- **GIVEN** a `4097`-unit line, the line `k: "unterminated`, a document of ten nested `&lN [*lM, *lM, ...]` alias levels, an empty `ArraySlice<UInt16>`, and out-of-bounds indices (`i >= end`, `i < startIndex`, `end > endIndex`, `indent > line.count`, `indent < 0`)
- **WHEN** `YAMLLineTokenizer.tokens(line:)`, `keyEnd(_:from:end:)`, `quotedEnd(_:from:end:)`, and `inspectStructure(line:indent:)` run
- **THEN** the overlong line yields no tokens, the unterminated quote yields one `quotedString` to end of line without error, aliases yield `alias` tokens only, and every empty or out-of-bounds call returns safely (`nil`, clamped offset, or `isIgnored == true`) without trapping (`CWE-125`, `CWE-129`)

### Requirement: REQ-005 Top-Level YAML Key Outline in the Document Navigator
WHEN the Document Navigator opens on a YAML tab, the YAMLOutlineEngine SHALL skip blank and whitespace-only lines across LF, CRLF, and CR endings, list up to 5000 column-0 mapping keys with exact UTF-16 offsets, and support confirmed clamped jumps [BC-004][UI-010][SEC-012].

#### Scenario: P5 Top-Level Keys With Blank Lines Listed and Jump Lands on the Key Line
- **Path**: P5
- **Trait**: positive
- **GIVEN** a `.yml` snapshot containing leading, middle, consecutive, and trailing blank lines in both `LF` (`"\n\nversion: 2\n\nservices:\n  web:\n    image: x\n\n\nvolumes: {}\n\n"`) and `CRLF` (`"\r\nversion: 2\r\n\r\nvolumes: {}\r\n"`)
- **WHEN** `YAMLOutlineEngine.outline(index:)` runs and the Navigator opens and confirms `volumes`
- **THEN** the outline skips every blank line without crashing, lists `version`, `services`, `volumes` (or `version`, `volumes`) with exact UTF-16 offsets, and the selection moves to the start of the `volumes:` line

#### Scenario: N5 Nested Keys Comments List Items Blank-Only Documents and Block Scalar Bodies Are Excluded
- **Path**: N5
- **Trait**: negative
- **GIVEN** a `.yml` snapshot with nested `web:`, a comment `# key: no`, a top-level list `- name: a`, `script: |` followed by an indented `fake: key` line, plus empty (`""`), blank-line-only (`"\n\n\r\n\r"`), and whitespace-only (`"   \n\t\n"`) YAML documents
- **WHEN** `YAMLOutlineEngine.outline(index:)` runs on each
- **THEN** only `script` is listed for the mixed document, empty/blank/whitespace-only documents return `[]` without trapping, and a stale offset beyond the current length is clamped before jumping

## REMOVED Requirements

## RENAMED Requirements
