# Domain Workflow Case Study in C#/.NET: Requirements & Commercial Offers

## 1. Domain Rules & Single-Source-of-Truth Catalog (`RequirementTypeCatalog`)

Consider a B2B MCP server managing **Technical Requirements (`REQ-YYYY-NNNN`)** and **Commercial Offers (`OFF-YYYY-NNNN`)**:
- Each requirement category (`functional`, `performance`, `security`, `integration`) enforces distinct mandatory metadata fields.
- A commercial offer can link **only** to requirements in `RequirementStatus.Approved` status.
- Both `catalog://requirement-types` (Resource) and `create_requirement` (Write Tool) validate against a single static `RequirementTypeCatalog`—eliminating schema drift between documentation and server validation.

```csharp
public sealed record RequirementTypeRule(
    string Category,
    string Description,
    IReadOnlyList<string> RequiredMetadataKeys,
    string ExampleJson);

public static class RequirementTypeCatalog
{
    public static readonly IReadOnlyDictionary<string, RequirementTypeRule> All =
        new Dictionary<string, RequirementTypeRule>(StringComparer.OrdinalIgnoreCase)
        {
            ["functional"] = new("functional", "User-facing business behavior",
                ["userRole", "businessProcess"], """{"userRole":"Buyer","businessProcess":"Checkout"}"""),
            ["performance"] = new("performance", "Latency, throughput, and SLA targets",
                ["targetLatencyMs", "peakRps"], """{"targetLatencyMs":"150","peakRps":"500"}"""),
            ["security"] = new("security", "Authentication, authorization, or compliance control",
                ["threatCategory", "complianceRef"], """{"threatCategory":"ElevationOfPrivilege","complianceRef":"ISO27001"}"""),
            ["integration"] = new("integration", "External system protocol and direction",
                ["externalSystem", "protocol"], """{"externalSystem":"SAP","protocol":"REST"}""")
        };
}
```

## 2. Token-Conscious Search Summaries (`SearchResult<T>` & `HasMore`)

Search tools (`search_requirements`, `list_offers`) MUST NOT dump full entity payloads into the LLM context window. Return a bounded summary record (`MaxLimit = 50`) with a `HasMore` pagination flag and instruct the model to call `get_requirement` (or read `requirement://{id}`) only for selected items:

```csharp
public sealed record RequirementSummaryDto(
    string Id, string Title, string Category, string Status, string Priority);

public sealed record SearchResult<T>(
    IReadOnlyList<T> Items, int TotalMatched, bool HasMore, string NextHint);

[McpServerToolType]
public sealed class RequirementSearchTools(IRequirementService service)
{
    [McpServerTool(Name = "search_requirements", ReadOnly = true, Idempotent = true),
     Description("Search requirements by keyword/category. Call BEFORE create_requirement to avoid duplicates. Returns compact summaries; call get_requirement for full details.")]
    public async Task<SearchResult<RequirementSummaryDto>> SearchRequirementsAsync(
        [Description("Search keyword or phrase")] string query,
        [Description("Optional category filter: functional, performance, security, integration")] string? category = null,
        [Description("Max results (1..50, default 10)")] int limit = 10,
        CancellationToken ct = default)
    {
        var clamped = Math.Clamp(limit, 1, 50);
        var (items, total) = await service.SearchSummariesAsync(query, category, clamped, ct);
        return new SearchResult<RequirementSummaryDto>(
            items, total, total > items.Count,
            "Use get_requirement(id) or resource requirement://{id} to inspect full fields.");
    }
}
```

## 3. Server-Side Invariant Enforcement in Write Tools (`create_requirement` & `create_offer`)

Following the Golden Rule (*"Instructions guide, server validation guarantees"*), write tools validate category metadata, check for semantic/keyword duplicates (`FindSimilarAsync`), and verify `RequirementStatus.Approved` before persisting:

```csharp
[McpServerToolType]
public sealed class RequirementWriteTools(IRequirementService reqService, IOfferService offerService)
{
    [McpServerTool(Name = "create_requirement", Destructive = false, Idempotent = false),
     Description("Create a new requirement. PRECONDITION: call search_requirements first and verify required metadata keys in catalog://requirement-types.")]
    public async Task<RequirementDto> CreateRequirementAsync(
        string title, string category, string priority,
        IReadOnlyList<string> acceptanceCriteria,
        IReadOnlyDictionary<string, string> metadata,
        [Description("Set true ONLY after the user explicitly confirms creation despite similar existing requirements")] bool force = false,
        CancellationToken ct = default)
    {
        if (!RequirementTypeCatalog.All.TryGetValue(category, out var rule))
            throw new McpException($"Invalid category '{category}'. Read catalog://requirement-types for valid categories.");

        var missing = rule.RequiredMetadataKeys.Where(k => !metadata.TryGetValue(k, out var v) || string.IsNullOrWhiteSpace(v)).ToList();
        if (missing.Count > 0)
            throw new McpException($"Category '{category}' requires metadata keys: {string.Join(", ", missing)}.");

        if (!force)
        {
            var similar = await reqService.FindSimilarAsync(title, ct);
            if (similar.Count > 0)
                throw new McpException(
                    $"Potential duplicate requirements found: {string.Join(", ", similar.Select(s => $"{s.Id} ('{s.Title}')"))}. " +
                    "Show these to the user and pass force=true only after explicit user confirmation.");
        }
        return await reqService.CreateAsync(title, category, priority, acceptanceCriteria, metadata, ct);
    }

    [McpServerTool(Name = "create_offer", Destructive = false, Idempotent = false),
     Description("Create a commercial offer in EUR net of VAT. PRECONDITION: all requirementIds must be in Approved status.")]
    public async Task<OfferDto> CreateOfferAsync(
        string customerName, IReadOnlyList<string> requirementIds,
        IReadOnlyList<OfferLineInput> lines, DateOnly validUntil, CancellationToken ct = default)
    {
        var unapproved = await reqService.GetNonApprovedIdsAsync(requirementIds, ct);
        if (unapproved.Count > 0)
            throw new McpException($"Cannot create offer: requirements {string.Join(", ", unapproved)} are not in Approved status.");
        return await offerService.CreateWithServerCalculatedTotalsAsync(customerName, requirementIds, lines, validUntil, ct);
    }
}
```

## Prompt-Injection & Security Invariants

- **Actionable Domain Errors Without Stack Traces (`CWE-209`, `SEC-MCP-06`)**: Throw `McpException` (or return `CallToolResult { IsError = true }`) with deterministic domain remediation guidance (missing keys, unapproved IDs, caller-scoped duplicate IDs); redact unexpected infrastructure exceptions in `AddCallToolFilter`.
- **Duplicate-Check Authorization (`BOLA`, `SEC-MCP-03`)**: `FindSimilarAsync` MUST query only requirements visible to the authenticated caller/tenant so duplicate warnings never leak cross-tenant titles.
- **Explicit User Gate on `force = true` (`SEC-MCP-05`)**: Forbid autonomous model retries with `force = true` without prior user confirmation; for destructive state changes (`delete_*`, `approve_*`), require `ElicitAsync` or an `HMACSHA256` confirmation token.
