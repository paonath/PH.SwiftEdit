# Spec Delta: ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions

## Purpose
Updates `REQ-004` of `ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions` to replace inline horizontal top-bar hover buttons with the root-`ZStack` translucent `HeaderBrandSubmenuView`, add `Cmd+P` (`Toggle Markdown Preview`) and `Cmd+Option+Shift+F` (`Format Markdown Section`) to `KeyboardShortcutsCheatSheetCatalog`, and enforce binary quarantine command lockouts across `SwiftEditCommands` while preserving all HTTPS external-link guards.

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-004 Classic FocusedValue Menus Graphical CheatSheet and Guarded About Dialog
WHEN rendering the header, opening `HeaderBrandSubmenuView`, invoking `SwiftEditCommands`, or opening `About PH.SwiftEdit`, the UI shell SHALL show the Concept E2 logo with a dwell-gated translucent submenu, isolate Zoom and Appearance on the right, list `Cmd+P` and `Cmd+Option+Shift+F` in the CheatSheet, disable mutating commands on binary tabs, and guard external About links [AR-014][DATA-003][SEC-004][UI-001][UI-008][UI-009][UI-010][UI-011].

Security-Waiver: replaces inline horizontal top-bar hover buttons in REQ-004 (removing obsolete scenario P7) with the dwell-gated HeaderBrandSubmenuView and centralized SwiftEditCommands while preserving scenarios P4, N5, and N9 intact and strengthening binary quarantine mediation via N11.

- **REMOVED-SCENARIO**: `P7 Hover-Revealed Topbar Concept E2 Logo Help About Entry and Validated License Link` — **Reason**: Superseded by P9 which replaces horizontal middle hover buttons with root-ZStack HeaderBrandSubmenuView while preserving Concept E2 logo, Help -> About, and HTTPS repo/license link checks.

#### Scenario: P9 Brand Header Translucent Submenu Updated CheatSheet and Validated About Links
- **Path**: P9
- **Trait**: positive
- **GIVEN** `SwiftEditWorkbenchModel`, `HeaderCommandCatalog`, `KeyboardShortcutsCheatSheetCatalog.allSections`, and `AboutSheetDescriptor.resolve(versionManifestData:)`
- **WHEN** the brand header dwell completes (`120 ms`), the CheatSheet catalog is inspected, and `AboutSheetDescriptor` validates repository and MIT License links
- **THEN** `HeaderBrandSubmenuView` opens with descriptive titles and badges while Zoom and Appearance stay isolated on the right, the CheatSheet includes `Cmd+Option+Shift+F` (`Format Markdown Section`) and `Cmd+P` (`Toggle Markdown Preview`), and both official GitHub HTTPS URLs produce valid confirmation prompts

#### Scenario: N11 Binary Tab Disables Duplicate Save and Format Entries in Command Descriptors
- **Path**: N11
- **Trait**: security
- **GIVEN** an active binary read-only tab (`safetyBanner.canSave == false`, `safetyBanner.canFormat == false`)
- **WHEN** command enablement state is evaluated for `Save`, `Save As…`, `Duplicate Line or Selection`, `Format Markdown Document`, and `Format Markdown Section`
- **THEN** all five mutating commands resolve as disabled while read-only navigation and inspection commands remain enabled

## REMOVED Requirements

## RENAMED Requirements
