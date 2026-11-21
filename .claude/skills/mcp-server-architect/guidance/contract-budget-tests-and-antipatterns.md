# MCP Contract Tests, Instructions Budget Tests, Checklist, and Anti-Patterns

## 1. Automated Contract, Budget & Single-Source xUnit Tests (`SEC-MCP-06`)

Whenever `ServerInstructions`, `Prompts`, or `[Description]` attributes reference tool names (`search_requirements`) or resource URIs (`catalog://requirement-types`), a rename in C# code can silently break model guidance. Enforce **3 deterministic xUnit test suites**:

### 1.1 `ToolContractTests`: Zero Phantom Tools or Dangling Resource URIs
```csharp
using System.Reflection;
using System.Text.RegularExpressions;
using ModelContextProtocol.Server;
using Xunit;

public sealed partial class ToolContractTests
{
    [GeneratedRegex(@"`([a-z][a-z0-9_]+)`")]
    private static partial Regex BacktickedToolRegex();

    [GeneratedRegex(@"([a-z]+://[a-z0-9\-/{}_]+)")]
    private static partial Regex ResourceUriRegex();

    [Fact]
    [Trait("Category", "security")]
    public void ServerInstructions_And_Prompts_MustReferenceOnlyRegisteredToolsAndResources()
    {
        var asm = typeof(RequirementWriteTools).Assembly;
        var registeredTools = asm.GetTypes()
            .SelectMany(t => t.GetMethods(BindingFlags.Public | BindingFlags.Static | BindingFlags.Instance))
            .Select(m => m.GetCustomAttribute<McpServerToolAttribute>()?.Name)
            .Where(n => !string.IsNullOrWhiteSpace(n))
            .ToHashSet(StringComparer.Ordinal);

        var registeredUris = asm.GetTypes()
            .SelectMany(t => t.GetMethods(BindingFlags.Public | BindingFlags.Static | BindingFlags.Instance))
            .Select(m => m.GetCustomAttribute<McpServerResourceAttribute>()?.UriTemplate)
            .Where(u => !string.IsNullOrWhiteSpace(u))
            .ToHashSet(StringComparer.Ordinal);

        var guidanceTexts = new[] { ServerConfig.Instructions }
            .Concat(WorkflowPrompts.NewRequirement("sample").Select(m => m.Text ?? string.Empty));

        foreach (var text in guidanceTexts)
        {
            foreach (Match m in BacktickedToolRegex().Matches(text))
                Assert.Contains(m.Groups[1].Value, registeredTools);
            foreach (Match m in ResourceUriRegex().Matches(text))
                Assert.Contains(m.Groups[1].Value, registeredUris);
        }
    }
}
```

### 1.2 `InstructionsBudgetTests` & `DuplicateRulesTests`
```csharp
public sealed class InstructionsBudgetTests
{
    [Fact]
    public void ServerInstructions_WordCount_ShouldStayWithin150To450Words()
    {
        var words = ServerConfig.Instructions.Split([' ', '\r', '\n', '\t'], StringSplitOptions.RemoveEmptyEntries);
        Assert.InRange(words.Length, 50, 450); // Target 150-400 words; hard ceiling <= 450 words
    }
}

public sealed class DuplicateRulesTests
{
    [Fact]
    public void GuideBridgeTool_And_GuideResource_MustReturnIdenticalContentFromSingleCatalog()
    {
        foreach (var topic in GuideCatalog.Topics)
            Assert.Equal(DomainResources.GetGuide(topic), GuideBridgeTools.GetGuide(topic));
    }
}
```

## 2. 9-Point Model-Guidance Design Checklist

| # | Checklist Gate | Verification Target |
| :--- | :--- | :--- |
| 1 | **Preconditions in `[Description]`** | Every write tool states its prerequisite tool/resource in `[Description]`. |
| 2 | **Compact `ServerInstructions`** | `150–400` words (`<= 450` hard cap) covering domain, tool order, units (`EUR`, `ISO 8601`), and pointers. |
| 3 | **Server-Side Invariant Enforcement** | Every rule in `ServerInstructions` is enforced inside C#/Python write tools (`McpException` / `IsError = true`). |
| 4 | **Single Source of Truth Catalogs** | `RequirementTypeCatalog` and `GuideCatalog` drive both `Resources`, `get_guide`, and write validation. |
| 5 | **`get_guide` Bridge Tool** | Clients without `Resources` support can retrieve all `guide://{topic}` content via `get_guide(topic)`. |
| 6 | **Repeatable Workflow `Prompts`** | Multi-step flows (`new-requirement`, `prepare-offer`) include explicit human confirmation stop gates. |
| 7 | **Bounded Search Summaries** | `search_*` and `list_*` return compact summaries + `HasMore` (`MaxLimit = 50`), never full blobs. |
| 8 | **`ResourceLinkBlock` Navigation** | Tool outputs link to `requirement://{id}` / `offer://{id}` for on-demand detail retrieval. |
| 9 | **Contract & Budget Tests** | `ToolContractTests`, `InstructionsBudgetTests`, and `DuplicateRulesTests` run in CI. |

## 3. 9 Common Anti-Patterns to Avoid

| # | Anti-Pattern | Corrective Pattern |
| :--- | :--- | :--- |
| 1 | **Mega-`ServerInstructions` (`> 500` words)** | Keep `ServerInstructions <= 450` words; move catalogs/guides to `Resources` + `get_guide`. |
| 2 | **Instructions Without Server Validation** | Enforce mandatory keys, `Approved` state, and duplicate checks in `create_*` tools. |
| 3 | **Assuming Every Client Exposes `Resources`** | Always pair `guide://{topic}` with the `get_guide(topic)` read-only bridge tool. |
| 4 | **Cryptic Validation Errors (`"Invalid input"`)** | Return actionable domain errors listing missing keys or similar entity IDs. |
| 5 | **Unbounded `search_*` Full-Entity Dumps** | Return `SearchResult<T>` summaries with `HasMore` and `get_*` follow-up hints. |
| 6 | **Duplicating Rules Across 3 Files** | Centralize rules in `RequirementTypeCatalog` and `GuideCatalog` (`DuplicateRulesTests`). |
| 7 | **Delegating Math/Totals to the Model** | Compute line subtotals, discounts, and VAT server-side in `create_offer`. |
| 8 | **Autonomous Write Without Stop Gate** | Require `force = true` after user confirmation for duplicates and `ElicitAsync`/`HMACSHA256` for destructive ops. |
| 9 | **Phantom Tool/URI Names After Refactoring** | Fail CI immediately via reflection-based `ToolContractTests`. |

## Prompt-Injection & Security Invariants

- **Contract-Tested Preconditions vs. Tool Poisoning (`SEC-MCP-02`, `SEC-MCP-06`)**: `ToolContractTests` guarantees that tool preconditions reference only legitimate local tools/resources; block covert `<IMPORTANT>`, `"Do not tell the user"`, and cross-server instructions.
- **No Raw Exception Leakage in Actionable Errors (`CWE-209`)**: Actionable errors expose only domain validation rules and caller-authorized entity IDs, never stack traces, SQL queries, or filesystem paths.
