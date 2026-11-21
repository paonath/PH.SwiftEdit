---
name: ears-syntax-standards
description: >-
  Authoritative skill for writing, linting, and governing software and system requirements using the
  Easy Approach to Requirements Syntax (EARS). Covers all 6 canonical patterns (Ubiquitous, Event-driven,
  State-driven, Optional, Unwanted Behaviour, Complex), active voice, single-SHALL atomicity, and deterministic
  CLI validation via scripts/ears_validate.py. Trigger for: EARS, requirements syntax, requirements engineering,
  acceptance criteria formulation, IF-THEN unwanted behaviour, DO-178C requirements, system shall.
---

# EARS Syntax Standards

Governed by Alistair Mavin et al. (Rolls-Royce, IEEE RE'09 & IEEE Software 2019), this skill enforces clear, unambiguous natural language requirements through 6 temporal patterns and deterministic linting.

## The 6 Canonical EARS Patterns

| Pattern | Template | Core Usage |
|---|---|---|
| **Ubiquitous** | `The <system> SHALL <response>` | Invariant, continuous system properties (no trigger) |
| **Event-Driven** | `WHEN <trigger>, the <system> SHALL <response>` | Discrete instantaneous event trigger |
| **State-Driven** | `WHILE <state>, the <system> SHALL <response>` | Valid during an active sustained state/interval |
| **Optional Feature** | `WHERE <feature is included>, the <system> SHALL <response>` | Applicable only if feature/hardware is present |
| **Unwanted Behaviour** | `IF <unwanted condition>, THEN the <system> SHALL <response>` | Errors, faults, timeouts, boundary rejections |
| **Complex Combination** | `[WHERE <f>,] [WHILE <s>,] [WHEN <t>,] the <system> SHALL <r>` | State + Trigger or State + Unwanted combination |

## Core Syntactic Rules

1. **Atomicity**: Exactly **ONE** `SHALL` per statement. Split conjoined behaviors ("and") into separate requirements.
2. **Active Voice**: Explicit system subject (`the <system name> SHALL`). Banned: passive voice (`SHALL BE`).
3. **No Vague Qualifiers**: Strictly forbid untestable adjectives (`fast`, `user-friendly`, `robust`, `adequate`, `etc.`, `and/or`).
4. **Mandatory Unwanted Handling**: For every trigger or state, formulate the corresponding `IF ... THEN` failure scenario.

## Progressive Disclosure Reference Modules

Load under Single-Reference Lock based on current need:
- `references/canonical-patterns.md`: Deep dive into all 6 patterns, formal grammar, and enterprise examples.
- `references/syntactic-rules.md`: Single-SHALL, active voice, forbidden words catalog, and precision metrics.
- `references/anti-patterns-and-remedies.md`: Common natural language pitfalls and step-by-step refactoring guides.
- `references/safety-and-aerospace-lineage.md`: DO-178C, Rolls-Royce CS-E 50 background, and audit traceability.

## Black-Box Execution

- **Do not read** script source before running it; the scripts are tested black boxes.
- Run commands from the skill base directory or pass the script path from any working directory (skill-relative path anchoring).
- Supports repository skills, Claude mirror, global user configuration, and Windows environments.
- Run the script with `--help` for options not listed below.
- Read the source only after a non-zero exit that stderr does not explain.

| Command | Parameters | Stdout | Exit codes |
|---|---|---|---|
| `python3 ./scripts/ears_validate.py` | `--file "<path>"`, `--text "<string>"`, `--json` | Human or JSON report | `0` valid, `1` violation, `2` error |

