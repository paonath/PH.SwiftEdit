---
name: performance-memory-and-async-patterns
description: "High-throughput C# memory optimization, Span<T>, ArrayPool<T>, async/await, Channels, and EF Core query performance."
---

# Performance, Memory, and Async Patterns in .NET

## Low-Allocation Memory Management

- **Stack and Slice Semantics**: Use `Span<T>` and `ReadOnlySpan<T>` for synchronous string slicing, binary parsing, and buffer manipulation to avoid heap allocations.
- **Buffer Pooling**: Rent large byte or char buffers (`>= 85,000` bytes) from `ArrayPool<T>.Shared` inside `try/finally` blocks to prevent Large Object Heap (`LOH`) fragmentation.
- **Struct Design**: Use `readonly record struct` for small value types (`<= 16–24` bytes) that are frequently created and passed by value or `in` reference; avoid boxing value types via non-generic interfaces.

## Asynchronous Throughput and Concurrency

- **End-to-End Async**: Propagate `CancellationToken` across all HTTP, database, and file I/O methods; never block thread-pool threads with `.Result`, `.Wait()`, or `.GetAwaiter().GetResult()` (sync-over-async deadlock/starvation risk).
- **Hot-Path `ValueTask<T>`**: Use `ValueTask<T>` only on hot paths that frequently complete synchronously (e.g., in-memory cache hits); never await a `ValueTask<T>` more than once.
- **Bounded Producer-Consumer Queues**: Use `Channel.CreateBounded<T>(new BoundedChannelOptions(capacity) { FullMode = BoundedChannelFullMode.Wait })` instead of `ConcurrentQueue<T>` polling loops to enforce backpressure (`CWE-400`).

## EF Core and Data Access Performance

| Optimization Technique | When to Apply | Performance Impact |
| :--- | :--- | :--- |
| `.AsNoTracking()` | All read-only queries and DTO projections | Eliminates change-tracker snapshot overhead and halves memory per row |
| `.Select(x => x.ToDto())` Projection | Listing and search endpoints | Fetches only required SQL columns; avoids loading unused LOBs or navigations |
| `IAsyncEnumerable<T>` Streaming | Large exports or batch processing | Streams rows incrementally without buffering the full result set in RAM |
| `AsSplitQuery()` | Multi-collection `.Include()` graphs | Prevents Cartesian explosion on `1:N:M` joins |
| `ExecuteUpdateAsync` / `ExecuteDeleteAsync` | Bulk state transitions (`net8+`) | Executes single set-based SQL `UPDATE`/`DELETE` without loading entities |

## Caching and Resilience

- Use `HybridCache` (`net9+`) or `IMemoryCache` with explicit `SizeLimit` and sliding/absolute expiration to prevent unbounded memory growth.
- Configure outbound `HttpClient` instances via `IHttpClientFactory` and `Microsoft.Extensions.Http.Resilience` standard pipelines (hedging, retry with jitter, circuit breaker, timeout).
