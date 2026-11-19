# Proposal: Full-App Semantic Light/Dark/Auto Theming, macOS Window Chrome Sync & UI Token Fitness

## Why
Interactive testing of `PH.SwiftEdit` after archiving `008-editor-ux-highlighting-sidebar-pin-tabs-and-about` revealed critical Light/Dark theming defects across the application shell and security warning surfaces:
1. Eight UI surfaces (`SwiftEditRootView.toolbarBar`, `collapsedSidebarEdgeHandle`, `sidebarView`, `statusBar`, `LineNumberGutterView`, `FindReplaceGoToLineBar`, `AboutSheetView`, and `KeyboardShortcutsCheatSheetView`) hardcode `palette.brandGround` (`#0B0614`), staying near-black even when `AppearanceMode` switches to `Light` and causing `1.10:1` dark-on-dark unreadable text in modal sheets, Find bar, and status bar.
2. `featherHighlight` (`#C4B5FD`) and `strokeLavender` (`#A78BFA`) remain unchanged across `.light` and `.black`, dropping to `~1.55:1` contrast once surfaces switch to Light Purple (`#F3E8FF`, `#EDE0FF`), while `.light` `unbalancedBracketHighlight` (`3.41:1`) and `.light` `nestedBracketPalette` (`3.30:1..4.07:1`) violate WCAG 2.2 AA (`4.5:1`).
3. Trojan Source BiDi (`CVE-2021-42574`), Binary Quarantine (`DATA-003`), and Inert Raw HTML containers rely on untestable SwiftUI `.opacity(...)` tints, and `.light` `sidebarBinaryDisabledText` (`2.29:1` on dark ground) appeared brighter than regular files (`1.01:1`).
4. `SwiftEditWorkbenchModel.init` defaults `systemPrefersDark: true` (flashing `.black` on Frame 0 on Light macOS desktops in `.auto` mode), while `NSApp.appearance` / `.preferredColorScheme` overrides mask `@Environment(\.colorScheme)` on `Light -> Black -> Auto` transitions, and `TextKit2EditorView` omits live selection, caret, and scroller appearance synchronization.

## What Changes
- **Semantic `PurpleThemePalette` Refactoring & Compile-Time `brandGround` Removal (`SwiftEditUI`)**:
  - Remove `public let brandGround` from `PurpleThemePalette` (preserving `#0B0614` strictly in `SwiftEditBrandLogoGeometry.groundHex` and private `.black` resolution) so view-layer dark-ground leaks fail at compile time (`[AR-008]`, `[AR-009]`, `[UI-001]`).
  - Expose contrast-paired Light and Black role tokens matching `docs/design/color-schemes-and-zed-layout.md` §3 (`topBarSurface`, `sheetSurface`, `sidebarSurface`, `tabBarSurface`, `tabActiveSurface`, `pinnedTabBadge`, `findBarSurface`, `submenuTranslucentSurface` with `1.0`-alpha clamping under `reduceTransparency || increasedContrast`, `gutterSurface`, `gutterForeground`, `gutterActiveForeground`, `statusBarSurface`, `statusBarForeground`, `chromeSurface`, `chromeForeground`, `secondaryForeground`, `chromeAccent`, `activeControlFill`, `activeControlForeground`, `badgeSurface`, `hairlineBorder`, `selectionBackground`, `diffInsertedBackground`, `diffRemovedBackground`) while preserving pure `#FFFFFF`/`#000000` (`21:1`) editor canvas (`[UI-001]`, `[UI-002]`, `[UI-003]`, `[UI-009]`).
  - Add explicit `RGBAColorToken` triples (`foreground`, `background`, `border`) for BiDi Trojan Source, Binary Quarantine, Unbalanced Brackets, and Inert Raw HTML verified at `>= 4.5:1` text and `>= 3.0:1` border contrast across `.light` and `.black` (`[DATA-003]`, `[SEC-004]`, `[UI-006]`, `[UI-008]`).
  - Centralize `RGBAColorToken.swiftUIColor` and `#if os(macOS)` `RGBAColorToken.nsColor` in `PurpleThemeAndZoom.swift` and migrate all 12 workspace, gutter, find-bar, preview, diff, status-bar, banner, and modal sheet views (`[AR-003]`, `[UI-001]`).
