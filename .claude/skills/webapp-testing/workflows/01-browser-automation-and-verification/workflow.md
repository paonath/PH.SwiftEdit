# Workflow 01: Browser Automation & UI Verification (`webapp-testing`)

## Prerequisites

- Node.js installed on the system
- A locally running web application (or accessible URL)
- Playwright will be installed automatically if not present

## Capabilities

### 1. Browser Automation
- Navigate to URLs
- Click buttons and links
- Fill form fields
- Select dropdowns
- Handle dialogs and alerts

### 2. Verification
- Assert element presence
- Verify text content
- Check element visibility
- Validate URLs
- Test responsive behavior

## Usage Examples

### Example 1: Basic Navigation Test
```javascript
// Navigate to a page and verify title
await page.goto('http://localhost:3000');
const title = await page.title();
console.log('Page title:', title);
```

### Example 2: Form Interaction
```javascript
// Fill out and submit a form
await page.fill('#username', 'testuser');
await page.fill('#password', 'password123');
await page.click('button[type="submit"]');
await page.waitForURL('**/dashboard');
```

## Common Verification Patterns & Guidelines

### Pattern: Wait for Element
```javascript
await page.waitForSelector('#element-id', { state: 'visible' });
```

### Pattern: Check if Element Exists
```javascript
const exists = await page.locator('#element-id').count() > 0;
```

### Guidelines
1. **Always verify the app is running** — Check that the local server is accessible before running tests.
2. **Use explicit waits** — Wait for elements or navigation to complete before interacting.
3. **Test incrementally** — Start with simple interactions before complex flows.
4. **Use selectors wisely** — Prefer `data-testid` or role-based selectors over CSS classes.

## Phase Requirements (EARS)

- The browser automation workflow SHALL verify server availability, use explicit element or navigation waits, and prefer `data-testid` or role-based selectors over brittle style classes.
- IF the local web server is unavailable before test execution, THEN the browser automation workflow SHALL report the connection precondition failure before invoking browser actions.
