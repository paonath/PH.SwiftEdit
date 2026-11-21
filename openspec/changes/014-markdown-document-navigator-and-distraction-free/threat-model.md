# Threat Model: Markdown Document Navigator and Distraction-Free Mode

## 1. Asset Boundaries & Trust Zones
Assets: the in-memory document snapshot of the active tab and the user's editing focus. The only input is document text (untrusted, possibly huge or malformed). No file, network, or subprocess boundary is crossed. [SEC-012]

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | Heading text imitating UI labels such as `H1` badges | Badge rendered from parsed level only; titles drawn as plain `Text`, never interpreted |
| Tampering | Stale heading offsets applied after the document changed | Offsets re-validated against the current snapshot revision and clamped before selection |
| Repudiation | Navigation altering content silently | Navigation only changes selection; zero text mutation, no Undo entry |
| Information Disclosure | Headings of another tab shown in the palette | Outline computed from the active tab snapshot only; cleared on close |
| Denial of Service | Huge file with millions of `#` lines or very long lines | Single O(n) pass, cap 5000 headings, line length cap `MarkdownLineIndex.maxLineUTF16`, nothing computed while closed |
| Elevation of Privilege | Distraction-free hiding save or safety banners for binary files | Binary read-only banner and quarantine rules stay enforced; mode only hides chrome, never bypasses guards |

## 3. Abuse Cases & Negative Scenarios
- Document with 100000 `# x` lines: outline truncated at 5000, UI stays responsive.
- Heading containing control characters or 100000 characters: title truncated for display, offset intact.
- Binary tab with `⌥\`: navigator refuses to open.

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-20
- Verdict: approved
- Open items: none
