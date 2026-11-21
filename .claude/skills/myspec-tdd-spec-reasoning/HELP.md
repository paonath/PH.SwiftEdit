**What**: Central specification engine of MySpec: conducts TDD interview (or ingests a brief), writes the brief in openspec/briefs/, and ALWAYS formalizes it into a 6-artifact change in openspec/changes/ that conforms to the tdd-spec-driven schema (validated by a mandatory fail-closed gate).
**When**: Before implementing any feature to clarify contracts, author specifications, and structure TDD triads.
**How**: `/myspec-tdd-spec-reasoning <feature prompt>` (Claude Code: `/myspec:tdd-spec-reasoning <feature prompt>`).
**Before**: `/myspec-init` · **After**: `/myspec-apply @openspec/changes/<change-id>`.
