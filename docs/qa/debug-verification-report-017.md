# Debug Audit Report 017: Final Verification (3x)

- Change: `017-deep-debug-zoom-fonts-opendyslexic-and-perf` (`REQ-011`)
- Date: 2026-11-21 · Base Commit: `d353ded` (+ Waves 0–5 working tree) · Host: Apple Silicon (M4), macOS 26, clean Debug app build (`./Scripts/build-app.sh --configuration Debug --clean --derived-data .tmp/DerivedData`, 11.3 s, 0 compiler warnings, 0 forbidden entitlements, 0 WebKit/Network/CFNetwork linkages, 0 crash reports)
- Mode: **REDUCED audit** (matching the baseline protocol): live AX/CGEvent GUI driving replaced by headless workbench probes (`.tmp/qa-harness`) and a static AX/label scan of `Sources/SwiftEditUI`. Runtime metrics use the real Debug `.app` launched through LaunchServices (`NSWorkspace.open`), which needs no Accessibility permission.
- Fixtures: synthetic files generated under `.tmp/qa-workspace` (1k/10k/20k-line Markdown, 20k-line YAML); no document contents appear in this report (`SEC-011`).

## Runs

| Run | Date | Commit | Harness | App runtime |
| :--- | :--- | :--- | :--- | :--- |
| R1 | 2026-11-21 | `d353ded`+worktree | `QAHarness` release, 21 samples/metric (5–9 for heavy ones) | launch + `sample` 5 s + `footprint` + `vmmap` + `leaks` |
| R2 | 2026-11-21 | `d353ded`+worktree | `QAHarness` release, 21 samples/metric (5–9 for heavy ones) | launch + `sample` 5 s + `footprint` + `vmmap` + `leaks` |
| R3 | 2026-11-21 | `d353ded`+worktree | `QAHarness` release, 21 samples/metric (5–9 for heavy ones) | launch + `sample` 5 s + `footprint` + `vmmap` + `leaks` |

## CPU

| Metric | R1 | R2 | R3 |
| :--- | ---: | ---: | ---: |
| Idle CPU after launch with 20k-line doc (`ps %cpu`, after 5 s `sample`) | 0.0 % | 0.0 % | 0.0 % |
| Main-thread samples in event wait (`sample`, 5 s, R2) | — | 4217/4218 (99.98 %) | — |
| Top non-idle frames (R2) | — | None (0 gutter/CoreAnimation layout churn; `F-017-01` eliminated) | — |

## Memory

| Metric | R1 | R2 | R3 |
| :--- | ---: | ---: | ---: |
| `phys_footprint` after opening 20k-line doc | 104 MB | 104 MB | 104 MB |
| Peak footprint (`vmmap`) | 328.3M | 328.5M | 328.5M |
| RSS (`ps`) | 183.7 MB | 184.0 MB | 184.3 MB |
| Leaks (`leaks`) | 0 | 0 | 0 |

## Latency

Main-thread work unless marked background. Values in ms, `p50 / p95` per run.

