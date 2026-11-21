---
name: blazor-mvc-and-fullstack-ui
description: "Blazor United (SSR, Server, WebAssembly), ASP.NET Core MVC, Razor Pages, and SignalR presentation architecture."
---

# Blazor, MVC, and Full-Stack .NET UI Architecture

## Blazor Render Modes and Component Design (`net8+`)

- **Render Mode Selection**:
  - **Static SSR**: Default for content-heavy, SEO-critical, and read-only pages with zero WebSocket or WASM payload overhead.
  - **Interactive Server (`@rendermode InteractiveServer`)**: Use for low-latency internal dashboards requiring direct backend service access over SignalR circuits; keep circuit state small to avoid server memory exhaustion.
  - **Interactive WebAssembly (`@rendermode InteractiveWebAssembly`) / Auto**: Use for client-intensive interactions; communicate with the backend exclusively through typed HTTP API clients and DTO records.
- **Component Boundaries**: Separate smart page components (`@page`) from stateless presentational components (`[Parameter, EditorRequired]`, `EventCallback<T>`).
- **Stream Rendering**: Apply `[StreamRendering]` on SSR pages performing slow asynchronous data fetches so initial HTML shell renders immediately.

## ASP.NET Core MVC and Razor Pages

- Keep Controllers and `PageModel` handlers thin: bind immutable ViewModels/Request records, validate via `FluentValidation`, delegate business logic to application services, and return explicit `IActionResult` views or redirects (`Post-Redirect-Get`).
- Enforce `[ValidateAntiForgeryToken]` (or automatic Razor Pages antiforgery) on all state-changing form endpoints (`POST`, `PUT`, `DELETE`).
- Never bind EF Core entities directly from form payloads (`[FromForm]` / `[FromBody]`) to prevent over-posting (`BOPLA`).

## SignalR Real-Time Hubs

- Define strongly-typed client contracts (`Hub<TClient>`) and authorize hubs with `[Authorize(Policy = "...")]`.
- Keep hub methods short and non-blocking; offload long-running work to bounded `Channel<T>` background workers and broadcast progress via `IHubContext<THub, TClient>`.

## Accessibility and Security in .NET Server UI

- Emit semantic HTML5 landmarks, explicit `<label for="...">` bindings on `InputText`/`InputSelect`, and `aria-invalid` / `role="alert"` on `<ValidationMessage>` outputs (`WCAG 2.2 AA`).
- Avoid `MarkupString` with unvalidated user input (`CWE-79`); sanitize rich HTML on the server using an allowlist sanitizer before rendering.
