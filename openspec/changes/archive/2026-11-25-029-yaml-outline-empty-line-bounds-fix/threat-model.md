# Threat Model: YAML Outline Empty-Line Crash Fix and Tokenizer Bounds Hardening

## 1. Asset Boundaries & Trust Zones
- **Trust Zone 1 — Pure `SwiftEditCore` YAML Engines**: `YAMLOutlineEngine` and `YAMLLineTokenizer` operating on untrusted UTF-16 `MarkdownLineIndex` / `ArraySlice<UInt16>` buffers (`[AR-002]`, `[BC-004]`).
- **Protected Assets**: Process availability and unsaved editor session stability when opening or navigating untrusted or hand-edited `.yml`/`.yaml` files (`[SEC-012]`).

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | N/A — pure local UTF-16 line scanner with no identity or network boundary. | Maintained by `SwiftEditCore` pure-`Foundation` isolation (`[AR-002]`). |
| Tampering | Out-of-bounds slice indices passed to `YAMLLineTokenizer` helpers (`keyEnd`, `quotedEnd`, `inspectStructure`). | Fail-closed slice-bounds guards (`i >= line.startIndex`, `i < end`, `end <= line.endIndex`, `indent >= 0`) prevent invalid indexing (`[SEC-012]`). |
| Repudiation | N/A — stateless pure functions producing outline headings and token ranges. | Deterministic output verified by unit and security tests (`[TEST-005]`). |
| Information Disclosure | Crash logs or unsaved buffer loss triggered by unexpected `SIGTRAP` termination. | Eliminating the blank-line `Index out of bounds` trap keeps the editor process alive and avoids crash-induced workflow disruption (`[SEC-012]`). |
| Denial of Service | Any `.yml`/`.yaml` file containing a blank line (`\n\n`, `\r\n\r\n`, `\r\r`) or malformed slice range crashing SwiftEdit via `SIGTRAP` (`CWE-125`, `CWE-129`). | `MODIFIED REQ-002` and `MODIFIED REQ-005` (`N2`, `Trait: security`) skip empty lines (`end > start`) in `YAMLOutlineEngine` and enforce bounds checks in `YAMLLineTokenizer` (`[SEC-012]`). |
| Elevation of Privilege | N/A — read-only UTF-16 buffer inspection without execution or alias/tag expansion (`CWE-776`). | Zero regex, zero alias resolution, and zero code execution preserved (`[AR-002]`, `[SEC-012]`). |

## 3. Abuse Cases & Negative Scenarios
- **Abuse Case 1 — Blank-Line & Empty/Out-of-Bounds Slice Crash (`N2`, `Trait: security`)**:
  - Opening the Document Navigator on a YAML document with blank lines (`LF`, `CRLF`, `CR`), or invoking `YAMLLineTokenizer.keyEnd`, `quotedEnd`, or `inspectStructure` with empty `ArraySlice<UInt16>`, `i >= end`, `i < line.startIndex`, `end > line.endIndex`, or `indent > line.count` / negative `indent`, MUST degrade cleanly without trapping (`CWE-125`, `CWE-129`, `[SEC-012]`).

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-25
- Verdict: approved
- Open items: none
