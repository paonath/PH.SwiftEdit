# Proposal: YAML Outline Empty-Line Crash Fix and Tokenizer Bounds Hardening

## Why
In release `0.1.8-beta1`, invoking the Document Navigator (`Option+\`) on any `.yml` or `.yaml` file containing a blank line (`\n`, `\r\n`, or `\r`) causes an immediate main-thread crash (`EXC_BREAKPOINT (SIGTRAP)` — `Swift runtime failure: Index out of bounds`) at `YAMLLineTokenizer.keyEnd(_:from:end:)` (`YAMLLineTokenizer.swift:110`) called from `YAMLOutlineEngine.outline(index:)` (`YAMLOutlineEngine.swift:36`).

1. `YAMLOutlineEngine.outline(index:)` filters only `space`, `tab`, and `#` at `units[start]`, allowing newline code units (`0x0A`/`0x0D`) to produce an empty slice `units[start..<start]` (`end == start`) and pass it directly into `YAMLLineTokenizer.keyEnd`.
2. `YAMLLineTokenizer.keyEnd(_:from:end:)`, `quotedEnd(_:from:end:)`, and `inspectStructure(line:indent:)` subscript `line[i]` without fail-closed slice-bounds guards (`i >= line.startIndex && i < end && end <= line.endIndex`), violating defensive parsing stability (`[SEC-012]`, `CWE-125`/`CWE-129`).
3. Existing tests in `YAMLOutlineNavigatorTests.swift` did not include blank-line YAML fixtures (`\n\n`, `\r\n\r\n`, `\r\r`).

## What Changes
- **Blank-Line Guard in `YAMLOutlineEngine` (`MODIFIED REQ-005`)**:
  - Reject empty lines (`guard end > start else { continue }`) in `YAMLOutlineEngine.outline(index:)` before constructing `units[start..<end]` or calling `YAMLLineTokenizer.keyEnd`, ensuring `.yml`/`.yaml` documents with leading, consecutive, or trailing blank lines across `LF`, `CRLF`, and `CR` never trap (`[BC-004]`, `[UI-010]`, `[SEC-012]`).
- **Fail-Closed Slice Bounds in `YAMLLineTokenizer` (`MODIFIED REQ-002`)**:
  - Guard `keyEnd(_:from:end:)`, `quotedEnd(_:from:end:)`, and `inspectStructure(line:indent:)` with explicit slice-bounds checks (`i >= line.startIndex`, `i < end`, `end <= line.endIndex`, and `indent >= 0`) so empty slices or out-of-range offsets degrade safely without `Index out of bounds` runtime traps (`[AR-002]`, `[BC-004]`, `[SEC-012]`).
- **Regression & Security Test Coverage**:
  - Add unit and security regression tests in `YAMLOutlineNavigatorTests.swift` and `YAMLLineTokenizerTests.swift` covering blank lines (`LF`/`CRLF`/`CR`), empty/whitespace-only YAML files, and direct empty/out-of-bounds `ArraySlice<UInt16>` calls (`[TEST-005]`, `[TEST-008]`).

## Capabilities
- New Capabilities: None
- Modified Capabilities: `yaml-native-support-frontmatter-properties-and-perf`

## Domain Carrier & Decision Ownership (BC-###)
- **BC-004**: `MarkdownLintAndFormat/YAMLSupport` (`YAMLOutlineEngine` and `YAMLLineTokenizer`) in pure `Foundation` `SwiftEditCore` owns YAML tokenization and top-level key outline extraction (`[BC-004]`, `[AR-002]`).
- **Owned Decisions**: Blank-line skipping during column-0 YAML outline extraction and fail-closed UTF-16 slice-bounds validation inside `YAMLLineTokenizer` (`[BC-004]`, `[SEC-012]`).
- **Forbidden Responsibilities**: Never throw, trap, or crash on empty, blank-line, or out-of-bounds YAML slices; never resolve YAML aliases/tags (`CWE-776`); never introduce regex engines (`CWE-1333`) or UI framework imports into `SwiftEditCore` (`[AR-002]`, `[AR-006]`, `[SEC-012]`).
- **External Decision References**: Consumes immutable `MarkdownLineIndex` snapshots (`[AR-008]`).

## Impact
- `Sources/SwiftEditCore/MarkdownLintAndFormat/YAMLSupport/YAMLOutlineEngine.swift`
- `Sources/SwiftEditCore/MarkdownLintAndFormat/YAMLSupport/YAMLLineTokenizer.swift`
- `Tests/SwiftEditTests/YAMLOutlineNavigatorTests.swift`
- `Tests/SwiftEditTests/YAMLLineTokenizerTests.swift`

## Security Impact
- Eliminates a deterministic client-side Denial of Service (`SIGTRAP` crash, `CWE-125`/`CWE-129`) triggered whenever any YAML document with blank lines is navigated via `Option+\` (`[SEC-012]`).
- Preserves zero-regex linear `O(L)` tokenization and alias/tag non-expansion (`CWE-776`, `CWE-1333`).

## Metadata
- Owner: swift-macos-expert
- Domain: apple-swift-macos, cyber-security, test-quality
- Reviewer: cyber-security-expert, oop-architecture-expert, test-quality-auditor
- Branch: main
- Manual-Steps: none
- Modifies-Specs: openspec/specs/yaml-native-support-frontmatter-properties-and-perf/spec.md
- Constitutional-Rules: AR-002, AR-006, AR-008, BC-004, UI-010, TEST-005, TEST-006, TEST-008, SEC-012, SDD-001, SDD-002, SDD-003
- Amends-Constitution: none

## Prerequisites
- `016-yaml-native-support-frontmatter-properties-and-perf`
- `027-tokensave-zero-cycles-complexity-and-coverage-convergence`