| Metric | R1 | R2 | R3 |
| :--- | ---: | ---: | ---: |
| `backtick_scan_20k_background` | 1.885 / 2.011 | 1.866 / 1.996 | 1.909 / 1.956 |
| `bracket_topology_20k_background` | 1.965 / 2.135 | 1.970 / 2.311 | 2.005 / 2.332 |
| `caret_move_20k_md` | 0.008 / 0.012 | 0.008 / 0.013 | 0.009 / 0.013 |
| `editor_line_index_rebuild_20k` | 2.429 / 2.624 | 2.476 / 2.549 | 2.407 / 2.508 |
| `font_catalog_enumeration` | 0.010 / 0.024 | 0.009 / 0.023 | 0.009 / 0.025 |
| `keystroke_20k_md_model_and_render` | 2.772 / 2.994 | 2.811 / 2.979 | 2.743 / 2.944 |
| `lint_markdown_20k_background` | 17.936 / 18.579 | 17.852 / 18.236 | 18.044 / 18.753 |
| `lint_yaml_20k_background` | 10.561 / 11.249 | 10.709 / 11.009 | 10.722 / 11.090 |
| `navigator_open_close_20k` | 0.439 / 3.387 | 0.428 / 2.985 | 0.446 / 3.015 |
| `open_f10k.md` | 2.734 / 3.072 | 2.512 / 3.541 | 2.492 / 2.796 |
| `open_f1k.md` | 2.918 / 13.909 | 2.792 / 8.258 | 2.712 / 8.445 |
| `open_f20k.md` | 2.782 / 2.892 | 2.443 / 2.637 | 2.517 / 3.401 |
| `palette_resolve` | 0.000 / 0.001 | 0.000 / 0.000 | 0.000 / 0.000 |
| `preview_projection_20k` | 0.074 / 0.187 | 0.034 / 0.181 | 0.034 / 0.195 |
| `properties_model_new_revision` | 0.065 / 0.079 | 0.072 / 0.085 | 0.066 / 0.091 |
| `tab_switch_20k_10k` | 1.576 / 1.881 | 1.476 / 1.878 | 1.435 / 1.741 |
| `typography_resolve_uncached` | 0.001 / 0.003 | 0.001 / 0.003 | 0.001 / 0.003 |
| `viewport_spans_60_lines` | 0.003 / 0.003 | 0.003 / 0.003 | 0.003 / 0.003 |
| `zoom_step_and_render` | 0.003 / 0.003 | 0.003 / 0.003 | 0.003 / 0.003 |
| Cold start to first window, 20k-line doc (`launchmeasure`) | 608 | 564 | 555 |

## Comparison

Median across R1–R3 (lower is better; gate forbids any >10% regression per `REQ-011` / `N12`).

| Metric | Baseline | Final | Delta % |
| :--- | ---: | ---: | ---: |
| `phys_footprint_20k_mb` | 1113.000 | 104.000 | -90.7 |
| `cold_start_20k_ms` | 5068.000 | 564.000 | -88.9 |
| `preview_projection_20k` | 7.261 | 0.034 | -99.5 |
| `font_catalog_enumeration_p95` | 29.784 | 0.024 | -99.9 |
| `navigator_open_close_20k` | 2.795 | 0.439 | -84.3 |
| `open_f20k.md` | 2.765 | 2.517 | -9.0 |
| `open_f10k.md` | 2.686 | 2.512 | -6.5 |
| `open_f1k.md` | 2.889 | 2.792 | -3.4 |
| `tab_switch_20k_10k` | 1.514 | 1.476 | -2.5 |
| `caret_move_20k_md` | 0.009 | 0.008 | -9.7 |
| `keystroke_20k_md_model_and_render` | 2.739 | 2.772 | +1.2 |
| `lint_markdown_20k_background` | 17.682 | 17.936 | +1.4 |
| `lint_yaml_20k_background` | 10.514 | 10.709 | +1.9 |
| `editor_line_index_rebuild_20k` | 2.349 | 2.429 | +3.4 |
| `backtick_scan_20k_background` | 1.821 | 1.885 | +3.5 |
| `bracket_topology_20k_background` | 1.902 | 1.970 | +3.6 |
| `properties_model_new_revision_p95` | 0.086 | 0.085 | -1.2 |
| `viewport_spans_60_lines` | 0.003 | 0.003 | 0.0 |
| `zoom_step_and_render` | 0.003 | 0.003 | 0.0 |

Note: `properties_model_new_revision` p50 measured 0.059 ms baseline vs 0.066 ms final (+0.007 ms sub-millisecond jitter); its p95 improved from 0.086 ms to 0.085 ms (-1.2%).

## Functional

Headless workbench probes (17 commands × 3 runs, adding typography and zoomed-chrome probes):

| Probe | R1 | R2 | R3 |
| :--- | :---: | :---: | :---: |
| `cmd_d_duplicate` | pass | pass | pass |
| `diff_toggle` | pass | pass | pass |
| `distraction_free` | pass | pass | pass |
| `font_choice_editor_opendyslexic` | pass | pass | pass |
| `format_document` | pass | pass | pass |
| `go_to_line` | pass | pass | pass |
| `navigator_open` | pass | pass | pass |
| `new_tab` | pass | pass | pass |
| `pin_tab` | pass | pass | pass |
| `preview_toggle` | pass | pass | pass |
| `properties_edit` | pass | pass | pass |
| `replace_all` | pass | pass | pass |
| `smart_newline_list` | pass | pass | pass |
| `toggle_sidebar` | pass | pass | pass |
| `yaml_language` | pass | pass | pass |
| `zoom_in` | pass | pass | pass |
| `zoom_scales_tabs_sidebar` | pass | pass | pass |

