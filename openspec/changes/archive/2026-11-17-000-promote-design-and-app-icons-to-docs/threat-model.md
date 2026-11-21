# Threat Model: Promote Concept E2 Brand Icons, AppIcon Sets, Color Schemes, and UI Previews to docs/design/

## 1. Asset Boundaries & Trust Zones
- **Untrusted / Ephemeral Input Zone (`reasoning/001_project-constitution/deliverables/`)**: Pre-development design Markdown files, SVG vector master, UI preview PNGs, and `AppIcon.appiconset` bundles authored on a local macOS workstation (originally containing `file:///Users/...` absolute URIs).
- **Canonical Tracked Repository Zone (`docs/design/` & `README.md`)**: Version-controlled documentation and Xcode-consumable icon catalogs bound by `[UI-001]`, `[SEC-003]`, `[SEC-004]`, and `[SEC-005]`. Every relative reference must resolve via `URL.resolvingSymlinksInPath()` inside `docs/design/`.
- **Offline Verification Boundary (`Scripts/verify-design-assets.swift`)**: Pure local Swift 6 CLI verifier executing 100% offline (`[SEC-004]`) using `Foundation` and `ImageIO` over bounded files (`<= 16 MiB` per asset) and isolated `--self-test` fixtures in `./.tmp/test-results/` (`[SEC-009]`, `[SEC-010]`).

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | Counterfeit or mismatched `AppIcon.appiconset` PNGs claiming Retina dimensions in `Contents.json` while supplying altered dimensions or wrong alpha modes (`[UI-001]`). | `Scripts/verify-design-assets.swift` parses `Contents.json` and cross-checks actual `ImageIO` pixel width, pixel height, and `kCGImagePropertyHasAlpha` against every declared `idiom`, `size`, and `scale` slot (`[TEST-007]`). |
| Tampering | Symbolic link injection or `..` path traversal in Markdown links or `Contents.json` `filename` entries referencing files outside `docs/design/` (`CWE-22`, `[SEC-003]`). | Reject any path containing `..` or leading `/`, reject symlinks inside `.appiconset`, and verify `resolvedURL.path` remains strictly prefixed by the canonical `docs/design/` directory path (`[SEC-003]`). |
| Repudiation | Silent divergence between `openspec/Constitution.md` (`v1.2.0`) color/icon rules and promoted `docs/design/` assets without auditable verification output. | Deterministic Swift 6 CLI verifier emits explicit per-rule pass/fail diagnostics and non-zero exit codes traceable to `[AR-001]`, `[UI-001]`, `[UI-002]`, and `[SDD-001]`. |
| Information Disclosure | Residual `file:///Users/<username>/...` workstation paths or embedded credentials leaked inside `docs/design/*.md` or `README.md` (`CWE-200`, `[SEC-005]`). | Rewrite all promoted Markdown links to relative paths and scan `docs/design/**/*.md` and `README.md` to block `file://`, `/Users/`, and secret token patterns (`[SEC-005]`). |
| Denial of Service | Decompression bomb, malformed image header, or oversized binary committed into `docs/design/assets/` exhausting `ImageIO` memory during CI/local verification (`CWE-400`). | Enforce a strict `16 MiB` file size cap before reading bytes or invoking `CGImageSourceCreateWithURL` with `kCGImageSourceShouldCache: false`. |
| Elevation of Privilege | Malicious `<script>`, `<foreignObject>`, `javascript:` URI, or XML external entity (`<!ENTITY`) inside `logo-e2-refined.svg` executing in Markdown/SVG previewers (`CWE-79`, `CWE-611`). | Scan SVG UTF-8 text to forbid `<script`, `<foreignobject`, `javascript:`, `onload=`, `onerror=`, and `<!entity` constructs while keeping runtime execution 100% offline (`[SEC-004]`). |

## 3. Abuse Cases & Negative Scenarios
- **Abuse Scenario `N2` (`CWE-22` Path/Symlink Traversal & `CWE-200` Host URI Leak — `Trait: security`)**: A Markdown document under `docs/design/` contains `[leak](../../../etc/passwd)`, a symlinked asset pointing outside `docs/design/`, a residual `file:///Users/...` path, or an `<script>` tag inside `logo-e2-refined.svg`; the verifier rejects the tree with exit status `2` (`[SEC-003]`, `[SEC-005]`).
- **Abuse Scenario `N4` (`AppIcon` Alpha Violation, Symlink Entry, or Oversized Asset — `Trait: security`)**: An iOS `AppIcon.appiconset` PNG includes an alpha channel (`hasAlpha == true`, violating App Store Connect `ITMS-90717` and `[UI-001]`), a macOS icon lacks outer transparency (`hasAlpha == false`), a `Contents.json` `filename` traverses directories or resolves to a symlink, or an asset exceeds `16 MiB`; the verifier rejects the catalog with exit status `2` (`[UI-001]`, `[SEC-003]`, `[TEST-007]`).

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-17
- Verdict: approved
- Status: approved
- Open items: none
