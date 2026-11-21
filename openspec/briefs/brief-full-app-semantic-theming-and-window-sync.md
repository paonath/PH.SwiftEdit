---
id: "brief-full-app-semantic-theming-and-window-sync"
change_id: "009-full-app-semantic-theming-and-window-sync"
capability: "full-app-semantic-theming-and-window-sync"
branch: "feature/FirstStub"
modifies_specs: "swifteditui-purple-zed-layout-textkit2-and-appicons (REQ-001, REQ-002), editor-ux-highlighting-sidebar-pin-tabs-and-about (REQ-005)"
status: "approved-via-qa"
date: "2026-11-19"
owners:
  - "swift-macos-expert"
  - "oop-architecture-expert"
  - "cyber-security-expert"
---

# TDD Specification Brief: `009-full-app-semantic-theming-and-window-sync`

## 1. Context & Source Traceability

- **Originating Reasoning Session**: `reasoning/003_theming-header-menu-and-markdown-editor/README.ai.md` (`TASK-01`, `TOPIC-01`, `ADR-01`).
- **Core Problem**:
  1. Eight UI surfaces (`SwiftEditRootView.toolbarBar`, `collapsedSidebarEdgeHandle`, `sidebarView`, `statusBar`, `LineNumberGutterView`, `FindReplaceGoToLineBar`, `AboutSheetView`, `KeyboardShortcutsCheatSheetView`) hardcode `palette.brandGround` (`#0B0614`), remaining near-black even when `AppearanceMode` is set to `.light`, and rendering unreadable dark-on-dark `1.10:1` text in `AboutSheetView`, `KeyboardShortcutsCheatSheetView`, and `statusBar`.
  2. `featherHighlight` (`#C4B5FD`) and `strokeLavender` (`#A78BFA`) are static across `.light` and `.black`, dropping below `1.60:1` contrast once surfaces switch to Light Purple (`#F3E8FF`, `#EDE0FF`, `#E9D5FF`, `#F5F3FF`), while `.light` `unbalancedBracketHighlight` (`3.41:1`) and `.light` `nestedBracketPalette` (`3.30:1..4.07:1`) fail WCAG 2.2 AA `4.5:1`.
  3. Safety banners (`InspectionSafetyBannerState` BiDi Trojan Source and Binary Quarantine) and inert HTML blocks use untestable ad-hoc SwiftUI `.opacity(...)` tints, and `.light` `sidebarBinaryDisabledText` (`2.29:1` on dark ground) appeared brighter than regular files (`1.01:1`).
  4. `SwiftEditWorkbenchModel.init` defaults `systemPrefersDark = true` (causing cold-start `.black` flash on Light macOS desktops in `.auto` mode), and syncing `NSApp.appearance` / `.preferredColorScheme` masks `@Environment(\.colorScheme)` on `Light -> Black -> Auto` round-trips unless backed by an unmasked OS `AppleInterfaceStyle` detector.
  5. `TextKit2EditorView` omits `selectedTextAttributes`, `usesAdaptiveColorMappingForDarkAppearance = false`, `NSScrollView` background & `scrollerKnobStyle`, and live viewport restyling on theme switches.
- **Active Git Branch**: `feature/FirstStub` (baseline SHA `51ff0907674ddba9c21ffe1dfd44213e6f47645e`).
- **Consolidated Specs Modified (`modifies_specs`)**:
  - `swifteditui-purple-zed-layout-textkit2-and-appicons` (`REQ-001` & `REQ-002` MODIFIED to replace `public let brandGround` with role-specific semantic Light/Black surface, foreground, accent, gutter, tab, diff, sheet, status-bar, translucent-submenu, and security-warning tokens verified at `>= 4.5:1` text and `>= 3.0:1` UI/border contrast while preserving `#FFFFFF`/`#000000` `21:1` editor canvas and all `- **Trait**: security` scenarios).
  - `editor-ux-highlighting-sidebar-pin-tabs-and-about` (`REQ-005` MODIFIED to synchronize `NSApp.appearance` via `MacOSAppearanceSynchronizer`, seed and track unmasked `AppleInterfaceStyle` via `systemDarkDetector` without feedback loops, clamp `submenuTranslucentSurface` / `findBarSurface` to `1.0` alpha under `reduceTransparency` / `increasedContrast`, and update `TextKit2EditorView` selection, caret, and scroller styling in-place without reloading buffers).