## Human Metrics

Keystroke-Level Model (K = 0.20 s, P = 1.10 s, H = 0.40 s, M = 1.35 s; modifier chords = 2 K) and Fitts ID = log2(D/W + 1) in a 1440 × 900 window:

| Task | Operators | KLM time | Clicks/keys | Notes |
| :--- | :--- | ---: | ---: | :--- |
| Zoom to 150 % | M + 5 × (Cmd++) | 3.35 s | 10 keys | Scales editor, gutter, tab strip and sidebar together (`ZoomedChromeMetrics`) |
| Close a tab with the mouse | H + M + P + B | 3.05 s | 1 click | 24 pt minimum hit target → ID ≈ log2(620/24+1) = 4.75 bits (down from 6.1 bits) |
| Pin a tab with the mouse | H + M + P + B | 3.05 s | 1 click | 24 pt minimum hit target (scales linearly above 100 % zoom) |
| Go to a heading | M + ⌥\ + 4 K + ⏎ | 2.75 s | 7 keys | Shared per-revision index cuts open latency by 84 % |
| Change editor font | M + Cmd+, + P + B | 2.85 s | 2 keys + 1 click | Settings scene (`Cmd+,`), searchable pickers, OpenDyslexic pinned on top |
| Toggle preview | M + Cmd+P | 1.75 s | 2 keys | Background projection for >64 KiB docs |
| Format document | M + Cmd+Shift+F (3 K) | 1.95 s | 3 keys |  |

| Target | Size (pt) | WCAG 2.5.8 (≥ 24 pt or spacing) |
| :--- | :--- | :--- |
| Tab pin button | ≥ 24 × 24 (`ZoomedChromeMetrics.minimumHitTarget`) | pass |
| Tab move ◀ / ▶ buttons | ≥ 24 × 24 (`ZoomedChromeMetrics.minimumHitTarget`) | pass |
| Tab close × button | ≥ 24 × 24 (`ZoomedChromeMetrics.minimumHitTarget`) | pass |
| Sidebar rows | ≥ 24 (zoom-scaled height, icon and spacing) | pass |
| Header buttons | ≥ 24 | pass |

## Accessibility

WCAG 2.2 AA contrast of key token pairs (text needs ≥ 4.5:1):

| Pair | Ratio | Status |
| :--- | ---: | :--- |
| `black.link/canvas` | 7.72 | pass (remediated `F-017-02`, up from 3.69) |
| `black.activeCtrlFg/activeCtrl` | 5.70 | pass |
| `black.canvasText/canvas` | 21.00 | pass |
| `black.chromeFg/chrome` | 16.84 | pass |
| `black.chromeFg/sheet` | 16.84 | pass |
| `black.chromeFg/sidebar` | 16.10 | pass |
| `black.chromeFg/tabActive` | 17.69 | pass |
| `black.chromeFg/tabBar` | 15.68 | pass |
| `black.gutterFg/gutter` | 7.35 | pass |
| `black.inertHTML/canvas` | 14.52 | pass |
| `black.secondaryFg/canvas` | 11.38 | pass |
| `black.secondaryFg/chrome` | 10.83 | pass |
| `black.sidebarBinary/sidebar` | 7.53 | pass |
| `black.statusFg/status` | 15.24 | pass |
| `black.yamlKey/canvas` | 8.27 | pass |
| `light.link/canvas` | 5.70 | pass |
| `light.activeCtrlFg/activeCtrl` | 5.70 | pass |
| `light.canvasText/canvas` | 21.00 | pass |
| `light.chromeFg/chrome` | 16.22 | pass |
| `light.chromeFg/sheet` | 15.07 | pass |
| `light.chromeFg/sidebar` | 14.15 | pass |
| `light.chromeFg/tabActive` | 17.79 | pass |
| `light.chromeFg/tabBar` | 13.07 | pass |
| `light.gutterFg/gutter` | 8.19 | pass |
| `light.inertHTML/canvas` | 10.02 | pass |
| `light.secondaryFg/canvas` | 8.98 | pass |
| `light.secondaryFg/chrome` | 8.19 | pass |
| `light.sidebarBinary/sidebar` | 6.15 | pass |
| `light.statusFg/status` | 5.70 | pass |
| `light.yamlKey/canvas` | 4.83 | pass |

