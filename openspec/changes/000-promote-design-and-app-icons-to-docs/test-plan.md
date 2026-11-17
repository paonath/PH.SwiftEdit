# Test Plan: Promote Concept E2 Brand Icons, AppIcon Sets, Color Schemes, and UI Previews to docs/design/

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `DesignDocsPromotionAndLinkIntegrity` (`DesignAssetsVerifier.verifyDocumentationAndAssets`) | `P1`: Verifies presence of `color-schemes-and-zed-layout.md`, `app-icons-riepilogo.md`, `logo-e2-refined.svg` (`#0B0614`, `#A78BFA`, `#C4B5FD`, `#7C3AED`), `logo-e2-refined-512.png` (`512x512`), 3 UI preview PNGs, intact `reasoning/001_project-constitution/deliverables/`, and valid relative links in `docs/design/*.md` and `README.md` (`[UI-001]`, `[UI-002]`, `[UI-004]`). | `N1`: Rejects missing promoted file or broken relative Markdown link with exit code `1`; `N2` (`security`): Rejects `../` traversal, symlink escaping `docs/design/`, residual `file://` or `/Users/` host URI, or `<script>`/`<!ENTITY` SVG content with exit code `2` (`[SEC-003]`, `[SEC-005]`). |
| `AppIconCatalogVerification` (`DesignAssetsVerifier.verifyAppIconCatalogs`) | `P2`: Decodes `macos/AppIcon.appiconset/Contents.json` (10 PNGs `16..1024 px`, `hasAlpha == true`) and `ios/AppIcon.appiconset/Contents.json` (9 slots -> 8 PNGs `40..1024 px`, `hasAlpha == false`) and verifies exact `size * scale` pixel dimensions via `ImageIO` (`[AR-001]`, `[UI-001]`, `[TEST-007]`). | `N3`: Rejects malformed `Contents.json`, missing slot/PNG, or `size * scale` pixel dimension mismatch with exit code `1`; `N4` (`security`): Rejects iOS `hasAlpha == true`, macOS `hasAlpha == false`, symlink/slash `filename` in `Contents.json`, or `> 16 MiB` payload with exit code `2` (`[UI-001]`, `[SEC-003]`). |

## 2. Test Automation Strategy & Commands
- Self-test runner command (executes all `P1, P2, N1, N2, N3, N4` isolated fixture tests): `swift Scripts/verify-design-assets.swift --self-test`
- Security trait filter command (executes `N2` and `N4` security abuse tests): `swift Scripts/verify-design-assets.swift --self-test --filter security`
- Live workspace verification command: `swift Scripts/verify-design-assets.swift --root .`

## 3. Testability Seams & Test Doubles
- Real collaborators: Real Swift `Codable` `Contents.json` manifests, real UTF-8 Markdown/SVG files, and real `CGContext` + `CGImageDestination` (`ImageIO`) RGBA/RGB PNG fixtures (with and without alpha channels) generated programmatically during `--self-test`.
- Isolation seams: Root directory injection (`DesignAssetsVerifier(rootURL: URL)`) backed by ephemeral fixture directories under `./.tmp/test-results/verify-design-assets-<uuid>/` cleaned deterministically via `defer { try? FileManager.default.removeItem(at: tempDir) }` — zero mocking frameworks (`[TEST-007]`).

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | Given/When/Then scenarios defined in `specs/design-assets-promotion/spec.md` (`REQ-001..REQ-003`) |
| Path coverage completeness | Verified | Both units declare explicit positive (`P1`, `P2`) and negative (`N1..N4`) paths |
| Security traits tagged | Verified | Abuse scenarios `N2` and `N4` tagged `- **Trait**: security` (`[SEC-003]`, `[SEC-005]`) |