- **New Capability Added**:
  - `full-app-semantic-theming-and-window-sync` (`REQ-001` static architecture fitness scanner `ArchitectureImportScanner.scanSwiftEditUIThemeTokens` rejecting `brandGround`, raw 6-digit hex literals, `Color(.sRGB`, and `NSColor(srgbRed:` in `Sources/SwiftEditUI/Views/*.swift`, plus full-app surface/contrast/window-sync verification).
- **Governing Constitutional Rules (`v1.3.0`)**: `[AR-001]`, `[AR-002]`, `[AR-003]`, `[AR-006]`, `[AR-008]`, `[AR-009]`, `[DATA-003]`, `[SEC-004]`, `[SEC-009]`, `[SEC-012]`, `[TEST-001]`..`[TEST-006]`, `[UI-001]`..`[UI-012]`, `[SDD-001]`..`[SDD-003]`.

## 2. Domain, Architecture & Security Expert Notes

- **`swift-macos-expert` & `oop-architecture-expert`**:
  - Remove `public let brandGround` from `PurpleThemePalette` (`#0B0614` stays strictly in `SwiftEditBrandLogoGeometry.groundHex` and private `.black` resolution inside `PurpleThemePalette.resolve(appearance:systemPrefersDark:reduceTransparency:increasedContrast:)`).
  - Expose role-specific semantic `RGBAColorToken` properties on `PurpleThemePalette`: `topBarSurface` & `sheetSurface` (`#F3E8FF` / `#0B0614`), `sidebarSurface` (`#EDE0FF` / `#140A24`), `tabBarSurface` (`#E9D5FF` / `#180C2C`), `tabActiveSurface` (`#FFFFFF` / `#000000`), `pinnedTabBadge` (`#7C3AED` / `#C4B5FD`), `findBarSurface` (`#EDE9FE` / `#140A24`), `submenuTranslucentSurface` (`alpha 0.90` normal, clamped `1.0` when `reduceTransparency || increasedContrast`), `gutterSurface` (`#F5F3FF` / `#0B0614`), `gutterForeground` (`#5B21B6` / `#A78BFA`), `gutterActiveForeground` (`#1E1035` / `#EDE9FE`), `statusBarSurface` (`#7C3AED` / `#2E1065`) + `statusBarForeground` (`#FFFFFF`), `chromeSurface` (`#F5F3FF` / `#0B0614`), `chromeForeground` (`#1E1035` / `#EDE9FE`), `secondaryForeground` (`#5B21B6` / `#C4B5FD`), `chromeAccent` (`#7C3AED` / `#A78BFA`), `activeControlFill` (`#7C3AED`) + `activeControlForeground` (`#FFFFFF`), `badgeSurface` (`#E9D5FF` / `#2E1065`), `hairlineBorder` (`#C4B5FD` / `#3B1D6E`, stepped up to `#6D28D9` / `#DDD6FE` under `increasedContrast`), `selectionBackground` (`#DDD6FE` / `#3B0764`), `diffInsertedBackground` (`#DCFCE7` / `#052E16`), `diffRemovedBackground` (`#FEE2E2` / `#450A0A`).
  - Centralize `RGBAColorToken.swiftUIColor` and `#if os(macOS)` `RGBAColorToken.nsColor` in `PurpleThemeAndZoom.swift` and eliminate every inline `Color(.sRGB, ...)` / raw color literal across `Sources/SwiftEditUI/Views/*.swift`.
  - Implement `#if os(macOS)` `@MainActor` `MacOSAppearanceSynchronizer` + injectable `systemDarkDetector: @MainActor () -> Bool` in `SwiftEditWorkbenchModel.init` (defaulting to unmasked `UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"`, observing `DistributedNotificationCenter` `"AppleInterfaceThemeChangedNotification"`, and guarding `SwiftEditRootView.onChange(of: systemColorScheme)` behind `model.appearanceMode == .auto`).
  - Update `TextKit2EditorView` (`usesAdaptiveColorMappingForDarkAppearance = false`, `selectedTextAttributes`, `insertionPointColor` + focused caret refresh, `scrollView.drawsBackground = true`, `scrollView.backgroundColor`, `scrollView.appearance`, `scrollerKnobStyle`, and viewport-only rendering attribute refresh).
