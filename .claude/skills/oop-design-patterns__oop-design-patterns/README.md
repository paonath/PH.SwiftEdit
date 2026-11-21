# OOP Design Patterns AI Agent Skill

A modular, production-ready AI Agent Skill providing authoritative architectural guidance and modern, idiomatic implementations for all 23 Gang of Four (GoF) object-oriented design patterns.

## Features

- **23 Dedicated Pattern Documents**: Organized by category under `references/`.
- **Tripartite Modern Code Examples**:
  - **C# (.NET 10)**: Primary constructors, records, pattern matching, keyed DI, and `ValueTask`.
  - **TypeScript (Angular v20+)**: Standalone components, reactive Signals (`signal`, `computed`), and `inject()`.
  - **Python (3.12+)**: PEP 695 generics, PEP 544 `Protocol`, `@dataclass(slots=True, frozen=True)`.
- **Standardized Applicability Rubric**: 4-part decision matrix (Rule of Three, Language-First, Micro vs Macro scoping, 3 Green Flags, 3 Red Flags, and Alternative Simplifications).
- **Autonomous AI Activation**: Compact root manifest (`SKILL.md`) structured for progressive disclosure and minimal token overhead.
- **Automated Validation**: Built-in Python test harness (`scripts/validate_skill.py`) verifying schema, catalog exhaustiveness, syntax, and zero-secrets compliance.

---

## Catalog at a Glance

| Category | Patterns (Count) | Description | Reference Folder |
|---|---|---|---|
| **Creational** | 5 | Decouple object creation from representation and usage | [`references/creational/`](./references/creational/) |
| **Structural** | 7 | Compose classes and objects into flexible, loosely-coupled structures | [`references/structural/`](./references/structural/) |
| **Behavioral** | 11 | Encapsulate communication, algorithms, and state transitions | [`references/behavioral/`](./references/behavioral/) |

### 1. Creational Patterns
- **[Abstract Factory](./references/creational/abstract-factory.md)**: Families of related/dependent objects without specifying concrete classes.
- **[Builder](./references/creational/builder.md)**: Separate construction of complex objects from their representation.
- **[Factory Method](./references/creational/factory-method.md)**: Defer instantiation to subclasses or factory delegates.
- **[Prototype](./references/creational/prototype.md)**: Clone existing instances using copy constructors or identity-guarded graphs.
- **[Singleton](./references/creational/singleton.md)**: Ensure exactly one thread-safe instance with immutable state.

### 2. Structural Patterns
- **[Adapter](./references/structural/adapter.md)**: Convert incompatible interfaces into expected target contracts.
- **[Bridge](./references/structural/bridge.md)**: Decouple abstraction from implementation so both can vary independently.
- **[Composite](./references/structural/composite.md)**: Tree structures representing part-whole hierarchies with uniform handling.
- **[Decorator](./references/structural/decorator.md)**: Attach responsibilities dynamically without inheritance ladders.
- **[Facade](./references/structural/facade.md)**: Unified high-level interface over a complex subsystem.
- **[Flyweight](./references/structural/flyweight.md)**: Share fine-grained intrinsic immutable state to support high volumes.
- **[Proxy](./references/structural/proxy.md)**: Surrogate placeholder controlling access, lazy loading, or caching.

### 3. Behavioral Patterns
- **[Chain of Responsibility](./references/behavioral/chain-of-responsibility.md)**: Pipeline of potential handlers processing a request.
- **[Command](./references/behavioral/command.md)**: Encapsulate requests as objects enabling undo/redo and queuing.
- **[Interpreter](./references/behavioral/interpreter.md)**: Grammar representation and AST evaluation for domain languages.
- **[Iterator](./references/behavioral/iterator.md)**: Sequential traversal of collections without exposing internal representation.
- **[Mediator](./references/behavioral/mediator.md)**: Encapsulate object interaction to prevent complex many-to-many coupling.
- **[Memento](./references/behavioral/memento.md)**: Capture and restore internal object state without violating encapsulation.
- **[Observer](./references/behavioral/observer.md)**: One-to-many change notification via reactive signals and streams.
- **[State](./references/behavioral/state.md)**: Dynamic behavior alteration based on internal state transitions.
- **[Strategy](./references/behavioral/strategy.md)**: Encapsulate interchangeable algorithms behind a common contract.
- **[Template Method](./references/behavioral/template-method.md)**: Define algorithm skeleton, deferring primitive steps to subclasses.
- **[Visitor](./references/behavioral/visitor.md)**: Execute operations across heterogeneous object structures.

---

## Validation & Testing

Execute the automated test harness:

```bash
python3 plugins/oop-design-patterns/skills/oop-design-patterns/scripts/validate_skill.py
```
