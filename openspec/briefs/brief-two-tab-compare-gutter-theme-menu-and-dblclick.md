---
id: "brief-two-tab-compare-gutter-theme-menu-and-dblclick"
change_id: "022-two-tab-compare-gutter-theme-menu-and-dblclick"
capability: "two-tab-compare-gutter-theme-menu-and-dblclick"
branch: "feature/contaxtual_actions"
mode: "myspec-quick"
modifies_specs: "integrations-autocomplete-contextual-menu-and-redesign-plan"
status: "implemented"
date: "2026-11-23"
---

# Quick Brief: Two-Tab Compare, Grey Gutter, Theme Menu, Palette Outside Click, Double-Click Cycle

## 1. Disambiguated Prompt

1. **Compare**: `Shift+Cmd+D` opens Compare on the active tab (source, left); the header picker "Compare with" lists the saved version and other open text tabs; the X drops only the destination and returns to saved vs current; a closed destination is cleared automatically.
2. **Gutter**: editor gutter only; grey surface (`#F1F0F4` Light, `#121117` Black), numbers at 85% of the zoomed editor size, baseline-aligned; dark numbers lightened to `#8A8597` to keep 4.5:1.
3. **Theme**: Light, Dark, Auto (System) in the SwiftEdit menu with a check; the status-bar toggle stays.
4. **Palette**: a full-window transparent catcher below the palette closes it like Esc on any outside click.
5. **Double-click**: word -> whitespace-free token (leading brackets/quotes and trailing brackets/quotes/punctuation trimmed) -> no selection; a word equal to its token deselects on the second double-click.

## 2. QA Decision Log

| Item | Decision |
| :--- | :--- |
| Destination selection | Picker in the Compare header (Recommended) |
| Line-number column | Editor gutter only (user choice) |
| Token boundary | Whitespace-free token with trimming (Recommended) |
| Theme placement | Menu items added, status-bar toggle kept (default) |

## 3. STRIDE

| Category | Threat | Mitigation |
| :--- | :--- | :--- |
| Spoofing | Destination picker listing hidden or binary content | Only open non-binary, non-tail tabs; never the source |
| Tampering | Compare or double-click editing text | Both are read-only projections; selection changes only |
| Repudiation | Silent destination swap | Header always names source and destination |
| Information Disclosure | Diff of a closed tab lingering | Closed destinations are cleared on the next refresh |
| Denial of Service | Huge token scans on minified lines | Token expansion capped at 4096 UTF-16 units; diff keeps the existing Myers budget |
| Elevation of Privilege | New entitlements or processes | None |

- Security Review: approved

## 4. Verification (P/N)

- `Integrations022Tests`: P-CMP1, P-CMP2, N-CMP1, P-GUT2, P-MENU1, P-CTX1, P-DBL1, N-DBL1, P-DBL2.
- Contrast audit extended to the new gutter surface (Light and Black).
- Visual: snapshot 17 (two-tab Compare), updated 01/04/16 in Light and Dark.
- Totals: full suite 388/388 green.

## Metadata
- Branch: feature/contaxtual_actions
