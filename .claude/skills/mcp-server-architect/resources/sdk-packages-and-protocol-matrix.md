# MCP SDK Packages, JSON-RPC Error Codes, and Protocol Matrix

## 1. Official SDK Package Matrix (C# Primary & Python Secondary)

| Stack & Package | Ecosystem | Key Types & Extension Methods | Primary Use Case |
| :--- | :--- | :--- | :--- |
| **`ModelContextProtocol`** | NuGet (C# .NET 8/9/10) | `IMcpServerBuilder`, `AddMcpServer()`, `WithStdioServerTransport()`, `WithToolsFromAssembly()`, `[McpServerToolType]`, `[McpServerResourceType]`, `[McpServerPromptType]`, `WithRequestFilters()` | Default package for C# `stdio` servers, DI integration, and declarative/programmatic tool/resource/prompt registration. |
| **`ModelContextProtocol.AspNetCore`** | NuGet (C# .NET 8/9/10) | `WithHttpTransport(HttpServerTransportOptions)`, `MapMcp()`, `Stateless` mode | ASP.NET Core `Streamable HTTP` remote MCP servers with JWT Bearer (`RFC 8707`) auth and horizontal scaling. |
| **`ModelContextProtocol.Core`** | NuGet (C# .NET 8/9/10) | `McpServer`, `McpClient`, `StreamServerTransport`, `StreamClientTransport`, `CallToolResult` | Low-level transport/protocol primitives and minimal-dependency library integrations. |
| **`mcp` (`FastMCP`)** | PyPI (Python 3.10–3.13+) | `FastMCP`, `Context`, `@mcp.tool()`, `@mcp.resource()`, `@mcp.prompt()`, `lifespan` | Secondary stack: high-level Python MCP servers over `stdio` and ASGI `streamable-http`. |

## 2. Transport & Capability Compatibility Matrix

| MCP Capability | `stdio` (`WithStdioServerTransport`) | `Streamable HTTP` (`Stateless = true`) | `Streamable HTTP` (`Stateless = false`) | Security & Operational Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Tools (`tools/list`, `tools/call`)** | Supported | Supported | Supported | Use `.WithRequestFilters` (`AddCallToolFilter`) for Spotlighting and `IsError = true` sanitization. |
| **Resources (`resources/list`, `resources/read`)** | Supported | Supported | Supported | Enforce `CWE-22` root confinement, `MaxOutputBytes`, and `NextCursor` pagination. |
| **Prompts (`prompts/list`, `prompts/get`)** | Supported | Supported | Supported | Keep prompt templates static; never inject untrusted data into system instructions. |
| **Completions (`completion/complete`)** | Supported | Supported | Supported | Bound autocomplete results (`<= 20` items) via `.WithCompleteHandler`. |
| **Sampling (`sampling/createMessage`)** | Supported | **Not Supported** | Supported | Requires `ClientCapabilities.Sampling != null` and bidirectional session channel. |
| **Elicitation (`elicitation/create`)** | Supported | **Not Supported** (Use `HMACSHA256` token) | Supported | Requires `ClientCapabilities.Elicitation != null`; use `HMACSHA256` token fallback on stateless HTTP. |

## 3. Standard JSON-RPC 2.0 & MCP Error Codes

| Code | Name | Meaning & MCP Server Usage |
| :--- | :--- | :--- |
| `-32700` | Parse error | Invalid JSON received by the transport layer. |
| `-32600` | Invalid Request | JSON payload is not a valid JSON-RPC 2.0 request object. |
| `-32601` | Method not found | Requested MCP method or capability is not registered on the server. |
| `-32602` | Invalid params | Missing, malformed, or out-of-range tool/resource arguments (`FluentValidation` / schema failure). |
| `-32603` | Internal error | Sanitized server-side failure (never expose stack traces or secrets in `message` or `data`; `CWE-209`). |
| `IsError = true` | Tool Execution Error | Returned inside `CallToolResult` when a tool call fails business validation or security policy without terminating the transport session. |

## 4. Prompt-Injection & Security Invariants

- Always return sanitized domain/validation failures via `CallToolResult { IsError = true }` or standard JSON-RPC `-32602`/`-32603` codes without echoing untrusted payloads (`CWE-209`).
