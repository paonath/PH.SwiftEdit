# Performance Analysis 017: Measured Bottleneck Ranking and Extreme Optimization Passes

- Change: `017-deep-debug-zoom-fonts-opendyslexic-and-perf` (`REQ-010`)
- Date: 2026-11-21
- Sources:
  - baseline audit `docs/qa/debug-audit-report-017-baseline.md`: `QAHarness` release, 3 runs, p50/p95;
  - real-app `launchmeasure`/`sample`/`footprint`/`heap`;
  - read-only review of `Sources/` hot paths after units 1–11 (typography and zoom metrics added).
- Gates:
  - each pass starts from a RED benchmark comparing the optimized path to an in-process reference of the old path (`>= 20%` or `UI-012` budget);
  - `PerfGolden016` + `PerfGolden017` fingerprints (spans, lint, outline, gutter, status bar, frontmatter, smart edits, preview, typography, zoom metrics) must stay identical.

## Already Removed During Remediation

| ID | Fix | Before | After |
| :--- | :--- | ---: | ---: |
| `F-017-01` | Gutter viewport sampling capped at 512 rows (`maxGutterLineMetrics`) | 1.1–1.3 GB footprint, 5.1 s to first window (relaunch with 20k-line doc) | 109–111 MB, 0.47–0.49 s |

## Ranked Bottlenecks

| Rank | ID | Bottleneck | Evidence (baseline p50) | Pass |
| :--- | :--- | :--- | :--- | :--- |
| B1 | `PERF-017-B1` | `markdownPreviewDocument` projects the whole document synchronously on `@MainActor` for every revision while the preview is open | `preview_projection_20k` 7.1–7.3 ms per keystroke on top of the 2.7 ms keystroke path | Pass 1 |
| B2 | `PERF-017-B2` | First `NSFontManager.availableFontFamilies` enumeration blocks the main thread when Settings opens; per-row preview fonts resolved on the main thread | `font_catalog_enumeration` first call 30–98 ms (p95) | Pass 2 (+ `N11` cache staleness) |
| B3 | `PERF-017-B3` | The Document Navigator rebuilds its own `MarkdownLineIndex` for the outline on every open, duplicating the per-revision index | `navigator_open_close_20k` 2.7–2.8 ms (index rebuild 2.35 ms of it) | Pass 3 |
| B4 | — | Whole-document Markdown (17.7 ms) and YAML (10.5 ms) lint per revision | Background (off `@MainActor`) | Residual |
| B5 | — | 217 MB owned graphics memory in Release (window backing / CoreAnimation) | `footprint` | Residual (needs Instruments) |

## Pass Results

Release build, median of 5–7 samples per gate (`swift test -c release --filter "PerfPass1_017|PerfPass2_017|PerfPass3_017"`), 20k-line fixtures. Every pass kept the full suite (277 tests) and the `PerfGolden016` + `PerfGolden017` fingerprints unchanged.

| Pass | Target | Change | Before | After | Gain |
| :--- | :--- | :--- | ---: | ---: | ---: |
| 1 | `PERF-017-B1` | Buffers above 64 KiB are projected for the preview in a detached task guarded by `(DocumentID, BufferRevision)`; the previous projection stays visible until the new one lands (`previewGeneration`), small buffers stay synchronous | 7.68 ms per keystroke with preview open (main) | 0.063 ms | −99% |
| 2 | `PERF-017-B2` | `SystemFontFamilyCache` enumerates families once off the main actor through thread-safe CoreText at launch and stores them filtered and sorted; Settings reads the cache; preview fonts cached per choice; `N11` proves font and zoom caches never go stale | 0.065 ms steady state (plus the 30–98 ms first-call stall on the main thread) | 0.0073 ms (first call moved off the main actor) | −89% |
| 3 | `PERF-017-B3` | One `MarkdownLineIndex` per `(DocumentID, BufferRevision)` owned by the workbench and shared by the TextKit 2 validator (`lineIndexProvider`), the heading navigator and the YAML outline (`outline(index:)`) | 5.58 ms per revision + navigator open | 3.11 ms | −44% |

## Residual Bottlenecks (future work)

- Full-document Markdown and YAML lint (`B4`) could be made incremental by edited line range.
- The 217 MB owned graphics footprint in Release (`B5`) needs an Instruments (Metal/CoreAnimation) trace; heap is ≈ 10 MB.
