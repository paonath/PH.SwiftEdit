---
id: "brief-bundle-size-header-shortcuts-panel-and-duplicate"
change_id: "021-bundle-size-header-shortcuts-panel-and-duplicate"
capability: "bundle-size-header-shortcuts-panel-and-duplicate"
branch: "feature/contaxtual_actions"
mode: "direct-follow-up"
modifies_specs: "integrations-autocomplete-contextual-menu-and-redesign-plan"
status: "implemented"
date: "2026-11-23"
---

# Brief: Compact Bundles, Header Layout and Zoom, Shortcuts Panel, Duplicate Document

## 1. Request

1. Shrink the app bundle, Debug included.
2. Move the header command icons next to the SwiftEdit menu; move the document title to the right.
3. Scale header icons and the SwiftEdit menu with the editor zoom.
4. Offer the keyboard shortcuts as a right side panel too; add a top search (function, description, shortcut) with row highlight to both; make shortcuts clickable.
5. Open the contextual menu without a selection; add Duplicate Document (in memory only when the source is in memory).

## 2. Decisions

| Item | Decision |
| :--- | :--- |
| Debug size | Xcode Debug: dead-strip + symbols in dSYM (debugger unchanged); `build-app.sh` Debug defaults to compact `-Osize` in `.build/xcode-compact`, `--debuggable` restores `-Onone` |
| Code refactor | Measured per module: SwiftTerm is 40% of Debug code; optimisation level, not source refactor, is the dominant lever |
| Header | Logo menu, icon cluster, spacer, breadcrumb; all sizes from `ZoomedChromeMetrics` (24 pt target floor) |
| Shortcuts | Shared `ShortcutsCatalogList`; `CheatSheetCommand` per row; text actions sent to the editor `NSTextView`; sheet runs the command after closing; `Option+Cmd+/` toggles the panel |
| Duplicate | `name copy.ext`, `name copy N.ext`, never overwrite; current buffer content; confined atomic `DocumentLoader.save`; new tab right after the source; untitled stays in memory |

## 3. STRIDE

| Category | Threat | Mitigation |
| :--- | :--- | :--- |
| Spoofing | Copy name crafted to escape the folder | Only the last component changes and derives from the source name; same parent folder |
| Tampering | Duplicate overwrites an existing file | Free-name search plus a final existence check; `fileWriteFileExists` aborts |
| Repudiation | Silent clicks in the shortcuts list | Every run goes through the same model commands as keyboard shortcuts; status banner on failures |
| Information Disclosure | Duplicating a binary shown in inspection | Refused while a binary inspection, binary tab or live tail is active |
| Denial of Service | Unbounded copy-name search | Capped at 999 attempts |
| Elevation of Privilege | Clicked rows bypassing quarantine gates | Save/Format/Duplicate keep `canSave`/`canFormat` checks; no new entitlements or processes |

- Security Review: approved

## 4. Verification

- Bundle: Debug 25 MB to 13 MB with `-Onone` (symbols 13.3 MB to 1.0 MB) and 7.5 MB compact; Release 6.9 MB.
- Tests: full suite 379/379 green; new `Integrations021Tests` (naming, file and memory duplicate, no overwrite, binary refusal, palette action, search, clickable commands, panel shortcut, header zoom, header order).
- Visual: new snapshots 14 (shortcuts panel), 15 (palette without selection), 16 (150% header and menu) in Light and Dark.

## Metadata
- Branch: feature/contaxtual_actions
