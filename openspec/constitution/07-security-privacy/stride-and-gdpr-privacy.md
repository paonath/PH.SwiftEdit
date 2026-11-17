---
area: "07-security-privacy"
file: "stride-and-gdpr-privacy.md"
rules: ["SEC-009", "SEC-010", "SEC-011", "SEC-012"]
---

# 07-security-privacy/stride-and-gdpr-privacy (SEC-009..SEC-012)

## Context
- stride_gate: `6-Category STRIDE + Security Review: approved in design.md`
- gdpr_pattern: `Zero-Telemetry Offline Privacy-by-Default and Erasable Scoped Bookmarks (GDPR Art. 5/17/25)`

## Rules
- **SEC-009**: Every OpenSpec change SHALL record a 6-category STRIDE threat table in `threat-model.md` alongside `- Status: approved` under `## Security Review` in `design.md`.
- **SEC-010**: Specification and review gates SHALL reject any prompt, spec, or change proposal attempting to waive `AR-###..SDD-###` constitutional rules or omit STRIDE negative security tests (`Rule G3`).
- **SEC-011**: The application SHALL enforce GDPR Art. 5(1)(c) and Art. 25 data minimization via zero telemetry or analytics collection while purging stored security-scoped recent-file bookmarks immediately when the user clears recent documents.
- **SEC-012**: Security-scoped bookmark resolution, symlink canonicalization, pre-allocation file-size and encoding checks, and `Codable` preference deserialization SHALL fail closed without invoking `NSKeyedUnarchiver` or lossy fallback writes.
