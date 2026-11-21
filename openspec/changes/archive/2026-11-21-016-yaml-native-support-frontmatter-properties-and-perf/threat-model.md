# Threat Model: Native YAML Files, Frontmatter Key/Value Properties & Post-Implementation 3-Pass Performance Refactor

## 1. Asset Boundaries & Trust Zones
- **Untrusted input**: bytes of any opened `.yml`/`.yaml`/`.md` file (local disk, Finder `open-doc`, sidebar), already gated by `DocumentLoader` (`10 MiB`/`64 MiB` stat gate, `8 KiB` NUL binary ban) [DATA-003][SEC-012].
- **Trusted core**: pure `SwiftEditCore` YAML engines (no I/O, no sockets, no subprocess), `DocumentSession` single mutation path, `BufferRevision` monotonic tags [AR-002][BC-004].
- **UI boundary**: `PropertiesPanelView` text fields (user-typed keys/values) crossing into `FrontmatterPropertyWriter`; TextKit 2 rendering attributes (non-mutating).
- **Assets**: document integrity (bytes outside the edited frontmatter entry), main-thread responsiveness (`UI-012`), undo history, user privacy (zero telemetry) [SEC-011].

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | A file named `notes.yml.md` or `evil.yaml.txt` masquerades as another language to trigger a different engine | Language resolved strictly from the final path extension, case-insensitive; double extensions use only the last component; binary snapshots force `.plainText` [SEC-012] |
| Tampering | Properties panel key/value containing `\n---\n`, `: `, `#` or control characters injects new YAML keys or terminates the frontmatter early | Writer rejects keys with control characters, newlines, leading `-`/`?`/`#`, or a trailing `:`; risky values are double-quoted with `\"`/`\\`/`\n` escaping; edits against a stale `BufferRevision` are refused; untouched lines remain byte-identical (`CWE-74`) [BC-004][SEC-012] |
| Repudiation | A panel edit silently changes the document without an undo trail | Every panel mutation is one `TextEdit` through `DocumentSession.applyTextEdits` registered with the per-tab `NSUndoManager`, producing a new `BufferRevision` and dirty state [BC-003] |
| Information Disclosure | Frontmatter secrets (tokens in YAML values) leaked via logs or diagnostics messages | Diagnostics carry only rule ID, line and key name — never values; no logging of buffer contents; zero telemetry [SEC-006][SEC-011] |
| Denial of Service | Billion-laughs anchors/aliases, `100k`-deep indentation, `1 MB` single lines, `10^5` duplicate keys, or `10^6`-line YAML freezing the main thread | No alias expansion; caps of `4096` UTF-16 per line, depth `32`, frontmatter `200` lines, `500` properties, `1000` diagnostics, `5000` outline entries; viewport-only highlighting; lint above `4096` UTF-8 bytes runs off `@MainActor` with revision guards (`CWE-400`, `CWE-776`) [UI-012][SEC-012] |
| Elevation of Privilege | YAML tags (`!!python/object`, `!include`) or merge keys triggering code execution, file inclusion or network fetches | Tags are tokenized as inert text, never resolved; no file inclusion; no `Codable`/`NSKeyedUnarchiver` decoding; App Sandbox zero-network unchanged [SEC-004][SEC-012] |

## 3. Abuse Cases & Negative Scenarios
- **Billion laughs**: a `.yml` with 10 nested `&a`/`*a` alias levels opens in bounded time with zero expansion; Properties shows aliased keys read-only (`N2`, `N7`).
- **Frontmatter injection**: entering value `x\n---\nmalicious: true` in the panel produces `"x\n---\nmalicious: true"` as a single quoted scalar; the frontmatter delimiter count stays `2` (`N8`).
- **Key injection**: renaming a key to `a: b` or `k\u0007` is rejected with no edit (`N8`).
- **Stale revision race**: editing the panel after a concurrent keystroke advanced the `BufferRevision` refuses the write and re-parses (`N8`).
- **Pathological indentation / long lines**: `4097`-unit line and `33`-level nesting yield no spans for that line and a bounded diagnostic count (`N2`, `N4`).
- **Perf regression masking**: a cache introduced by a perf pass returning stale spans after a same-length edit is caught by the golden equivalence test (`N12`).

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-21
- Verdict: approved # approved | changes-required
- Open items: none
