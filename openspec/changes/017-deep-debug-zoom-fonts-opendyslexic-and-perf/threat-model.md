# Threat Model: 3x Deep Debug Audit, Zoomed Tabs/Sidebar/Gutter, System & OpenDyslexic App Fonts and Extreme Performance Passes

## 1. Asset Boundaries & Trust Zones
- **Font binaries (new supply-chain asset)**: OpenDyslexic `.otf` files bundled as `SwiftEditUI` resources, downloaded once by the agent from the official upstream repository after per-file user confirmation, pinned by SHA-256 [SEC-008].
- **Preferences**: `UserDefaults` keys holding `FontChoice` per role (family names only, never paths) [DATA-008].
- **Installed system fonts**: read-only enumeration through `NSFontManager`; untrusted names.
- **Audit tooling**: compiled AX/CGEvent driver and QAHarness living only in `.tmp/`, executed with a temporary Accessibility grant; reports in `docs/qa/` [SEC-011].
- **Document buffers**: must remain untouched by typography and zoom (`BufferRevision` invariant) [BC-004].

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | A look-alike or malicious `.otf` replaces the bundled OpenDyslexic file, or a system font named `OpenDyslexic` shadows the bundled one | SHA-256 of every bundled file is verified before registration (fail-closed, entry disabled); the bundled face is resolved by PostScript name from the registered URL, never by family name lookup alone [SEC-008][SEC-012] |
| Tampering | Crafted preference values (`../../evil.otf`, 10 KB names, control characters) aim to load arbitrary fonts or crash decoding | `FontChoice` stores family names only, capped at 128 scalars and printable characters; unknown families resolve to the default; no API ever loads a font from a path taken from preferences [DATA-008][SEC-012] |
| Repudiation | Audit findings or perf claims not reproducible | Each report records commit, build configuration, the 3 run timings, the tool commands and the device; benchmarks are automated tests with goldens [TEST-005] |
| Information Disclosure | Audit artefacts (`sample`, `leaks`, AX dumps, screenshots) leak document contents or user paths | The audit only uses synthetic fixtures under `.tmp/qa-workspace`; reports contain metrics only; `.tmp/` is deleted after each run [SEC-011] |
| Denial of Service | A corrupt font file crashes CoreText registration; enumerating thousands of families on every render; extreme zoom causes layout loops | Registration result checked and errors swallowed fail-closed; font catalog computed once and cached; resolved `NSFont` instances cached per (choice, role, size, weight); metrics clamped `50%..300%` with min/max tab widths [UI-012][SEC-012] |
| Elevation of Privilege | Font registered system-wide or new entitlements added to reach user font folders; Accessibility grant left enabled | `CTFontManagerScope.process` only; zero `.entitlements` changes (Scope Guard `SDD-007`); manual step 4 revokes the Accessibility grant after the audit [SEC-001][SEC-004] |

## 3. Abuse Cases & Negative Scenarios
- **Tampered bundle**: a modified `OpenDyslexic-Regular.otf` (hash mismatch) leaves OpenDyslexic disabled in Settings and the app on the default font (`N7`).
- **Malicious preference**: `swiftedit.font.editor = "../../../tmp/x.otf"` or a 10,000-character value decodes to `.default` (`N4`).
- **Shadow family**: an installed system font named `OpenDyslexic` is never used for the `.openDyslexic` choice; the bundled verified face is (`N7`).
- **Stale cache**: switching font or zoom never renders with the previous font or metrics (`N11`).
- **Audit leakage**: no report line contains fixture text beyond the synthetic markers (`N2`).

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-21
- Verdict: approved # approved | changes-required
- Open items: none
