import { test, expect, type Page } from '@playwright/test';

type SessionFixture = { token?: string | null; userId?: number | null; role?: string; language?: string; theme?: string };
const pointModes = [
  { tab: 'wheel', label: '商城', traditionalLabel: '商城', detail: '积分转盘', traditionalDetail: '積分轉盤' },
  { tab: 'mall', label: '转盘', traditionalLabel: '轉盤', detail: '积分商城', traditionalDetail: '積分商城' },
  { tab: 'pool', label: '乐购', traditionalLabel: '樂購', detail: '奖池', traditionalDetail: '獎池' },
] as const;
type PointTab = typeof pointModes[number]['tab'];
const pointsEntry = (page: Page, tab: PointTab = 'wheel') => page.locator(`.home-points-card[href="/c/points?tab=${tab}"]`);
const pointsTarget = (tab: PointTab) => `/c/points?tab=${tab}`;
const loginTarget = (tab: PointTab) => '/c/login?redirect=' + encodeURIComponent(pointsTarget(tab));
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
  await page.route('**/fixture-home-banner.svg', route => route.fulfill({
    contentType: 'image/svg+xml', body: '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="240"><rect width="600" height="240" fill="#674b37"/></svg>',
  }));
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
      { code: 'study', name: '求学业', landingType: 'aggregate' },
      { code: 'taisui', name: '化太岁', landingType: 'aggregate' },
      { code: 'rite', name: '仪式服务', landingType: 'service' },
    ] };
    if (path.endsWith('/marketing/banners')) data = { total: 1, list: [{ id: 1, title: '首页活动', placement: 'customer_home', imageUrl: '/fixture-home-banner.svg', linkType: 'diy', linkValue: '', sort: 1, status: 'enabled', startTime: '', endTime: '' }] };
    if (path.endsWith('/diy/designs')) data = { total: 0, list: [], page: 1, size: 20 };
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

async function assertPlazaHidden(page: Page) {
  const diy = page.locator('.home-diy-section');
  await expect(diy.locator('.home-diy-entry')).toBeVisible();
  await expect(diy.locator('.home-plaza-heading, .home-designs, .home-design-more, .home-design, .home-design-example, .home-plaza-example-label, .home-design-status')).toHaveCount(0);
  await expect(diy.getByRole('status')).toHaveCount(0);
  await expect(diy.getByRole('alert')).toHaveCount(0);
  await expect(diy.getByRole('button', { name: '重新加载', exact: true })).toHaveCount(0);
}

