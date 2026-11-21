# Workflow 02: Scaffold Directory & Author `SKILL.md` (`skill-creator`)

## Step 3: Create Skill Directory & SKILL.md

Create directory structure:
```bash
mkdir -p skills/skill-name/{scripts,examples,references}
```

Create `SKILL.md` with required frontmatter:
```yaml
---
name: skill-name
description: |
  [One-sentence purpose]. Use when: (1) [trigger 1], (2) [trigger 2], (3) [trigger 3]
---
```

**Requirements**:
- `name`: lowercase, hyphens only, max 64 characters
- `description`: clear triggers + use cases, max 1024 characters
- Body: under 500 lines (or `<= 90` lines for progressive-disclosure routers), uses imperative form ("Use", "Generate", "Run")

## Step 4: Write SKILL.md Body

Structure your `SKILL.md` body based on your pattern:

**Pattern 1 (Guidance)**:
```text
## Overview
## Principle 1: [Name]
## Principle 2: [Name]
## Decision Tree
## Examples
```

**Pattern 2 (Scripts)**:
```text
## Overview
## Step 1: [Operation] (AI agent executes: python scripts/...)
## Step 2: [Next Operation]
## Black-Box Execution (mandatory when scripts/ exists)
## Examples
## Troubleshooting
```

**Black-Box Execution section (copy and adapt)**:
```markdown
## Black-Box Execution

- **Do not read** script source before running it; the scripts are tested black boxes.
- Run commands from the skill base directory (the folder containing this `SKILL.md`).
- Run the script with `--help` for options not listed below.
- Read the source only after a non-zero exit that stderr does not explain.

| Command | Parameters | Stdout | Exit codes |
|---|---|---|---|
| `python3 ./scripts/tool.py --input "<path>"` | `--input` required | JSON report | 0 ok, 1 error, 2 invalid option |
```

- Quote every `<placeholder>` in command templates (`"<path>"`).
- Use skill-relative paths only; never physical paths.
- For library modules replace the table header with `| Module | Import | Public API | Notes |`.
- `validate_skill.py` warns when the section is missing.

**Pattern 3 (Multi-Domain)**:
```text
## Domain Selection
## Domain 1: [Name] (guidance + scripts)
## Domain 2: [Name] (guidance + scripts)
## Comparison Table
## Troubleshooting
```

## Skill Directory Structure & Progressive Disclosure

- **`SKILL.md`**: Guidance or thin router for the AI Agent
- **`scripts/`**: Executable code (Python/Bash/JS) for deterministic operations
- **`examples/`**: Code samples and templates for output generation
- **`references/`** / **`workflows/`**: Detailed guides or phase workflows loaded on demand (`Single-Reference Lock`)

### Progressive Disclosure Levels
1. **Metadata** (always): `name` + `description` -> trigger matching
2. **Body** (on trigger): `SKILL.md` body -> core guidance or workflow routing table
3. **Resources** (on-demand): `scripts/` / `examples/` / `references/` / `workflows/` -> loaded one at a time as needed

### Content Guidelines
- Use imperative form: "Use...", "Generate...", "Run...", not "This is..."
- Include inline examples (code blocks) for common cases
- Reference advanced topics to external files in `references/` or `workflows/`
- Provide decision trees to help the AI agent choose

## Phase Requirements (EARS)

- The scaffolding workflow SHALL enforce lowercase hyphenated skill names up to 64 characters and router bodies within 90 lines.
- WHERE a skill includes a scripts directory, the authoring workflow SHALL embed a Black-Box Execution section with quoted command placeholders.
