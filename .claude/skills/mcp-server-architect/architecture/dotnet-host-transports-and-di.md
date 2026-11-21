# C# / .NET MCP Hosting, Transports, and Dependency Injection

## 1. Official NuGet Packages & Target Frameworks

- Target `net8.0`, `net9.0`, or `net10.0` with `<Nullable>enable</Nullable>` and `<GenerateDocumentationFile>true</GenerateDocumentationFile>`.
- **`ModelContextProtocol`**: Core server/client runtime, `IHostApplicationBuilder` DI registration (`AddMcpServer`), `stdio` transport, and declarative attributes (`[McpServerToolType]`, `[McpServerResourceType]`, `[McpServerPromptType]`).
- **`ModelContextProtocol.AspNetCore`**: ASP.NET Core Streamable HTTP transport (`WithHttpTransport`) and endpoint routing (`MapMcp`).
- **`ModelContextProtocol.Core`**: Low-level protocol primitives (`McpServer`, `McpClient`, `StreamServerTransport`) for minimal-dependency libraries.

## 2. Transport Selection & Hosting Topologies

| Transport Mode | Hosting Builder & Registration | Mandatory Operational & Security Invariants |
| :--- | :--- | :--- |
| **`stdio` (Local Subprocess)** | `Host.CreateApplicationBuilder(args)` + `.AddMcpServer().WithStdioServerTransport()` | **Stdout Purity (`CWE-532`)**: `stdout` carries exclusively JSON-RPC 2.0 frames. Configure `builder.Logging.AddConsole(o => o.LogToStandardErrorThreshold = LogLevel.Trace)` and never call `Console.Write*`. |
| **`Streamable HTTP` (`Stateless = true`)** | `WebApplication.CreateBuilder(args)` + `.AddMcpServer().WithHttpTransport(o => o.Stateless = true)` + `app.MapMcp("/mcp")` | Default for horizontally scaled web deployments. Server-to-client `SampleAsync` and `ElicitAsync` are unavailable in stateless mode; use `HMACSHA256` confirmation tokens for destructive tools. |
| **`Streamable HTTP` (`Stateless = false`)** | `WebApplication.CreateBuilder(args)` + `.AddMcpServer().WithHttpTransport(o => o.Stateless = false)` + `app.MapMcp("/mcp")` | Required when remote HTTP tools invoke bidirectional `IMcpServer.SampleAsync` or `IMcpServer.ElicitAsync`. Enforce session idle timeouts and OAuth 2.1 `RFC 8707` audience validation. |

## 3. Dependency Injection Lifetimes & KISS/SOLID Boundaries

- **Thin Protocol Adapters (`SRP` + `KISS-First`)**:
  - Keep `[McpServerToolType]`, `[McpServerResourceType]`, and `[McpServerPromptType]` classes free of business/persistence logic.
  - Pure deterministic helpers may use `static` methods; handlers orchestrating domain logic or I/O inject `1:1` DI service contracts (`IFooService`) or standard .NET seams (`TimeProvider`, `IHttpClientFactory`, `ILogger<T>`).
- **Scoped Per-Request Resolution**:
  - Method parameters resolved from `IServiceProvider` in `[McpServerTool]` and `[McpServerResource]` handlers honor scoped DI lifetimes when registered on `builder.Services`.
  - Never inject `DbContext` into singleton state; resolve `DbContext` or `IDbContextFactory<T>` inside a scoped application service with `AsNoTracking()` for read queries.
- **No Speculative Interfaces**:
  - Never create interfaces for tool argument records or response DTOs. Apply the **Rule of Three (`>= 3` concrete implementations)** before introducing Strategy/Factory hierarchies.

## 4. Dual-Mode Bootstrap Pattern (`stdio` + `Streamable HTTP`)

```csharp
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using ModelContextProtocol.Server;

var useHttp = args.Contains("--http", StringComparer.OrdinalIgnoreCase);
if (!useHttp)
{
    var builder = Host.CreateApplicationBuilder(args);
    builder.Logging.ClearProviders();
    builder.Logging.AddConsole(o => o.LogToStandardErrorThreshold = LogLevel.Trace);
    builder.Services.AddSingleton(TimeProvider.System);
    builder.Services.AddHttpClient();
    builder.Services
        .AddMcpServer()
        .WithStdioServerTransport()
        .WithToolsFromAssembly()
        .WithResourcesFromAssembly()
        .WithPromptsFromAssembly();

    await builder.Build().RunAsync();
}
```

## 5. Prompt-Injection & Security Invariants

- **Zero `stdout` Pollution**: Any non-JSON byte written to `stdout` breaks the `stdio` JSON-RPC framing or leaks internal state.
- **Graceful Cancellation**: Every async tool, resource, and prompt method MUST accept `CancellationToken ct` as its final parameter and pass it to all downstream I/O calls.
