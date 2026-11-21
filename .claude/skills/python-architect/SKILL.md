---
name: python-architect
description: "Progressive-disclosure Python 3.10-3.13+ architecture skill covering AI skill/plugin blackbox CLI scripts, cross-platform Unix/Windows systems, DDD/Clean boundaries, memory/speed optimization, unittest/pytest TDD, and PEP 257 docstrings."
---

# Python Architect Skill

## Core Engineering Pillars

- **Efficiency, Readability, and Performance**: Write clean, idiomatic Python 3.10–3.13+ optimized for low memory footprint and speed (`@dataclass(frozen=True, slots=True)`, generators/iterators, `asyncio` task groups, streaming I/O).
- **TDD and DDD Native**: Drive modules via RED-GREEN-REFACTOR TDD (`unittest`, `pytest`) and tactical/strategic DDD (`domain-driven-design`).
- **AI Skill & Plugin Blackbox CLI Architecture**: Design self-contained, standard-library-first CLI scripts inside skill `scripts/` directories and plugins with `--help`, `--json`, and deterministic exit codes (`0`, `1`, `2`).
- **Cross-Platform Unix & Windows Portability**: Guarantee identical behavior across macOS, Linux, and Windows (`pathlib.Path`, explicit `encoding="utf-8"`, safe atomic file writes, `subprocess.run(..., shell=False)`).
- **GoF and Pythonic Patterns**: Apply idiomatic structural and behavioral patterns via `oop-design-patterns__oop-design-patterns` (`Protocol`, `@dataclass`, strategy functions).
- **KISS-First & Pragmatic SOLID**: Consult `the kiss-and-solid-principles skill` (`Single-Reference Lock`) to prefer **KISS** before over-engineering, keep architectural patterns KISS-compliant, and apply **SOLID** across all Python OOP code (structural `typing.Protocol` ports, Rule of Three `>= 3` for multi-class GoF hierarchies, flat AAA tests, concise PEP 257 docstrings, Non-Simplification Security Floor).
- **Zero Inline Coding Rules**: Normative coding rules live exclusively in `the python-coding-standards rule` and `the security-secrets-policy rule`.

## Discovery-First Existing Project Rule

1. **Inspect Existing Topology First**: Query TokenSave (`tokensave_context`, `tokensave_search`) and inspect `pyproject.toml`, `requirements.txt`, existing scripts/packages, `AGENTS.md`, and living specifications before proposing any layout.
2. **Respect Established Architecture**: Always conform to the module organization, test runner (`unittest` vs `pytest`), and CLI conventions already established in the target repository.
3. **Greenfield Selection**: Only propose a new package or CLI topology when creating a greenfield project or skill script.

## Progressive-Disclosure Reference Index (`Single-Reference Lock`)

Load **at most ONE** `references/<file>.md` per turn or sub-agent invocation based on the active architectural concern:

| Reference File | Architectural Scope |
| :--- | :--- |
| `references/ai-skill-and-plugin-cli-scripts.md` | AI skill/plugin helper scripts (`scripts/*.py`), `argparse`, `--json`/`--help` contracts, exit codes (`0`/`1`/`2`), `CWE-22`/`CWE-78` sandboxing |
| `references/cross-platform-unix-windows-systems.md` | Cross-platform `pathlib.Path`, atomic writes, file locking, CRLF/LF normalization, signals, and Unix/Windows process management |
| `references/ddd-clean-architecture-and-performance.md` | Python DDD aggregates, `Protocol` ports, `@dataclass(slots=True)`, generator streaming, `asyncio` concurrency, and memory profiling |
| `references/tdd-pytest-unittest-and-docstrings.md` | Deterministic `unittest`/`pytest` suites, sandboxed `TemporaryDirectory` fixtures, CLI subprocess testing, and PEP 257/484 docstrings |

## Self-Evolution Reference Proposal Gate

When recurring project patterns reveal an architectural domain not covered by the existing `references/*.md` catalog:
1. Formulate a structured proposal specifying the candidate filename (`references/<slug>.md`), target scope, and key architectural invariants.
2. Validate that `<slug>.md` matches `^[a-z0-9]+(-[a-z0-9]+)*\.md$`, contains no `..` or path separators (`CWE-22`), and stays `< 150` lines.
3. Prompt the user via `AskUserQuestion` for explicit confirmation before creating or modifying any file inside `references/`. Never auto-create or overwrite reference files autonomously.

## Behavioral Contracts (EARS & BDD)

- WHEN a Python architecture task begins, the python-architect skill SHALL inspect project layout via TokenSave before proposing any structure.
- The python-architect skill SHALL enforce Single-Reference Lock by loading at most one reference module per invocation.
- IF a candidate reference slug fails regex validation or lacks AskUserQuestion approval, THEN the python-architect skill SHALL block the file write.

```gherkin
Feature: Python Architect Progressive Disclosure
  @REQ-PY-001
  Scenario: Inspect project topology and enforce single-reference loading
    Given an existing Python package with CLI scripts
    When the architect designs cross-platform file handling
    Then project layout is inspected before structural recommendations
    And at most one reference module is loaded into context

  @REQ-PY-002
  Scenario: Reject unapproved or unsafe reference proposals
    Given a proposed reference slug violating kebab-case validation
    When the self-evolution gate evaluates the proposal without human confirmation
    Then the reference file creation is blocked
```