- **`cyber-security-expert`**:
  - Add explicit `RGBAColorToken` triples (`foreground`, `background`, `border`) for BiDi Trojan Source (`#78350F` on `#FEF3C7` border `#B45309` in `.light`; `#FDE68A` on `#451A03` border `#F59E0B` in `.black`), Binary Quarantine (`#7C2D12` on `#FFEDD5` border `#C2410C` in `.light`; `#FED7AA` on `#431407` border `#FB923C` in `.black`), Unbalanced Brackets (`#991B1B` on `#FEE2E2` in `.light`; `#FCA5A5` on `#450A0A` in `.black`), and Inert Raw HTML (`#7F1D1D` on `#FEE2E2` border `#DC2626` in `.light`; `#FECACA` on `#450A0A` border `#EF4444` in `.black`), plus `.light` `nestedBracketPalette` darkened to `>= 4.5:1` on `#FFFFFF`.
  - Enforce static theme fitness gate `ArchitectureImportScanner.scanSwiftEditUIThemeTokens(content:filePath:)` and automated WCAG `>= 4.5:1` / `>= 3.0:1` security contrast tests (`- **Trait**: security`).

## 3. Path Coverage Matrix (`P1..P3`, `N1..N4`)

| Unit | Path ID | Trait | Scenario Summary |
| :--- | :--- | :--- | :--- |
| `PurpleThemePalette` & Security Tokens | `P1` | `positive` | Semantic `.light` and `.black` role tokens match §3 hex anchors, `21:1` `#FFFFFF`/`#000000` canvas, `>= 4.5:1` text contrast, and `>= 3.0:1` UI/border contrast across all 12 surfaces |
| `PurpleThemePalette` & Accessibility | `N1` | `negative` | `reduceTransparency` and `increasedContrast` clamp translucent surfaces (`submenuTranslucentSurface`, `findBarSurface`) to `1.0` alpha and step up `hairlineBorder` >= `3.0:1` |
| `PurpleThemePalette` Security Salience | `N2` | `security` | BiDi Trojan Source, Binary Quarantine, Sidebar Binary Disabled, Unbalanced Bracket, and Inert HTML token pairs satisfy `>= 4.5:1` text and `>= 3.0:1` border contrast across `.light` and `.black` while preserving binary lockouts across live switches |
| `MacOSAppearanceSynchronizer` & Workbench | `P2` | `positive` | Cold launch in `.auto` seeds unmasked OS Light/Dark style on Frame 0, and live `Light <-> Black <-> Auto` switches sync `NSApp.appearance` and `TextKit2EditorView` styling without incrementing `BufferRevision` |
| `MacOSAppearanceSynchronizer` & Workbench | `N3` | `negative` | Forced `.black` / `.light` container `colorScheme` overrides are ignored while `appearanceMode != .auto`, so switching back to `.auto` restores the true underlying OS appearance |
| `ArchitectureImportScanner` Theme Fitness | `P3` | `positive` | Live `Sources/SwiftEditUI/Views/*.swift` files pass `scanSwiftEditUIThemeTokens` with zero `brandGround`, raw hex, or inline `sRGB` constructor violations |
| `ArchitectureImportScanner` Theme Fitness | `N4` | `security` | View snippets referencing `brandGround`, raw `#0B0614` hex literals, `Color(.sRGB`, or `NSColor(srgbRed:` are rejected fail-closed as `CWE-451` UI redressing / dark-leak violations |
