---
area: "06-testing-fitness"
file: "architecture-fitness-and-quality.md"
rules: ["TEST-005", "TEST-006", "TEST-007", "TEST-008"]
---

# 06-testing-fitness/architecture-fitness-and-quality (TEST-005..TEST-008)

## Context
- fitness_tool: `{{ARCH_FITNESS_TOOL}}`
- crap_threshold: `CRAP <= 30, Critical Domain Coverage >= 85%`

## Rules
- **TEST-005**: Automated architecture fitness tests (`{{ARCH_FITNESS_TOOL}}`) SHALL verify ring dependency direction (`AR-006`) and module isolation (`AR-008`) on every build.
- **TEST-006**: Modified methods in `Core` domain modules SHALL maintain `CRAP <= 30` and `>= 85%` branch coverage across happy, boundary, and error paths (`P#/N#`).
- **TEST-007**: API and persistence adapters SHALL be verified via hermetic integration tests (`WebApplicationFactory` / ephemeral test containers).
- **TEST-008**: Gherkin BDD scenarios SHALL carry `@REQ-<CAP>-<NNN>` tags and use declarative business language with zero imperative CSS/XPath selectors.
