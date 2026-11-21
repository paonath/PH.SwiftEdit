# Performance Analysis 016 — Whole-Codebase Bottleneck Ranking

- Change: `016-yaml-native-support-frontmatter-properties-and-perf` (`REQ-011`)
- Date: 2026-11-21
- Scope: full read-only review of `Sources/SwiftEditCore` and `Sources/SwiftEditUI` hot paths (per keystroke, per caret move, per revision, per render) after Waves 1–4 were green.
- Method: `swift test -c release` microbenchmarks, median of 15 `ContinuousClock` samples, Apple Silicon (M4), on a 20,000-line Markdown fixture (~1 MB, frontmatter + headings + lists + code + links) and a 20,000-line YAML fixture. Pass gates compare the optimized path against an in-process reference of the old path (`PerfBench016`), so thresholds are machine-independent. Behavior is locked by golden fingerprints captured before pass 1 (`PerfGolden016`).

## Baseline Measurements (release, 20k lines)

| Path | When | Thread | Median |
| :--- | :--- | :--- | ---: |
| `DocumentSession.replaceFullTextIfChanged(textView.string)` (bridged `NSString` vs session text) | every keystroke | main | 25.2 ms |
| `LineNumberGutterProjection.evaluate` on bridged session text | every revision / caret move | main | 9.3 ms |
| `StatusBarMetricsProjection.evaluate` on bridged session text | every revision / caret move | main | 10.4 ms |
| `MarkdownLineIndex(text: textView.string)` in the TextKit 2 validator | first fragment of every revision | main | 8.7 ms |
| `LineNumberGutterProjection` / `StatusBarMetricsProjection` on native text | every caret move | main | 1.7 ms / 0.55 ms |
| `YAMLStructureLinter.lint(frontmatterOnly: true)` (full-document index) | every Markdown revision | background | 2.5 ms |
| 26-rule Markdown lint, native / bridged | every revision | background | 18 ms / 37 ms |
| `YAMLStructureLinter.lint` (20k lines) | every YAML revision | background | 10.4 ms |
| Native UTF-8 conversion of the bridged buffer (`String(decoding:as:)`) | — | — | 2.1 ms |
| `activeDocumentLanguage` + render reads (`PERF-C1`, already cached in Unit 2) | every render | main | 0.002 ms |

## Ranked Bottlenecks

| Rank | ID | Bottleneck | Evidence | Pass |
| :--- | :--- | :--- | :--- | :--- |
| B1 | `PERF-B1` | TextKit hands `textView.string` (lazily bridged `NSString`) to `handleEditorTextChanged`; the `O(N)` bridged comparison costs 25 ms per keystroke and the bridged buffer then slows every downstream scan 2–19x (gutter 9.3 ms, status bar 10.4 ms, lint 37 ms). Exceeds the `UI-012` 16 ms keystroke budget on its own. | Baseline rows 1–3, 6 | Pass 1 |
| B2 | `PERF-B2` (`PERF-C2`) | Gutter and status bar rescan the whole buffer on every caret move (cache keyed on caret), and the frontmatter linter builds a full-document line index to lint a few lines. | Rows 5–6 | Pass 2 |
| B3 | `PERF-B3` (`PERF-C3`) | The TextKit 2 rendering validator rebuilds `MarkdownLineIndex` from bridged `textView.string` (8.7 ms on the main thread per revision) although the native text was already produced for the model. | Row 4 | Pass 3 |
| B4 | `PERF-C4` | Broad `@Observable` invalidation of `SwiftEditWorkbenchModel`. | Render reads measured at 0.002 ms; not a measured bottleneck | Residual |
| B5 | — | Full-document linters (Markdown 18 ms, YAML 10.4 ms) run per revision. | Already off `@MainActor` above 4 KiB with revision guards | Residual |

`PERF-C1` (language re-derivation) was eliminated during Wave 1 (`DocumentLanguage` cached on `TabDescriptor`) and measures at noise level, so it is replaced by `PERF-B1` as the pass-1 target. `PERF-C4` is not supported by measurement and is left for future work.

## Pass Results

Release build, median of 5 samples per gate (`swift test -c release --filter PerfPass`), 20k-line fixtures. Every pass kept the full suite and the `PerfGolden016` fingerprints (spans, lint, outline, gutter, status bar, frontmatter, smart edits) unchanged.

| Pass | Target | Change | Before | After | Gain |
| :--- | :--- | :--- | ---: | ---: | ---: |
| 1 | `PERF-B1` | `NativeTextNormalizer.native` at the TextKit → model boundary (`handleEditorTextChanged`, `Coordinator.textDidChange`): one ~2 ms transcoding replaces the bridged comparison and keeps every downstream scan native | 48.3 ms keystroke path (store + gutter + status bar) | 4.6 ms | −90% |
| 2 | `PERF-B2` | `DocumentTextIndex` + `DocumentTextIndexCache` keyed strictly by `(DocumentID, BufferRevision)`: gutter and status bar answer caret moves by binary search; frontmatter lint uses a bounded prefix index | 11.9 ms (5 caret moves) / 2.47 ms (frontmatter lint) | 0.0003 ms (+0.54 ms index build once per revision) / 0.049 ms | −99% / −98% |
| 3 | `PERF-B3` | Coordinator `nativeTextMirror`: validator line index, `updateNSView` sync check and programmatic updates use native text instead of re-bridging `textView.string` | 8.8 ms (index rebuild + sync check) | 2.5 ms | −71% |

Net effect on a 1 MB Markdown keystroke (main thread): bridged comparison (25 ms) + bridged gutter/status bar (~20 ms) + bridged index rebuild (8.7 ms) ≈ 54 ms → native transcoding (2.1 ms) + index (0.5 ms) + line index (2.4 ms) ≈ 5 ms, back inside the `UI-012` 16 ms budget.

## Residual Bottlenecks (future work)

- Full-document Markdown (18 ms) and YAML (10.4 ms) linters re-run on every revision off `@MainActor`; an incremental, line-range lint would bound them by the edit size.
- `MarkdownHeadingOutlineEngine.outline` (2.9 ms) rebuilds its own line index when the navigator opens; it could reuse the editor's per-revision index.
- `PERF-C4` (`@Observable` invalidation breadth) showed no measurable cost (render reads 0.002 ms) and is not worth the risk of splitting `SwiftEditWorkbenchModel` now.
