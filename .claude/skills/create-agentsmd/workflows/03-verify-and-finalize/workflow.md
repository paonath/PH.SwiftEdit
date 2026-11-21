# Workflow 03: Verify Commands & Finalize `AGENTS.md` (`create-agentsmd`)

## Implementation Steps 4–6: Verification & Audit

1. **Include specific, actionable commands** that agents can execute directly.
2. **Test the instructions** by ensuring all commands work as documented.
3. **Keep it focused** on what agents need to know, not general project information, adhering to the `markdown-style-ai` rule.

## Best Practices

- **Be specific**: Include exact commands, not vague descriptions.
- **Use code blocks**: Wrap commands in backticks for clarity.
- **Include context**: Explain why certain steps are needed.
- **Stay current**: Update as the project evolves.
- **Test commands**: Ensure all listed commands actually work.
- **Consider nested files**: For monorepos, create `AGENTS.md` files in subprojects as needed.

## Final Quality Checklist

- Prioritizes clarity, completeness, and actionability.
- Gives any coding agent enough context to contribute without requiring additional human guidance.

## Phase Requirements (EARS)

- WHEN finalizing `AGENTS.md`, the verification workflow SHALL test each documented command against the repository and audit formatting against the `markdown-style-ai` rule.
- IF any documented command fails execution or references missing targets, THEN the verification workflow SHALL block completion until the instruction is corrected.
