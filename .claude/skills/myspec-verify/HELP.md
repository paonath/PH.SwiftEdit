**What**: Verifies task completion, green test run, and scenario path coverage with security trait audit.
**When**: After `/myspec-apply` finishes implementation of an OpenSpec change.
**How**: `/myspec-verify <change-id> [--converge]` (Claude Code: `/myspec:verify <change-id> [--converge]`).
**Before**: `/myspec-apply` · **After**: `/myspec-archive` (clean) or `/myspec-apply` (drift).
