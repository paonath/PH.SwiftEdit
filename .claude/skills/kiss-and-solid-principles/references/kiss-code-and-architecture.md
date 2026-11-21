---
name: kiss-code-and-architecture
description: Authoritative KISS (Keep It Simple, Stupid) reference for production code and software architecture, distilling AlgoMaster KISS, Kent Beck's 4 Rules of Simple Design, YAGNI, and the Non-Simplification Security Floor.
---

# KISS in Production Code and Software Architecture

## 1. Origin & Core Engineering Meaning
- **Origin**: **KISS** (*Keep It Simple, Stupid*) was coined by the **U.S. Navy** in **1960** (attributed to Lockheed Skunk Works aircraft engineer Kelly Johnson): systems work best when kept simple rather than made complex; unnecessary complexity must be avoided so systems can be repaired and modified reliably under pressure (`algomaster.io/learn/lld/kiss`).
- **Software Translation**: Simple code is **not** lazy, sloppy, or feature-stripped code; it is code with zero accidental complexity across three dimensions:
  1. **Easy to Read**: A developer understands what a method or class does immediately without tracing 30 minutes of indirection.
  2. **Easy to Understand**: Control flow follows a natural, predictable path without hidden side effects or clever tricks.
  3. **Easy to Change**: Modifying a behavior does not silently break abstractions three layers deep.

## 2. Breaking the Complexity Cycle
Every over-engineered codebase degrades through a predictable feedback loop (**The Complexity Cycle**):
`Hard-to-understand class` -> `A subtle bug slips in` -> `Someone patches it with a defensive workaround` -> `The workaround adds accidental complexity` -> `The class becomes even harder to understand` -> `Eventually nobody dares touch it and the team rewrites from scratch`.
- **KISS Mandate**: Break the Complexity Cycle at step 1 by refusing speculative indirection and keeping control flow explicit.

## 3. Case Study: Over-Engineered Calculator vs. Simple Calculator
When asked to build a basic 4-operation calculator (`+`, `-`, `*`, `/`):

| Dimension | Over-Engineered Calculator (KISS Violation) | Simple Calculator (KISS Compliant) |
| :--- | :--- | :--- |
| **Type Count** | **6 types**: `Operation` interface + `Addition`, `Subtraction`, `Multiplication`, `Division` classes + delegating `Calculator` class | **1 class**: `Calculator` with a single `calculate(op, a, b)` method |
| **Control Flow** | Polymorphic dispatch table + registration wiring ceremony for 4 fixed arithmetic operators | Direct `switch` / `match` / `if` dispatch with an explicit division-by-zero guard (`b == 0`) |
| **Cognitive Cost** | Navigating 6 files and constructor maps to inspect 4 lines of arithmetic | 15 self-contained lines readable in 5 seconds |
| **When to Evolve** | Only if the domain genuinely grows to `>= 20` pluggable scientific/custom user-defined operators | **Build for the problem you have today, not the speculative future you imagine (YAGNI)** |

## 4. The 4 Dangers of Accidental Complexity
1. **Harder to Read**: Every extra abstraction layer, generic wrapper, or indirection hop taxes working memory.
2. **More Places for Bugs to Hide**: Edge cases, null states, and race conditions conceal themselves in glue code between layers.
3. **Slower Onboarding**: New engineers spend days learning bespoke internal micro-frameworks instead of domain logic.
4. **Poor Debuggability**: Stack traces spanning 15 proxy/interceptor/factory frames obscure the root failure site.

## 5. The 7 Signs You Are Violating KISS
1. **Speculative Single-Implementation Interface**: Adding an interface before a second implementation exists (outside standard DI-registered application/domain services, repositories, or I/O testability seams).
2. **Reflection Over Direct Calls**: Using runtime reflection, dynamic invocation, or `eval()` (`CWE-94`) where a direct method call or typed dispatch suffices.
3. **"Just in Case" Layers**: Adding pass-through manager/helper/adapter layers that only forward arguments unchanged.
4. **Flag-Driven Deep Nesting**: Writing methods with 5+ optional boolean/nullable parameters and `> 3` levels of nested `if/else` conditionals instead of guard clauses (`early return`).
5. **Clever Recursion Over Simple Loops**: Using recursion (risking stack overflow) where a flat `for`/`foreach` loop or comprehension is clearer.
6. **Three-Class Hop to Understand One Behavior**: A developer cannot understand what one class does without reading at least 3 other classes first.
7. **Boilerplate Eclipse**: Ceremonial wiring, mappers, and factories outweigh actual domain business logic.

## 6. The 5 Actionable Guidelines to Apply KISS
1. **Write Code for Humans, Not Machines**: Use intention-revealing identifiers (`customerOrderTotal`, `isInvoiceOverdue`) instead of cryptic abbreviations (`x`, `calc2`) or compressed nested ternaries.
2. **Avoid Premature Abstraction**: Wait until duplication and variation axes are proven (`Rule of Three`) before extracting generic frameworks.
3. **Favor Composition Over Inheritance**: Assemble behavior from small, focused collaborators rather than deep (`> 2` level) class inheritance trees.
4. **Keep Functions Short and Cohesive**: Every function should be describable in one clear sentence without conjunctions (*"and"*).
5. **Use Familiar Constructs**: Prefer idiomatic standard-library primitives (`List`, `Dictionary`/`Map`, `for` loops, `switch` expressions, records/dataclasses) over custom data structures.

## 7. The 3 Guardrails on When NOT to Simplify & Security Floor
1. **Don't Oversimplify Critical Systems (Non-Simplification Security Floor)**:
   - Aligns with Saltzer & Schroeder's (1975) *Economy of Mechanism*: keep the design simple and small so it can be audited, **never** strip essential reliability or security controls.
   - **Mandatory Controls**: Never cite KISS to omit boundary input validation (`CWE-20`), parameterized database queries (`CWE-89`), authentication and object/property authorization checks (`BOLA`/`BOPLA`), authenticated encryption (`AES-GCM`), transaction error handling, GDPR Art. 5/17 PII redaction in logs (`CWE-532`), or STRIDE negative tests (`Rule G3`).
2. **Avoid Duplicating Logic Just to Keep Things "Simple" (KISS + DRY Synergy)**:
   - Copy-pasting the same 15-line validation or calculation block across 5 callers violates both DRY and KISS because a bug fix must be remembered in 5 places. Extract a single, well-named helper function.
3. **Know Your Audience (Standard Idioms Are Simple)**:
   - Standard stack idioms familiar to the team (constructor Dependency Injection, `async/await`, Angular `signal()`/`computed()`, Python context managers `with`) are simpler than reinventing ad-hoc manual plumbing.

## 8. Kent Beck's 4 Rules of Simple Design (Priority Order)
Per Martin Fowler (`martinfowler.com/bliki/BeckDesignRules.html`), evaluate simplicity in strict priority order:
1. **Passes the Tests**: The system works and satisfies all functional and security requirements.
2. **Reveals Intention**: The code clearly communicates its purpose to the next reader.
3. **No Duplication (DRY of Knowledge)**: Every piece of authoritative business knowledge has a single unambiguous representation.
4. **Fewest Elements**: Remove any class, method, parameter, or hierarchy that does not serve rules 1–3.
