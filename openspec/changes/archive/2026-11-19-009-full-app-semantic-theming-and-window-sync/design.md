# Design: Full-App Semantic Light/Dark/Auto Theming, macOS Window Chrome Sync & UI Token Fitness

## Context
Following `008-editor-ux-highlighting-sidebar-pin-tabs-and-about`, eight workspace and modal surfaces (`SwiftEditRootView.toolbarBar`, `collapsedSidebarEdgeHandle`, `sidebarView`, `statusBar`, `LineNumberGutterView`, `FindReplaceGoToLineBar`, `AboutSheetView`, and `KeyboardShortcutsCheatSheetView`) still reference `palette.brandGround` (`#0B0614`), staying dark in `Light` mode and collapsing foreground contrast to `1.10:1` on sheets and status bar. Furthermore, `featherHighlight` (`#C4B5FD`) and `strokeLavender` (`#A78BFA`) fail WCAG 2.2 AA (`< 1.60:1`) on Light Lavender chrome, `.light` `unbalancedBracketHighlight` drops to `3.41:1`, `SwiftEditWorkbenchModel.init` defaults `systemPrefersDark: true` on Frame 0, and `NSApp.appearance` / `TextKit2EditorView` scroller and selection attributes are not synchronized dynamically (`[UI-001]`, `[UI-002]`, `[UI-003]`, `[UI-009]`).

## Goals / Non-Goals
- Goals:
  - Eliminate `public let brandGround` from `PurpleThemePalette` and migrate all 12 workspace, gutter, find-bar, preview, diff, status-bar, safety-banner, and sheet views to contrast-verified semantic role tokens (`>= 4.5:1` text, `>= 3.0:1` UI/border, `21:1` `#FFFFFF`/`#000000` canvas) (`[AR-008]`, `[UI-001]`, `[UI-002]`, `[UI-009]`).
  - Synchronize `NSApp.appearance`, modal sheets, `NSScrollView` scrollers, and `TextKit2EditorView` selection/caret attributes via `MacOSAppearanceSynchronizer` and an unmasked `AppleInterfaceStyle` `systemDarkDetector` without incrementing `BufferRevision` (`[AR-003]`, `[BC-006]`, `[UI-003]`, `[UI-012]`).
  - Enforce static view token fitness via `ArchitectureImportScanner.scanSwiftEditUIThemeTokens` (`[AR-006]`, `[SEC-009]`, `[TEST-006]`).
- Non-Goals:
  - Translucent `HeaderBrandSubmenuView` and `Cmd+P` Markdown Preview command reorganization (deferred to `TASK-02` / `010`, though `submenuTranslucentSurface` token + `reduceTransparency`/`increasedContrast` clamping is provisioned here).
  - Multi-class GoF `ThemeFactory` or `ThemeStrategy` hierarchies (`< 3` concrete modes violates Rule of Three `[AR-009]`).

## Architecture Memory & Module Boundaries (AR-###)
- **AR-001**: `SwiftEditCore` (`ArchitectureFitness` — **Generic** subdomain) targets `.macOS(.v26)` and `.iOS(.v26)` importing only `Foundation` and `Markdown` (`[AR-002]`, `[BC-002]`); `SwiftEditUI` (Presentation layer) depends inward on `SwiftEditCore` and isolates `AppKit` symbols (`NSApp`, `NSAppearance`, `NSColor`, `NSScrollView`) behind `#if os(macOS)` (`[AR-003]`, `[UI-005]`).
- **AR-018**: `SwiftEditWorkbenchModel` and `WorkspaceEditorCoordinator` coordinate appearance transitions exclusively via value-type `AppearanceMode` and `PurpleThemePalette` snapshots without mutating `DocumentSession` buffers or `BufferRevision` (`[BC-006]`, `[UI-003]`).

## Constitutional Alignment & Module Boundaries (AR-### / UI-### / DATA-### / API-###)
- **Bounded Context Classification (`[BC-001]`, `[BC-002]`)**:
  - `DocumentCore`: **Core** (`SwiftEditCore` — untouched, preserves `BufferRevision` and `isBinaryReadOnly` invariants `[DATA-003]`).
  - `ArchitectureFitness`: **Generic** (`SwiftEditCore` — extended with `scanSwiftEditUIThemeTokens` `[AR-006]`, `[TEST-006]`).
  - `SwiftEditUI`: **Presentation** (`PurpleThemePalette`, `MacOSAppearanceSynchronizer`, `SwiftEditWorkbenchModel`, `TextKit2EditorView` `[UI-001..012]`).
- **Single-Reference Lock**: Consulted `openspec/constitution/03-ui-ux/design-system-and-tokens.md` (`UI-001..004`), `03-ui-ux/component-state-and-forms.md` (`UI-005..008`), `03-ui-ux/accessibility-and-cwv.md` (`UI-009..012`), `01-architecture/dependency-and-layering.md` (`AR-006..010`), and `07-security-privacy/` (`SEC-004`, `SEC-009`, `SEC-012`) (`[SDD-001]`, `[SDD-002]`, `[SDD-003]`).

