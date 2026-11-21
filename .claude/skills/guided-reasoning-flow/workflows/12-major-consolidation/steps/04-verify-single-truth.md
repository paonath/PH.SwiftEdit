# Step 04: Single-Truth Verification Pass

## Actions
1. Execute an automated scan across all live markdown files in the session root and `brief/`:
   - Search for prohibited historical tokens: `precedentemente`, `nella versione precedente`, `in revision`, `superseded`, `delta`, `vecchia versione`.
   - Verify that zero inline annotations `[[...]]` remain in any live file.
2. Verify that no file in the live root or `brief/` carries a `.old` extension.
3. Validate session integrity via `scaffold_reasoning.py --session-dir <dir> --validate --json`.
4. If any prohibited token or uncompleted task is flagged, immediately rectify the file before marking this step complete.
