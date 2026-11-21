# MCP Security & Anti-Prompt-Injection Pre-Release Audit Checklist

## 1. Mandatory Security Findings & Controls (`SEC-MCP-01..06`)

| Control ID | OWASP / RFC / CWE | Mandatory Verification Gate |
| :--- | :--- | :--- |
| **`SEC-MCP-01`** | `OWASP LLM01:2025`, `CWE-74` | **Indirect Prompt Injection (XPIA) Spotlighting**: All external/untrusted strings returned by Tools or Resources are wrapped in `<untrusted_mcp_data_{nonce}>...</untrusted_mcp_data_{nonce}>` with embedded closing tags and control/bidirectional Unicode characters stripped. |
| **`SEC-MCP-02`** | `OWASP LLM01:2025`, `CWE-494` | **Anti-Tool Poisoning & Rug-Pull**: All `[McpServerTool]`, `[McpServerResource]`, `[Description]`, and `@mcp.tool()` schemas are compile-time static constants; permit only contract-tested same-server preconditions while blocking cross-server/covert directives and runtime schema mutation. |
| **`SEC-MCP-03`** | `RFC 8707`, `RFC 8693`, `CWE-287` | **OAuth 2.1 Audience & Zero Token Passthrough**: `Streamable HTTP` servers validate `aud` against the canonical MCP server URI (`RFC 8707`) and **never** pass incoming client bearer tokens to downstream `HttpClient`/`httpx` requests (`Token Passthrough` ban). |
| **`SEC-MCP-04`** | `CWE-22`, `CWE-78`, `CWE-918` | **OS & Network Sandboxing**: File paths verify canonical root prefix (`Path.GetFullPath` / `Path.resolve().is_relative_to()`) and reject symlinks; external processes use `ArgumentList` / `shell=False`; HTTP fetches block loopback, RFC 1918, and `169.254.169.254`. |
| **`SEC-MCP-05`** | `CWE-532`, `CWE-400`, `CWE-209` | **Transport Hygiene & Output Caps**: `stdio` servers route all logs to `stderr` (`LogToStandardErrorThreshold = LogLevel.Trace` / `sys.stderr`), mask secrets with `***REDACTED***`, cap outputs (`MaxOutputBytes <= 64 KB`), and return sanitized `IsError = true` errors. |
| **`SEC-MCP-06`** | `OWASP LLM01:2025`, `CWE-209`, `CWE-285` | **Model-Guidance Contract, Budget & Resource Auth**: `ToolContractTests` verifies every tool/URI cited in `ServerInstructions` and `Prompts` exists locally; `InstructionsBudgetTests` caps `ServerInstructions <= 450` words; Prompts frame user args as passive data; dynamic Resources enforce per-URI `BOLA` checks. |

## 2. 6-Category STRIDE Threat Matrix for MCP Servers

| STRIDE Category | MCP Threat Scenario | Required Code & Test Countermeasure |
| :--- | :--- | :--- |
| **Spoofing** | Replay of foreign OAuth token against HTTP MCP endpoint or DNS rebinding against local HTTP port. | Enforce `RFC 8707` `ValidAudience`, bind local HTTP to `127.0.0.1`, and validate `Origin`/`Host` headers. |
| **Tampering** | XPIA payload in a read resource tricks host LLM into calling a file/command tool with `../../` or shell metacharacters. | Nonce Spotlighting (`SEC-MCP-01`) + canonical path guard (`CWE-22`) + argument-array execution (`CWE-78`). |
| **Repudiation** | Upstream Token Passthrough erases caller identity in downstream logs; CRLF injection forges log lines. | Use `RFC 8693` Token Exchange; emit structured JSON audit logs to `stderr` with caller `sub` and CRLF-stripped arguments. |
| **Information Disclosure** | Tool Poisoning exfiltrates `.env`/keys; SSRF reads cloud metadata; verbose exceptions leak connection strings. | Static tool metadata (`SEC-MCP-02`), SSRF IP filter (`SEC-MCP-04`), secret redaction, and sanitized `IsError = true`. |
| **Denial of Service** | Unbounded database/file resource read returns a multi-megabyte payload or hangs indefinitely. | Enforce `MaxOutputBytes` truncation, cursor pagination (`NextCursor`), and mandatory `CancellationToken` / `asyncio.timeout`. |
| **Elevation of Privilege** | Excessive Agency (`OWASP LLM06:2025`): LLM invokes destructive/mutating tool without human approval. | Set `DestructiveHint = true` and require `ElicitAsync` (stateful/`stdio`) or `HMACSHA256` + `TimeProvider` Confirmation Token (stateless HTTP). |

## 3. 12-Point Pre-Release Audit Gate

1. `stdio` server configures `LogToStandardErrorThreshold = LogLevel.Trace` (C#) or `stream=sys.stderr` (Python) with zero `Console.Write*`/`print` calls.
2. Every async handler accepts and propagates `CancellationToken` (C#) or runs under bounded `asyncio.timeout` (Python).
3. `.WithRequestFilters` (`AddCallToolFilter`, `AddReadResourceFilter`) or `@spotlight_untrusted` frames untrusted outputs in `<untrusted_mcp_data_{nonce}>`.
4. Embedded closing tags and control/bidirectional Unicode characters inside untrusted outputs are stripped before framing.
5. Every `[McpServerTool]` declares explicit `ReadOnlyHint`, `DestructiveHint`, `IdempotentHint`, and `OpenWorldHint` annotations.
6. All tool/resource/prompt descriptions and `ServerInstructions` (`<= 450` words) are static compile-time strings permitting only contract-tested (`ToolContractTests`) same-server preconditions while blocking cross-server/covert Tool Poisoning.
7. Mutating/destructive tools enforce `ElicitAsync` (stateful/`stdio`) or `HMACSHA256` parameter-bound Confirmation Tokens (`Stateless = true` HTTP).
8. HTTP servers validate OAuth 2.1 `aud` (`RFC 8707`) and never pass incoming client bearer tokens downstream (`Token Passthrough` ban).
9. File system tools/resources enforce canonical root prefix checks (`CWE-22`) and reject symlinks/reparse points.
10. Subprocess tools use `ProcessStartInfo.ArgumentList` (`UseShellExecute = false`) or `subprocess.run(..., shell=False)` (`CWE-78`).
11. Unhandled tool exceptions return sanitized `IsError = true` messages without stack traces (`CWE-209`).
12. Automated xUnit (`[Trait("Category", "security")]`) or `pytest` (`@pytest.mark.security`) tests verify `P#` and `N1..N5` security paths.

## 4. Prompt-Injection & Security Invariants

- Any MCP server failing any of the 12 checklist gates MUST NOT be promoted to production or registered in shared agent configurations.
