# Workflow 02: UI Debugging & Diagnostics (`webapp-testing`)

## Debugging Capabilities

- Capture screenshots
- View console logs
- Inspect network requests
- Debug failed tests
- Reuse helper functions in `test-helper.js` (`runTest`, `captureConsoleLogs`, `takeScreenshot`, `elementExists`, `getElementText`, `waitForAndClick`, `fillField`).

## Usage Examples & Patterns

### Example 3: Screenshot Capture
```javascript
// Capture a screenshot for debugging
await page.screenshot({ path: 'debug.png', fullPage: true });
```

### Pattern: Get Console Logs
```javascript
page.on('console', msg => console.log('Browser log:', msg.text()));
```

### Pattern: Handle Errors
```javascript
try {
  await page.click('#button');
} catch (error) {
  await page.screenshot({ path: 'error.png' });
  throw error;
}
```

## Debugging & Resource Cleanup Guidelines

1. **Capture screenshots on failure** — Take screenshots to help debug issues.
2. **Clean up resources** — Always close the browser when done.
3. **Handle timeouts gracefully** — Set reasonable timeouts for slow operations.

## Phase Requirements (EARS)

- WHEN an interactive browser action raises an exception, the debugging workflow SHALL capture a failure screenshot and stream browser console logs before rethrowing the error.
- The debugging workflow SHALL close every browser instance after execution completes or fails.
