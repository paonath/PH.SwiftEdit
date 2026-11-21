# C# / .NET Advanced Capabilities: Sampling, Elicitation, and Completions

## 1. Capability & Transport Compatibility Rules

Server-to-client requests (`IMcpServer.SampleAsync` and `IMcpServer.ElicitAsync`) require **both**:
1. **Client Support**: Verified at runtime via `server.ClientCapabilities?.Sampling is not null` or `server.ClientCapabilities?.Elicitation is not null`.
2. **Bidirectional Stateful Transport**: Supported on `stdio` (`WithStdioServerTransport`) and stateful HTTP (`WithHttpTransport(o => o.Stateless = false)`). On stateless HTTP (`Stateless = true`), `SampleAsync` and `ElicitAsync` throw `InvalidOperationException`.

## 2. Human-in-the-Loop Confirmation: `ElicitAsync` vs. `HMACSHA256` Token

For any tool marked `DestructiveHint = true` or mutating critical state (`OWASP LLM06:2025`):

- **Path A — Stateful Transport with Client Elicitation (`ElicitAsync`)**:
  ```csharp
  if (server.ClientCapabilities?.Elicitation is not null)
  {
      var elicitResult = await server.ElicitAsync(new ElicitRequestParams
      {
          Message = $"Confirm permanent deletion of record '{recordId}'?"
      }, ct);
      if (elicitResult.Action != "accept")
          return "Operation cancelled by user.";
  }
  ```
- **Path B — Stateless HTTP Fallback (`HMACSHA256` + `TimeProvider` Confirmation Token)**:
  - Step 1: When called without a `confirmationToken`, compute `HMACSHA256(key, $"{callerSub}|{toolName}|{canonicalArgsHash}|{expiresUnixSeconds}")` using `TimeProvider.GetUtcNow()` (`TTL <= 120s`) and return a prompt instructing the human operator to confirm with the token.
  - Step 2: When called with `confirmationToken`, verify expiration and constant-time MAC equality (`CryptographicOperations.FixedTimeEquals`) before executing the mutation.

## 3. Server-Initiated LLM Sampling (`IMcpServer.SampleAsync`)

- Use `server.SampleAsync(new CreateMessageRequestParams { ... }, ct)` only when the server needs the client host's LLM to summarize or classify data.
- **Anti-Recursion & Quota Guard**: Bound `MaxTokens`, set `IncludeContext = ContextInclusion.None` by default, and never pass raw un-spotlighted external payloads as system instructions.

## 4. Argument Autocompletion (`.WithCompleteHandler`) & Progress Notifications

- **Completions (`WithCompleteHandler`)**:
  ```csharp
  builder.Services.AddMcpServer()
      .WithCompleteHandler(async (ctx, ct) =>
      {
          var prefix = ctx.Params?.Argument?.Value ?? string.Empty;
          var matches = AllowedSlugs.Where(s => s.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)).Take(20).ToList();
          return new CompleteResult
          {
              Completion = new Completion { Values = matches, Total = matches.Count, HasMore = false }
          };
      });
  ```
- **Progress Notifications (`ProgressToken`)**:
  - Inspect `requestContext.Params?.Meta?.ProgressToken`. For multi-step operations, emit progress updates via `server.SendNotificationAsync("notifications/progress", ...)` while honoring `CancellationToken ct`.

## 5. Prompt-Injection & Security Invariants

- Never trust an LLM-generated `ElicitAsync` response if `ClientCapabilities.Elicitation` is absent; fail closed or require a cryptographic `HMACSHA256` confirmation token bound to the exact tool arguments.