## Glossario & Convenzioni
- `PurpleThemePalette`: Immutable `Sendable` value struct resolving `.light` and `.black` role-specific `RGBAColorToken` properties (`[BC-009]`, `[UI-001]`).
- `MacOSAppearanceSynchronizer`: Stateless `#if os(macOS)` `@MainActor` bridge applying `NSApp.appearance` (`.aqua`, `.darkAqua`, `nil`) (`[AR-003]`, `[UI-003]`).
- `systemDarkDetector`: Injectable `@MainActor () -> Bool` closure reading unmasked `AppleInterfaceStyle` for Frame 0 initialization and `.auto` restoration (`[UI-003]`, `[TEST-004]`).
- `scanSwiftEditUIThemeTokens`: Static `ArchitectureImportScanner` method rejecting `brandGround`, raw 6-digit hex literals, `Color(.sRGB`, and `NSColor(srgbRed:` in `Sources/SwiftEditUI/Views/*.swift` (`[AR-006]`, `[TEST-006]`).

## Decisions
- **D1 — Exhaustive Value-Type `PurpleThemePalette` & Removal of `public let brandGround` (`KISS` + `ISP`)**: Removing `brandGround` from `PurpleThemePalette` turns all 8 view-layer dark-surface leaks into immediate compiler errors without introducing GoF `ThemeStrategy` classes (`Rule of Three`: 2 modes `[AR-009]`). Centralizing `RGBAColorToken.swiftUIColor` and `nsColor` in `PurpleThemeAndZoom.swift` removes 12 inline `Color(.sRGB, ...)` constructors.
- **D2 — Unmasked `systemDarkDetector` + `MacOSAppearanceSynchronizer`**: Reading `UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"` (and observing `DistributedNotificationCenter` `"AppleInterfaceThemeChangedNotification"`) decouples true OS dark/light state from `.preferredColorScheme` / `NSApp.appearance` overrides, preventing both Frame 0 `.black` FOUC and `.auto` feedback lockups (`[UI-003]`, `[UI-012]`).
- **D3 — Explicit Security Warning `RGBAColorToken` Triples**: Replacing `.opacity(0.25)` tints and `.light` `#DC2626` (`3.41:1`) with dedicated foreground, background, and border tokens guarantees `>= 6.78:1..12.08:1` text contrast and `>= 3.94:1` border contrast for Trojan Source BiDi, Binary Quarantine, Unbalanced Brackets, and Inert HTML (`[SEC-004]`, `[UI-008]`, `[UI-009]`).
- **D4 — Viewport-Only `TextKit2EditorView` Live Restyling**: Updating `usesAdaptiveColorMappingForDarkAppearance = false`, `selectedTextAttributes`, `insertionPointColor` (+ focused timer restart), `scrollView.drawsBackground = true`, `scrollView.backgroundColor`, `scrollerKnobStyle`, and `textViewportLayoutController.layoutViewport()` keeps live theme toggles O(viewport) with zero `ensureLayout` (`[UI-007]`, `[UI-012]`).

## Risks / Trade-offs
- Existing `PurpleThemeZoomAndSafetyBannerTests.swift` asserts `lightPalette.brandGround.hex == "#0B0614"` -> Migrate assertion to `SwiftEditBrandLogoGeometry.groundHex == "#0B0614"` and `blackPalette.topBarSurface.hex == "#0B0614"` while asserting `lightPalette.topBarSurface.hex == "#F3E8FF"`.
- Global `NSApp.appearance` mutation during parallel unit tests when `NSApp == nil` -> Guard `NSApp?.appearance` safely in `MacOSAppearanceSynchronizer` and inject deterministic `systemDarkDetector` closures in `SwiftEditTests` (`[TEST-003]`, `[TEST-004]`).

## Migration Plan
1. Add `scanSwiftEditUIThemeTokens` in `ArchitectureImportScanner.swift` (`SwiftEditCore`).
2. Refactor `PurpleThemePalette` (`PurpleThemeAndZoom.swift`) removing `public let brandGround`, adding §3 role + security + translucent tokens and centralized `swiftUIColor`/`nsColor` helpers, plus `#if os(macOS)` `MacOSAppearanceSynchronizer`.
3. Update `SwiftEditWorkbenchModel`, `WorkspaceEditorCoordinator`, `TextKit2EditorView`, and all 6 view files under `Sources/SwiftEditUI/Views/`.
4. Verify `swift test` passes 100% in parallel (`Swift Testing`).

## Security Review
- Reviewer: cyber-security-expert
- Date: 2026-11-19
- Verdict: approved
- Open items: none
