---
name: typescript-nodejs-and-state-patterns
description: "Strict TypeScript 5.x modeling, RxJS-to-Signal interop, functional HTTP interceptors, and Node.js tooling/BFF patterns."
---

# TypeScript, Node.js, and State Patterns

## Strict TypeScript 5.x Domain Modeling

- Enable `"strict": true`, `"noImplicitOverride": true`, `"noUncheckedIndexedAccess": true`, and `"exactOptionalPropertyTypes": true` in `tsconfig.json`.
- Model asynchronous and domain states using **discriminated unions** rather than boolean flag combinations:
  ```ts
  export type LoadState<T> =
    | { readonly status: 'idle' }
    | { readonly status: 'loading' }
    | { readonly status: 'loaded'; readonly data: T }
    | { readonly status: 'error'; readonly message: string };
  ```
- Use branded types or type predicates (`function isOrderDto(value: unknown): value is OrderDto`) at external API boundaries instead of `as` type assertions.

## RxJS and Signal Interoperability

- **Use Signals for Synchronous State**: Component state, derived UI flags, and store snapshots belong in signals (`signal`, `computed`).
- **Use RxJS for Event Streams**: Debounced search inputs, WebSocket multiplexing, retry/backoff pipelines, and cancellation chains (`switchMap`, `exhaustMap`) belong in RxJS observables, bridged to templates via `toSignal(stream$, { initialValue })`.
- Avoid nested `.subscribe()` calls; compose higher-order flattening operators (`switchMap` for latest read, `exhaustMap` for form submission to prevent double-submit).

## Functional HTTP Interceptors and Security

- Configure `provideHttpClient(withFetch(), withInterceptors([authInterceptor, errorInterceptor]))`.
- Attach bearer tokens or correlation headers only to allowlisted API origins (`req.url.startsWith(environment.apiBaseUrl)`) to prevent token leakage to third-party CDNs.
- Never use `DomSanitizer.bypassSecurityTrust*`, `eval()`, or raw `innerHTML` with untrusted data (`CWE-79`).

## Node.js Tooling and BFF Architecture

- Use modern Node.js LTS (`20+`/`22+`) with native ESM (`import`/`export`), `node:fs/promises`, `node:path`, and `AbortSignal` timeouts on outbound `fetch()` calls.
- Validate all CLI arguments and environment configuration at startup before executing build, SSR, or BFF proxy tasks.
