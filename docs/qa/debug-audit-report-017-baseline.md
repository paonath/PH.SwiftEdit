# Debug Audit Report 017: Baseline (3x)

- Change: `017-deep-debug-zoom-fonts-opendyslexic-and-perf` (`REQ-001`)
- Date: 2026-11-21 · Commit: `d353ded` · Host: Apple Silicon (M4), macOS 26, Debug app build (`./Scripts/build-app.sh --configuration Debug --clean`, 16.0 s, 0 warnings) plus a Release build for the cold-start cross-check
- Mode: **REDUCED audit**: the Accessibility grant did not take effect (`AXIsProcessTrusted() == false` after manual step 1), so live AX/CGEvent GUI driving was replaced by headless workbench probes (`.tmp/qa-harness`) and a static AX/label scan of `Sources/SwiftEditUI`. Runtime metrics use the real `.app` launched through LaunchServices (`NSWorkspace.open`), which needs no Accessibility permission.
- Fixtures: synthetic files generated under `.tmp/qa-workspace` (1k/10k/20k-line Markdown, 20k-line YAML); the reports never include their contents.

## Runs

| Run | Date | Commit | Harness | App runtime |
| :--- | :--- | :--- | :--- | :--- |
| R1 | 2026-11-21 | `d353ded` | `QAHarness` release, 21 samples/metric (5–9 for heavy ones) | launch + `sample` 5 s + `footprint` + `vmmap` + `leaks` |
| R2 | 2026-11-21 | `d353ded` | `QAHarness` release, 21 samples/metric (5–9 for heavy ones) | launch + `sample` 5 s + `footprint` + `vmmap` + `leaks` |
| R3 | 2026-11-21 | `d353ded` | `QAHarness` release, 21 samples/metric (5–9 for heavy ones) | launch + `sample` 5 s + `footprint` + `vmmap` + `leaks` |

## CPU

| Metric | R1 | R2 | R3 |
| :--- | ---: | ---: | ---: |
| Idle CPU after launch with 20k-line doc (`ps %cpu`, after 5 s `sample`) | 0.0 % | 0.0 % | 0.0 % |
| Main-thread samples in event wait (`sample`, 5 s, R2) | 3446/3809 (90 %) | — | — |
| Top non-idle frames (R2) | SwiftUI tooltip hit-testing over a 20k-view gutter, `CA::Layer::insert_sublayer`, `AG::Graph` updates | — | — |

## Memory

| Metric | R1 | R2 | R3 |
| :--- | ---: | ---: | ---: |
| `phys_footprint` after opening 20k-line doc | 106 MB | 1115 MB | 1113 MB |
| Peak footprint (`vmmap`) | 330.1M | 1.3G | 1.3G |
| Leaks (`leaks`) | 0 | 0 | 0 |
| Heap top type (R2/R3) | — | ~160k `_DictionaryStorage<ObjectIdentifier, AnyTrackedValue>`, ~20k `ResolvedStyledText`, ~20k `NSTextLayoutFragment` | same |
| Small doc footprint (Debug / Release) | 56 MB / 273 MB | — | — |
| Release footprint breakdown | 217 MB owned graphics memory (window backing / CoreAnimation), heap ≈ 10 MB | — | — |

## Latency

Main-thread work unless marked background. Values in ms, `p50 / p95` per run.

