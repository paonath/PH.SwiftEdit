---
name: bdd-gherkin-specifications
description: >-
  Authoritative skill for formulating, governing, and automating Behaviour-Driven Development (BDD)
  specifications using Gherkin v6+. Covers collaborative discovery (Example Mapping, Three Amigos),
  declarative domain-level scenarios, polyglot test automation across 7 runtimes (.NET Reqnroll,
  Angular Playwright-BDD, Python pytest-bdd, Java Cucumber-JVM, Go Godog, Swift, Bash), and deterministic
  CLI validation via scripts/bdd_validate.py. Trigger for: BDD, Gherkin, Cucumber, Reqnroll, Given When Then,
  Feature file, Scenario Outline, Example Mapping, executable specifications.
---

# BDD Gherkin Specifications

Governed by Dan North's original BDD foundation, Aslak Hellesøy's Cucumber/Gherkin standards, and Matt Wynne's Example Mapping, this skill guides the creation of executable, human-readable behavioral specifications.

## The BDD Lifecycle: Three Core Practices

1. **Discovery**: Three Amigos (Dev, QA, Business) explore domain rules and edge cases using Example Mapping (Rules, Examples, Questions).
2. **Formulation**: Document examples as clean Gherkin `.feature` files using declarative domain language.
3. **Automation**: Connect Gherkin steps to automated test runners across your target runtime.

## Core Principles

- **Declarative Domain Language**: Step definitions must represent business intent, NEVER imperative UI clicks (`#btn-id`, xpath).
- **Mandatory Traceability**: Every Scenario or Rule must carry an explicit traceability tag: `@REQ-<CAPABILITY>-<NNN>`.
- **Zero Secrets in Examples**: Never commit live API tokens, passwords, or PII into `Examples:` tables.

## Progressive Disclosure Reference Modules

Load under Single-Reference Lock based on active stack:
- `references/gherkin-grammar-and-rules.md`: Gherkin v6+ syntax (`Feature`, `Rule`, `Background`, `Scenario Outline`, `Examples`).
- `references/discovery-and-example-mapping.md`: Collaborative Three Amigos workshop and 4-card Example Mapping.
- `references/declarative-vs-imperative.md`: Refactoring anti-patterns: converting brittle UI scripts to domain behavior.
- `references/dotnet-reqnroll-runner.md`: .NET C# Reqnroll + xUnit + in-memory `WebApplicationFactory`.
- `references/typescript-angular-playwright.md`: Angular Standalone + Playwright-BDD (`playwright-bdd`).
- `references/python-pytest-bdd-runner.md`: Python `pytest-bdd` scenario fixtures and outside-in testing.
- `references/polyglot-java-go-swift-bash.md`: Bindings for Java (`cucumber-jvm`), Go (`godog`), Swift (`Cucumberish`), and Bash (`BATS`).

## Black-Box Execution

- **Do not read** script source before running it; the scripts are tested black boxes.
- Run commands from the skill base directory or pass the script path from any working directory (skill-relative path anchoring).
- Supports repository skills, Claude mirror, global user configuration, and Windows environments.
- Run the script with `--help` for options not listed below.
- Read the source only after a non-zero exit that stderr does not explain.

| Command | Parameters | Stdout | Exit codes |
|---|---|---|---|
| `python3 ./scripts/bdd_validate.py` | `--dir "<path>"`, `--file "<path>"`, `--allow-untagged`, `--json` | Human or JSON report | `0` valid, `1` violation, `2` error |

