---
id: "brief-integrations-autocomplete-contextual-menu-and-redesign-plan"
change_id: "020-integrations-autocomplete-contextual-menu-and-redesign-plan"
capability: "integrations-autocomplete-contextual-menu-and-redesign-plan"
branch: "feature/contaxtual_actions"
mode: "myspec-quick"
modifies_specs: "translucent-header-brand-submenu, yaml-native-support-frontmatter-properties-and-perf, editor-ux-highlighting-sidebar-pin-tabs-and-about, constitution-v1-3-governance-and-fitness"
status: "implemented"
date: "2026-11-23"
---

# Quick Brief: Word Completion, Collapsed Properties, Compare Shortcut, ElementContextualMenu, Literal Occurrences and Redesign Plan

## 1. Disambiguated Prompt

1. **Word completion (ghost text)**:
   - in-memory per-document `WordCompletionIndex` (words of 4...64 UTF-16 units, sorted unique words + frequencies, one linear scalar pass, no regex, never persisted);
   - rebuilt off the main actor 350 ms after the last edit, excluding the word under the caret; lookup = binary search + at most 512 candidates;
   - ranking: frequency, then shorter word, then alphabetical; case-sensitive; prefix of at least 2 units;
   - grey inline suffix after the caret only right after a typed character; `Tab` accepts (one undoable insert), `Esc`/any other key/caret move dismisses; with no suggestion `Tab` keeps list/table/default behaviour; every file type; disabled for binary, degraded and log-tail views.
2. **YAML Properties panel** collapsed by default (`PropertiesPanelState.isCollapsed = true`).
3. **File Compare**: removed from the header quick menu; `Shift+Cmd+D` in the View menu, shortcut dispatcher and CheatSheet.
4. **ElementContextualMenu** (`Cmd+Return` with a selection):
   - SwiftUI palette anchored under the selection (filter field, expandable group headers with count, action rows with icon/title/preview), full keyboard navigation (Up/Down, Right/Left expand/collapse, Return, Esc) and VoiceOver labels;
   - declarative registry `ElementContextualActionCatalog.groups` -> `ElementContextualActionGroup` -> `ElementContextualAction` (`ElementContextualActionKind`), so new sub-menus are one new group;
   - "Surround With...": backticks, code fence (fences on their own lines), parentheses; one `TextEdit` per action, inner text stays selected;
   - without a selection `Cmd+Return` is not consumed; Edit menu item "Contextual Actions...".
5. **Smart occurrence highlighting** (root cause): the pipeline worked for whole words only; any other selection (partial word, `->`, groups with inner spaces) was rejected by `WordOccurrenceScanner`. Now: whole word -> whole-word matches; any other single-line, non-blank group -> case-sensitive literal matches excluding overlaps with the selection; multi-line and whitespace-only selections highlight nothing.
6. **Redesign (plan only)**: offscreen visual audit harness `VisualAuditSnapshotTests` (opt-in via `SWIFTEDIT_VISUAL_AUDIT_DIR`), 12 Light/Dark snapshots, Zed-inspired mockups (SVG + PNG), icon-system comparison and phased plan in `docs/design/redesign-020/analisi-e-piano.md`.

## 2. QA Decision Log

| Item | Decision |
| :--- | :--- |
| Completion presentation and `Tab` conflict | Ghost text inline; `Tab` accepts only when a suggestion is visible (Recommended) |
| ElementContextualMenu technology | SwiftUI palette popover (user choice over native `NSMenu`) |
| Occurrence matching | Exact, case-sensitive; whole word for words, literal for character groups (Recommended) |
| Redesign scope | Analysis + mockups + plan; no graphic implementation now (Recommended) |
| Defaults applied | Triple backtick = fenced block on own lines; prefix >= 2; all file types |

## 3. STRIDE

