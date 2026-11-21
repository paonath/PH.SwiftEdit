# Workflow 01: Session Startup (`tokensave-memory-bridge`)

## Procedure — Session Startup

1. Optional index check: execute `bash ./scripts/check-tokensave.sh "<project-dir>"` from the skill root (`0` indexed, `1` not indexed, `2` not installed).
2. WHEN starting a tracked session, the session-startup workflow SHALL invoke `tokensave_session_start` and review the returned `memory_delta` (up to 5 recent decisions and 5 recent code areas).
3. WHERE the task targets a specific domain (e.g., chunked file upload), the session-startup workflow SHALL invoke `tokensave_session_recall` with a targeted query (e.g., `"upload" OR "chunked"`) to retrieve historic decisions.
4. IF `bash ./scripts/check-tokensave.sh "<project-dir>"` returns exit `1` or `2`, THEN the session-startup workflow SHALL report the unindexed or missing TokenSave status per the `tokensave-first` rule.
