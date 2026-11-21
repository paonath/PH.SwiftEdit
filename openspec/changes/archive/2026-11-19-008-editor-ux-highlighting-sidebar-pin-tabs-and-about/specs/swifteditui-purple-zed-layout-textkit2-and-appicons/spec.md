# Spec Delta: Live Theme Selector Highlight Tokens Sidebar Zoom and TextKit 2 Decorations

## Purpose
Extends `REQ-001` and `REQ-003` of `swifteditui-purple-zed-layout-textkit2-and-appicons` additively to synchronize `Light`/`Dark`/`Auto` with live system appearance, define current-line, nested-bracket, backtick, and disabled-binary theme tokens, scale left sidebar typography with `50%..300%` zoom, and render non-mutating TextKit 2 visual highlights and Markdown smart newlines.

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-001 Concept E2 Purple Chrome Inverted B/W Canvas and 50..300 Percent Zoom
WHEN resolving theme tokens, layout state, or zoom commands across `Light`, `Black`, and `Auto` modes, the theme and zoom controller SHALL expose the Concept E2 Purple palette (`#0B0614`, `#7C3AED`, `#A78BFA`, `#C4B5FD`) plus current-line, nested-bracket, backtick, and disabled-binary tokens, invert the `#FFFFFF`/`#000000` canvas at `21:1` contrast, sync `.auto` to live system appearance, and scale both editor and sidebar zoom across `50%..300%` [UI-001][UI-002][UI-003][UI-004][UI-009].

Security-Waiver: additive modification only; existing scenarios P1 and N1 and all UI-001..004 and UI-009 invariants remain intact while adding current-line, nested-bracket, backtick, disabled-binary tokens, live Auto sync, and proportional sidebar zoom.

#### Scenario: P4 Highlight Tokens Live Auto Sync and Proportional Sidebar Zoom Scaling
- **Path**: P4
- **Trait**: positive
- **GIVEN** `PurpleThemePalette` resolved for `.light`, `.black`, and `.auto` (with `systemPrefersDark: false` and `true`) and `EditorZoomController` at `150%`
- **WHEN** highlight tokens and `sidebarScaledFontSizePoints` are evaluated
- **THEN** current-line resolves `#161224` in Black and `#F3F0FA` in Light, disabled binary resolves `#9CA3AF` in Black and `#52525B` in Light, nested bracket depth colors and backtick tint tokens are populated, and `sidebarScaledFontSizePoints` equals `19.5`

#### Scenario: N7 Sidebar Zoom Clamps at 50 and 300 Percent Boundaries
- **Path**: N7
- **Trait**: negative
- **GIVEN** `EditorZoomController` clamped at `50%` and `300%`
- **WHEN** `sidebarScaledFontSizePoints` is evaluated at both boundaries
- **THEN** sidebar typography clamps cleanly at `6.5pt` and `39.0pt`

### Requirement: REQ-003 MainActor TextKit 2 Scoped Transactions Diff Coordinator and Inert Preview
WHEN coordinating edits, theme switches, visual highlights, Markdown smart newlines, previews, or Myers diffs on `@MainActor`, the editor and diff coordinators SHALL keep live text in `NSTextContentStorage`, render current-line, nested bracket, and backtick highlights without mutating text, project Side-by-Side diff rows, and render raw HTML previews as inert plain text [AR-003][SEC-004][UI-003][UI-005][UI-006][UI-007][UI-009][UI-010][UI-011][UI-012].

Security-Waiver: additive modification only; existing scenarios P2, N3, and N4 and all SEC-004 inert HTML preview and binary lockout invariants remain strictly preserved while adding non-mutating visual highlighting and smart newline coordination.

#### Scenario: P5 Non-Mutating Visual Highlight Projection for Current Line Nested Brackets and Backticks
- **Path**: P5
- **Trait**: positive
- **GIVEN** a `@MainActor` `SwiftEditWorkbenchModel` holding `"scrivo{a[b(c)]} `code`"` with caret inside `"(c)"`
- **WHEN** visual highlight state is projected for TextKit 2 rendering
- **THEN** active line, depth-colored bracket spans, and backtick ranges are projected without incrementing `BufferRevision` or mutating `session.text`

#### Scenario: N8 Binary Read-Only Buffer Suppresses Smart Newline and Visual Edit Mutation
- **Path**: N8
- **Trait**: negative
- **GIVEN** a `@MainActor` `SwiftEditWorkbenchModel` holding a binary read-only snapshot
- **WHEN** `handleSmartNewline(at:)` is invoked
- **THEN** the call returns `false` and leaves the binary buffer unmodified

## REMOVED Requirements

## RENAMED Requirements