- **`MacOSAppearanceSynchronizer`, Unmasked `Auto` OS Detector & Live `TextKit2EditorView` Sync (`SwiftEditUI`)**:
  - Add `#if os(macOS)` `@MainActor` `MacOSAppearanceSynchronizer` synchronizing `NSApp.appearance` (`.aqua`, `.darkAqua`, or `nil` for `.auto`) and inject `systemDarkDetector: @MainActor () -> Bool` into `SwiftEditWorkbenchModel.init` reading unmasked `AppleInterfaceStyle` + `DistributedNotificationCenter` `"AppleInterfaceThemeChangedNotification"`, guarding `onChange(of: systemColorScheme)` behind `appearanceMode == .auto` (`[AR-003]`, `[UI-003]`, `[UI-005]`, `[UI-012]`).
  - Update `TextKit2EditorView` (`usesAdaptiveColorMappingForDarkAppearance = false`, `selectedTextAttributes`, `insertionPointColor` + focused timer refresh, `NSScrollView` background & `scrollerKnobStyle`, and viewport-only attribute refresh without incrementing `BufferRevision` or calling whole-document `ensureLayout`) (`[UI-002]`, `[UI-006]`, `[UI-007]`, `[UI-012]`).
- **Static UI Theme Token Fitness Scanner (`SwiftEditCore` + `SwiftEditTests`)**:
  - Add `ArchitectureImportScanner.scanSwiftEditUIThemeTokens(content:filePath:)` rejecting `brandGround`, raw 6-digit hex literals, `Color(.sRGB`, or `NSColor(srgbRed:` inside `Sources/SwiftEditUI/Views/*.swift` (`[AR-006]`, `[SEC-009]`, `[TEST-006]`).

## Capabilities
- New Capabilities: `full-app-semantic-theming-and-window-sync`
- Modified Capabilities: `swifteditui-purple-zed-layout-textkit2-and-appicons`, `editor-ux-highlighting-sidebar-pin-tabs-and-about`

## Domain Carrier & Decision Ownership (BC-###)
- **BC-001**: Spans `ArchitectureFitness` (`SwiftEditCore` Generic/Governance — owns pure static `scanSwiftEditUIThemeTokens` source text audit) and `SwiftEditUI` (Presentation — owns `PurpleThemePalette`, `MacOSAppearanceSynchronizer`, `SwiftEditWorkbenchModel` appearance state, and `TextKit2EditorView` viewport styling).
- **Owned Decisions**: Mode-resolved `.light` and `.black` `RGBAColorToken` assignments, accessibility opacity/border clamping (`reduceTransparency`, `increasedContrast`), unmasked macOS interface style detection for `.auto`, `NSApp.appearance` / `NSScrollView` synchronization, and static rejection of raw color literals in `Views/*.swift`.
- **Forbidden Responsibilities**: `SwiftEditCore` MUST NEVER import `AppKit`, `UIKit`, `SwiftUI`, or `WebKit` (`[AR-002]`). `SwiftEditUI` theme switching MUST NEVER reload open `DocumentSession` buffers, increment `BufferRevision`, clear `InspectionSafetyBannerState` binary/BiDi lockouts, or invoke whole-document `NSTextLayoutManager.ensureLayout` (`[BC-006]`, `[DATA-003]`, `[UI-003]`, `[UI-008]`, `[UI-012]`).
- **External Decision References**: `DocumentID`, `BufferRevision`, `AppearanceMode`.

## Impact
- **Production Modules (`SwiftEditCore`)**:
  - `Sources/SwiftEditCore/ArchitectureFitness/ArchitectureImportScanner.swift` (extended with `scanSwiftEditUIThemeTokens` and directory scan helper)
