---
name: performance-ssr-hydration-and-memory
description: "Angular rendering performance, zoneless signals, SSR incremental hydration, Core Web Vitals optimization, and memory leak prevention."
---

# Performance, SSR Hydration, and Memory Management in Angular

## Change Detection and Zoneless Rendering

- Use `ChangeDetectionStrategy.OnPush` on all components or enable zoneless change detection (`provideExperimentalZonelessChangeDetection()` / `provideZonelessChangeDetection()`).
- Drive all template updates through signals (`signal()`, `computed()`, `input()`) or `AsyncPipe` so Angular updates only dirty component subtrees without full-tree polling.
- Never bind impure methods or heavy array sorting/filtering directly inside template expressions; memoize derived collections in `computed()`.

## Core Web Vitals (`LCP`, `INP`, `CLS`) and `@defer`

| Metric | Optimization Strategy | Angular Implementation |
| :--- | :--- | :--- |
| **LCP** (Largest Contentful Paint) | Prioritize hero image discovery and avoid render-blocking bundles | `<img ngSrc="hero.webp" width="800" height="450" priority />` (`NgOptimizedImage`) |
| **INP** (Interaction to Next Paint) | Keep event handlers `< 50ms`; defer non-critical chart/editor rendering | `@defer (on viewport; prefetch on idle) { <app-heavy-chart /> } @placeholder { <div class="skeleton"></div> }` |
| **CLS** (Cumulative Layout Shift) | Reserve explicit dimensions for images, skeletons, and `@defer` placeholders | Always set `width`/`height` or CSS `aspect-ratio` on media and `@placeholder` blocks |

## SSR and Incremental Hydration

- Configure `provideClientHydration(withEventReplay(), withIncrementalHydration())` when using Angular SSR so server-rendered HTML hydrates smoothly without DOM destruction flickering.
- Guard browser-only APIs (`window`, `document`, `localStorage`, `ResizeObserver`) inside `afterNextRender()` or `afterRender()` callbacks; never invoke them in component constructors.

## Memory Leak Prevention

- Unsubscribe RxJS streams automatically via `takeUntilDestroyed()` (`@angular/core/rxjs-interop`) or convert streams to signals with `toSignal()`.
- Register manual DOM listeners, timers, or `IntersectionObserver` instances cleanup inside `DestroyRef.onDestroy(() => ...)`.
- Use `@cdk/scrolling` (`cdk-virtual-scroll-viewport`) when rendering lists exceeding `200` complex rows.
