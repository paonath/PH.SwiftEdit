# Angular & TypeScript BDD Automation with Playwright-BDD

Combines Cucumber Gherkin `.feature` files with Playwright's high-speed end-to-end browser automation.

## 1. Setup
```bash
npm install -D playwright-bdd @playwright/test @cucumber/cucumber
```

## 2. Step Definition Implementation
```typescript
import { createBdd } from 'playwright-bdd';
import { expect } from '@playwright/test';

const { Given, When, Then } = createBdd();

Given('a registered user on the login page', async ({ page }) => {
  await page.goto('/login');
});

When('the user submits valid credentials', async ({ page }) => {
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('ValidPass123!');
  await page.getByRole('button', { name: 'Sign In' }).click();
});

Then('access is granted to the personal dashboard', async ({ page }) => {
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```
