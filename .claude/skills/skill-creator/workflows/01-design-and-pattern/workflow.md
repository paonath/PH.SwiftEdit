# Workflow 01: Define Purpose & Choose Skill Pattern (`skill-creator`)

## Step 1: Define Your Skill Purpose

Clarify what your skill does and when the AI agent should use it:

- **One-sentence purpose**: "This skill helps the agent [action] by [what it provides]"
- **Identify triggers**: User requests that should activate your skill
- **Assess scope**: Single domain (narrow) or multiple domains (broad)

Example skill definitions:
- "Assign least-privilege Azure roles" -> `azure-role-selector`
- "Validate and format JSON" -> `json-validator`
- "Deploy to AWS/GCP/Azure" -> `cloud-deployment`

## Step 2: Choose Your Skill Pattern

Agent Skills follow three organizational patterns (see [design-patterns.md](../../references/design-patterns.md) and `examples/*.md`):

### Pattern 1: High-Freedom Guidance (no scripts)
- Multiple valid approaches; context-dependent decisions
- Examples: Code review guidance, architecture decisions, best practices
- Structure: `SKILL.md` only (all guidance inline, or progressive `workflows/`/`references/`)

### Pattern 2: Medium-Freedom Scripts (guidance + validation)
- Preferred patterns exist; deterministic operations needed
- Examples: JSON validation, format conversion, file processing
- Structure: `SKILL.md` + `scripts/` + `examples/`

### Pattern 3: Low-Freedom Multi-Domain (per-domain patterns)
- Different frameworks/providers with incompatible approaches
- Examples: Cloud deployment (AWS/GCP/Azure), language-specific tools
- Structure: `SKILL.md` + `scripts/` + `examples/` + `references/` (domain guides)

**Decision**: Choose based on whether the agent needs:
- Multiple valid approaches? -> Pattern 1
- Deterministic scripts? -> Pattern 2 or 3
- Multi-domain selection? -> Pattern 3

## Phase Requirements (EARS)

- The design phase workflow SHALL define a single-sentence purpose, concrete activation triggers, and domain scope before scaffolding directories.
- WHEN deterministic operations are needed across one or multiple domains, the skill-creator workflow SHALL select Pattern 2 or Pattern 3 with dedicated scripts.
