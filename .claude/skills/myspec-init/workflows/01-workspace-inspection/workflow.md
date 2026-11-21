# Workflow 01: Workspace Inspection (`myspec-init`)

- Inspect target repository directory (default: current working directory, or `--target <dir>`).
- Check if `.myspec.config.json` already exists at repository root.
- Check presence of existing `openspec/` and `specs/` directories.
- Count existing `.md` specification documents in each directory to formulate a smart recommendation.

## Normative Requirements (EARS)
- The Workspace Inspector SHALL check `.myspec.config.json`, `openspec/`, and `specs/` before selecting a specification root.