async function assertHomeLayout(page: Page, language: string) {
  const traditional = language === 'zh-Hant';
  const entries = page.locator('.home-core-entries > .home-core-entry');
  await expect(entries).toHaveCount(2);
  await expect(entries.locator('strong')).toHaveText(traditional ? ['找寺廟', '找師傅'] : ['找寺庙', '找师傅']);
  await expect(entries.nth(0)).toHaveAttribute('href', '/c/temples');
  await expect(entries.nth(1)).toHaveAttribute('href', '/c/masters');
  await expect(entries.locator('.home-core-copy > span')).toHaveCount(2);
  await expect(page.locator('.home-belief-card, .home-belief-grid, .home-points-entry, .home-points-balance, .home-directory')).toHaveCount(0);
  await expect(entries.locator('.home-core-icon > svg')).toHaveCount(2);
  const patterns = entries.locator('svg.home-core-pattern');
  await expect(patterns).toHaveCount(2);
  for (let index = 0; index < 2; index++) {
    await expect(patterns.nth(index)).toHaveAttribute('aria-hidden', 'true');
    await expect(patterns.nth(index)).toHaveAttribute('focusable', 'false');
    await expect(patterns.nth(index)).toHaveCSS('pointer-events', 'none');
  }
  const cards = await entries.evaluateAll(elements => elements.map(element => {
    const rect = element.getBoundingClientRect();
    const label = element.querySelector('strong')!.getBoundingClientRect();
    const icon = element.querySelector('.home-core-icon > svg')!.getBoundingClientRect();
    const pattern = element.querySelector('svg.home-core-pattern')!;
    const style = getComputedStyle(element);
    return { x: rect.x, y: rect.y, width: rect.width, height: rect.height, right: rect.right,
      labelCenter: label.x + label.width / 2, iconCenter: icon.x + icon.width / 2,
      labelFits: label.left >= rect.left && label.right <= rect.right && label.top >= rect.top && label.bottom <= rect.bottom,
      pattern: pattern.innerHTML, opacity: Number(getComputedStyle(pattern).opacity), color: style.color, background: style.backgroundColor,
      iconSize: icon.width, font: getComputedStyle(element.querySelector('strong')!).fontFamily };
  }));
  expect(new Set(cards.map(card => card.pattern)).size).toBe(2);
  for (const card of cards) {
    expect(Math.abs(card.width - cards[0].width)).toBeLessThan(1);
    expect(Math.abs(card.height - cards[0].height)).toBeLessThan(1);
    expect(card.height).toBeGreaterThanOrEqual(page.viewportSize()!.width < 360 ? 156 : 164);
    expect(card.x).toBeGreaterThanOrEqual(0);
    expect(card.right).toBeLessThanOrEqual(page.viewportSize()!.width);
    expect(card.labelFits).toBeTruthy();
    expect(Math.abs(card.labelCenter - (card.x + card.width / 2))).toBeLessThan(1);
    expect(Math.abs(card.iconCenter - (card.x + card.width / 2))).toBeLessThan(1);
    expect(card.opacity).toBeGreaterThan(0);
    expect(card.opacity).toBeLessThan(0.25);
    expect(card.background).not.toBe('rgba(0, 0, 0, 0)');
    expect(card.color).toBe(cards[0].color);
    expect(card.iconSize).toBe(36);
  }
  expect(Math.abs(cards[0].y - cards[1].y)).toBeLessThan(1);
  expect(cards[1].x - cards[0].right).toBeCloseTo(12, 0);

  const wishes = page.locator('.home-wishes > .home-intent');
  await expect(wishes).toHaveCount(7);
  expect(await wishes.evaluateAll(elements => elements.map(element => element.getAttribute('href')))).toEqual(
    ['peace', 'wealth', 'love', 'career', 'study', 'taisui', 'rite'].map(code => '/c/intentions/' + code));
  await expect(page.locator('.home-wishes')).toHaveCSS('overflow-x', 'auto');
  const wishRail = await page.locator('.home-wishes').evaluate(element => {
    const cards = [...element.children].map(child => child.getBoundingClientRect());
    return { display: getComputedStyle(element).display, firstTop: cards[0].top, lastTop: cards.at(-1)!.top, scrollWidth: element.scrollWidth, clientWidth: element.clientWidth };
  });
  expect(wishRail.display).toBe('flex');
  expect(wishRail.firstTop).toBeCloseTo(wishRail.lastTop, 0);
  // Narrow screens expose the remaining wishes by scrolling; wide screens may fit all seven.
  if (page.viewportSize()!.width < 768) expect(wishRail.scrollWidth).toBeGreaterThan(wishRail.clientWidth);

  const diy = page.locator('.home-diy-entry');
  await expect(diy).toHaveAttribute('href', '/c/diy/editor');
  await expect(diy.locator('strong')).toHaveText(traditional ? '開始設計' : '开始设计');
  await expect(diy.locator('.home-diy-reward')).toHaveText(traditional ? '創作返利' : '创作返利');
  await assertPlazaHidden(page);

  const pointCards = page.locator('.home-points-grid > .home-points-card');
  await expect(pointCards).toHaveCount(3);
  for (const [index, mode] of pointModes.entries()) {
    await expect(pointCards.nth(index)).toHaveAttribute('href', pointsTarget(mode.tab));
    await expect(pointCards.nth(index)).toHaveAttribute('aria-label', `${traditional ? mode.traditionalLabel : mode.label} · ${traditional ? mode.traditionalDetail : mode.detail}`);
    await expect(pointCards.nth(index).locator('strong')).toHaveText(traditional ? mode.traditionalLabel : mode.label);
  }

  await expect(page.locator('.home-promotions-window')).toBeVisible();
  const layout = await page.locator('.customer-home').evaluate(element => {
    const sections = [...element.querySelectorAll(':scope > .home-discovery-section')];
    const core = element.querySelector('.home-core-entries')!.getBoundingClientRect();
    const banner = element.querySelector('.home-promotions-window')!.getBoundingClientRect();
    const wishes = element.querySelector('.home-wishes')!.getBoundingClientRect();
    const diy = element.querySelector('.home-diy-entry')!.getBoundingClientRect();
    const points = element.querySelector('.home-points-grid')!.getBoundingClientRect();
    return {
      ids: sections.map(section => section.getAttribute('aria-labelledby')),
      bounds: [banner, ...sections.map(section => section.getBoundingClientRect()), wishes, diy, points].map(rect => ({ left: rect.left, right: rect.right })),
      left: core.left, right: core.right, bannerBottom: banner.bottom, coreTop: core.top,
      headingFont: getComputedStyle(sections[0].querySelector('h2')!).fontFamily,
      surfaces: [...element.querySelectorAll('.home-core-entry, .home-intent, .home-diy-entry, .home-design, .home-design-more, .home-points-card')].map(item => {
        const style = getComputedStyle(item);
        return { radius: style.borderRadius, left: style.borderLeftWidth, right: style.borderRightWidth };
      }),
    };
  });
  expect(layout.ids).toEqual(['home-intents-title', 'home-diy-title', 'home-points-title', 'home-temples-title', 'home-masters-title']);
  expect(layout.bannerBottom).toBeLessThanOrEqual(layout.coreTop);
  for (const bounds of layout.bounds) {
    expect(Math.abs(bounds.left - layout.left)).toBeLessThan(1);
    expect(Math.abs(bounds.right - layout.right)).toBeLessThan(1);
  }
  expect(cards[0].font).toBe(layout.headingFont);
  for (const surface of layout.surfaces) expect(surface).toEqual({ radius: '12px', left: '0px', right: '0px' });
  for (const entry of await wishes.all()) expect(await entry.evaluate(element => element.scrollWidth <= element.clientWidth + 1)).toBeTruthy();
  const utilityLayout = await page.locator('.customer-home').evaluate(element => {
    const wishes = element.querySelector('.home-wishes')!.getBoundingClientRect();
    const wishCards = [...element.querySelectorAll('.home-intent')].map(item => item.getBoundingClientRect());
    const diy = element.querySelector('.home-diy-entry')!.getBoundingClientRect();
    const points = element.querySelector('.home-points-grid')!.getBoundingClientRect();
    const pointCards = [...element.querySelectorAll('.home-points-card')].map(item => item.getBoundingClientRect());
    const pointsSection = element.querySelector('.home-points-section')!.getBoundingClientRect();
    const titleBottom = (id: string) => element.querySelector('#' + id)!.getBoundingClientRect().bottom;
    return {
      heights: [...wishCards, diy, ...pointCards].map(rect => rect.height),
      wishRight: wishes.right, fourthWishRight: wishCards[3].right, fifthWishLeft: wishCards[4].left,
      gaps: [wishCards[1].left - wishCards[0].right, pointCards[1].left - pointCards[0].right, pointCards[2].left - pointCards[1].right],
      pointWidths: pointCards.map(rect => rect.width), pointTops: pointCards.map(rect => rect.top),
      headingGaps: [wishes.top - titleBottom('home-intents-title'), diy.top - titleBottom('home-diy-title'), points.top - titleBottom('home-points-title')],
      diyToPoints: pointsSection.top - diy.bottom,
    };
  });
  for (const height of utilityLayout.heights) expect(height).toBeCloseTo(88, 0);
  for (const gap of utilityLayout.gaps) expect(gap).toBeCloseTo(12, 0);
  for (const gap of utilityLayout.headingGaps) expect(gap).toBeCloseTo(12, 0);
  for (const width of utilityLayout.pointWidths) expect(width).toBeCloseTo(utilityLayout.pointWidths[0], 0);
  for (const top of utilityLayout.pointTops) expect(top).toBeCloseTo(utilityLayout.pointTops[0], 0);
  expect(utilityLayout.diyToPoints).toBeCloseTo(28, 0);
  if (page.viewportSize()!.width < 768) {
    expect(utilityLayout.fourthWishRight).toBeCloseTo(utilityLayout.wishRight, 0);
    expect(utilityLayout.fifthWishLeft).toBeGreaterThan(utilityLayout.wishRight);
  }
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBeTruthy();
}

