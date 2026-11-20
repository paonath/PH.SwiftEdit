# Capability: translucent-header-brand-submenu

## Purpose
Establishes the root-`ZStack` translucent `HeaderBrandSubmenuView` governed by `HeaderSubmenuStateMachine` (`120 ms` hover dwell, `180 ms` exit grace, `Escape` suppression latch, `0.0 pt` layout shift), replaces cryptic header buttons with descriptive verb-noun `HeaderCommandCatalog` items and shortcut badges, centralizes keyboard shortcuts in `SwiftEditCommands` (`Cmd+P` default-OFF preview, `⌥⇧⌘F` format section), and enforces synchronized binary quarantine command lockouts.

## Requirements

### Requirement: REQ-001 Dwell-Gated Root-ZStack Header Submenu With Zero Layout Shift
WHEN the pointer hovers, exits, clicks, or presses `Escape` across the `36 pt` header or translucent submenu, `HeaderSubmenuStateMachine` and `HeaderBrandSubmenuView` SHALL open after `120 ms` continuous dwell (`0 ms` on click toggle), bridge `180 ms` travel, latch closed on `Escape` or active drag, clamp `submenuTranslucentSurface` alpha under accessibility flags, and keep `0.0 pt` vertical displacement [TEST-004][UI-001][UI-003][UI-010][UI-011][UI-012].

#### Scenario: P1 Intentional 120ms Dwell Click Toggle and 180ms Travel Keep Submenu Open With Zero Shift
- **Path**: P1
- **Trait**: positive
- **GIVEN** a closed `HeaderSubmenuStateMachine` with `topBarHeight == 36.0` and isolated trailing Zoom and Appearance controls
- **WHEN** the pointer enters the brand header region for `120 ms`, exits toward the submenu and enters the submenu within `180 ms`, and trailing Zoom/Appearance regions receive hover events while closed
- **THEN** the submenu opens at `120 ms`, remains open across the `<= 180 ms` gap, ignores trailing-control hover when closed, supports instant `0 ms` click toggle, and keeps `topBarHeight == 36.0` (`0.0 pt` editor shift)

#### Scenario: N1 Sub-120ms Pass-Through Active Drag or Escape Latch Suppresses Submenu Opening
- **Path**: N1
- **Trait**: negative
- **GIVEN** a `HeaderSubmenuStateMachine` experiencing a `90 ms` pointer pass-through, an active tab/sidebar drag, or an `Escape` keypress while open over the brand trigger
- **WHEN** dwell ticks advance during each condition
- **THEN** the `90 ms` pass-through and active drag never open the submenu, and `Escape` closes the submenu immediately while latching `isSuppressedUntilPointerExit == true` until the pointer exits and re-enters or an explicit click occurs

### Requirement: REQ-002 Descriptive Verb-Noun Command Catalog Format Section and Single-Source Shortcuts
The `HeaderCommandCatalog`, `SwiftEditCommands`, and `SwiftEditWorkbenchModel` SHALL expose descriptive verb-noun command titles with shortcut badges, default `showMarkdownPreview` to `false` toggled in-memory via `Cmd+P` (`CommandGroup(replacing: .printItem)`), format selected Markdown sections via `⌥⇧⌘F` in one `BufferRevision` step, and omit duplicate `.keyboardShortcut` modifiers from header views [AR-006][AR-008][BC-004][BC-006][SEC-004][TEST-006][UI-009][UI-010].

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
