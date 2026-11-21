# Step 01: Archive & Snapshot Creation

## Actions
1. The orchestrator invokes `scripts/scaffold_reasoning.py` with `--new-major`:
   ```bash
   python3 <skill-dir>/scripts/scaffold_reasoning.py \
     --session-dir "reasoning/[NNN]_[slug]" \
     --new-major \
     --json
   ```
2. Verify JSON output:
   - `status`: `"success"`
   - `superseded_dir`: confirms directory `<session_dir>/superseded/<version>/` exists
   - `renamed_old_files_count`: confirms all markdown files were renamed to `.md.old`
   - `semantic_version`: confirms version incremented to `(int(major)+1).0` (e.g. `2.0`, `3.0`)
3. Confirm that no preexisting `superseded/` directory was recursively copied into the new snapshot.