for (const theme of ['light', 'dark']) for (const language of ['zh-Hans', 'zh-Hant']) for (const width of [320, 390, 509, 768]) {
  test(`confirmed homepage structure and guest redirect ${theme} ${language} ${width}`, async ({ page }) => {
    await page.setViewportSize({ width, height: 954 });
    await setup(page, { theme, language });
    let accountRequests = 0;
    page.on('request', request => { if (isPointsAccount(request.url())) accountRequests++; });
    await page.goto('/c');
    await expect(page.locator('html')).toHaveAttribute('data-theme', theme);
    await assertHomeLayout(page, language);
    expect(accountRequests).toBe(0);
    await pointsEntry(page).click();
    await expect(page).toHaveURL(new RegExp('/c/login\\?redirect=' + encodeURIComponent(pointsTarget('wheel')) + '$'));
    await expect(page.locator('.account-submit')).toBeVisible();
    expect(accountRequests).toBe(0);
  });
}

function designFixture(id: number, status = 'public') {
  return { id, name: `公开作品${id}`, status, userId: '99026', designData: JSON.stringify({ version: 1, wristSizeMm: 160,
    beads: Array.from({ length: 18 }, (_, position) => ({ position, materialId: 1, materialName: '紫檀', spec: '10mm', unitPrice: 1, subtype: 'main_bead', diameterMm: 10, colorHex: '694834', materialType: 'wood', textureKey: 'wood_grain', shape: 'round' })) }) };
}