- **Production Modules (`SwiftEditUI`)**:
  - `Sources/SwiftEditUI/Theme/PurpleThemeAndZoom.swift` (semantic Light/Black surface, foreground, accent, submenu, and security-warning tokens; centralized `swiftUIColor`/`nsColor` bridges; `MacOSAppearanceSynchronizer`)
  - `Sources/SwiftEditUI/Coordinators/WorkspaceEditorAndDiffCoordinators.swift` (`systemDarkDetector` alignment in `WorkspaceEditorCoordinator`)
  - `Sources/SwiftEditUI/Views/SwiftEditRootView.swift` (migrated `toolbarBar`, `collapsedSidebarEdgeHandle`, `sidebarView`, `tabBar`, `safetyAndErrorBanners`, `markdownPreviewPanel`, `diffPanel`, `statusBar`, `TextKit2EditorView` scroller/selection/caret sync, and unmasked `.auto` tracking)
  - `Sources/SwiftEditUI/Views/LineNumberGutterView.swift` (migrated to `gutterSurface`, `gutterForeground`, `gutterActiveForeground`, `hairlineBorder`)
  - `Sources/SwiftEditUI/Views/FindReplaceGoToLineBar.swift` (migrated to `findBarSurface`, `chromeForeground`, `chromeAccent`, `hairlineBorder`)
  - `Sources/SwiftEditUI/Views/AboutSheetView.swift` (migrated to `sheetSurface`, `chromeForeground`, `secondaryForeground`, `activeControlFill`, `chromeAccent`)
  - `Sources/SwiftEditUI/Views/KeyboardShortcutsCheatSheetView.swift` (migrated to `sheetSurface`, `chromeForeground`, `secondaryForeground`, `badgeSurface`, `hairlineBorder`)
- **Test Suites (`SwiftEditTests`)**: Updated `PurpleThemeZoomAndSafetyBannerTests.swift`, `EditorUXLayoutThemeAndAboutTests.swift`, `ArchitectureFitnessTests.swift`, plus new `FullAppSemanticThemingAndWindowSyncTests.swift`.
- **External Dependencies**: Zero new SwiftPM dependencies (`[AR-005]`).

## Security Impact
- **Anti-Camouflage & UI Redressing Defense (`[SEC-004]`, `[SEC-009]`, `[UI-008]`, `CWE-451`, `CVE-2021-42574`)**: Eliminates `1.10:1` Light-mode contrast collapse on `AboutSheetView` and `statusBar`, fixes `2.29:1` binary sidebar salience inversion, fixes `3.41:1` Light unbalanced-bracket error pill (`-> 6.78:1`), and enforces explicit `>= 8.15:1` text / `>= 3.94:1` border tokens on Trojan Source BiDi, Binary Quarantine, and Inert Raw HTML warnings.
- **Quarantine Persistence Across Theme Transitions (`[DATA-003]`, `[SEC-012]`)**: Switching `Light`, `Black`, or `Auto` preserves `InspectionSafetyBannerState` (`canSave == false`, `canFormat == false`, `canPinTab == false`) on binary buffers and retains `ExternalURIConfirmationPrompt` (`https`/`http`/`mailto`) confirmation gates.

## Metadata
- Owner: swift-macos-expert
- Domain: apple-swift-macos
- Reviewer: cyber-security-expert
- Branch: feature/FirstStub
- Manual-Steps: none
- Modifies-Specs: swifteditui-purple-zed-layout-textkit2-and-appicons (REQ-001, REQ-002), editor-ux-highlighting-sidebar-pin-tabs-and-about (REQ-005)
- Constitutional-Rules: AR-001, AR-002, AR-003, AR-005, AR-006, AR-008, AR-009, BC-001, BC-006, DATA-003, SEC-004, SEC-009, SEC-012, TEST-001, TEST-002, TEST-003, TEST-004, TEST-006, UI-001, UI-002, UI-003, UI-004, UI-005, UI-006, UI-007, UI-008, UI-009, UI-010, UI-011, UI-012, SDD-001, SDD-002, SDD-003
- Amends-Constitution: none

## Prerequisites
- `openspec/Constitution.md` (`v1.3.0`, active)
- `docs/design/color-schemes-and-zed-layout.md` (`v1.2.0`, Section 3 semantic token anchor table)
- `openspec/changes/archive/2026-11-18-004-swifteditui-purple-zed-layout-textkit2-and-appicons` (archived)
- `openspec/changes/archive/2026-11-19-008-editor-ux-highlighting-sidebar-pin-tabs-and-about` (archived)
- `openspec/briefs/brief-full-app-semantic-theming-and-window-sync.md`
