---
name: ddd-clean-architecture-and-performance
description: "Python DDD tactical patterns, typing.Protocol ports, @dataclass(slots=True), generator streaming, and CPU/memory optimization."
---

# DDD, Clean Architecture, and Performance in Python

## Clean Architecture and Structural Subtyping (`typing.Protocol`)

- Decouple domain and application logic from infrastructure I/O using structural subtyping (`typing.Protocol`) rather than heavy abstract base class hierarchies:
  ```python
  class SpecRepositoryPort(Protocol):
      def load(self, spec_id: str) -> SpecDocument: ...
      def save(self, doc: SpecDocument) -> None: ...
  ```
- Keep domain models pure and synchronous (`Domain` ring), injecting filesystem, SQLite, or HTTP adapters at the `Application` / CLI composition root (`domain-driven-design`, `oop-design-patterns__oop-design-patterns`).

## Memory-Efficient Domain Modeling

| Construct | Memory & Speed Benefit | When to Use |
| :--- | :--- | :--- |
| `@dataclass(frozen=True, slots=True)` | Eliminates per-instance `__dict__` (`~40-60%` RAM reduction) and enforces immutability | Value Objects, Commands, Domain Events, parsed AST/config nodes |
| `typing.NamedTuple` | Compact tuple memory layout with named field access | Lightweight coordinate, span, or row return values |
| Generator expressions & `yield` | `O(1)` working memory across arbitrarily large file trees or log streams | Directory scanning (`rglob`), JSONL transcript parsing, line filtering |
| `functools.lru_cache(maxsize=256)` | Memoizes pure regex compilation or schema parsing with bounded cache size | Repeated validation or path resolution helpers |

## High-Performance Iteration and Regex Pre-Compilation

- Pre-compile module-level regular expressions (`PATTERN: Final[ re.Pattern[str] ] = re.compile(...)`) instead of recompiling inside loops.
- Use `set` or `frozenset` for membership checks (`O(1)` lookup) instead of scanning `list` or `tuple` (`O(n)`).
- Use `itertools` (`islice`, `chain.from_iterable`) and `collections.deque(maxlen=N)` for bounded sliding windows.

## Structured Concurrency (`asyncio.TaskGroup`)

- For I/O-bound concurrent workloads in Python 3.11+, use `async with asyncio.TaskGroup() as tg:` with an `asyncio.Semaphore(limit)` to bound concurrent open sockets or subprocesses and guarantee automatic cancellation on first unhandled exception.
