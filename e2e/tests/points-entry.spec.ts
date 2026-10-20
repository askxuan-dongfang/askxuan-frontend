import { test, expect, type Page } from '@playwright/test';

type SessionFixture = { token?: string | null; userId?: number | null; role?: string; language?: string; theme?: string };
const pointsEntry = (page: Page) => page.locator('.home-core-points');
const isPointsAccount = (url: string) => new URL(url).pathname === '/api/v1/points';

async function setup(page: Page, options: SessionFixture = {}) {
  await page.addInitScript(options => {
    localStorage.setItem('askxuan-language', options.language || 'zh-Hans');
    localStorage.setItem('askxuan-theme', options.theme || 'light');
    if ('token' in options) {
      if (options.token) localStorage.setItem('h5_token', options.token);
      else localStorage.removeItem('h5_token');
      localStorage.setItem('h5-auth', JSON.stringify({ state: { token: options.token, role: options.role || 'customer', userId: options.userId === undefined ? 99026 : options.userId }, version: 0 }));
    }
  }, options);
  await page.route('**/api/v1/**', async route => {
    const path = new URL(route.request().url()).pathname;
    let data: unknown = [];
    if (['/beliefs', '/intentions/tags', '/temples', '/masters', '/marketing/banners'].some(suffix => path.endsWith(suffix))) data = { total: 0, list: [] };
    if (path.endsWith('/beliefs')) data = { list: [
      { code: 'han_buddhism', name: '汉传佛教', summary: '慈悲与智慧并行' },
      { code: 'tibetan_buddhism', name: '藏传佛教', summary: '传承、修持与慈悲' },
      { code: 'theravada_buddhism', name: '南传佛教', summary: '戒、定、慧与日常修习' },
      { code: 'daoism', name: '道教', summary: '道法自然，清静修持' },
      { code: 'folk', name: '民间信仰', summary: '乡土传统与民俗传承' },
    ] };
    if (path.endsWith('/intentions/tags')) data = { list: [
      { code: 'peace', name: '求平安', landingType: 'aggregate' },
      { code: 'wealth', name: '求财运', landingType: 'aggregate' },
      { code: 'love', name: '求姻缘', landingType: 'aggregate' },
      { code: 'career', name: '事业发展', landingType: 'aggregate' },
      { code: 'health', name: '身体健康', landingType: 'aggregate' },
      { code: 'wisdom', name: '开启智慧', landingType: 'aggregate' },
      { code: 'rite', name: '仪式服务', landingType: 'service' },
    ] };
    if (path.endsWith('/auth/options')) data = { emailEnabled: true, agreementVersion: 'test' };
    if (path.endsWith('/auth/captcha')) data = { id: 'local-fixture', image: 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg"/%3E', expiresIn: 300 };
    if (path.endsWith('/auth/login')) data = { accessToken: 'local-only', refreshToken: 'local-refresh', userInfo: { userId: 99026, nickname: '测试' } };
    if (path.endsWith('/points')) data = { balance: 0 };
    await route.fulfill({ json: { code: 0, data } });
  });
}

async function login(page: Page) {
  await page.getByLabel('邮箱／用户名', { exact: true }).fill('test-user');
  await page.getByLabel('密码', { exact: true }).fill('test-password');
  // Local mocked proof only; no live challenge or account is involved.
  await page.getByRole('textbox', { name: '图片验证码', exact: true }).fill('12345');
  await page.locator('.account-submit').click();
}

async function assertCoreGrid(page: Page, language: string) {
  const entries = page.locator('.home-core-entries > .home-core-entry');
  await expect(entries).toHaveCount(4);
  await expect(entries.locator('strong')).toHaveText(language === 'zh-Hant'
    ? ['找寺院', '找師傅', 'DIY手串', '積分中心']
    : ['找寺院', '找师傅', 'DIY手串', '积分中心']);
  await expect(entries.locator('small, p')).toHaveCount(0);
  await expect(page.locator('.home-points-entry, .home-points-balance, .home-directory')).toHaveCount(0);
  await expect(entries.locator('.home-core-icon > svg')).toHaveCount(4);
  const patterns = entries.locator('svg.home-core-pattern');
  await expect(patterns).toHaveCount(4);
  for (let index = 0; index < 4; index++) {
    await expect(patterns.nth(index)).toHaveAttribute('aria-hidden', 'true');
    await expect(patterns.nth(index)).toHaveAttribute('focusable', 'false');
    await expect(patterns.nth(index)).toHaveCSS('pointer-events', 'none');
  }
  const cards = await entries.evaluateAll(elements => elements.map(element => {
    const rect = element.getBoundingClientRect();
    const label = element.querySelector('strong')!.getBoundingClientRect();
    const pattern = element.querySelector('svg.home-core-pattern')!;
    const icon = element.querySelector('.home-core-icon > svg')!.getBoundingClientRect();
    const labelStyle = getComputedStyle(element.querySelector('strong')!);
    const style = getComputedStyle(element);
    return { x: rect.x, y: rect.y, width: rect.width, height: rect.height, right: rect.right,
      labelX: label.x, labelFits: label.left >= rect.left && label.right <= rect.right && label.top >= rect.top && label.bottom <= rect.bottom,
      pattern: pattern.innerHTML, opacity: Number(getComputedStyle(pattern).opacity), color: style.color, background: style.backgroundColor,
      iconSize: icon.width, labelSize: parseFloat(labelStyle.fontSize), font: labelStyle.fontFamily };
  }));
  expect(new Set(cards.map(card => card.pattern)).size).toBe(4);
  for (const card of cards) {
    expect(Math.abs(card.width - cards[0].width)).toBeLessThan(1);
    expect(Math.abs(card.height - cards[0].height)).toBeLessThan(1);
    expect(card.height).toBeGreaterThanOrEqual(96);
    expect(card.x).toBeGreaterThanOrEqual(0);
    expect(card.right).toBeLessThanOrEqual(page.viewportSize()!.width);
    expect(card.labelFits).toBeTruthy();
    expect(card.opacity).toBeGreaterThan(0);
    expect(card.opacity).toBeLessThan(0.25);
    expect(card.background).toBe('rgba(0, 0, 0, 0)');
    expect(card.color).toBe(cards[0].color);
    expect(card.iconSize).toBe(32);
    expect(card.labelSize).toBe(18);
  }
  await expect(page.locator('.home-belief-copy strong')).toHaveCount(5);
  await expect(page.locator('.home-belief-grid, .home-wishes')).toHaveCount(2);
  const typography = await page.locator('.home-discovery-section').first().evaluate(element => ({
    heading: getComputedStyle(element.querySelector('h2')!).fontFamily,
    title: getComputedStyle(element.querySelector('.home-belief-copy strong')!).fontFamily,
    description: getComputedStyle(element.querySelector('.home-belief-copy > span')!).fontFamily,
  }));
  expect(cards[0].font).toBe(typography.heading);
  expect(typography.title).toBe(typography.heading);
  expect(typography.description).toBe(typography.heading);
  const alignment = await page.locator('.customer-home').evaluate(element => {
    const beliefs = [...element.querySelectorAll('.home-belief-card')];
    const heading = element.querySelector('.home-discovery-section h2')!.getBoundingClientRect();
    const wishes = [...element.querySelectorAll('.home-intent')];
    return {
      headingX: heading.x,
      beliefTitles: beliefs.map(belief => belief.querySelector('strong')!.getBoundingClientRect().x),
      beliefRight: beliefs.map(belief => belief.getBoundingClientRect().right),
      lastSealRight: beliefs.at(-1)!.querySelector('.home-belief-seal')!.getBoundingClientRect().right,
      sealVisible: getComputedStyle(beliefs.at(-1)!.querySelector('.home-belief-seal')!).display !== 'none',
      wishX: wishes[0].getBoundingClientRect().x,
      verticalBorders: [...beliefs, ...wishes].map(item => ({
        left: getComputedStyle(item).borderLeftWidth, right: getComputedStyle(item).borderRightWidth,
      })),
    };
  });
  expect(Math.abs(cards[0].labelX - alignment.headingX)).toBeLessThan(1);
  expect(Math.abs(cards[0].labelX - alignment.beliefTitles[0])).toBeLessThan(1);
  expect(Math.abs(cards[1].labelX - alignment.beliefTitles[1])).toBeLessThan(1);
  expect(Math.abs(cards[0].labelX - alignment.beliefTitles[4])).toBeLessThan(1);
  expect(Math.abs(cards[0].labelX - alignment.wishX)).toBeLessThan(1);
  expect(Math.abs(alignment.beliefRight[1] - alignment.beliefRight[4])).toBeLessThan(1);
  if (alignment.sealVisible) {
    expect(Math.abs(alignment.lastSealRight - alignment.beliefRight[4])).toBeLessThan(1);
  }
  for (const border of alignment.verticalBorders) {
    expect(border).toEqual({ left: '0px', right: '0px' });
  }
  for (const section of await page.locator('.home-belief-grid, .home-wishes').all()) {
    await expect(section).toHaveCSS('background-color', 'rgba(0, 0, 0, 0)');
    await expect(section).toHaveCSS('border-top-width', '0px');
    await expect(section).toHaveCSS('border-radius', '0px');
  }
  for (const entry of await page.locator('.home-intent, .home-ritual-entry').all()) {
    expect(await entry.evaluate(element => element.scrollWidth <= element.clientWidth + 1)).toBeTruthy();
  }
  expect(Math.abs(cards[0].y - cards[1].y)).toBeLessThan(1);
  expect(Math.abs(cards[2].y - cards[3].y)).toBeLessThan(1);
  expect(Math.abs(cards[0].x - cards[2].x)).toBeLessThan(1);
  expect(Math.abs(cards[1].x - cards[3].x)).toBeLessThan(1);
  expect(cards[1].x).toBeGreaterThan(cards[0].right);
  expect(cards[2].y).toBeGreaterThan(cards[0].y + cards[0].height);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBeTruthy();
}

for (const theme of ['light', 'dark']) for (const language of ['zh-Hans', 'zh-Hant']) for (const width of [320, 390, 509]) {
  test(`four equal patterned entries and guest redirect ${theme} ${language} ${width}`, async ({ page }) => {
    await page.setViewportSize({ width, height: 954 });
    await setup(page, { theme, language });
    let accountRequests = 0;
    page.on('request', request => { if (isPointsAccount(request.url())) accountRequests++; });
    await page.goto('/c');
    await expect(page.locator('html')).toHaveAttribute('data-theme', theme);
    await assertCoreGrid(page, language);
    const entry = pointsEntry(page);
    await expect(entry).toHaveAttribute('aria-label', language === 'zh-Hans' ? '登录查看积分中心' : '登錄查看積分中心');
    await expect(entry).toHaveAttribute('href', '/c/login?redirect=%2Fc%2Fpoints');
    expect(accountRequests).toBe(0);
    await entry.click();
    await expect(page).toHaveURL(/\/c\/login\?redirect=%2Fc%2Fpoints$/);
    await expect(page.locator('.account-submit')).toBeVisible();
    expect(accountRequests).toBe(0);
  });
}

for (const outcome of [0, 871, 'failed'] as const) {
  test(`points center distinguishes pending and ${outcome}`, async ({ page }) => {
    const theme = outcome === 871 ? 'dark' : 'light';
    await setup(page, { token: 'local-only', theme });
    let release!: () => void, accountRequests = 0;
    const pending = new Promise<void>(resolve => { release = resolve; });
    await page.route('**/api/v1/points', async route => {
      accountRequests++;
      await pending;
      await route.fulfill(outcome === 'failed'
        ? { status: 503, json: { code: 500, message: '暂时不可用' } }
        : { json: { code: 0, data: { balance: outcome } } });
    });
    // The mall keeps the account card visible without the wheel's separate account loader.
    await page.goto('/c/points?tab=mall');
    await expect.poll(() => accountRequests).toBeGreaterThan(0);
    try {
      await expect(page.locator('.points-account-value')).toHaveText('—');
      await expect(page.getByRole('status', { name: '正在加载积分内容', exact: true })).toBeVisible();
    } finally { release(); }
    await expect(page.locator('.points-skeletons')).toHaveCount(0);
    if (outcome === 'failed') {
      await expect(page.locator('.points-account-value')).toHaveText('—');
      await expect(page.getByRole('alert')).toContainText('暂时不可用');
      await expect(page.getByRole('button', { name: '重新加载', exact: true })).toBeVisible();
      await expect(page.locator('.points-account-value')).not.toHaveText('0');
    } else {
      await expect(page.locator('.points-account-value')).toHaveText(String(outcome));
      await expect(page.getByRole('alert')).toHaveCount(0);
    }
    await expect(page.locator('.points-account-card')).toHaveCSS('background-color', theme === 'light' ? 'rgb(255, 253, 248)' : 'rgb(42, 30, 26)');
  });
}

test('signed-in customer goes directly from the home entry to points', async ({ page }) => {
  await setup(page, { token: 'local-only' });
  let accountRequests = 0;
  page.on('request', request => { if (isPointsAccount(request.url())) accountRequests++; });
  await page.goto('/c');
  await expect(pointsEntry(page)).toHaveAttribute('href', '/c/points');
  await expect(pointsEntry(page)).toHaveAttribute('aria-label', '进入积分中心');
  expect(accountRequests).toBe(0);
  await pointsEntry(page).click();
  await expect(page).toHaveURL(/\/c\/points$/);
  await expect(page.locator('.points-account-value')).toHaveText('0');
  expect(accountRequests).toBeGreaterThan(0);
});

test('guest home points entry returns to the center after login', async ({ page }) => {
  await setup(page);
  let accountRequests = 0;
  page.on('request', request => { if (isPointsAccount(request.url())) accountRequests++; });
  await page.goto('/c');
  await pointsEntry(page).click();
  await expect(page).toHaveURL(/\/c\/login\?redirect=%2Fc%2Fpoints$/);
  expect(accountRequests).toBe(0);
  await login(page);
  await expect(page).toHaveURL(/\/c\/points$/);
  await expect(page.locator('.points-account-value')).toHaveText('0');
  expect(accountRequests).toBeGreaterThan(0);
});

test('guest login returns to the selected points record without requesting an account first', async ({ page }) => {
  await setup(page);
  let accountRequests = 0;
  page.on('request', request => { if (isPointsAccount(request.url())) accountRequests++; });
  await page.goto('/c/points?tab=ledger');
  await expect(page).toHaveURL(/\/c\/login\?redirect=%2Fc%2Fpoints%3Ftab%3Dledger$/);
  expect(accountRequests).toBe(0);
  await login(page);
  await expect(page).toHaveURL(/\/c\/points\?tab=ledger$/);
  await expect(page.getByRole('tab', { name: '积分明细', exact: true })).toHaveAttribute('aria-selected', 'true');
  expect(accountRequests).toBeGreaterThan(0);
});

for (const fixture of [
  { name: 'missing token', token: null },
  { name: 'missing customer identity', token: 'local-only', userId: null },
  { name: 'non-customer role', token: 'local-only', role: 'master' },
]) {
  test(`incomplete persisted authentication can reach login: ${fixture.name}`, async ({ page }) => {
    await setup(page, fixture);
    let accountRequests = 0;
    page.on('request', request => { if (isPointsAccount(request.url())) accountRequests++; });
    await page.goto('/c/points');
    await expect(page).toHaveURL(/\/c\/login\?redirect=%2Fc%2Fpoints$/);
    await expect(page.locator('.account-submit')).toBeVisible();
    expect(accountRequests).toBe(0);
  });
}

test('mounted home entry follows account and guest changes without reading a balance', async ({ page }) => {
  await setup(page, { token: 'old-account' });
  let accountRequests = 0;
  page.on('request', request => { if (isPointsAccount(request.url())) accountRequests++; });
  await page.goto('/c');
  const entry = pointsEntry(page);
  await expect(entry).toHaveAttribute('href', '/c/points');
  await page.evaluate(async () => {
    // Vite test server module, sharing the mounted application's store.
    const { useAuthStore } = await import('/src/stores/auth.ts');
    localStorage.setItem('h5_token', 'new-account');
    useAuthStore.setState({ userId: 99027, token: 'new-account', role: 'customer' });
  });
  await expect(entry).toHaveAttribute('href', '/c/points');
  await expect(entry).toHaveAttribute('aria-label', '进入积分中心');
  await page.evaluate(async () => {
    const { useAuthStore } = await import('/src/stores/auth.ts');
    useAuthStore.setState({ userId: undefined });
  });
  await expect(entry).toHaveAttribute('href', '/c/login?redirect=%2Fc%2Fpoints');
  await page.evaluate(async () => {
    const { useAuthStore } = await import('/src/stores/auth.ts');
    useAuthStore.setState({ userId: 99027, role: 'master' });
  });
  await expect(entry).toHaveAttribute('href', '/c/login?redirect=%2Fc%2Fpoints');
  await page.evaluate(async () => {
    const { useAuthStore } = await import('/src/stores/auth.ts');
    useAuthStore.setState({ role: 'customer' });
  });
  await expect(entry).toHaveAttribute('href', '/c/points');
  await page.evaluate(async () => {
    const { useAuthStore } = await import('/src/stores/auth.ts');
    localStorage.removeItem('h5_token');
    useAuthStore.setState({ token: null, userId: undefined, role: null });
  });
  await expect(entry).toHaveAttribute('href', '/c/login?redirect=%2Fc%2Fpoints');
  await expect(entry).toHaveAttribute('aria-label', '登录查看积分中心');
  await expect(entry.locator('strong')).toHaveText('积分中心');
  await expect(page).toHaveURL(/\/c$/);
  expect(accountRequests).toBe(0);
});

test('late balance from the previous account cannot replace the new account in the points center', async ({ page }) => {
  await setup(page, { token: 'old-account' });
  let release!: () => void, oldRequests = 0, accountRequests = 0;
  const pending = new Promise<void>(resolve => { release = resolve; });
  await page.route('**/api/v1/points', async route => {
    accountRequests++;
    const old = route.request().headers().authorization === 'Bearer old-account';
    if (old) { oldRequests++; await pending; }
    await route.fulfill({ json: { code: 0, data: { balance: old ? 871 : 0 } } });
  });
  await page.goto('/c/points?tab=mall');
  await expect.poll(() => oldRequests).toBeGreaterThan(0);
  try {
    await expect(page.locator('.points-account-value')).toHaveText('—');
    await page.evaluate(async () => {
      const { useAuthStore } = await import('/src/stores/auth.ts');
      localStorage.setItem('h5_token', 'new-account');
      useAuthStore.setState({ userId: 99027, token: 'new-account', role: 'customer' });
    });
    await expect(page.locator('.points-account-value')).toHaveText('0');
    const response = page.waitForResponse(r => isPointsAccount(r.url()) && r.request().headers().authorization === 'Bearer old-account');
    release();
    await (await response).finished();
    await page.evaluate(() => new Promise<void>(resolve => requestAnimationFrame(() => resolve())));
    await expect(page.locator('.points-account-value')).toHaveText('0');
  } finally { release(); }
  const beforeLogout = accountRequests;
  await page.evaluate(async () => {
    const { useAuthStore } = await import('/src/stores/auth.ts');
    localStorage.removeItem('h5_token');
    useAuthStore.setState({ token: null, userId: undefined, role: null });
  });
  await expect(page).toHaveURL(/\/c\/login\?redirect=%2Fc%2Fpoints%3Ftab%3Dmall$/);
  await expect(page.locator('.points-account-card')).toHaveCount(0);
  expect(accountRequests).toBe(beforeLogout);
});
