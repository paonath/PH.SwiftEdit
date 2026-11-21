# Threat Model: Implement MarkdownLintAndFormat (swift-markdown AST) and SearchDiffAndBracketEngine (() {} [] & Myers Diff)

## 1. Asset Boundaries & Trust Zones
- **Untrusted Document Snapshot Input Zone**: User-opened Markdown or text buffers (`DocumentSnapshot`) which may contain deeply nested Markdown AST structures (`> 128` levels), `javascript:`/`file:`/`data:` links, minified single-line files (`> 4096` UTF-16 code units per line), or large `> 10 MiB` / degraded / binary inspection snapshots.
- **Stateless Pure Engine Zone (`MarkdownLintAndFormatEngine` & `SearchDiffAndBracketEngine`)**: Executes 100% offline (`[AR-011]`, `[SEC-004]`) over immutable `DocumentSnapshot` values using an injected `ElapsedTimeProviding` clock seam (`[AR-007]`, `[AR-013]`).
- **Single-Aggregate Mutation Boundary (`DocumentSession.applyTextEdits`)**: Validates `expectedRevision == session.revision`, `isBinaryReadOnly == false`, and non-overlapping `TextRange` bounds before mutating `DocumentSession` in a single atomic `BufferRevision` step (`[BC-003]`, `[BC-004]`).

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | Malicious Markdown links using `javascript:`, `data:`, `vbscript:`, or `file:` schemes disguised as documentation links (`[BC-012]`, `[SEC-004]`). | `MarkdownLintAndFormatEngine` inspects every AST `Link` and `Image` destination and emits an `.unsafeLinkScheme` diagnostic whenever a scheme outside `https`, `http`, or `mailto` is present (`[BC-012]`, `[SEC-004]`). |
| Tampering | Stale asynchronous formatting `[TextEdit]` batches overwriting newer user edits in `DocumentSession`, or formatting mutating binary read-only buffers (`[BC-003]`, `[BC-004]`, `[SEC-012]`). | `DocumentSession.applyTextEdits(_:expectedRevision:)` verifies `expectedRevision == revision` (throwing `DomainError.staleBufferRevision` on mismatch) and `isBinaryReadOnly == false` (throwing `DomainError.binaryFileSaveForbidden`). |
| Repudiation | Silent partial application of multi-range `Format Section` / `Format Document` edits corrupting buffer offsets (`[BC-003]`, `[BC-004]`). | Validate and sort all `TextEdit` ranges in descending UTF-16 order on a temporary copy before committing the new string and incrementing `BufferRevision` once (`[BC-004]`). |
| Information Disclosure | Automatic remote image/link fetching during Markdown AST parsing or preview linting leaking user IP or document contents (`[AR-011]`, `[SEC-004]`). | `MarkdownLintAndFormatEngine` uses `swiftlang/swift-markdown` purely in-memory with zero network calls or external resource loading (`[AR-011]`, `[SEC-004]`). |
| Denial of Service | Pathological Markdown nesting (`> 128` levels), `> 4096`-unit single lines in bracket matching, or `O(ND)` Myers diff on `> 10 MiB` or high-entropy files exhausting CPU/memory (`CWE-400`, `[BC-011]`). | Enforce `maxASTDepth = 128` and `250 ms` deadline in `MarkdownLintAndFormatEngine`, `maxBracketScanLineUTF16Length = 4096` in `SearchDiffAndBracketEngine`, and `maxDiffBytes = 10 MiB` + `500 ms` deadline in Myers diff, returning `.degradedOrTimedOut` (`[AR-013]`, `[BC-011]`, `[SEC-012]`). |
| Elevation of Privilege | Cross-context shared mutable state or `@MainActor` blocking during background lint/diff evaluation (`[AR-008]`, `[BC-006]`). | All engine inputs and outputs are immutable `Sendable` structs/enums (`DocumentSnapshot`, `MarkdownLintDiagnostic`, `TextEdit`, `BracketPairSpan`, `DiffHunk`) isolated from UI actors (`[AR-004]`, `[AR-008]`). |

## 3. Abuse Cases & Negative Scenarios
- **Abuse Scenario `N2` (Deep AST Bomb, Unsafe URI Scheme, or `> 250 ms` Lint/Format Timeout — `Trait: security`)**: A Markdown snapshot contains `> 128` nested blockquotes/lists, a `[click](javascript:alert(1))` URI, `isDegradedPlainText == true` / `isBinaryReadOnly == true`, or exceeds the `250 ms` clock budget; `MarkdownLintAndFormatEngine` flags `.unsafeLinkScheme` on dangerous URIs and returns `.degradedOrTimedOut` on depth/size/binary/timeout violations without crashing (`[AR-013]`, `[BC-011]`, `[BC-012]`, `[SEC-004]`, `[SEC-012]`).
- **Abuse Scenario `N4` (`> 4096` UTF-16 Single-Line Bracket Bomb or Binary Snapshot — `Trait: security`)**: A snapshot contains a line with `5000` UTF-16 code units of nested brackets or `isBinaryReadOnly == true`; `SearchDiffAndBracketEngine` skips unbounded scanning and returns `.degradedOrTimedOut` (`[BC-011]`, `[SEC-012]`).
- **Abuse Scenario `N6` (`> 10 MiB` or `> 500 ms` Myers Diff Bomb — `Trait: security`)**: Calling `computeMyersDiff` on a degraded `> 10 MiB` snapshot, a binary read-only snapshot, or a diff whose injected clock exceeds `500 ms` aborts immediately with `.degradedOrTimedOut` (`[AR-013]`, `[BC-011]`, `[SEC-012]`).

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-17
- Verdict: approved
- Status: approved
- Open items: none
