---
name: kiss-testing-and-technical-docs
description: Actionable KISS guidelines for unit/integration testing (linear Arrange-Act-Assert, real objects/fakes over brittle mocks) and technical documentation (Minimum Viable Documentation, high-density tables/Mermaid, why-focused docstrings).
---

# KISS in Automated Testing and Technical Documentation

## 1. Why KISS Matters Doubly in Tests and Documentation
Production code has tests to verify its behavior, **but tests and documentation have no unit tests of their own**. When a unit test contains complex branching or 40 lines of mock setup, bugs hide inside the test itself; when technical documentation repeats obvious code signatures in verbose prose, readers ignore it and it drifts out of sync.

## 2. KISS in Unit, Integration, and TDD Testing (`[RED]` -> `[GREEN]` -> `[REFACTOR]`)

| Testing Dimension | Anti-Pattern (Violates KISS) | KISS-Compliant Standard |
| :--- | :--- | :--- |
| **Test Body Structure** | Interleaving setup, assertions, loops, and conditional checks | Strict linear **Arrange -> Act -> Assert** (`GIVEN` / `WHEN` / `THEN`) with visually separated blocks |
| **Control Flow in Tests** | `if/else`, `for/while` loops, `try/catch` swallowing exceptions, or dynamic test generation | **Zero branching or loops** inside test methods; use parameterized test attributes (`[Theory]`/`[InlineData]`, `it.each`, `@pytest.mark.parametrize`, `subTest`) |
| **Collaborator Strategy** | Mocking 6 internal classes with brittle `.Verify(..., Times.Once)` call-order choreography | Instantiate **real domain objects/value objects** and use lightweight deterministic **fake** or in-memory stub implementations at I/O seams (`TimeProvider`, `IFileSystem`, `HttpTestingController`) per Google Testing Blog (*Prefer Fakes Over Mocks*) |
| **Assertion Focus** | Asserting private implementation details or internal method call sequences | Assert observable **state and output behavior** (return value, persisted state, emitted event, or specific thrown exception type/message) |
| **Setup Size** | 50+ lines of noisy inline object construction repeated in every test | Extract a concise helper factory (`create_valid_order(**overrides)`) or Object Mother when `Arrange` exceeds **10 lines** |
| **Path & Security Parity** | Writing only happy-path tests or dropping negative tests to "save time" | Maintain explicit positive (`P#`) and negative/abuse (`N#`) scenarios; **never** drop `Trait: security` or `Rule G3` negative tests |

### Canonical Linear AAA Test Template
```python
def test_p1_apply_discount_reduces_total_for_eligible_order() -> None:
    """[Path: P1] [Trait: positive] Eligible order receives exact percentage discount."""
    # Arrange (GIVEN)
    order = Order(subtotal=Decimal("100.00"), coupon_percent=15)
    # Act (WHEN)
    total = calculate_net_total(order)
    # Assert (THEN)
    assert total == Decimal("85.00")
```

## 3. KISS in Technical Documentation (`Minimum Viable Documentation`)
Following the *Google Developer Documentation Style Guide* (**Minimum Viable Documentation**): a short, accurate, high-density document is always superior to a sprawling, repetitive manual.
1. **Delete Conversational Filler**: Start directly with the architectural decision, contract, or command. Omit marketing preambles (*"In this document we will explore..."*).
2. **Prefer Structured Tables and Mermaid Diagrams Over Prose**:
   - Replace multi-paragraph comparisons or routing logic with a compact Markdown table.
   - Replace complex multi-actor sequences or state transitions with a single valid `Mermaid` diagram (`flowchart TD`, `sequenceDiagram`, `stateDiagram-v2`) adhering to `the mermaid-flow-diagrams skill`.
3. **Single Source of Truth (DRY in Docs)**: Reference canonical specifications, schemas, or commands instead of copy-pasting long code blocks that silently go stale.
4. **Progressive Disclosure**: Keep entry-point documents (`README.md`, `SKILL.md`, `AGENTS.md`) concise routers and place deep domain/stack specifics in dedicated reference modules.

## 4. KISS in In-Code Documentation (`[DOC]` Tasks & Docstrings)
When executing `[DOC]` tasks in `the myspec-apply skill` or documenting public APIs across languages:

| Language / Stack | Standard Format | KISS Documentation Rule (*Explain WHY, Never Restate WHAT*) |
| :--- | :--- | :--- |
| **C# / .NET** | XML Docs (`/// <summary>`, `<param>`, `<returns>`, `<exception>`) | State domain invariants, units/timezones (e.g. UTC), nullability, and thrown exceptions; never write `/// <summary>Gets or sets the Id.</summary>` |
| **TypeScript / Angular** | TSDoc (`/** ... */`, `@param`, `@returns`, `@throws`) | Document Signal reactivity invariants, SSR/hydration constraints, and accessibility contracts |
| **Python 3.10+** | PEP 257 Docstrings (`Args:`, `Returns:`, `Raises:`) | Document preconditions, complexity/streaming bounds, exit codes, and error conditions in 1–3 concise sentences |
| **Bash / Zsh / PowerShell** | Function Header Block (`# Purpose:`, `# Args:`, `# Exit Codes:` / `.SYNOPSIS`) | Document positional arguments, required environment variables, idempotency, and non-zero failure exit codes |

### Anti-Pattern vs. KISS Docstring Comparison
- **Bad (Tautological Noise — Violates KISS)**:
  `# Increment retry counter by one and return the retry counter.`
- **Good (High-Signal Engineering Context — KISS Compliant)**:
  `# Cap exponential backoff at MAX_RETRIES (5) to prevent thundering-herd reconnect storms during upstream outages.`
