import { test, expect, type Page, type Route } from '@playwright/test';

async function setup(page: Page, options: { token?: string | null; role?: string; language?: string; theme?: string } = {}) {
  await page.addInitScript(options => {
    localStorage.setItem('askxuan-language', options.language || 'zh-Hans');
    localStorage.setItem('askxuan-theme', options.theme || 'light');
    if ('token' in options) {
      if (options.token) localStorage.setItem('h5_token', options.token);
      localStorage.setItem('h5-auth', JSON.stringify({ state: { token: options.token, role: options.role || 'customer', userId: 99026 }, version: 0 }));
    }
  }, options);
  await page.route('**/api/v1/**', async route => {
    const path = new URL(route.request().url()).pathname;
    let data: unknown = [];
    if (path.endsWith('/auth/options')) data = { emailEnabled: true, agreementVersion: 'test' };
    if (path.endsWith('/auth/captcha')) data = { id: 'local-fixture', image: 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg"/%3E', expiresIn: 300 };
    if (path.endsWith('/auth/login')) data = { accessToken: 'local-only', refreshToken: 'local-refresh', userInfo: { userId: 99026, nickname: '测试' } };
    if (path.endsWith('/points')) data = { balance: 0 };
    await route.fulfill({ json: { code: 0, data } });
  });
}

for (const theme of ['light', 'dark']) for (const language of ['zh-Hans', 'zh-Hant']) {
  test(`guest entry, theme and language ${theme} ${language}`, async ({ page }) => {
    await page.setViewportSize({ width: language === 'zh-Hans' ? 320 : 503, height: 954 });
    await setup(page, { theme, language });
    let accountRequests = 0;
    page.on('request', request => { if (new URL(request.url()).pathname === '/api/v1/points') accountRequests++; });
    await page.goto('/c');
    const entry = page.locator('.home-points-entry');
    await expect(entry).toContainText(language === 'zh-Hans' ? '登录查看' : '登錄查看');
    await expect(entry.locator('small')).toHaveCount(0);
    await expect(entry).toHaveAttribute('href', '/c/login?redirect=%2Fc%2Fpoints');
    const colors = await page.evaluate(() => {
      const points = getComputedStyle(document.querySelector('.home-points-entry')!);
      const neighbor = getComputedStyle(document.querySelector('.home-directory-card')!);
      return [points.backgroundColor, neighbor.backgroundColor];
    });
    expect(colors[0]).toBe(colors[1]);
    const bounds = await entry.boundingBox();
    expect(bounds!.x).toBeGreaterThanOrEqual(0);
    expect(bounds!.x + bounds!.width).toBeLessThanOrEqual(page.viewportSize()!.width);
    expect(await entry.evaluate(el => el.scrollWidth <= el.clientWidth)).toBeTruthy();
    await entry.click();
    await expect(page).toHaveURL(/\/c\/login\?redirect=%2Fc%2Fpoints$/);
    await expect(page.locator('.account-submit')).toBeVisible();
    expect(accountRequests).toBe(0);
  });
}

for (const outcome of [0, 871, 'failed'] as const) {
  test(`customer balance distinguishes pending and ${outcome}`, async ({ page }) => {
    const theme = outcome === 871 ? 'dark' : 'light';
    await setup(page, { token: 'local-only', theme });
    let respond!: (route: Route) => Promise<void>;
    const ready = new Promise<void>(resolve => {
      respond = async route => { await new Promise<void>(done => { release = done; resolve(); });
        await route.fulfill(outcome === 'failed'
          ? { status: 503, json: { code: 500, message: '暂时不可用' } }
          : { json: { code: 0, data: { balance: outcome } } });
      };
    });
    let release!: () => void;
    await page.route('**/api/v1/points', respond);
    await page.goto('/c');
    await ready;
    const entry = page.locator('.home-points-entry');
    try { await expect(entry).toContainText('加载中…'); } finally { release(); }
    await expect(entry.locator('.home-points-balance strong')).toHaveText(outcome === 'failed' ? '暂未获取' : String(outcome));
    await expect(entry).not.toContainText('登录查看');
    await expect(entry).toHaveAttribute('href', '/c/points');
    if (outcome !== 'failed') {
      await page.unroute('**/api/v1/points', respond);
      await entry.click();
      await expect(page.locator('.points-account-value')).toHaveText('0');
      await expect(page.locator('.points-account-card')).toHaveCSS('background-color', theme === 'light' ? 'rgb(255, 253, 248)' : 'rgb(42, 30, 26)');
    }
  });
}

test('guest login returns to the selected points record without requesting an account first', async ({ page }) => {
  await setup(page);
  let accountRequests = 0;
  page.on('request', request => { if (new URL(request.url()).pathname === '/api/v1/points') accountRequests++; });
  await page.goto('/c/points?tab=ledger');
  await expect(page).toHaveURL(/\/c\/login\?redirect=%2Fc%2Fpoints%3Ftab%3Dledger$/);
  expect(accountRequests).toBe(0);
  await page.getByLabel('邮箱／用户名', { exact: true }).fill('test-user');
  await page.getByLabel('密码', { exact: true }).fill('test-password');
  // Local mocked proof only; no live challenge or account is involved.
  await page.getByRole('textbox', { name: '图片验证码', exact: true }).fill('12345');
  await page.locator('.account-submit').click();
  await expect(page).toHaveURL(/\/c\/points\?tab=ledger$/);
  await expect(page.getByRole('tab', { name: '积分明细', exact: true })).toHaveAttribute('aria-selected', 'true');
  expect(accountRequests).toBeGreaterThan(0);
});

test('incomplete persisted authentication can reach login', async ({ page }) => {
  await setup(page, { token: null });
  await page.goto('/c/points');
  await expect(page).toHaveURL(/\/c\/login\?redirect=%2Fc%2Fpoints$/);
  await expect(page.locator('.account-submit')).toBeVisible();
});

test('late balance from the previous account cannot replace the new account or guest entry', async ({ page }) => {
  await setup(page, { token: 'old-account' });
  let release!: () => void;
  const pending = new Promise<void>(resolve => { release = resolve; });
  await page.route('**/api/v1/points', async route => {
    const old = route.request().headers().authorization === 'Bearer old-account';
    if (old) await pending;
    await route.fulfill({ json: { code: 0, data: { balance: old ? 871 : 0 } } });
  });
  await page.goto('/c');
  await expect(page.locator('.home-points-balance')).toContainText('加载中…');
  await page.evaluate(async () => {
    // Vite test server module, sharing the mounted application's store.
    const { useAuthStore } = await import('/src/stores/auth.ts');
    localStorage.setItem('h5_token', 'new-account');
    useAuthStore.setState({ userId: 99027, token: 'new-account', role: 'customer' });
  });
  await expect(page.locator('.home-points-balance strong')).toHaveText('0');
  const response = page.waitForResponse(r => r.url().endsWith('/api/v1/points') && r.request().headers().authorization === 'Bearer old-account');
  release(); await response;
  await expect(page.locator('.home-points-balance strong')).toHaveText('0');
  await page.evaluate(async () => {
    const { useAuthStore } = await import('/src/stores/auth.ts');
    useAuthStore.setState({ token: null, userId: undefined, role: null });
  });
  await expect(page.locator('.home-points-balance')).toHaveText('登录查看');
  await expect(page.locator('.home-points-entry small')).toHaveCount(0);
});