| Metric | R1 | R2 | R3 |
| :--- | ---: | ---: | ---: |
| `backtick_scan_20k_background` | 1.826 / 1.853 | 1.771 / 1.790 | 1.821 / 1.828 |
| `bracket_topology_20k_background` | 1.914 / 2.110 | 1.902 / 2.058 | 1.894 / 2.072 |
| `caret_move_20k_md` | 0.010 / 0.016 | 0.009 / 0.014 | 0.009 / 0.014 |
| `editor_line_index_rebuild_20k` | 2.349 / 2.405 | 2.348 / 2.452 | 2.364 / 2.422 |
| `font_catalog_enumeration` | 0.000 / 97.572 | 0.000 / 29.784 | 0.000 / 29.701 |
| `keystroke_20k_md_model_and_render` | 2.729 / 2.977 | 2.739 / 3.180 | 2.743 / 3.041 |
| `lint_markdown_20k_background` | 17.755 / 17.906 | 17.682 / 18.718 | 17.675 / 18.441 |
| `lint_yaml_20k_background` | 10.430 / 10.510 | 10.514 / 10.671 | 10.537 / 10.633 |
| `navigator_open_close_20k` | 2.734 / 2.816 | 2.795 / 2.900 | 2.813 / 2.904 |
| `open_f10k.md` | 2.791 / 3.052 | 2.686 / 2.869 | 2.564 / 2.780 |
| `open_f1k.md` | 3.420 / 11.330 | 2.889 / 6.811 | 2.764 / 7.113 |
| `open_f20k.md` | 2.765 / 2.936 | 2.662 / 3.032 | 2.794 / 3.576 |
| `preview_projection_20k` | 7.261 / 7.835 | 7.333 / 7.374 | 7.083 / 7.224 |
| `properties_model_new_revision` | 0.059 / 0.087 | 0.065 / 0.086 | 0.059 / 0.080 |
| `tab_switch_20k_10k` | 1.514 / 1.858 | 1.571 / 1.929 | 1.489 / 1.696 |
| `viewport_spans_60_lines` | 0.003 / 0.003 | 0.003 / 0.004 | 0.003 / 0.004 |
| `zoom_step_and_render` | 0.003 / 0.003 | 0.003 / 0.003 | 0.003 / 0.003 |
| Cold start to first window, 20k-line doc (`launchmeasure`) | 1433 | 5113 | 5068 |
| Cold start to first window, small doc, Debug | 464 | 403 | 417 |
| Cold start to first window, small doc, Release | 615 | 368 | 403 |

## Functional

Headless workbench probes (same model code the UI binds to), 15 commands × 3 runs:

| Probe | R1 | R2 | R3 |
| :--- | :---: | :---: | :---: |
| `cmd_d_duplicate` | pass | pass | pass |
| `diff_toggle` | pass | pass | pass |
| `distraction_free` | pass | pass | pass |
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

Not covered in reduced mode: live menu/shortcut dispatch, drag-and-drop tab reorder, sheets and panels (no AX grant).

## Human Metrics

Keystroke-Level Model (K = 0.20 s per keystroke, P = 1.10 s point, H = 0.40 s home, M = 1.35 s mental; modifier chords count 2 K), Fitts index of difficulty ID = log2(D/W + 1) with D measured from the editor centre in a 1440 × 900 window.

| Task | Operators | KLM time | Clicks/keys | Notes |
| :--- | :--- | ---: | ---: | :--- |
| Zoom to 150 % | M + 5 × (Cmd++) | 3.35 s | 10 keys |  |
| Close a tab with the mouse | H + M + P + B | 3.05 s | 1 click | close glyph ≈ 9 × 9 pt → ID ≈ log2(620/9+1) = 6.1 bits (vs 4.8 bits at 24 pt) |
| Pin a tab with the mouse | H + M + P + B | 3.05 s | 1 click | pin glyph ≈ 10 × 10 pt |
| Go to a heading | M + ⌥\ + 4 K + ⏎ | 2.75 s | 7 keys |  |
| Change editor font | — | n/a | — | not possible before 017 (REQ-007) |
| Toggle preview | M + Cmd+P | 1.75 s | 2 keys |  |
| Format document | M + Cmd+Shift+F (3 K) | 1.95 s | 3 keys |  |

| Target | Size (pt) | WCAG 2.5.8 (≥ 24 pt or spacing) |
| :--- | :--- | :--- |
| Tab pin button | ≈ 10 × 10 (caption2 glyph, no frame) | fail |
| Tab move ◀ / ▶ buttons | ≈ 9 × 11 (9 pt glyph) | fail |
| Tab close × button | ≈ 9 × 9 (caption2 glyph) | fail |
| Sidebar rows | ≥ 24 (zoom-scaled font + padding) | pass |
| Header buttons | ≥ 24 | pass |

## Accessibility

WCAG 2.2 AA contrast of key token pairs (text needs ≥ 4.5:1):

