# Workflow 04: Package & Distribute Skill (`skill-creator`)

## Step 7: Package Your Skill

Create distributable `.skill` file (zip archive):

```bash
python3 ./scripts/package_skill.py "<skill-dir>" "<output-dir>"
```

Output:
```text
skill-name.skill created (zip archive with preserved structure)
Ready to deploy to your skills discovery directory
```

## Step 8: Distribute Your Skill

**Option 1: Project Skills**
```text
your-repo/skills/skill-name/
```
AI Assistants (Antigravity, Claude, AI Agent) auto-discover skills by name from the skills directory.

**Option 2: Personal Skills**
```text
~/.skills/skill-name/
```
Available to you across all repositories.

**Option 3: Community Sharing** (e.g. GitHub Awesome AI Agent or other AI registries)
- Fork or upload to relevant community registries
- Add skill to `skills/` directory
- Submit PR for community review

## Official Resources

- [VS Code Agent Skills Documentation](https://code.visualstudio.com/docs/copilot/customization/agent-skills)
- [Agent Skills Standard (agentskills.io)](https://agentskills.io/)
- [GitHub Awesome Copilot](https://github.com/github/awesome-copilot)

## Phase Requirements (EARS)

- WHEN a skill passes validation, the packaging workflow SHALL produce a distributable zip archive via `package_skill.py` preserving directory structure.
- IF validation fails before packaging, THEN the packaging workflow SHALL abort archive creation and report all validation errors.