| Category | Threat | Mitigation |
| :--- | :--- | :--- |
| Spoofing | Palette labels or previews rendering document content as markup | All palette strings are static catalog text via `Text(verbatim:)`; document text never shown (`SEC-012`) |
| Tampering | Surround applied to a stale or binary buffer | Revision-checked `applyTextEdits`, binary/degraded/log-tail guards, `canSave` gate, bounds checks (`CWE-20`) |
| Repudiation | Silent edits | Every accept/surround is one `BufferRevision` and one undo step; failures surface in the status banner |
| Information Disclosure | Word cache leaking document vocabulary | Cache lives only in memory for the open document, never persisted or logged |
| Denial of Service | Huge documents or pathological selections | Index capped at 8 Mi UTF-16 units and 64-unit words, debounced background build, bounded lookup (512), literal scan capped at 1000 matches, selection <= 1 MiB (`CWE-400`) |
| Elevation of Privilege | New entitlements or processes | None added; no network, subprocess or file access (`SEC-001`, `SEC-004` unchanged) |

- Security Review: approved

## 4. Verification (P/N)

- **Word completion**: P-WC1 ranking and >3-char filter; P-WC2 accented prefix detection; P-WC3 workbench suggestions with caret-word exclusion; N-WC1 short prefix, mid-word caret, excluded word, empty doc; P-GHOST ghost shown after third typed char, `Tab` inserts, `Esc` dismisses, `Tab` without suggestion falls through.
- **Properties/Compare**: P-PROP collapsed default; Compare absent from header items, `Shift+Cmd+D` toggles diff, CheatSheet entry.
- **ElementContextualMenu**: P-SUR1 backtick/parentheses/fence (mid-line and whole-line); N-SUR1 empty, out-of-bounds, binary; P-ECM1 state navigation, filter, collapse; P-ECM2 `Cmd+Return` -> Return applies one revision with inner selection; N-ECM1 no selection not consumed, Esc restores selection without edits.
- **Occurrences**: P-OCC1 whole words unchanged; P-OCC3 partial word, `->`, inner-space groups; N-OCC1 single char, whitespace-only, multi-line, binary.
- **Visual audit**: 12 snapshots (Light/Dark x 6 states) rendered; contextual palette verified in both modes.
- **Totals**: full suite 365/365 green, `swift build` clean, typography fitness clean, secret scan clean.

## 5. Spec Deltas

- `translucent-header-brand-submenu`: header submenu no longer lists File Compare; `HeaderCommandCatalog.items(canSave:canFormat:showMarkdownPreview:)`.
- `yaml-native-support-frontmatter-properties-and-perf`: Properties panel starts collapsed.
- `editor-ux-highlighting-sidebar-pin-tabs-and-about`: occurrence highlighting extended to literal character groups.

## Metadata
- Branch: feature/contaxtual_actions

## 6. Redesign Integration (2026-11-23, follow-up)

- **Request**: integrate every V-01..V-03 and R-01..R-10 correction plus the icon set; logo must not change.
- **Constitution**: v1.7.0 MINOR amendment of `UI-001` (Zed-neutral chrome, Purple accents only, in-code `AppIcon` line set, unchanged Concept E2 logo); validator expects `1.7.0` and a `UI-001` Sync Impact row.
- **Icons**: `Sources/SwiftEditUI/Theme/AppIcons.swift`, 50 original line icons on a 24-unit grid, no assets or third-party licence; all 43 SF Symbols replaced; Core actions use semantic `iconName`.
- **Chrome**: neutral header/status bar/tab strip/sidebar tokens, new `accentSoftSurface`, neutral high-contrast hairline (Reduce Transparency no longer paints purple borders), dark inline-code tokens.
- **Layout**: header breadcrumb + icon cluster; zoom menu and Light/Dark/Auto toggle in the status bar; left rail removed; flat tabs; gutter diagnostics column; compact Properties disclosure; `PREVIEW` label; sidebar empty state; soft header-menu highlight; Find bar icon navigation; Navigator restyled.
- **Bugs**: V-01 lint label is plain text; V-02 gutter column; V-03 confirmed false positive (menu occlusion); CheatSheet Close Document fixed to `Shift+Cmd+W`, Word Wrap `Cmd+W` added.
- **Rule G3**: `REQ-005` left unmodified (merger flagged it); harness extension recorded as `REQ-006` scenario P7; no Security-Waiver synthesized.
- **STRIDE delta**: no new data flows, entitlements, processes or network; Information Disclosure unchanged (breadcrumb shows only names already visible in tabs/sidebar).
- **Verification**: full suite 370/370 green, Debug app build succeeded, 26 Light/Dark snapshots in `docs/design/redesign-020/after/`.

