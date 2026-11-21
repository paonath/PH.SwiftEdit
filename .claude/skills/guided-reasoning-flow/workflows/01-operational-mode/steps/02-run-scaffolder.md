# Step 02: Execute Python Scaffolder (`scripts/scaffold_reasoning.py`)

## Actions
1. The `orchestrator` executes `scripts/scaffold_reasoning.py` directly using workspace command tools (never ask the human to run the script manually):
   - **Mode A (New Session)**:
     ```bash
     python3 <skill-dir>/scripts/scaffold_reasoning.py \
       --slug "<session-slug>" \
       --prompt "<raw-trigger-prompt>" \
       [--constitution-bootstrap] \
       [--attachment "/abs/path/to/external-file"] \
       --json
     ```
   - **Constitution-Bootstrap Mode (`--constitution-bootstrap`)**: When invoked by `myspec-init` (or the user) to plan and populate `<spec_root>/Constitution.md` + `<spec_root>/constitution/**`, pass `--constitution-bootstrap` (`operational_mode: "constitution-bootstrap"`, `twin_readme_required: false`).
   - **Mode B (Rework Mode)**:
     ```bash
     python3 <skill-dir>/scripts/scaffold_reasoning.py \
       --rework-from "reasoning/[NNN]_[slug]" \
       --prompt "<rework-trigger-prompt>" \
       [--major] \
       [--attachment "/abs/path/to/new-file"] \
       --json
     ```
2. Parse the JSON output to obtain `session_id`, `session_dir`, `semantic_version`, `parsed_annotations`, and `ingested_attachments`.
3. Mark `T01-01`, `T01-02`, and `T01-03` as `[x]` in `task.md`.
