# Workflow 01: Pre-Flight & Baseline Health Gate (`myspec-apply`)

1. **Target Identification & Dual-Mode Detection**:
   - Check project root for `.myspec.config.json` to resolve `spec_root` (`openspec` or `specs`) and mapped directory paths. If absent, auto-discover by checking for `specs/` and `openspec/`.
   - Check if the target is an OpenSpec change (e.g. `<spec_root>/changes/<change-id>/`, `<change-id>`) or a legacy specification file under `specs/*.md`.
   - For OpenSpec change targets:
     - Verify existence of `<changes_dir>/<change-id>/tasks.md`.
     - Read change context: `proposal.md`, `specs/**/spec.md`, `design.md`, `threat-model.md`, `test-plan.md`.
     - Verify `- Branch:` metadata in `proposal.md`; if the current active git branch differs from the draft branch recorded under `## Metadata` in `proposal.md`, append `(implemented: <current-branch>)` to `- Branch:` in `proposal.md` via `MySpecGitBranchTracker.record_branch_in_proposal(..., phase="implemented")`.
   - For Legacy specification targets:
     - Verify file existence under `specs/*.md`.
     - Read 15-section legacy content and Section 12 YAML task breakdown.
2. **Mandatory Initial WIP Git Checkpoint**:
   - Before modifying any code or running tasks, identify all pending uncommitted `.md` files associated with the target specification workspace:
     - For OpenSpec change targets: stage `<changes_dir>/<change-id>/**/*.md`, `<briefs_dir>/brief-[slug].md`, and `<spec_root>/index.yml` if updated.
     - For Legacy specification targets: stage `specs/<filename>.md` and associated briefs.
   - **Staging Boundary**: Restrict staging strictly to pending specification markdown files (`.md`); never run blind `git add .` or stage untracked source code, configuration files, or environment secrets.
   - Execute the initial work-in-progress Git commit: `git commit -m "wip: <spec-name>"` (where `<spec-name>` is the change ID or specification file name, e.g. `wip: <change-id>`).
   - If no pending specification `.md` files exist (all spec documents are already committed), log an informational note and continue.
3. **Verify Baseline Health**:
   - Run the project baseline build (e.g., `dotnet build`, `npm run build`, `python3 ...`) *before* editing any files.
   - If the build fails, stop and invoke the `qa` skill to ask the user to resolve pre-existing syntax/build errors.
   - Run the project baseline test suite (e.g., using `dotnet-test-suite__run-tests` from the `dotnet-test-suite` plugin for .NET projects, or native test runners).
   - If baseline tests fail, stop and invoke the `qa` skill asking the user whether to resolve pre-existing failures or proceed.

## Normative Requirements (EARS)
- WHEN uncommitted specification markdown files exist, the Pre-Flight Gate SHALL stage only specification markdown files and commit `wip: <spec-name>`.
- IF the baseline build or test suite fails before edits, THEN the Pre-Flight Gate SHALL halt and request user guidance via `the qa skill`.
