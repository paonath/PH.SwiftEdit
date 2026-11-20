# Spec Delta: editor-ux-highlighting-sidebar-pin-tabs-and-about

## Purpose
Updates `REQ-006` from `120 ms` dwell header submenu opening to click/keyboard-only activation while aligning `REQ-007`'s About fallback version string to `"0.0.1-alpha5"` and preserving all sidebar confinement, theme, and external HTTPS confirmation security checks.

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-006 Percentage-Based Collapsible Pinned Sidebar Hover Topbar and Confined Right-Click Create
WHEN laying out the left sidebar, interacting with the top bar brand region, or right-clicking the sidebar to create a file or folder, the workbench SHALL size sidebar width as `0.12...0.65` of container width, support manual pin/collapse, toggle `HeaderBrandSubmenuView` solely via click or keyboard, keep Logo, Zoom, and Theme visible, and validate prompted creation names inside scope [BC-012][SEC-003][SEC-012][UI-001][UI-005][UI-011].

Security-Waiver: replaces dwell-hover trigger in P9/N12 with click/keyboard-only submenu activation (`BUG-006`, `PERF-004`) while preserving `P6`, `N8`, and `N9` traversal/symlink confinement without lowering security checks.

- **REMOVED-SCENARIO**: `P9 Proportional Sidebar Width Pin Collapse Dwell Header Submenu and Empty-Area Right-Click Create` — **Reason**: Dwell-hover submenu opening is disabled per `BUG-006` click/keyboard-only UX resolution; replaced by `P10`.
- **REMOVED-SCENARIO**: `N12 Active Sidebar Divider Drag Blocks Submenu Hover Opening` — **Reason**: Hover opening is disabled entirely; replaced by `N13` asserting neither hover nor drag opens the submenu.

#### Scenario: P10 Proportional Sidebar Width Pin Collapse Click Header Submenu and Empty-Area Create
- **Path**: P10
- **Trait**: positive
- **GIVEN** `SidebarLayoutGeometry` across `1200pt` and `2560pt` widths, an expanded pinned sidebar, `HeaderSubmenuStateMachine`, and a mounted workspace folder
- **WHEN** `sidebarWidthRatio` updates to `0.40`, `toggleSidebarPinCollapse()` runs, `clickToggle()` activates the brand button, and `sidebarCreateFile(named: "new.md", in:)` runs
- **THEN** computed widths scale to `480pt` and `1024pt`, unpinning collapses the sidebar, `HeaderBrandSubmenuView` stays persistently open past `1000 ms` with `0.0 pt` shift, and `"new.md"` is created inside scope

#### Scenario: N13 Pointer Hover and Active Sidebar Divider Drag Never Open Submenu
- **Path**: N13
- **Trait**: negative
- **GIVEN** a `SwiftEditWorkbenchModel` during normal pointer hover over the brand header or an active sidebar divider drag (`isDraggingTabOrSidebar == true`)
- **WHEN** hover ticks and drag events run without a click or keyboard activation
- **THEN** `HeaderSubmenuStateMachine.isOpen` remains `false` and sidebar ratio clamping (`0.12...0.65`) operates uninterrupted

### Requirement: REQ-007 Concept E2 Vector Brand Logo and Help About Dialog With Validated Repo and License Links
WHEN rendering the top bar brand header or opening `Help -> About PH.SwiftEdit`, the UI shell SHALL display the Concept E2 vector logo small beside `PH.SwiftEdit` and large inside the About dialog alongside App Name, `nbgv` version (fallback `"0.0.1-alpha5"`), validated GitHub repo link, and validated MIT License link [AR-014][SEC-004][UI-001][UI-008][UI-010].

Security-Waiver: aligns stale `"0.0.1-alpha3"` fallback string to current `"0.0.1-alpha5"` manifest version (`BUG-018`) while keeping `P7` and `N10` non-HTTPS / JavaScript URI rejection intact.

#### Scenario: P11 AboutSheetDescriptor Fallback Matches Bundle Version Alpha5 When Manifest Absent
- **Path**: P11
- **Trait**: positive
- **GIVEN** a `nil` bundle resource and missing `CFBundleShortVersionString` in `AboutSheetDescriptor.resolve(versionManifestData: nil)`
- **WHEN** `AboutSheetDescriptor` resolves its deterministic version fallback
- **THEN** the resolved fallback string equals `"0.0.1-alpha5"` instead of stale `"0.0.1-alpha3"`, and official GitHub HTTPS repo and MIT License prompts remain valid

## REMOVED Requirements

## RENAMED Requirements