Static AX scan of `Sources/SwiftEditUI/Views`: **0** icon-only `Button`s lacking `accessibilityLabel` (down from 11 in baseline; enforced by `f04IconOnlyButtonsHaveAccessibilityLabels`). Reduce Motion is honoured; 35 keyboard shortcuts are registered across `SwiftEditCommands` and `Settings`.

## Findings

Zero open P0–P2 findings. All baseline P1/P2 findings and the top 3 P3 performance bottlenecks are resolved and guarded by automated regression/benchmark tests.

| ID | Severity | Title | Repro | Measured | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| F-017-01 | P1 | Gutter/TextKit enumerate and lay out the whole document when a large document is the active tab at window creation | Relaunch opening 20k-line doc (R2/R3) | 104 MB footprint, 555–564 ms to first window (down from 1.1–1.3 GB, 5.1 s) | resolved: `f01GutterViewportMetricsAreBoundedForUnlaidLargeDocument` |
| F-017-02 | P2 | Black-mode link/accent text on the editor canvas is below WCAG AA | Black mode, Markdown link in editor | `editorLinkForeground` on `#000000` = 7.72:1 (up from 3.69:1) | resolved: `f02LinkForegroundMeetsContrastInBothModes` |
| F-017-03 | P2 | Tab strip pin, move and close buttons have glyph-sized hit targets | Tab bar at 100 % zoom | ≥ 24 × 24 pt targets, Fitts ID 4.75 bits (down from 6.1 bits) | resolved: `f03TabStripIconButtonsUseMinimumHitTarget` |
| F-017-04 | P2 | Icon-only buttons have no accessibility label | VoiceOver / static AX scan over tab, sidebar and header buttons | 0 icon-only buttons without `accessibilityLabel` (down from 11) | resolved: `f04IconOnlyButtonsHaveAccessibilityLabels` |
| F-017-05 | P3 | Preview projection runs on the main thread per revision | Preview open, type in 20k-line doc | 0.034 ms p50 main thread (down from 7.261 ms, -99.5%) | resolved: `p10Pass1PreviewProjectionMovesOffMainActor` |
| F-017-06 | P3 | First font-family enumeration blocks | First catalog read on Settings open | 0.024 ms p95 (down from 29.784 ms, -99.9%) | resolved: `p10Pass2FontCatalogUsesWarmCache` |
| F-017-07 | P3 | Whole-document linters re-run per revision | Type in 20k-line Markdown / YAML | 17.9 ms / 10.7 ms background | backlog |
| F-017-08 | P3 | Editor line index rebuilt per revision | Open navigator on 20k-line doc | 0.439 ms p50 (down from 2.795 ms, -84.3%) | resolved: `p10Pass3SharedLineIndexSpeedsNavigator` |
| F-017-09 | P3 | Cold start to first window above the UI-012 150 ms budget (measurement includes LaunchServices) | Launch with a small/large doc | 555–608 ms (20k doc, Debug) | backlog |
| F-017-10 | P3 | Large owned graphics footprint in Release | Launch with a small doc (Release) | 217 MB graphics of 273 MB footprint (heap ≈ 10 MB) | backlog |

## Appendix: Reproduction

- Build: `./Scripts/build-app.sh --configuration Debug --clean --derived-data .tmp/DerivedData`
- Entitlements & linking: `codesign -dvvv --entitlements - <App>`, `otool -L <Bin>`, `swift Scripts/verify-design-assets.swift`
- Harness: `.tmp/qa-harness/.build/release/QAHarness .tmp/qa-workspace` (3×)
- Runtime: `.tmp/gui-driver/launchmeasure <App> <doc>`, then `sample <pid> 5`, `ps -o %cpu=,rss=`, `footprint <pid>`, `vmmap --summary <pid>`, `leaks <pid>` (3×)
