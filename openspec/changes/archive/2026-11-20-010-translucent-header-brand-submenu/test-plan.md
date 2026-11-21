# Test Plan: Root-ZStack Translucent Header Brand Submenu, Descriptive Action Badges, Single-Source SwiftEditCommands & Binary Quarantine Guards

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `HeaderSubmenuStateMachine` | P1: `120 ms` continuous dwell on brand/center header opens submenu (`0 ms` on explicit click toggle), `<= 180 ms` travel into submenu keeps it open, trailing Zoom/Appearance hover never opens when closed, and `topBarHeight` stays `36.0 pt` (`0.0 pt` layout shift) | N1: `< 120 ms` transient pass-through and active tab/sidebar drag keep submenu closed; `Escape` closes immediately and latches `isSuppressedUntilPointerExit == true` until pointer exit or explicit click |
| `HeaderCommandCatalog`, `SwiftEditCommands` & `SwiftEditWorkbenchModel` | P2: Catalog projects descriptive verb-noun titles + badges (`Duplicate Line or Selection` `⌘D`, `Format Markdown Document` `⇧⌘F`, `Format Markdown Section` `⌥⇧⌘F`, `Show/Hide Markdown Preview` `⌘P` with initial `showMarkdownPreview == false`), `formatActiveSection()` formats only the selected section in `+1` `BufferRevision`, CheatSheet lists `Cmd+P` & `Cmd+Option+Shift+F` (`P9`), and `scanSwiftEditUIViewsDirectory` reports zero violations (`P3`) | N2 [Security]: Binary read-only tab (`isBinaryReadOnly == true`) disables `Save Document`, `Save Document As…`, `Duplicate Line or Selection`, `Format Markdown Document`, and `Format Markdown Section` (`N11`) and blocks all five workbench methods with zero `BufferRevision` mutation and zero `savePanelProvider` calls; N3: `formatActiveSection()` on degraded or already-formatted buffers preserves text safely |

## 2. Test Automation Strategy & Commands
- Unit test runner command: `swift test --parallel`
- Targeted suite command: `swift test --filter TranslucentHeaderBrandSubmenuTests`
- Regression suite command: `swift test --filter "EditorUXLayoutThemeAndAboutTests|MinimalLayoutGutterAndParentNavigationTests|WorkbenchSearchLifecycleAndMenusTests|FullAppSemanticThemingAndWindowSyncTests"`

## 3. Testability Seams & Test Doubles
- Real collaborators: `HeaderSubmenuStateMachine`, `HeaderCommandCatalog`, `SwiftEditWorkbenchModel`, `DocumentSession`, `MarkdownLintAndFormatEngine`, `KeyboardShortcutsCheatSheetCatalog`, `ArchitectureImportScanner` (`[TEST-002]`, `[TEST-004]`).
- Isolation seams: Deterministic `Duration` step progression on `HeaderSubmenuStateMachine`, injectable `savePanelProvider: @MainActor () -> URL?` spy/stub on `SwiftEditWorkbenchModel`, ephemeral `UserDefaults(suiteName:)` preferences, and temporary `SessionRecoveryStore` directories (`[TEST-003]`, `[TEST-004]`).

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | Atomic EARS requirements (`<= 500` chars) and declarative Given/When/Then scenarios defined across 3 capability specs (`[SDD-001]`) |
| Path coverage completeness | Verified | Both units (`HeaderSubmenuStateMachine` and `HeaderCommandCatalog`/`SwiftEditWorkbenchModel`) define `P1..P3`, `P9`, `N1..N3`, `N11` (`[TEST-001]`, `[TEST-002]`) |
| Security traits tagged | Verified | Binary quarantine mediation and save-panel suppression scenarios (`N2`, `N11`) tagged `- **Trait**: security` (`[SEC-009]`) |
