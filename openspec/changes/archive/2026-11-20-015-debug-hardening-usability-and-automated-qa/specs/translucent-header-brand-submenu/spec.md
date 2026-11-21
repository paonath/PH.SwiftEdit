# Spec Delta: translucent-header-brand-submenu

## Purpose
Replaces hover dwell and auto-close timers in `HeaderSubmenuStateMachine` and `HeaderBrandSubmenuView` with click-and-keyboard-only sticky activation, full arrow/Escape accessibility navigation, exact header/backdrop geometry alignment, and Opt+Cmd+F shortcut badge parity (`BUG-006`, `PERF-004`).

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-001 Click-and-Keyboard-Only Translucent Header Submenu With Zero Hover Auto-Open and Zero Layout Shift
WHEN the user clicks the header brand trigger or activates it via keyboard or VoiceOver, the header submenu controller SHALL toggle open in `0 ms` and persist until outside click, trigger re-click, item click, `Escape`, or window resign-key, support arrow navigation, emit zero hover auto-open or 20 ms polling tasks, and keep `0.0 pt` shift [TEST-004][UI-001][UI-003][UI-009][UI-010][UI-011][UI-012].

Security-Waiver: replaces dwell-gated hover auto-open and 180 ms exit grace in REQ-001 (superseding legacy P1 and N1 hover-timer scenarios per UX accessibility decision and BUG-006/PERF-004) with deterministic click/keyboard-only WCAG 2.2 SC 1.4.13 persistence while retaining Reduce Transparency opaque clamping, zero layout shift, and command lockout invariants intact.

- **REMOVED-SCENARIO**: `P1 Intentional 120ms Dwell Click Toggle and 180ms Travel Keep Submenu Open With Zero Shift` — **Reason**: Superseded by P1 Click-and-Keyboard-Only Sticky Persistence eliminating accidental hover open and premature 180ms auto-dismiss (`BUG-006`, `PERF-004`).
- **REMOVED-SCENARIO**: `N1 Sub-120ms Pass-Through Active Drag or Escape Latch Suppresses Submenu Opening` — **Reason**: Superseded by N1 Hover Never Opens or Closes Submenu and Explicit Dismiss Locks Closed cleanly without dwell/grace polling timers.

#### Scenario: P1 Click-and-Keyboard-Only Sticky Submenu Arrow Navigation and Zero Layout Shift
- **Path**: P1
- **Trait**: positive
- **GIVEN** a closed `HeaderSubmenuStateMachine` over `toolbarBar` whose rendered height equals `topBarHeight` and click-outside backdrop positioned strictly below `topBarHeight`
- **WHEN** `clickToggle()` activates, `1000 ms` elapse while the pointer moves off the trigger across trailing controls, `↓`/`↑`/`Home`/`End` navigate items, and `Return` activates the focused item
- **THEN** `isOpen` stays `true` past `1000 ms`, row focus/hover styling and VoiceOver `Expanded`/`Collapsed` traits update accurately, `topBarHeight` causes `0.0 pt` vertical shift, and item activation runs once and closes the menu

#### Scenario: N1 Prolonged Hover Never Opens or Auto-Closes Submenu While Esc and Outside Click Dismiss
- **Path**: N1
- **Trait**: negative
- **GIVEN** a closed `HeaderSubmenuStateMachine` receiving `700 ms` continuous hover over the brand trigger or trailing controls, and subsequently an open state receiving `Escape`, outside click, or window resign-key
- **WHEN** pointer hover enters/exits without clicking, then `clickToggle()` opens the menu and `escapePressed()` or click-outside dismiss triggers
- **THEN** hover alone never opens the menu, moving off an opened menu never auto-closes it, zero 20 ms `.task` polling loops run, and `Escape`/outside-click/resign-key closes immediately

### Requirement: REQ-002 Descriptive Verb-Noun Command Catalog Format Section and Single-Source Shortcuts
The header command catalog SHALL expose descriptive verb-noun command titles with shortcut badges, align `Find and Replace…` on `Opt+Cmd+F`, default `showMarkdownPreview` to `false` via `Cmd+P`, format Markdown sections via `⌥⇧⌘F` in one `BufferRevision`, and keep Views free of `.keyboardShortcut` duplicates [AR-006][AR-008][BC-004][BC-006][SEC-004][TEST-006][UI-009][UI-010].

Security-Waiver: preserves single-source shortcut isolation, offline SEC-004 confinement, and existing scenarios P2 and N3 while adding explicit Opt+Cmd+F alignment and click-only command execution parity via P4.

#### Scenario: P4 Click-Only Header Submenu Dispatches Diff and Format Commands With Badge Parity
- **Path**: P4
- **Trait**: positive
- **GIVEN** an open click-activated `HeaderBrandSubmenuView` over a Markdown tab after `1000 ms` delay
- **WHEN** the user moves pointer down to `"Show File Compare Diff"` (`toggleDiffPane`) and clicks it, and audits shortcut sources
- **THEN** `"Show File Compare Diff"` remains open until clicked (never auto-dismissed at `180 ms`), `showDiffPane` toggles `true`, and `scanSwiftEditUIViewsDirectory` reports zero duplicate shortcuts or polling loops

## REMOVED Requirements

## RENAMED Requirements
- FROM: `### Requirement: REQ-001 Dwell-Gated Root-ZStack Header Submenu With Zero Layout Shift`
- TO: `### Requirement: REQ-001 Click-and-Keyboard-Only Translucent Header Submenu With Zero Hover Auto-Open and Zero Layout Shift`
