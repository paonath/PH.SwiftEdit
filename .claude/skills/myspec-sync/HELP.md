**What**: Merges delta requirements into living capability specifications without archiving the change.
**When**: When you want to update living specs mid-flight before final change archival.
**How**: `/myspec-sync <change-id>` (Claude Code: `/myspec:sync <change-id>`).
**Before**: `/myspec-apply` · **After**: `/myspec-verify`, then `/myspec-archive`.
