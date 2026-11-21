# Workflow 02: Author `AGENTS.md` Structure & Sections (`create-agentsmd`)

## File Structure and Content Guidelines

### 1. Required Setup
- Create the file as `AGENTS.md` in the repository root.
- Use standard Markdown formatting (adhering to the `markdown-style-ai` rule).
- Consult `references/templates.md` ([templates.md](../../references/templates.md)) for customizable starting templates and real-world examples.

### 2. Essential Sections to Include

- **Project Overview**: Brief description of what the project does, architecture overview if complex, key technologies and frameworks used.
- **Setup Commands**: Installation instructions, environment setup steps, dependency management commands, database setup if applicable.
- **Development Workflow**: How to start development server, build commands, watch/hot-reload setup, package manager specifics (`npm`, `pnpm`, `yarn`, etc.).
- **Testing Instructions**: How to run tests (unit, integration, e2e), test file locations and naming conventions, coverage requirements, specific test patterns or frameworks used, how to run a subset of tests.
- **Code Style Guidelines**: Language-specific conventions, linting and formatting rules, file organization patterns, naming conventions, import/export patterns.
- **Build and Deployment**: Build commands and outputs, environment configurations, deployment steps and requirements, CI/CD pipeline information.

### 3. Optional but Recommended Sections

- **Security Considerations**: Security testing requirements, secrets management, authentication patterns, permission models.
- **Monorepo Instructions**: How to work with multiple packages, cross-package dependencies, selective building/testing, package-specific commands.
- **Pull Request Guidelines**: Title format requirements, required checks before submission, review process, commit message conventions.
- **Debugging and Troubleshooting**: Common issues and solutions, logging patterns, debug configuration, performance considerations.

## Phase Requirements (EARS)

- The authoring workflow SHALL include Project Overview, Setup Commands, Development Workflow, Testing Instructions, Code Style Guidelines, and Build and Deployment sections.
- WHEN drafting the initial skeleton, the authoring workflow SHALL load `references/templates.md` under Single-Reference Lock and apply the `markdown-style-ai` rule.
