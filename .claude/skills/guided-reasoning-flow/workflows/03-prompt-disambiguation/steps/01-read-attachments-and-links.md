# Step 01: Read Attachments & Referenced Repository Documents

## Actions
1. Inspect `attachments/INDEX.md` and any document paths or links mentioned in the raw prompt.
2. If any external file mentioned in the prompt has not yet been copied into `attachments/`, invoke:
   ```bash
   python3 <skill-dir>/scripts/scaffold_reasoning.py \
     --session-dir "reasoning/[NNN]_[slug]" \
     --attachment "/abs/path/to/file" \
     --json
   ```
3. Read all files in `attachments/` and referenced repository documents in full (using `headroom_compress` if any file exceeds 150 lines).
4. Mark `T03-01` as `[x]` in `task.md`.