test('homepage previews only four public designs without metadata and keeps one plaza destination', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 954 });
  await setup(page);
  const list = [designFixture(9000, 'private'), ...[9001, 9002, 9003, 9004, 9005].map(id => designFixture(id)), designFixture(9006, 'withdrawn')];
  await page.route('**/api/v1/diy/designs**', route => route.fulfill({ json: { code: 0, data: { total: list.length, list } } }));
  await page.goto('/c');
  const designs = page.locator('.home-designs > a.home-design');
  await expect(designs).toHaveCount(4);
  await expect(page.locator('.home-plaza-heading h3')).toHaveText('广场精选');
  expect(await designs.evaluateAll(elements => elements.map(element => element.getAttribute('href')))).toEqual([9001, 9002, 9003, 9004].map(id => '/c/diy/' + id));
  await expect(page.locator('.home-design-example, .home-plaza-example-label')).toHaveCount(0);
  await expect(designs.locator('strong, small, p')).toHaveCount(0);
  for (const [index, design] of (await designs.all()).entries()) {
    await expect(design).toHaveAttribute('aria-label', `查看作品：公开作品${9001 + index}`);
    expect(await design.innerText()).toBe('');
    const rect = (await design.boundingBox())!;
    expect(rect.width).toBeCloseTo(104, 0);
    expect(rect.height).toBeCloseTo(104, 0);
  }
  const tail = page.locator('.home-design-more');
  await expect(tail).toHaveCount(1);
  await expect(page.locator('.home-designs > *')).toHaveCount(5);
  await expect(page.locator('.home-designs > :last-child')).toHaveClass(/home-design-more/);
  await expect(tail).toHaveAttribute('href', '/c/diy?tab=plaza');
  const tailRect = (await tail.boundingBox())!;
  expect(tailRect.width).toBeCloseTo(104, 0);
  expect(tailRect.height).toBeCloseTo(104, 0);
  await expect(page.locator('.home-diy-section a[href="/c/diy?tab=plaza"]')).toHaveCount(1);
  const rail = await page.locator('.home-designs').evaluate(element => {
    const items = [...element.children].map(child => child.getBoundingClientRect());
    return { display: getComputedStyle(element).display, tops: items.map(item => item.top), gap: items[1].left - items[0].right, scrollWidth: element.scrollWidth, clientWidth: element.clientWidth };
  });
  expect(rail.display).toBe('flex');
  for (const top of rail.tops) expect(top).toBeCloseTo(rail.tops[0], 0);
  expect(rail.gap).toBeCloseTo(12, 0);
  expect(rail.scrollWidth).toBeGreaterThan(rail.clientWidth);
  await tail.click();
  await expect(page).toHaveURL(/\/c\/diy\?tab=plaza$/);
});

test('homepage hides pending, failed and private-only plaza data and restores public works after reload', async ({ page }) => {
  await setup(page);
  let phase: 'pending' | 'failed' | 'private' | 'public' = 'pending';
  let started = false, release!: () => void;
  const pending = new Promise<void>(resolve => { release = resolve; });
  const isDesignResponse = (url: string) => new URL(url).pathname === '/api/v1/diy/designs';
  await page.route('**/api/v1/diy/designs**', async route => {
    started = true;
    if (phase === 'pending') await pending;
    if (phase === 'failed') return route.fulfill({ status: 503, json: { code: 500, message: '暂时不可用' } });
    const list = phase === 'private' ? [designFixture(9000, 'private'), designFixture(9006, 'withdrawn')] : [designFixture(9001)];
    await route.fulfill({ json: { code: 0, data: { total: list.length, list } } });
  });
  await page.goto('/c');
  await expect.poll(() => started).toBe(true);
  const failedResponse = page.waitForResponse(response => isDesignResponse(response.url()) && response.status() === 503);
  try { await assertPlazaHidden(page); }
  finally { phase = 'failed'; release(); }
  await (await failedResponse).finished();
  await assertPlazaHidden(page);

  phase = 'private';
  const privateResponse = page.waitForResponse(response => isDesignResponse(response.url()) && response.status() === 200);
  await page.reload();
  await (await privateResponse).finished();
  await assertPlazaHidden(page);

  phase = 'public';
  await page.reload();
  const gallery = page.locator('.home-diy-section');
  await expect(gallery.locator('a.home-design')).toHaveCount(1);
  await expect(gallery.locator('a.home-design')).toHaveAttribute('href', '/c/diy/9001');
  await expect(gallery.locator('.home-plaza-heading h3')).toHaveText('广场精选');
  await expect(gallery.locator('.home-design-more')).toHaveCount(1);
  await expect(gallery.locator('.home-design-more')).toHaveAttribute('href', '/c/diy?tab=plaza');
  await expect(gallery.locator('.home-design-example, .home-plaza-example-label, .home-design-status')).toHaveCount(0);
});

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

