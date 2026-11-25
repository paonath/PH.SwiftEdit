# Brief: YAML Outline Empty-Line Crash Fix & Tokenizer Bounds Hardening

- **Change ID**: `029-yaml-outline-empty-line-bounds-fix`
- **Branch**: `main`
- **Date**: `2026-11-25`
- **Modifies Specs**: `openspec/specs/yaml-native-support-frontmatter-properties-and-perf/spec.md` (`MODIFIED REQ-002`, `MODIFIED REQ-005`)
- **Amends Constitution**: `none` (adheres to `openspec/Constitution.md` v1.7.0)

## 1. Context & Crash Root Cause
Release `0.1.8-beta1` crashed with `EXC_BREAKPOINT (SIGTRAP)` (`Swift runtime failure: Index out of bounds`) on the main thread when opening the Document Navigator (`Option+\`) on a `.yml`/`.yaml` file containing blank lines (`LF` / `CRLF` / `CR`):
1. `YAMLOutlineEngine.outline(index:)` (`Sources/SwiftEditCore/MarkdownLintAndFormat/YAMLSupport/YAMLOutlineEngine.swift:17-36`) filtered only `space` (`0x20`), `tab` (`0x09`), and `#` (`0x23`), allowing blank lines (`0x0A` / `0x0D`) to produce an empty slice `units[start..<start]` (`end == start`) passed directly to `YAMLLineTokenizer.keyEnd(slice, from: start, end: end)`.
2. `YAMLLineTokenizer.keyEnd(_:from:end:)` (`YAMLLineTokenizer.swift:110`) subscripted `line[i]` without checking `i >= line.startIndex && i < end && end <= line.endIndex`, triggering `SIGTRAP`. The same defensive guard is missing in `quotedEnd(_:from:end:)` (line `123`) and `inspectStructure(line:indent:)` (line `57`).
3. Existing tests (`YAMLOutlineNavigatorTests.swift`) lacked blank-line fixtures (`\n\n`, `\r\n\r\n`, `\r\r`).

## 2. Four-Pillar Summary
- **Pillar 1 (Public Behaviors)**: `YAMLOutlineEngine.outline(index:)` skips all empty/whitespace-only lines across `LF`, `CRLF`, `CR`, and empty documents while listing every valid column-0 mapping key with exact UTF-16 offsets. `YAMLLineTokenizer` safely returns `nil` / bounded positions on empty or out-of-range slices.
- **Pillar 2 (Edge Cases & Boundaries)**: Leading/trailing/consecutive blank lines, `CRLF`/`CR`-only blank lines, empty documents, whitespace-only lines, empty `ArraySlice<UInt16>`, `i >= end`, `end > line.endIndex`, and `indent > line.count` in `inspectStructure`.
- **Pillar 3 (Testability & KISS/SOLID)**: Pure `Foundation` value-type tests in `YAMLOutlineNavigatorTests` and `YAMLLineTokenizerTests` using real `MarkdownLineIndex` and `ArraySlice<UInt16>` inputs (zero mocks, zero new abstractions, keeping `YAMLOutlineEngine` and `YAMLLineTokenizer` within `<= 25` members and `cyclomatic <= 15`).
- **Pillar 4 (Security / STRIDE)**: Prevents DoS / process crash (`CWE-125`, `CWE-129`, `SEC-012`) from untrusted or hand-edited YAML files containing blank lines or adversarial slice bounds; tagged `- **Trait**: security`.

## 3. Path Coverage Matrix

| Unit | Positive Paths | Negative / Security Paths |
| :--- | :--- | :--- |
| `YAMLOutlineAndTokenizerBoundsFix` | `P1`: `YAMLOutlineEngine.outline(index:)` parses `.yml` files containing leading, middle, consecutive, and trailing blank lines (`LF`, `CRLF`, `CR`) and lists all column-0 keys with exact UTF-16 offsets | `N1`: Empty document, blank-line-only, and whitespace-only YAML files return `[]` cleanly without crashing; `N2` (`Trait: security`): `YAMLLineTokenizer.keyEnd`, `quotedEnd`, and `inspectStructure` fail closed without `Index out of bounds` traps on empty `ArraySlice`, `i >= end`, `i < startIndex`, `end > endIndex`, or `indent > line.count` (`CWE-125`, `CWE-129`, `SEC-012`) |
