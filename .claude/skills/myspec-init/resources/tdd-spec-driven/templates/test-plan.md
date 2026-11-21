# Test Plan: [Feature Name]

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `[UnitName]` | P1: [Description of nominal behavior] | N1: [Boundary or guard failure]; N2: [Security rejection] |

## 2. Test Automation Strategy & Commands
- Unit test runner command: `python3 -m unittest ...`
- Trait filter command: `pytest -m security ...`

## 3. Testability Seams & Test Doubles
- Real collaborators: [Domain models, state objects]
- Isolation seams: [TimeProvider, filesystem abstractions, network fakes]

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | Given/When/Then scenarios defined |
| Path coverage completeness | Verified | All units have P# and N# paths |
| Security traits tagged | Verified | Security abuse cases tagged trait: security |
