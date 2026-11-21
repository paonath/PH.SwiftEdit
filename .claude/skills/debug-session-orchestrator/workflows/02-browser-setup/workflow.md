# Workflow 02: Browser Setup — Clean Slate (`debug-session-orchestrator`)

1. **Isolation:**
   - The Debug Session Orchestrator SHALL launch Chromium in an Incognito window or clean temporary profile to avoid cache or cookie false positives.
2. **DevTools Attachment:**
   - The Debug Session Orchestrator SHALL attach to the browser session with Remote Debugging Port active.
3. **Active Monitoring:**
   - WHILE executing browser diagnostics, the Debug Session Orchestrator SHALL run Active Monitoring over Console exceptions and Network XHR/Fetch payloads with 4xx/5xx statuses and log initialization to memory.
