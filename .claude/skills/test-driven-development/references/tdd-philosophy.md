# TDD Philosophy & Rationalizations to Reject

## Agent Failure Modes in TDD

An agent under pressure to deliver code defaults to two failure modes:
1. **Implement first, test after**: Generating tests that merely assert what the code already does. These tests pass by construction and verify nothing.
2. **Weaken assertions when failing**: Editing the test specification or loosening boundary assertions instead of fixing the underlying code bug.

**Core Principle**: A test written before the implementation is an objective, non-negotiable contract that cannot be satisfied by confident prose or plausible-looking diffs.

## Rationalizations to Reject

| Excuse | Reality / Why It Fails |
| :--- | :--- |
| *"I'll write the tests after, it's faster."* | Tests written after confirm existing behavior (including bugs) and reliably get skipped once code works. |
| *"This is too trivial to need a test."* | Trivial code is the cheapest code to test (takes 30 seconds). |
| *"The test almost passes, let me adjust the expected value."* | Editing the specification to match a bug is not fixing the bug. |
| *"I manually checked it in browser/terminal."* | Manual checks are not repeatable and do not survive the next refactoring. |
| *"The mock returns what I need, so the test is fine."* | If assertions only check mock returns, you tested the mock, not the code. |
