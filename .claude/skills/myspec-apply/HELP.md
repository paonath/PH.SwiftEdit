**What**: Stages pending spec .md files, creates initial 'wip:' commit, and implements tasks with strict TDD gates.
**When**: After `/myspec-validate` passes on an OpenSpec change or legacy spec.
**How**: `/myspec-apply <change-id>` or `@specs/<file>.md` (Claude Code: `/myspec:apply <change-id>`).
**Before**: `/myspec-validate` · **After**: `/myspec-verify`, then `/myspec-archive`.
