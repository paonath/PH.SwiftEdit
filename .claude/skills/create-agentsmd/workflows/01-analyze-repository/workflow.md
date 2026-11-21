# Workflow 01: Analyze Repository & Identify Workflows (`create-agentsmd`)

## Implementation Steps 1–2: Discovery & Scope

1. **Analyze the project structure**: Follow the `tokensave-first` rule to quickly identify programming languages, frameworks, package managers, testing frameworks, and overall project architecture.
2. **Identify key workflows** by examining:
   - `package.json` scripts
   - `Makefile` or other build files
   - CI/CD configuration files (`.github/workflows/`, etc.)
   - Documentation files

## Monorepo Considerations

For large monorepos:
- Place a main `AGENTS.md` at the repository root.
- Create additional `AGENTS.md` files in subproject directories.
- The closest `AGENTS.md` file takes precedence for any given location.
- Include navigation tips between packages/projects.

## Phase Requirements (EARS)

- The repository analysis workflow SHALL inspect build files, package manifests, and CI workflows using the `tokensave-first` rule.
- WHERE a repository follows a monorepo layout, the discovery workflow SHALL map subproject boundaries and cross-package navigation paths.
