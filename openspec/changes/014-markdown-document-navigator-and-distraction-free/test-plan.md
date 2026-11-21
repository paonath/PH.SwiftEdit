# Test Plan: Markdown Document Navigator and Distraction-Free Mode

## 1. Path Coverage Matrix

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `MarkdownHeadingOutlineEngine` | P1: H1..H6 with level, title, offset | N1: fences, frontmatter, `#tag`, 7 hashes, 4-space indent ignored; N2: 100000 headings capped |
| `DocumentNavigatorState` | P1: filter and wrap-around selection | N1: empty outline or no match gives nil confirm |
| `DocumentNavigatorOverlay` | P1: `⌥\` open, confirm jump, ESC and `⌥\` close | N1: non-markdown/binary tab refuses open; stale offset clamped |
| `DistractionFreeMode` | P1: `⌥1` hides chrome, ESC and `⌥1` restore | N1: system full-screen exit resyncs flag; double toggle is idempotent |

Governing rules: [TEST-001][UI-005][UI-009][SEC-012].

## 2. Test Automation Strategy & Commands
- Unit test runner command: `swift test --filter DocumentNavigator`
- Full suite: `swift test`
- Build gate: `swift build`

## 3. Testability Seams & Test Doubles
- Real collaborators: `MarkdownLineIndex`, `SwiftEditWorkbenchModel` with in-memory sessions.
- Isolation seams: window full-screen action injected as a closure (`toggleFullScreen`) so tests assert calls without a real `NSWindow`.

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | Given/When/Then scenarios defined |
| Path coverage completeness | Verified | All units have P# and N# paths |
| Security traits tagged | Verified | Abuse cases tagged trait: security |
