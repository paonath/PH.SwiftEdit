# Step 03: Author `design.md`, `threat-model.md`, and `test-plan.md`

1. **`design.md`**:
   - Context, Goals / Non-Goals, optional uncommented `## Architecture Memory & Module Boundaries (AR-###)` section (declaring `- **AR-001**:` module/ring placement and `- **AR-018**:` Saga/Coordinator non-authority invariants for multi-context changes), Decisions, Risks / Trade-offs, Migration Plan, and `## Security Review` with `- Verdict: approved`, enforcing **KISS-First + Pragmatic SOLID** (`the kiss-and-solid-principles skill`: keep architectural patterns KISS-compliant, apply SOLID in OOP, and avoid over-engineered hierarchies).
2. **`threat-model.md`**:
   - Asset Boundaries, 6-category STRIDE table (Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege), Abuse Cases, and `## 4. Security Review Verdict` with `- Verdict: approved`.
3. **`test-plan.md`**:
   - Path Coverage Matrix, test automation strategy and runner commands, linear Arrange-Act-Assert (`GIVEN-WHEN-THEN`) testability seams preferring real objects/fakes over brittle mocks, AI-Readiness table.

## Normative Requirements (EARS)
- The Architecture and Threat Author SHALL document all 6 STRIDE threat categories in `threat-model.md` and record `- Verdict: approved` in both `design.md` and `threat-model.md`.
