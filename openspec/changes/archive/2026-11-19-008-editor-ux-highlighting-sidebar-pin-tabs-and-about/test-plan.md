# Test Plan: PH.SwiftEdit Editor UX, Highlighting, Percentage-Resized Collapsible Sidebar, Tab Reordering & Help About Integrations

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `NestedBracketAndBacktickEngine` (`BracketMatcher`, `BacktickHighlightScanner`) | P1: Assigns exact 0-based `nestingDepth` (`0, 1, 2`) and `enclosingPairs` on nested `{ [ () () ] }`, and detects inline `` `code` `` plus multiline `` ```swift\n...\n``` `` spans (`[AR-004]`, `[AR-012]`). | N1: Unclosed inline backticks, unclosed fences, and mismatched nested brackets produce deterministic unmatched reports without crashing (`[BC-011]`). N2 (`security`): Lines `> 4096` UTF-16 units or binary snapshots return `.degradedOrTimedOut` (`[BC-011]`, `[SEC-012]`). |
| `MarkdownSmartNewlineEngine` | P2: Continues unordered (`-`/`*`/`+`), task (`- [ ]`), incremented ordered (`N.`/`N)`), and blockquote (`>`) lines preserving indentation, and strips empty markers to exit lists (`[BC-004]`, `[BC-006]`). | N3: Inside fenced `` ``` `` blocks, non-Markdown files, or plain prose returns `nil` (`[BC-006]`). N4 (`security`): Binary read-only snapshots, out-of-range carets, or `> 4096` UTF-16 lines return `nil` safely (`[DATA-003]`, `[SEC-012]`). |
| `WorkspaceTabReordering` (`WorkspaceTabSession`) | P3: `moveTabLeft`, `moveTabRight`, and `moveTab(id:toIndex:)` reorder pinned and unpinned tabs inside their partitions preserving `activeTabID` (`[BC-006]`, `[BC-008]`). | N5: Boundary cross-partition moves remain inert preserving pinned-first ordering; unknown `DocumentID` throws `DomainError.tabNotFound` (`[BC-008]`). |
| `DotfileBinaryEntryDetection` (`DotfileFolderNavigator`) | P4: Shallow directory listing marks files with `0x00` in first `8 KiB` as `isBinary == true` while text files and directories report `isBinary == false` with balanced scope release (`[DATA-003]`, `[DATA-007]`, `[SEC-002]`). | N6 (`security`): Escaping symlink aborts with `DomainError.securityScopeViolation` before any `8 KiB` binary probe executes with `startCount == stopCount` (`[SEC-002]`, `[SEC-003]`). |
| `ThemeSelectorCurrentLineAndZoom` (`PurpleThemePalette`, `EditorZoomController`, `SwiftEditWorkbenchModel`) | P5: 3-way `Light`/`Black`/`Auto` selector syncs live `systemPrefersDark`, resolves current-line (`#161224`/`#F3F0FA`), nested bracket depth, backtick, and disabled-binary (`#9CA3AF`/`#52525B`) tokens, and scales sidebar typography across `50%..300%` (`[UI-001]`..`[UI-004]`). | N7: Clicking a binary sidebar entry opens no tab and mutates no session; sidebar zoom clamps at `50%` (`6.5pt`) and `300%` (`39.0pt`) (`[DATA-003]`, `[UI-004]`, `[UI-008]`). |
| `PercentageSidebarPinHoverToolbarAndContextCreate` (`SidebarLayoutGeometry`, `SwiftEditWorkbenchModel`) | P6: Sidebar width computes strictly as `containerWidth * clampedRatio` (`0.12...0.65`) across display widths; manual `pin` collapses/expands sidebar; top-bar commands follow `isToolbarHovered` while Logo/Zoom/Theme remain always visible; empty-area and row right-click Create File/Folder resolves target directory and creates validated items (`[BC-012]`, `[UI-001]`, `[UI-005]`, `[UI-011]`). | N8: Out-of-bounds ratios (`< 0.12` / `> 0.65`), zero container width, and invalid prompt names (`""`, `"."`) clamp or fail without disk writes (`[BC-012]`). N9 (`security`): Path traversal (`../escape.md`), BiDi override names, or escaping symlinks throw `DomainError.invalidItemName` or `DomainError.securityScopeViolation` (`[SEC-003]`, `[SEC-012]`). |
| `BrandLogoAndHelpAboutDialog` (`SwiftEditBrandLogoGeometry`, `AboutSheetDescriptor`, `SwiftEditCommands`) | P7: Concept E2 vector logo geometry exposes exact `#0B0614`/`#A78BFA`/`#C4B5FD`->`#7C3AED` primitives for small topbar and large About views; `Help` menu exposes `About PH.SwiftEdit`; `AboutSheetDescriptor` resolves App Name, `nbgv` version, validated GitHub repo link, and validated MIT License link (`[AR-014]`, `[UI-001]`, `[SEC-004]`). | N10 (`security`): Non-HTTPS or tampered repository/license URIs (`http://`, `javascript:`, `file://`) return `nil` from `prepareExternalLinkConfirmation` (`[SEC-004]`, `[UI-008]`). |

## 2. Test Automation Strategy & Commands
- Full parallel unit & fitness test runner command: `swift test`
- Targeted suite filter command: `swift test --filter "NestedBracketAndBacktickEngineTests|MarkdownSmartNewlineEngineTests|TabReorderAndBinarySidebarTests|EditorUXLayoutThemeAndAboutTests"`
- Security abuse-case filter command: `swift test --filter "Security|security|N2|N4|N6|N9|N10"`
- Constitutional & Architecture fitness verification: `swift test --filter "ArchitectureFitnessTests|ConstitutionFitnessTests"`

## 3. Testability Seams & Test Doubles
- **Real Collaborators (`[TEST-002]`, `[TEST-003]`)**: Pure immutable `SwiftEditCore` structs/enums (`DocumentSession`, `DocumentSnapshot`, `BracketMatcher`, `BacktickHighlightScanner`, `MarkdownSmartNewlineEngine`, `WorkspaceTabSession`, `SidebarItemNameValidator`) and `SwiftEditUI` value-type projections (`PurpleThemePalette`, `EditorZoomController`, `SidebarLayoutGeometry`, `SwiftEditBrandLogoGeometry`, `AboutSheetDescriptor`).
- **Isolation Seams (`[TEST-003]`, `[TEST-004]`)**: Ephemeral per-test temporary directories under `FileManager.default.temporaryDirectory`, isolated `UserDefaults(suiteName: UUID().uuidString)`, counting `SecurityScopedResourceAccessing` fakes, `FileSystemProviding` and `DesktopWorkspaceIntegrating` fakes, and zero shared mutable global state or `Task.sleep`.

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | EARS requirements and declarative Given/When/Then scenarios cover all 13 user items and 4 modified living specs (`[SDD-001]`). |
| Path coverage completeness | Verified | Every unit lists `>= 1` positive (`P1..P7`) and `>= 1` negative (`N1..N10`) linear Arrange-Act-Assert `@Test` cases (`[TEST-001]`, `[TEST-002]`). |
| Security traits tagged | Verified | Abuse cases (`N2`, `N4`, `N6`, `N9`, `N10`) are explicitly tagged `- **Trait**: security` and mapped to STRIDE mitigations (`[SEC-002]`..`[SEC-012]`). |
