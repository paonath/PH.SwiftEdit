# Test Plan: Build SwiftEditUI (Concept E2 Purple Chrome, #FFFFFF/#000000 Inverted TextKit 2 Editor, 50%..300% Zoom, Diff View) and Xcode .app Shell with AppIcon.appiconset and nbgv

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `PurpleThemeZoomAndSafetyBanner` (`PurpleThemePalette`, `EditorZoomController`, `InspectionSafetyBannerState`) | `P1`: Resolves Concept E2 Purple (`#0B0614`, `#7C3AED`, `#A78BFA`, `#C4B5FD`) chrome tokens, `#FFFFFF`/`#000000` (`Light`) and `#000000`/`#FFFFFF` (`Black`) editor canvas tokens with `21:1` WCAG contrast (`>= 4.5:1` on chrome), scales font size across `50%..300%` (`Cmd++`, `Cmd+-`, `Cmd+0`, pane focus) without mutating text, and prepares confirmation prompts for `https://` links (`[UI-001..004]`, `[UI-008]`, `[UI-009]`). | `N1`: Clamps `zoomOut()` at `50%` and `zoomIn()` at `300%`; `N2` (`security`): Activates read-only binary warning banner (`canSave == false`, `canFormat == false`, `canPinTab == false`) on binary snapshots, detects Trojan Source BiDi scalars (`U+202E`, `U+2066`, `U+061C`) with exact UTF-16 offsets, and blocks `javascript:`/`file:`/`data:` external URI handoffs (`[DATA-003]`, `[SEC-004]`, `[SEC-012]`, `[UI-008]`). |
| `TextKit2EditorAndDiffCoordinator` (`WorkspaceEditorCoordinator`, `TextKit2BufferAdapter`, `DiffPaneCoordinator`) | `P2`: `@MainActor` coordinator updates `NSTextContentStorage` via scoped `performEditingTransaction` on dirty/viewport ranges, executes `Cmd+D` and `Format Document`/`Section`, switches `.light`/`.black` themes dynamically without reloading buffers, projects Side-by-Side Myers diff rows, and exposes VoiceOver descriptors + Reduce Motion suppression (`[AR-003]`, `[UI-005..012]`). | `N3`: Invoking `performCommandD` or `formatDocument` on a binary read-only tab sets `lastErrorBannerMessage` without mutating the buffer; `N4` (`security`): Projecting Markdown containing `<script>` or `<iframe>` tags marks raw HTML blocks as `isInertPlainTextHTML == true` without executing or stripping literal text (`[SEC-004]`, `[UI-006]`, `[UI-008]`, `[UI-009]`). |
| `XcodeAppShellAndPackagingFitness` (`EntitlementsFitnessValidator`, `InfoPlistVersionStamper`, `XcodeApp/` bundle resources) | `P3`: Verifies `XcodeApp/Assets.xcassets/AppIcon.appiconset` (10 macOS PNGs) and `XcodeApp/iOSAssets.xcassets/AppIcon.appiconset` (8 iOS PNGs), validates least-privilege macOS/iOS `.entitlements`, and stamps/verifies `CFBundleShortVersionString` (`"0.0.1"`) and `CFBundleVersion` (`"0.0.1-alpha1"`) in `XcodeApp/Info.plist` from `version.json` (`[AR-001]`, `[AR-014]`, `[SEC-001]`, `[TEST-007]`, `[TEST-008]`). | `N5`: Rejects malformed `version.json` or `Info.plist` payloads with `PackagingFitnessError`; `N6` (`security`): Rejects `.entitlements` plists missing `com.apple.security.app-sandbox` or enabling `network.client`, `network.server`, `files.all`, `temporary-exception`, or `cs.disable-library-validation` (`[SEC-001]`, `[SEC-004]`, `[SEC-008]`). |

## 2. Test Automation Strategy & Commands
- Unit test runner command: `swift test --parallel`
- Security trait / suite filter command: `swift test --parallel --filter Security`
- Coverage verification command: `swift test --parallel --enable-code-coverage`

## 3. Testability Seams & Test Doubles
- Real collaborators: Real `@MainActor` `NSTextContentStorage` inside `TextKit2BufferAdapter`, real `DocumentSession`, `MarkdownLintAndFormatEngine`, and `SearchDiffAndBracketEngine`, and real `XcodeApp/` plist/icon assets on disk.
- Isolation seams: Ephemeral `UserDefaults(suiteName:)` and in-memory plist `Data` fixtures for negative entitlement and version-stamping tests (`TEST-003`, `TEST-004`).

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | Given/When/Then scenarios defined in `specs/swifteditui-purple-zed-layout-textkit2-and-appicons/spec.md` (`REQ-001..REQ-004`) |
| Path coverage completeness | Verified | All 3 units cover positive (`P1..P3`) and negative (`N1..N6`) paths |
| Security traits tagged | Verified | Abuse cases `N2`, `N4`, and `N6` tagged `- **Trait**: security` (`[SEC-001]`, `[SEC-004]`, `[SEC-008]`, `[SEC-012]`, `[UI-006]`, `[UI-008]`) |
