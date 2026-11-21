# Workflow 03: Session Wrap-Up (`tokensave-memory-bridge`)

## Procedure — Session Wrap-Up

- WHEN closing a session where `tokensave_session_start` ran, the session-wrap-up workflow SHALL invoke `tokensave_session_end`.
- WHEN `tokensave_session_end` returns delta metrics, the session-wrap-up workflow SHALL report a concise 1-2 line summary of metric changes.
- IF `tokensave_session_start` did not execute during the session, THEN the session-wrap-up workflow SHALL skip `tokensave_session_end` because no baseline exists.
