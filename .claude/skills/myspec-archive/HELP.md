**What**: Fail-closed gate: validates change, merges into living specs, archives change, and commits changelog.
**When**: After `/myspec-verify` confirms 100% tasks and green tests for a change or spec.
**How**: `/myspec-archive <change-id>` or `@specs/<file>.md` (Claude Code: `/myspec:archive <change-id>`).
**Before**: `/myspec-verify` (or `/myspec-apply`) · **After**: `/myspec-status` or next change.
