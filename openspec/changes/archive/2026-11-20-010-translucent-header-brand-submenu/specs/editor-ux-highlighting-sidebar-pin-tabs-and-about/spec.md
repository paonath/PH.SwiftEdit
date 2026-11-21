# Spec Delta: editor-ux-highlighting-sidebar-pin-tabs-and-about

## Purpose
Updates `REQ-006` of `editor-ux-highlighting-sidebar-pin-tabs-and-about` to replace inline `isToolbarHovered` horizontal top-bar buttons with the `120 ms`-dwell / `180 ms`-grace / `Escape`-latched `HeaderBrandSubmenuView` while keeping percentage-only sidebar resizing (`12%..65%`), manual `pin` collapse, and confined right-click file/folder creation intact.

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-006 Percentage-Based Collapsible Pinned Sidebar Hover Topbar and Confined Right-Click Create
WHEN laying out the left sidebar, interacting with the top bar brand region, or right-clicking the sidebar to create a file or folder, the workbench SHALL size sidebar width strictly as a clamped percentage ratio (`0.12...0.65`) of container width, support manual pin/collapse, gate `HeaderBrandSubmenuView` via `120 ms` dwell while keeping Logo, Zoom, and Theme always visible, and validate prompted creation names inside scope [BC-012][SEC-003][SEC-012][UI-001][UI-005][UI-011].

Security-Waiver: updates REQ-006 (superseding scenario P6 with P9 and adding N12) to replace inline horizontal hover buttons with the dwell-gated HeaderBrandSubmenuView while preserving negative and security scenarios N8 and N9 completely unchanged.

- **REMOVED-SCENARIO**: `P6 Proportional Sidebar Width Pin Collapse Hover Topbar and Empty-Area Right-Click Create` — **Reason**: Superseded by P9 which replaces inline isToolbarHovered buttons with HeaderSubmenuStateMachine (120 ms dwell) while preserving proportional sidebar width, pin collapse, and empty-area right-click creation.

#### Scenario: P9 Proportional Sidebar Width Pin Collapse Dwell Header Submenu and Empty-Area Right-Click Create
- **Path**: P9
- **Trait**: positive
- **GIVEN** `SidebarLayoutGeometry` across `1200pt` and `2560pt` display widths, an expanded pinned sidebar, `HeaderSubmenuStateMachine`, and a mounted workspace folder
- **WHEN** `sidebarWidthRatio` updates to `0.40`, `toggleSidebarPinCollapse()` runs, brand header dwell reaches `120 ms`, and `resolveSidebarCreationDirectory(for: nil)` + `sidebarCreateFile(named: "new.md", in:)` execute
- **THEN** computed widths scale strictly to `480pt` and `1024pt` (`40%`), unpinning collapses the sidebar, `HeaderBrandSubmenuView` opens without shifting editor layout while Logo, Zoom, and Theme remain visible, and `"new.md"` is created inside the current folder

#### Scenario: N12 Active Sidebar Divider Drag Blocks Submenu Hover Opening
- **Path**: N12
- **Trait**: negative
- **GIVEN** an active sidebar percentage divider drag (`isDraggingTabOrSidebar == true`)
- **WHEN** the pointer crosses the brand header region for `120 ms`
- **THEN** `HeaderSubmenuStateMachine` remains closed and sidebar ratio clamping (`0.12...0.65`) continues uninterrupted

## REMOVED Requirements

## RENAMED Requirements
