const { test, expect } = require('@playwright/test');

const publicRoutes = [
  '/',
  '/disclaimer',
  '/onboarding',
  '/profile-setup',
  '/legal/terms',
  '/legal/privacy',
  '/about/release-notes',
];

test.beforeEach(async ({ page }) => {
  await page.route(
    'https://www.googleapis.com/identitytoolkit/v3/relyingparty/getProjectConfig**',
    route => route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        projectId: 'demo-najm',
        authorizedDomains: ['127.0.0.1', 'localhost'],
      }),
    }),
  );
});

async function enableFlutterSemantics(page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  if (await placeholder.count()) {
    await placeholder.evaluate(element => element.click());
  }
}

function captureRuntimeErrors(page) {
  const errors = [];
  page.on('pageerror', error => errors.push(`pageerror: ${error.message}`));
  page.on('response', response => {
    if (response.status() >= 400) {
      errors.push(`http ${response.status()}: ${response.url()}`);
    }
  });
  page.on('console', message => {
    if (message.type() === 'error' &&
        !message.text().startsWith('Failed to load resource:')) {
      errors.push(`console: ${message.text()}`);
    }
  });
  return errors;
}

async function openReady(page, route = '/') {
  await page.goto(`/#${route}`, { waitUntil: 'domcontentloaded' });
  await page.locator('flutter-view').waitFor({ state: 'attached', timeout: 90_000 });
  await enableFlutterSemantics(page);
  await expect(page.getByText(/Disclaimer|Crew Intelligence Platform|Create Account/).first()).toBeVisible();
}

async function fillFlutterField(page, locator, value) {
  for (let attempt = 0; attempt < 3; attempt += 1) {
    await locator.focus();
    await page.waitForTimeout(250);
    await page.keyboard.press('ControlOrMeta+A');
    await page.keyboard.type(value, { delay: 50 });
    await page.keyboard.press('Tab');
    if (await locator.inputValue() === value) return;
  }
  await expect(locator).toHaveValue(value);
}

test('boots, exposes reachable public routes, and redirects protected routes safely', async ({ page }) => {
  const runtimeErrors = captureRuntimeErrors(page);
  await openReady(page);

  for (const route of publicRoutes) {
    await page.goto(`/#${route}`, { waitUntil: 'domcontentloaded' });
    await enableFlutterSemantics(page);
    await expect(page.locator('flutter-view')).toBeVisible();
    await expect(page.getByText('Route not found:', { exact: false })).toHaveCount(0);
  }

  for (const route of ['/home', '/lines', '/bids', '/trades', '/assistant', '/settings']) {
    await page.goto(`/#${route}`, { waitUntil: 'domcontentloaded' });
    await enableFlutterSemantics(page);
    await expect(page.getByText('Disclaimer', { exact: true })).toBeVisible();
  }

  expect(runtimeErrors).toEqual([]);
});

test('safe onboarding actions lead to account creation', async ({ page }) => {
  const runtimeErrors = captureRuntimeErrors(page);
  await openReady(page, '/disclaimer');

  const checkbox = page.getByRole('checkbox');
  await checkbox.click();
  await expect(checkbox).toHaveAttribute('aria-checked', 'true');
  await page.getByRole('button', { name: 'I Understand' }).click();
  await expect(page.getByRole('button', { name: 'Skip' })).toBeVisible();
  await page.getByRole('button', { name: 'Skip' }).click();
  await expect(page.getByText('Create Account', { exact: true }).first()).toBeVisible();

  expect(runtimeErrors).toEqual([]);
});

test('creates a safe development account using Firebase emulators', async ({ page }, testInfo) => {
  const runtimeErrors = captureRuntimeErrors(page);
  await openReady(page, '/profile-setup');
  const email = `e2e-${testInfo.project.name}-${Date.now()}@example.test`;

  await fillFlutterField(page, page.getByRole('textbox', { name: 'Full Name' }), 'NAJM E2E User');
  await fillFlutterField(page, page.getByRole('textbox', { name: 'Crew ID' }), 'E2E12345');
  await fillFlutterField(page, page.getByRole('textbox', { name: 'Email Address' }), email);
  await fillFlutterField(page, page.getByRole('textbox', { name: 'Password' }), 'SafeE2E123!');
  await page.getByRole('button', { name: 'Create Account' }).click();

  await expect(page.getByText('Account Under Review')).toBeVisible();
  expect(runtimeErrors).toEqual([]);
});