| Pair | Ratio |
| :--- | ---: |
| `black.accent/canvas` | 3.69 ⚠ |
| `black.activeCtrlFg/activeCtrl` | 5.70 |
| `black.canvasText/canvas` | 21.00 |
| `black.chromeFg/chrome` | 16.84 |
| `black.chromeFg/sheet` | 16.84 |
| `black.chromeFg/sidebar` | 16.10 |
| `black.chromeFg/tabActive` | 17.69 |
| `black.chromeFg/tabBar` | 15.68 |
| `black.gutterFg/gutter` | 7.35 |
| `black.inertHTML/canvas` | 14.52 |
| `black.secondaryFg/canvas` | 11.38 |
| `black.secondaryFg/chrome` | 10.83 |
| `black.sidebarBinary/sidebar` | 7.53 |
| `black.statusFg/status` | 15.24 |
| `black.yamlKey/canvas` | 8.27 |
| `light.accent/canvas` | 5.70 |
| `light.activeCtrlFg/activeCtrl` | 5.70 |
| `light.canvasText/canvas` | 21.00 |
| `light.chromeFg/chrome` | 16.22 |
| `light.chromeFg/sheet` | 15.07 |
| `light.chromeFg/sidebar` | 14.15 |
| `light.chromeFg/tabActive` | 17.79 |
| `light.chromeFg/tabBar` | 13.07 |
| `light.gutterFg/gutter` | 8.19 |
| `light.inertHTML/canvas` | 10.02 |
| `light.secondaryFg/canvas` | 8.98 |
| `light.secondaryFg/chrome` | 8.19 |
| `light.sidebarBinary/sidebar` | 6.15 |
| `light.statusFg/status` | 5.70 |
| `light.yamlKey/canvas` | 4.83 |

Static AX scan of `Sources/SwiftEditUI/Views`: 11 icon-only `Button`s without `accessibilityLabel` (`.help` tooltips only), so VoiceOver announces raw SF Symbol names: `HeaderBrandSubmenuView.swift:188`, `MarkdownDiagnosticsPopoverView.swift:31`, `SwiftEditRootView.swift:2352, 2434, 2492, 2507, 2515, 2523, 2627, 2641, 2658`. Reduce Motion is honoured at 6 call sites; 34 keyboard shortcuts are registered in `SwiftEditCommands`.

## Findings

| ID | Severity | Title | Repro | Measured | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| F-017-01 | P1 | Gutter/TextKit enumerate and lay out the whole document when a large document is the active tab at window creation | Open a 20k-line doc, quit, relaunch opening it again (R2/R3) | 1.1–1.3 GB footprint, 5.1 s to first window, ~20k SwiftUI Text views | resolved: `f01GutterViewportMetricsAreBoundedForUnlaidLargeDocument` |
| F-017-02 | P2 | Black-mode link/accent text on the editor canvas is below WCAG AA | Black mode, a Markdown link in the editor | `primaryAccent` on `#000000` = 3.69:1 | resolved: `f02LinkForegroundMeetsContrastInBothModes` |
| F-017-03 | P2 | Tab strip pin, move and close buttons have glyph-sized hit targets | Tab bar at 100 % zoom | ≈ 9–11 pt targets (< 24 pt), Fitts ID 6.1 bits | resolved: `f03TabStripIconButtonsUseMinimumHitTarget` |
| F-017-04 | P2 | Icon-only buttons have no accessibility label | VoiceOver over tab, sidebar and header icon buttons | 11 buttons without `accessibilityLabel` | resolved: `f04IconOnlyButtonsHaveAccessibilityLabels` |
| F-017-05 | P3 | Preview projection runs on the main thread per revision | Preview open, type in a 20k-line doc | 7.1–7.3 ms p50 | backlog |
| F-017-06 | P3 | First font-family enumeration blocks | First `NSFontManager.availableFontFamilies` call | 30–98 ms p95 (first call) | backlog |
| F-017-07 | P3 | Whole-document linters re-run per revision | Type in 20k-line Markdown / YAML | 17.7 ms / 10.5 ms background | backlog |
| F-017-08 | P3 | Editor line index rebuilt per revision | Type in a 20k-line doc | 2.35 ms p50 main thread | backlog |
| F-017-09 | P3 | Cold start to first window above the UI-012 150 ms budget (measurement includes LaunchServices) | Launch with a small doc | 368–615 ms (Release), 403–464 ms (Debug) | backlog |
| F-017-10 | P3 | Large owned graphics footprint in Release | Launch with a small doc (Release) | 217 MB graphics of 273 MB footprint | backlog |

## Appendix: Reproduction

- Build: `./Scripts/build-app.sh --configuration Debug --clean --derived-data .tmp/DerivedData`
- Harness: `.tmp/qa-harness` (SwiftPM executable depending on the local package), `swift build -c release -Xswiftc -enable-testing`, run `QAHarness .tmp/qa-workspace` 3×
- Runtime: `.tmp/gui-driver/launchmeasure <App> <doc>` (NSWorkspace launch → first layer-0 on-screen window via `CGWindowListCopyWindowInfo`), then `sample <pid> 5`, `ps -o %cpu,rss`, `footprint`, `vmmap --summary`, `leaks`, `heap -s`
- Side effect: the app's own container (recent files, SessionRecovery) received the synthetic fixture paths; no user documents were opened.
