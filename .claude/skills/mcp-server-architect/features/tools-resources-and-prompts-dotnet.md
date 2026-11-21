# C# / .NET MCP Tools, Resources, and Prompts

## 1. Declarative vs. Programmatic Capability Registration

| Registration Style | C# SDK APIs (`ModelContextProtocol.Server`) | When to Use (`KISS-First`) |
| :--- | :--- | :--- |
| **Declarative Attributes (Default)** | `[McpServerToolType]` + `[McpServerTool]`, `[McpServerResourceType]` + `[McpServerResource]`, `[McpServerPromptType]` + `[McpServerPrompt]` with `.WithToolsFromAssembly()`, `.WithResourcesFromAssembly()`, `.WithPromptsFromAssembly()` | Default for 95% of servers: compile-time static metadata, zero reflection boilerplate, automatic JSON Schema generation from C# types and `[Description]`. |
| **Programmatic Factory** | `McpServerTool.Create(delegateOrMethod, options)`, `McpServerResource.Create(...)`, `McpServerPrompt.Create(...)` registered via `.WithTools(...)`, `.WithResources(...)`, `.WithPrompts(...)` | Use when wrapping pre-compiled `Microsoft.Extensions.AI` `AIFunction` instances or registering explicit tool subsets per host profile. |

## 2. Authoring Tools (`[McpServerToolType]` & Tool Annotations)

- **Explicit Tool Annotations (`OWASP LLM06:2025` Agency Control)**:
  - Always declare `ReadOnlyHint`, `DestructiveHint`, `IdempotentHint`, and `OpenWorldHint` on `[McpServerTool]` so MCP hosts know whether human confirmation is required.
- **Parameter Binding**:
  - Primitives and immutable `record` parameters bind from the JSON-RPC `arguments` object.
  - `IMcpServer`, `RequestContext<CallToolRequestParams>`, DI-registered `1:1` services (`IFooService`), and `CancellationToken` are injected automatically by the SDK.

```csharp
using System.ComponentModel;
using ModelContextProtocol.Server;

[McpServerToolType]
public sealed class OrderQueryTools(IOrderReadService orderService)
{
    /// <summary>Retrieves a summary of an order by its canonical identifier.</summary>
    [McpServerTool(
        Name = "get_order_summary",
        ReadOnlyHint = true,
        DestructiveHint = false,
        IdempotentHint = true,
        OpenWorldHint = false)]
    [Description("Returns the status and line-item count for a verified order ID.")]
    public async Task<string> GetOrderSummaryAsync(
        [Description("Canonical order GUID.")] Guid orderId,
        CancellationToken ct)
    {
        var dto = await orderService.GetByIdAsync(orderId, ct);
        return dto is null ? "Order not found." : $"Order {dto.Id}: {dto.Status} ({dto.ItemCount} items)";
    }
}
```

## 3. Authoring Resources (`[McpServerResourceType]` & URI Templates)

- Expose read-only context (schemas, configuration snapshots, confined workspace files) via `[McpServerResource(UriTemplate = "repo://docs/{slug}", Name = "...", MimeType = "text/markdown")]`.
- Enforce **Cursor Pagination (`NextCursor`)** and `MaxOutputBytes` (`<= 64 KB`) when listing or reading large collections.

## 4. Authoring Prompts (`[McpServerPromptType]`)

- Use `[McpServerPrompt]` returning `ChatMessage` / `PromptMessage` sequences (`Microsoft.Extensions.AI`) to provide standardized, parameterized prompt templates.
- Never concatenate untrusted external data directly into `ChatRole.System` or instruction blocks inside a prompt template.

## 5. Prompt-Injection & Security Invariants

- **Static Description Rule (`SEC-MCP-02`)**: `[Description]` strings MUST be compile-time C# constants describing only what the tool/parameter does. Never include cross-tool orchestration instructions or load descriptions from a database/API (`Tool Poisoning` & `Rug-Pull` defense).
