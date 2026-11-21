# Secondary Stack: Python `FastMCP` Architecture and Async Lifecycle

## 1. Official Python `mcp` SDK & Clean Boundary Rules

- Target Python `3.10–3.13+` using the official `mcp` package (`from mcp.server.fastmcp import Context, FastMCP`).
- **Thin Presentation Adapters (`KISS-First` + `SOLID` `DIP`)**:
  - `@mcp.tool()`, `@mcp.resource("scheme://{param}")`, and `@mcp.prompt()` functions MUST remain thin adapters.
  - Delegate domain logic to typed services satisfying `typing.Protocol` ports and returning immutable `@dataclass(frozen=True, slots=True)` or Pydantic v2 `BaseModel` payloads.
- **Static Schema Generation**:
  - Use explicit PEP 484 type annotations and `pydantic.Field(description="...", max_length=...)` on tool parameters so `FastMCP` generates strict JSON Schemas at startup.

## 2. Lifespan Context & Bounded Async Concurrency

Manage shared pools (`httpx.AsyncClient`, database connections, `asyncio.Semaphore`) via an `@asynccontextmanager` lifespan function rather than module-level mutable globals:

```python
from __future__ import annotations
import asyncio
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from dataclasses import dataclass
from pathlib import Path
import sys
import logging
from mcp.server.fastmcp import Context, FastMCP

logging.basicConfig(level=logging.INFO, stream=sys.stderr)

@dataclass(frozen=True, slots=True)
class AppLifespanState:
    workspace_root: Path
    io_semaphore: asyncio.Semaphore

@asynccontextmanager
async def app_lifespan(_server: FastMCP) -> AsyncIterator[AppLifespanState]:
    state = AppLifespanState(
        workspace_root=Path("/srv/mcp-safe-root").resolve(),
        io_semaphore=asyncio.Semaphore(8),
    )
    yield state

mcp = FastMCP("secure-python-mcp", lifespan=app_lifespan)
```

## 3. Transport Selection (`stdio` vs. `streamable-http`)

- **`stdio` Transport (`mcp.run(transport="stdio")`)**:
  - Route all `logging` handlers strictly to `sys.stderr`. Never call `print()` without `file=sys.stderr` (`CWE-532`).
- **`streamable-http` Transport (`mcp.run(transport="streamable-http")` / ASGI mount)**:
  - Mount into FastAPI/Starlette (`app.mount("/mcp", mcp.streamable_http_app())`), enforce OAuth 2.1 `RFC 8707` audience validation middleware, and bind local servers to `127.0.0.1`.

## 4. Mandatory Python Security & Anti-Prompt-Injection Guards

- **`@spotlight_untrusted` Decorator (`OWASP LLM01:2025`)**:
  - Wrap untrusted tool/resource strings in randomized nonce tags `<untrusted_mcp_data_{nonce}>...</untrusted_mcp_data_{nonce}>` and strip embedded closing tags and control characters before returning to the LLM host.
- **`CWE-22` Path Confinement (`pathlib.Path.is_relative_to`)**:
  ```python
  def resolve_confined_path(root: Path, user_rel_path: str) -> Path:
      root_resolved = root.resolve()
      candidate = (root_resolved / user_rel_path).resolve(strict=False)
      if not candidate.is_relative_to(root_resolved) or candidate.is_symlink():
          raise ValueError("Path traversal or symlink outside confined root is forbidden (CWE-22).")
      return candidate
  ```
- **`CWE-78` Subprocess Execution**:
  - Always invoke `subprocess.run(argv_list, shell=False, check=False, capture_output=True, text=True, timeout=15)` with an allowlisted binary path.

## 5. Prompt-Injection & Security Invariants

- Never interpolate user or LLM arguments into docstrings, dynamic `@mcp.tool(description=...)` metadata (`Tool Poisoning` / `Rug-Pull`), or `shell=True` commands.
