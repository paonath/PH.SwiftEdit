**What**: Displays diagnostics on active changes, living specs, index.yml, TDD triads, legacy specs, and delta code changes.
**When**: At any point during development to inspect implementation progress or detect unaligned code changes (`--detect-delta`).
**How**: `/myspec-status [--change <id>] [--detect-delta] [--deep-scan] [--json]` (Claude Code: `/myspec:status`).
**Before**: Any command or code edit · **After**: `/myspec-tdd-spec-reasoning`, `/myspec-validate`, or `/myspec-apply`.
