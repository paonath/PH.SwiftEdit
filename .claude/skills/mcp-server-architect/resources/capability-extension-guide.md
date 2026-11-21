# Progressive-Disclosure Capability Extension Guide

## 1. Purpose & 5-Folder Progressive-Disclosure Governance

`the mcp-server-architect skill` is designed for long-term extensibility while preserving a minimal context footprint under `Single-Reference Lock`:
- **Router Ceiling**: `SKILL.md` MUST remain `<= 90` lines.
- **Module Ceiling**: Every progressive-disclosure file inside `architecture/`, `features/`, `examples/`, `resources/`, and `guidance/` MUST remain `< 150` lines and self-contained in English.
- **Slug Safety (`CWE-22`)**: Every module filename MUST match `^[a-z0-9]+(-[a-z0-9]+)*\.md$` with zero `..` segments, path separators, or uppercase characters.

## 2. Target Folder Selection Matrix

When extending the skill with a new MCP capability (e.g., Registry API, Audio/Multimodal streams, Tasks, OpenTelemetry tracing, or domain model-guidance patterns), place the module in the matching folder:

| Target Folder | When to Add a New Module Here | Naming Pattern Example |
| :--- | :--- | :--- |
| `architecture/` | New transport bindings, hosting lifecycles, distributed session stores, or auth/observability middleware pipelines. | `architecture/dotnet-opentelemetry-and-tracing.md` |
| `features/` | New MCP protocol capabilities (Tasks, Audio content blocks, Roots, Subscriptions) or new security defenses. | `features/mcp-roots-and-resource-subscriptions.md` |
| `examples/` | End-to-end, copy-ready C#/.NET (primary) or Python (secondary) production + TDD test blueprints for a capability. | `examples/dotnet-efcore-resource-provider.md` |
| `resources/` | Protocol lookup tables, error/capability matrices, compliance checklists, or migration references. | `resources/mcp-spec-version-migration-matrix.md` |
| `guidance/` | Server-side model-guidance patterns (`ServerInstructions`, workflow `Prompts`, `Resources`, `get_guide` bridges, contract/budget tests). | `guidance/multi-step-approval-workflows.md` |

## 3. Self-Evolution Capability Proposal Gate Workflow

Never create or modify files inside `architecture/`, `features/`, `examples/`, `resources/`, or `guidance/` autonomously. Follow this 4-step gate:

1. **Formulate Proposal**: Identify the target folder (`architecture/`, `features/`, `examples/`, `resources/`, or `guidance/`), candidate filename `<slug>.md`, target stack (C#/.NET primary or Python secondary), and key invariants.
2. **Enforce Mandatory Security Section**: Every new module across all 5 folders MUST end with an explicit `## Prompt-Injection & Security Invariants` section analyzing:
   - Untrusted taint inputs and Indirect Prompt Injection (`OWASP LLM01:2025`) Spotlighting requirements.
   - Tool Poisoning / Rug-Pull static schema constraints.
   - Authorization (`RFC 8707` `aud`), `CWE-22`/`CWE-78`/`CWE-918` sandboxing, and `MaxOutputBytes` bounds.
3. **Request Human Approval via `AskUserQuestion`**: Present the proposed `<folder>/<slug>.md` path, 2–3 bullet summary, and security invariants to the user via `AskUserQuestion`.
4. **Register & Verify**: Upon confirmation, write the `< 150` line module, add a concise 1-line routing row in `SKILL.md` (`<= 90` lines), add its required tokens to `EXPECTED_FOLDERS` in `test_mcp_server_architect_skill.py`, and run `test_agent_assets_validity.py`.

## 4. Standard Capability Module Template (`< 150` Lines)

```markdown
# <Capability Title> (<C# / .NET | Python | Protocol>)

## 1. Overview & Protocol Contract
- Concise specification of the MCP capability, SDK types, and transport requirements.

## 2. Architectural & Implementation Rules (KISS + SOLID)
- Thin adapter boundary, 1:1 DI service/port contracts, and resource/cancellation rules.

## 3. Production & TDD Code Blueprint
- Idiomatic C# (ModelContextProtocol) or Python (FastMCP) snippet + deterministic Pipe/in-memory test.

## 4. Prompt-Injection & Security Invariants
- Mandatory Spotlighting, static metadata, CWE-22/78/918, and [Trait("Category", "security")] test contract.
```

## 5. Prompt-Injection & Security Invariants

- Any capability extension lacking `## Prompt-Injection & Security Invariants` or human `AskUserQuestion` approval fails governance verification (`N3`/`N5`).
