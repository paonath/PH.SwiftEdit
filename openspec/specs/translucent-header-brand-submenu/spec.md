# Capability: translucent-header-brand-submenu

## Purpose
Replaces hover dwell and auto-close timers in `HeaderSubmenuStateMachine` and `HeaderBrandSubmenuView` with click-and-keyboard-only sticky activation, full arrow/Escape accessibility navigation, exact header/backdrop geometry alignment, and Opt+Cmd+F shortcut badge parity (`BUG-006`, `PERF-004`).

## Requirements

### Requirement: REQ-001 Click-and-Keyboard-Only Translucent Header Submenu With Zero Hover Auto-Open and Zero Layout Shift
WHEN the user clicks the header brand trigger or activates it via keyboard or VoiceOver, the header submenu controller SHALL toggle open in `0 ms` and persist until outside click, trigger re-click, item click, `Escape`, or window resign-key, support arrow navigation, emit zero hover auto-open or 20 ms polling tasks, and keep `0.0 pt` shift [TEST-004][UI-001][UI-003][UI-009][UI-010][UI-011][UI-012].

#### Scenario: N1 Sub-120ms Pass-Through Active Drag or Escape Latch Suppresses Submenu Opening
- **Path**: N1
- **Trait**: negative
- **GIVEN** a `HeaderSubmenuStateMachine` experiencing a `90 ms` pointer pass-through, an active tab/sidebar drag, or an `Escape` keypress while open over the brand trigger
- **WHEN** dwell ticks advance during each condition
- **THEN** the `90 ms` pass-through and active drag never open the submenu, and `Escape` closes the submenu immediately while latching `isSuppressedUntilPointerExit == true` until the pointer exits and re-enters or an explicit click occurs

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

#### Scenario: P2 Descriptive Badges Default-Off Cmd+P Preview and Single-Revision Format Section
- **Path**: P2
- **Trait**: positive
- **GIVEN** a newly initialized `SwiftEditWorkbenchModel` containing `"#BadHeading\n\n#Untouched"` with selection covering line `1`
- **WHEN** `HeaderCommandCatalog.items(for:)` is evaluated, `toggleMarkdownPreview()` runs (`Cmd+P`), and `formatActiveSection()` runs (`⌥⇧⌘F`)
- **THEN** initial `showMarkdownPreview` is `false` before toggling to `true`, catalog items include `"Duplicate Line or Selection"` (`"⌘D"`), `"Format Markdown Document"` (`"⇧⌘F"`), `"Format Markdown Section"` (`"⌥⇧⌘F"`), and `"Hide Markdown Preview"` (`"⌘P"`), line `1` becomes `"# BadHeading"` while line `3` stays `"#Untouched"` in `+1` `BufferRevision`, and `scanSwiftEditUIViewsDirectory` reports zero violations (`P3`)

#### Scenario: N3 Format Section on Degraded or Out-of-Range Selection Preserves Buffer Safely
- **Path**: N3
- **Trait**: negative
- **GIVEN** an active degraded plain-text snapshot (`isDegradedPlainText == true`) or an already-formatted Markdown section
- **WHEN** `formatActiveSection()` executes
- **THEN** buffer text remains unchanged without throwing and a non-destructive status message is recorded

#### Scenario: P4 Click-Only Header Submenu Dispatches Preview and Format Commands With Badge Parity
- **Path**: P4
- **Trait**: positive
- **GIVEN** an open click-activated `HeaderBrandSubmenuView` over a Markdown tab after `1000 ms` delay
- **WHEN** the user moves pointer down to `"Show Markdown Preview"` and clicks it, and audits shortcut sources
- **THEN** the submenu remains open until clicked (never auto-dismissed at `180 ms`), lists no File Compare entry (moved to `Shift+Cmd+D`, spec 020), and `scanSwiftEditUIViewsDirectory` reports zero duplicate shortcuts or polling loops

### Requirement: REQ-003 Synchronized Binary Quarantine Lockouts Across Submenu Menu Bar and Workbench
IF the active document is binary read-only (`isBinaryReadOnly == true`), THEN `HeaderCommandCatalog`, `SwiftEditCommands`, and `SwiftEditWorkbenchModel` SHALL disable and reject `Save Document`, `Save Document As…`, `Duplicate Line or Selection`, `Format Markdown Document`, and `Format Markdown Section` without mutating `BufferRevision` or opening `NSSavePanel` [DATA-003][SEC-004][SEC-012][UI-008].

#### Scenario: P3 Regular Editable Markdown Tab Enables Mutating Submenu and Menu Commands
- **Path**: P3
- **Trait**: positive
- **GIVEN** a `SwiftEditWorkbenchModel` whose active tab is a non-binary UTF-8 Markdown document (`canSave == true`, `canFormat == true`)
- **WHEN** `HeaderCommandCatalog.items(for:)` is evaluated and `HeaderBrandSubmenuView` / `SwiftEditCommands` sources are audited by `scanSwiftEditUIViewsDirectory`
- **THEN** `Save Document`, `Save Document As…`, `Duplicate Line or Selection`, `Format Markdown Document`, and `Format Markdown Section` all report `isEnabled == true` and `scanSwiftEditUIViewsDirectory` reports zero violations

#### Scenario: N2 Binary Read-Only Tab Disables and Blocks Save Save-As Duplicate and Format Commands
- **Path**: N2
- **Trait**: security
- **GIVEN** a `SwiftEditWorkbenchModel` whose active tab is a quarantined NUL-bearing binary snapshot (`canSave == false`, `canFormat == false`)
- **WHEN** `HeaderCommandCatalog.items(for:)` is inspected and `saveActiveDocument()`, `saveActiveDocumentAsViaPanel()`, `performCommandD()`, `formatActiveDocument()`, and `formatActiveSection()` are invoked
- **THEN** all five mutating commands report `isEnabled == false` in the catalog while non-mutating commands (`New Document`, `Open File…`, `Keyboard Shortcuts CheatSheet`) remain enabled, and all five workbench methods fail closed with zero `BufferRevision` change and zero save-panel invocations