for (const mode of pointModes) {
  test(`signed-in ${mode.label} entry opens ${mode.detail}`, async ({ page }) => {
    await setup(page, { token: 'local-only' });
    let accountRequests = 0;
    page.on('request', request => { if (isPointsAccount(request.url())) accountRequests++; });
    await page.goto('/c');
    await expect(pointsEntry(page, mode.tab)).toHaveAttribute('href', pointsTarget(mode.tab));
    expect(accountRequests).toBe(0);
    await pointsEntry(page, mode.tab).click();
    await expect(page).toHaveURL(new RegExp('/c/points\\?tab=' + mode.tab + '$'));
    await expect(page.getByRole('tab', { name: mode.detail, exact: true })).toHaveAttribute('aria-selected', 'true');
    await expect(page.locator('.points-account-value')).toHaveText('0');
    expect(accountRequests).toBeGreaterThan(0);
  });

  test(`guest ${mode.label} entry preserves ${mode.detail} after login`, async ({ page }) => {
    await setup(page);
    let accountRequests = 0;
    page.on('request', request => { if (isPointsAccount(request.url())) accountRequests++; });
    await page.goto('/c');
    await pointsEntry(page, mode.tab).click();
    await expect(page).toHaveURL(new RegExp('/c/login\\?redirect=' + encodeURIComponent(pointsTarget(mode.tab)) + '$'));
    await expect(page.locator('.account-submit')).toBeVisible();
    expect(accountRequests).toBe(0);
    await login(page);
    await expect(page).toHaveURL(new RegExp('/c/points\\?tab=' + mode.tab + '$'));
    await expect(page.getByRole('tab', { name: mode.detail, exact: true })).toHaveAttribute('aria-selected', 'true');
    await expect(page.locator('.points-account-value')).toHaveText('0');
    expect(accountRequests).toBeGreaterThan(0);
  });
}

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

test('home destinations remain stable through account changes and the points page guards guests', async ({ page }) => {
  await setup(page, { token: 'old-account' });
  let accountRequests = 0;
  page.on('request', request => { if (isPointsAccount(request.url())) accountRequests++; });
  await page.goto('/c');
  for (const mode of pointModes) await expect(pointsEntry(page, mode.tab)).toHaveAttribute('href', pointsTarget(mode.tab));
  for (const identity of [
    { token: 'new-account', userId: 99027, role: 'customer' },
    { token: 'new-account', userId: undefined, role: 'customer' },
    { token: 'new-account', userId: 99027, role: 'master' },
    { token: 'new-account', userId: 99027, role: 'customer' },
    { token: null, userId: undefined, role: null },
  ]) {
    await page.evaluate(async identity => {
      const { useAuthStore } = await import('/src/stores/auth.ts');
      if (identity.token) localStorage.setItem('h5_token', identity.token);
      else localStorage.removeItem('h5_token');
      useAuthStore.setState(identity);
    }, identity);
    for (const mode of pointModes) {
      await expect(pointsEntry(page, mode.tab)).toHaveAttribute('href', pointsTarget(mode.tab));
      await expect(pointsEntry(page, mode.tab)).toHaveAttribute('aria-label', `${mode.label} · ${mode.detail}`);
    }
    expect(accountRequests).toBe(0);
  }
  await expect(page).toHaveURL(/\/c$/);
  await pointsEntry(page, 'mall').click();
  await expect(page.locator('.account-submit')).toBeVisible();
  expect(new URL(page.url()).pathname + new URL(page.url()).search).toBe(loginTarget('mall'));
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
