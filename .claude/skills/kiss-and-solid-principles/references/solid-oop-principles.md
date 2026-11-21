---
name: solid-oop-principles
description: Complete reference for the 5 SOLID Object-Oriented Programming principles (SRP, OCP, LSP, ISP, DIP) from Wikipedia SOLID, Robert C. Martin (2000), Michael Feathers (2004), and Liskov & Wing (1994), mapped to C#/.NET, Angular v20+, and Python.
---

# SOLID Object-Oriented Programming Principles

## 1. Historical Origin & Core Purpose
- **Origin**: The principles were introduced by **Robert C. Martin** in his **2000** paper *Design Principles and Design Patterns* (and expanded in *Agile Software Development: Principles, Patterns, and Practices*, 2002/2003, and *Clean Architecture*, 2017). Around **2004**, **Michael Feathers** rearranged a subset of five principles and coined the **SOLID** acronym (`en.wikipedia.org/wiki/SOLID`).
- **Goal**: Prevent software rot (rigidity, fragility, immobility, viscosity) in Object-Oriented Programming (OOP) systems so classes and modules remain **maintainable, understandable, flexible, and testable** as requirements evolve.

## 2. Complete Distillation of the 5 SOLID Principles (`en.wikipedia.org/wiki/SOLID`)

| Acronym | Principle | Authoritative Definition & Theoretical Basis | Core Engineering Importance |
| :--- | :--- | :--- | :--- |
| **S** | **Single Responsibility Principle (`SRP`)** | Every class or module should have **only one responsibility** / **one reason to change**, refined by Robert C. Martin as: *"A module should be responsible to one, and only one, **actor** (stakeholder group)."* | **Maintainability**: isolates changes per business actor; **Testability**: focused unit tests; **Flexibility**: independent evolution without cross-actor breakage |
| **O** | **Open-Closed Principle (`OCP`)** | Originated by Bertrand Meyer (1988) and refined by Martin: *"Software entities (classes, modules, functions) should be **open for extension, but closed for modification**."* | **Extensibility**: add new behaviors via composition/polymorphism; **Stability**: protects proven, tested core code from regression; **Flexibility**: adapts to new rules |
| **L** | **Liskov Substitution Principle (`LSP`)** | Formulated by **Barbara Liskov** (1987) and formalized with **Jeannette Wing** (**1994** behavioral subtyping): *"Functions that use pointers or references to base classes must be able to use objects of derived classes without knowing it."* | **Polymorphism**: callers trust base contracts without type-checking (`isinstance`/`is`); **Reliability**: subtypes preserve invariants; **Predictability**: zero surprise runtime exceptions |
| **I** | **Interface Segregation Principle (`ISP`)** | *"Clients should not be forced to depend upon interfaces and methods that they do not use."* Split fat, general-purpose interfaces into small, role-specific client contracts. | **Decoupling**: clients only know methods they invoke; **Flexibility**: easier to implement and fake; **Avoids Unnecessary Dependencies** & enforces **Least Privilege** |
| **D** | **Dependency Inversion Principle (`DIP`)** | (1) *"High-level modules should not import anything from low-level modules. Both should depend on **abstractions**."* (2) *"Abstractions should not depend on details. Details (concrete implementations) should depend on abstractions."* | **Loose Coupling**: decouples domain policy from DB/HTTP/filesystem details; **Flexibility**: swap infrastructure adapters cleanly; **Maintainability & Testability** |

## 3. Behavioral Subtyping Rules for LSP (Liskov & Wing, 1994)
When designing inheritance or interface implementations, subtypes MUST honor four behavioral rules:
1. **Preconditions Cannot Be Strengthened**: A subtype must accept at least all inputs valid for the base contract.
2. **Postconditions Cannot Be Weakened**: A subtype must guarantee all output invariants promised by the base contract.
3. **Invariants Must Be Preserved**: State invariants of the base type must remain true in all subtype transitions (avoid the classic `Square` inherits from mutable `Rectangle` violation).
4. **No Refused Bequest (`NotImplementedException`)**: If a subclass throws `NotImplementedException` or leaves interface methods as no-op traps, the interface violates **ISP** and the subclass violates **LSP**. Split the interface (`ISP`) or use composition.

## 4. Idiomatic SOLID Implementation Across Repository OOP Stacks

| Principle | C# / .NET (`net8/9/10` & `net48`) | Angular v20+ & TypeScript | Python 3.10–3.13+ |
| :--- | :--- | :--- | :--- |
| **SRP** | Separate Minimal API Endpoint / Controller (HTTP transport), `FluentValidation` validator, Application Service (use-case orchestration), and Domain Entity/Record | Separate Standalone Smart Container (orchestration), Presentational Component (`input()`/`output()`, `OnPush`), and Signal Store/Facade | Separate CLI `argparse` entrypoint, pure domain logic module/class (`@dataclass(slots=True)`), and filesystem/subprocess adapter |
| **OCP** | Inject strategy/policy interfaces (`ITaxRule`, `INotificationChannel`) via DI or pattern-matched discriminated records when variation is proven | Compose reusable directives, pipe transforms, or typed configuration tokens (`InjectionToken<T>`) instead of editing core components | Pass first-class callables (`Callable[[T], R]`) or `typing.Protocol` implementations into core orchestration functions |
| **LSP** | Honor `IReadOnlyList<T>` / `Stream` / base contracts without throwing `NotSupportedException` in derived implementations | Ensure child/custom form controls (`ControlValueAccessor`) and HTTP interceptors honor full observable/signal contracts | Subclasses of `abc.ABC` or structural `Protocol` implementations preserve return types, exception hierarchies, and mutability guarantees |
| **ISP** | Define narrow role interfaces (`IOrderReader`, `IOrderWriter`, `ITokenSigner`) instead of a 25-method `IGlobalRepository` | Pass narrow `Signal<UserSummary>` slices or specific TypeScript `Pick<T, K>` interfaces to child components instead of god-services | Define 1–2 method structural `typing.Protocol` contracts (e.g., `SupportsRead`, `ClockPort`) rather than wide abstract base classes |
| **DIP** | High-level services depend on domain/application interfaces (`IOrderService`, `IOrderRepository`, `TimeProvider`); EF Core / HTTP clients live in Infrastructure | Components and stores inject abstractions via `inject(OrderApiPort)` or `InjectionToken`; HTTP details stay inside data-access services | Domain services accept abstract ports (`repo: OrderRepositoryProtocol`) via constructor/parameter injection; SQLite/HTTP adapters inject at composition root |

## 5. Security Synergy: SOLID as Defense-in-Depth
- **SRP**: Isolating authentication, authorization, and business logic prevents cross-actor bypasses when business rules change.
- **ISP & Least Privilege**: Narrow read-only vs. administrative interfaces prevent low-privilege callers from invoking privileged mutations (`BOLA`/`BOPLA`).
- **DIP**: Keeping cryptographic (`AES-GCM`), secret-retrieval, and SQL parameterization (`CWE-89`) details behind dedicated infrastructure ports ensures domain logic cannot accidentally construct raw queries or leak credentials.
