# Workflow 04: Global Verification & Quality Gate (`myspec-apply`)

1. **Formatting & Linting Gate**:
   - Run project linter/formatter on modified files.
2. **Global Regression Check**:
   - Run full project test suites to verify zero regressions.
3. **Security Scan**:
   - Run `security-secret-scanner` across modified files to ensure zero secrets or credentials are introduced.

## Normative Requirements (EARS)
- WHEN all tasks complete, the Global Verification Gate SHALL run formatting checks, full regression tests, and `security-secret-scanner` before handoff.
