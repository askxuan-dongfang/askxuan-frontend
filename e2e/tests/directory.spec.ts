import { test, expect, type Page } from '@playwright/test';

const beliefs = [
  { code: 'han_buddhism', name: '汉传佛教' }, { code: 'tibetan_buddhism', name: '藏传佛教' },
  { code: 'theravada_buddhism', name: '南传佛教' }, { code: 'daoism', name: '道教' }, { code: 'folk', name: '民间信仰' },
];
const tags = [{ code: 'chan', group: 'tradition', name: '禅宗', value: '禅宗', beliefCode: 'han_buddhism', status: 'enabled' }];
const regions = [{ code: 'zj', name: '浙江省' }, { code: 'bj', name: '北京市' }];
const services = [{ code: 'S006', name: '开光' }, { code: 'S002', name: '供灯' }, { code: 'S001', name: '祈福' }, { code: 'S003', name: '上香' }];

async function setup(page: Page, failSecondPage = false, appearance = { language: 'zh-Hans', theme: 'light' }, ratings: { fail?: boolean; pending?: Promise<void> } = {}) {
  const calls: URL[] = [];
  let shouldFail = failSecondPage;
  await page.addInitScript(appearance => {
    localStorage.setItem('askxuan-language', appearance.language);
    localStorage.setItem('askxuan-theme', appearance.theme);
  }, appearance);
  await page.route('**/api/v1/**', async route => {
    const url = new URL(route.request().url()), path = url.pathname.replace('/api/v1', '');
    calls.push(url);
    let data: unknown = { list: [], total: 0 };
    if (path === '/beliefs') data = { list: beliefs };
    if (path === '/beliefs/directory-tags') data = { list: tags };
    if (path === '/regions') data = { list: regions };
    if (path === '/service-types') data = { list: services };
    if (path === '/reviews/ratings') {
      if (ratings.pending) await ratings.pending;
      if (ratings.fail) return route.fulfill({ status: 503, json: { code: 500, message: '评分接口暂时不可用' } });
      data = [
        { kind: 'master', code: '1', average: 4.6, count: 1234 },
        { kind: 'temple', code: '2', average: 5, count: 6 },
        { kind: 'master', code: '3', average: 0, count: 2 },
        { kind: 'master', code: '125', average: 4, count: 1 },
      ];
    }
    if (path === '/temples' || path === '/masters') {
      const pageNumber = Number(url.searchParams.get('page') || 1);
      if (shouldFail && pageNumber === 2) {
        return route.fulfill({ status: 503, json: { code: 500, message: '分页暂时不可用' } });
      }
      const rows = Array.from({ length: 125 }, (_, index) => {
        const target = index === 124;
        const common = { id: String(index + 1), regionCode: target ? 'zj' : 'bj', beliefCode: target ? 'han_buddhism' : 'daoism', traditionCodes: target ? ['chan'] : [], type: target ? '汉传佛教' : '道教', sect: '', rating: 4.8, status: 'enabled' };
        return path === '/temples'
          ? { ...common, name: target ? '灵隐寺' : `普通寺院${index + 1}`, region: target ? '杭州' : '北京', address: '', coverImage: '', serviceCodes: [target ? 'S006' : 'S002'], serviceTags: [target ? '开光' : '供灯'] }
          : { ...common, dharmaName: target ? '慧觉法师' : `普通师傅${index + 1}`, layName: target ? '张三' : '', templeName: '', position: index === 0 ? '自定义称谓' : '独立师傅', specialties: target ? ['禅修'] : [], avatar: '', serviceTags: [...(target ? [{ serviceCode: 'S001', price: 168, status: 'enabled' }, { serviceCode: 'S003', price: 168, status: 'enabled' }] : []), { serviceCode: target ? 'S006' : 'S002', price: 168, status: 'enabled' }, ...(index === 0 ? [{ serviceCode: 'S006', price: 99, status: 'disabled' }] : [])] };
      }).filter(row => !url.searchParams.get('regionCode') || row.regionCode === url.searchParams.get('regionCode'));
      // Deliberately cap the server page at 20 despite the client's size=100 request.
      data = { list: rows.slice((pageNumber - 1) * 20, pageNumber * 20), total: rows.length, page: pageNumber, size: 20 };
    }
    await route.fulfill({ json: { code: 0, data } });
  });
  return { calls, recover: () => { shouldFail = false; } };
}

for (const appearance of [{ language: 'zh-Hans', theme: 'light' }, { language: 'zh-Hant', theme: 'dark' }]) {
  test(`masters: cards use one real ratings batch, preserve unrated states and compose with services ${appearance.language}`, async ({ page }) => {
    const { calls } = await setup(page, false, appearance);
    await page.goto('/c/masters');
    const cards = page.locator('.master-result-card');
    await expect(cards).toHaveCount(125);
    const rated = cards.filter({ has: page.getByText('普通师傅1', { exact: true }) });
    await expect(rated.locator('.master-card-rating')).toHaveText(appearance.language === 'zh-Hant' ? '4.6 · 1,234條評價' : '4.6 · 1,234条评价');
    await expect(rated.locator('.master-card-rating span')).toHaveAttribute('aria-busy', 'false');
    const unrated = appearance.language === 'zh-Hant' ? '暫無評分' : '暂无评分';
    for (const name of ['普通师傅2']) {
      await expect(cards.filter({ has: page.getByText(name, { exact: true }) }).locator('.master-card-rating')).toHaveText(unrated);
    }
    await expect(cards.filter({ has: page.getByText('普通师傅3', { exact: true }) }).locator('.master-card-rating')).toHaveText(appearance.language === 'zh-Hant' ? '評分暫不可用' : '评分暂不可用');
    const geometry = await rated.locator('.master-card-rating').evaluate(element => {
      const box = element.getBoundingClientRect(), card = element.closest('a')!.getBoundingClientRect();
      const affiliation = element.previousElementSibling!.getBoundingClientRect();
      return { withinCard: box.left >= card.left && box.right <= card.right, belowRegion: box.top >= affiliation.bottom - 1, overflow: element.scrollWidth > element.clientWidth + 1 };
    });
    expect(geometry).toEqual({ withinCard: true, belowRegion: true, overflow: false });
    await page.getByRole('group', { name: appearance.language === 'zh-Hant' ? '提供服務' : '提供服务', exact: true }).getByRole('button', { name: appearance.language === 'zh-Hant' ? '開光' : '开光', exact: true }).click();
    await expect(cards).toHaveCount(1);
    await expect(cards.locator('.master-card-rating')).toHaveText(appearance.language === 'zh-Hant' ? '4.0 · 1條評價' : '4.0 · 1条评价');
    expect(calls.filter(url => url.pathname.endsWith('/reviews/ratings'))).toHaveLength(1);
    await cards.click();
    await expect(page).toHaveURL(/\/c\/masters\/125$/);
  });
}

test('masters: rating failure leaves directory and service filters usable without seed scores', async ({ page }) => {
  await setup(page, false, { language: 'zh-Hans', theme: 'light' }, { fail: true });
  await page.goto('/c/masters');
  const cards = page.locator('.master-result-card');
  await expect(cards).toHaveCount(125);
  await expect(cards.first().locator('.master-card-rating')).toHaveText('评分暂不可用');
  await expect(cards.first()).not.toContainText('4.8');
  await page.getByRole('group', { name: '提供服务', exact: true }).getByRole('button', { name: '开光', exact: true }).click();
  await expect(cards).toHaveCount(1);
  await expect(cards.locator('.master-card-rating')).toHaveText('评分暂不可用');
});

test('masters: pending ratings show a placeholder before the real result arrives', async ({ page }) => {
  let release!: () => void;
  const pending = new Promise<void>(resolve => { release = resolve; });
  await setup(page, false, { language: 'zh-Hans', theme: 'light' }, { pending });
  try {
    await page.goto('/c/masters');
    const rating = page.locator('.master-card-rating').first();
    await expect(rating).toHaveText('—');
    await expect(rating.locator('span')).toHaveAttribute('aria-busy', 'true');
    release();
    await expect(rating).toHaveText('4.6 · 1,234条评价');
  } finally { release(); }
});

for (const directory of ['temples', 'masters'] as const) {
  test(`${directory}: all pages, simplified/traditional search and selected filters compose`, async ({ page }) => {
    const { calls } = await setup(page);
    await page.goto(`/c/${directory}`);
    const cards = page.locator('.directory-results a.card-press');
    await expect(cards).toHaveCount(125);
    expect(calls.some(url => url.pathname.endsWith(`/${directory}`) && url.searchParams.get('page') === '7')).toBe(true);
    await page.getByRole('button', { name: '搜索', exact: true }).click();
    const search = page.getByRole('searchbox');
    await search.fill(directory === 'temples' ? '  靈隱 浙江 開光  ' : '  慧覺 浙江 開光  ');
    await expect(cards).toHaveCount(1);
    await expect(cards).toContainText(directory === 'temples' ? '灵隐寺' : '慧觉法师');
    if (directory === 'masters') {
      await page.getByRole('group', { name: '提供服务', exact: true }).getByRole('button', { name: '开光', exact: true }).click();
      await expect(page).toHaveURL(/serviceCode=S006/);
    }
    await page.locator('.directory-filters').getByRole('button', { name: '汉传佛教', exact: true }).click();
    await page.locator('.directory-traditions').getByRole('button', { name: '禅宗', exact: true }).click();
    await page.locator('.directory-region-trigger').click();
    await page.locator('.directory-region-panel').getByRole('button', { name: '浙江省', exact: true }).click();
    await expect(cards).toHaveCount(1);
    await expect(page).toHaveURL(/regionCode=zj/);
    await expect(page).toHaveURL(/traditionCode=chan/);
    await expect(page.locator('.directory-region-trigger')).toContainText('浙江');
    await search.fill('開光 北京');
    await expect(page.getByText('当前筛选无结果', { exact: true })).toBeVisible();
    await page.locator('.directory-search').getByRole('button', { name: '取消', exact: true }).click();
    await expect(search).toHaveCount(0);
    await expect(cards).toHaveCount(1);
    expect(new URL(page.url()).searchParams.has('q')).toBe(false);
    expect(new URL(page.url()).searchParams.get('regionCode')).toBe('zj');
  });

  test(`${directory}: fixed region trigger and mutually exclusive popovers never move results`, async ({ page }) => {
    await setup(page);
    await page.goto(`/c/${directory}`);
    await expect(page.locator('.directory-results a.card-press')).toHaveCount(125);
    const trigger = page.locator('.directory-region-trigger');
    const beforeTrigger = await trigger.boundingBox();
    const beforeResults = await page.locator('.directory-body').boundingBox();
    await page.locator('.directory-filters').evaluate(element => { element.scrollLeft = element.scrollWidth; });
    const afterScroll = await trigger.boundingBox();
    expect(afterScroll!.x).toBeCloseTo(beforeTrigger!.x, 1);
    await trigger.click();
    await expect(page.locator('.directory-region-panel')).toBeVisible();
    expect((await page.locator('.directory-body').boundingBox())!.y).toBeCloseTo(beforeResults!.y, 1);
    await page.locator('.directory-filters').evaluate(element => { element.scrollLeft = 0; });
    await page.locator('.directory-filters').getByRole('button', { name: '汉传佛教', exact: true }).click();
    await expect(page.locator('.directory-region-panel')).toHaveCount(0);
    await expect(page.locator('.directory-traditions')).toBeVisible();
    await trigger.click();
    await expect(page.locator('.directory-traditions')).toHaveCount(0);
    await expect(page.locator('.directory-region-panel')).toBeVisible();
    expect((await page.locator('.directory-body').boundingBox())!.y).toBeCloseTo(beforeResults!.y, 1);
    await page.keyboard.press('Escape');
    await expect(page.locator('.directory-region-panel')).toHaveCount(0);
    await expect(trigger).toBeFocused();
    await trigger.press('ArrowDown');
    await expect(page.locator('.directory-region-panel').getByRole('button', { name: '全部地区', exact: true })).toBeFocused();
    // Clicking through the transparent dismiss area must close, not open the covered result.
    await page.mouse.click(page.viewportSize()!.width - 25, page.viewportSize()!.height - 100);
    await expect(page.locator('.directory-region-panel')).toHaveCount(0);
    expect(new URL(page.url()).pathname).toBe(`/c/${directory}`);
    const geometry = await page.evaluate(() => ({ width: document.documentElement.clientWidth, scroll: document.documentElement.scrollWidth }));
    expect(geometry.scroll).toBeLessThanOrEqual(geometry.width + 1);
    if (directory === 'temples') {
      const sizes = await page.locator('.directory-sidebar').evaluate(element => [
        parseFloat(getComputedStyle(element.querySelector('.directory-group-heading')!).fontSize),
        parseFloat(getComputedStyle(element.querySelector('button')!).fontSize),
      ]);
      expect(sizes[0]).toBeGreaterThanOrEqual(sizes[1]);
    }
  });
}

for (const appearance of [{ language: 'zh-Hans', theme: 'light' }, { language: 'zh-Hant', theme: 'dark' }]) {
  test(`masters: standard services filter enabled offerings while retired identities cannot narrow results ${appearance.language}`, async ({ page }) => {
    const { calls } = await setup(page, false, appearance);
    await page.goto('/c/masters?specialty=不存在&serviceCode=unavailable&position=不存在的称谓&priceRange=0-200');
    const cards = page.locator('.directory-results a.card-press');
    await expect(cards).toHaveCount(125);
    await expect.poll(() => new URL(page.url()).searchParams.has('specialty')).toBe(false);
    await expect.poll(() => new URL(page.url()).searchParams.has('serviceCode')).toBe(false);
    expect(new URL(page.url()).searchParams.has('position')).toBe(false);
    expect(new URL(page.url()).searchParams.get('priceRange')).toBe('0-200');
    expect(calls.filter(url => url.pathname.endsWith('/masters')).every(url => !url.searchParams.has('specialty') && !url.searchParams.has('serviceCode'))).toBe(true);
    await expect(page.getByText(/独立师傅 · 含演示资料|獨立師傅 · 含演示資料/)).toHaveCount(0);
    const headings = page.locator('.master-directory-filter-toggle');
    await expect(headings).toHaveCount(2);
    await expect(headings).toHaveText(appearance.language === 'zh-Hant' ? ['提供服務', '價格區間'] : ['提供服务', '价格区间']);
    for (const heading of await headings.all()) {
      await expect(heading).toHaveAttribute('aria-expanded', 'true');
      const layout = await heading.evaluate(element => {
        const label = element.querySelector('span')!;
        const range = document.createRange();
        range.selectNodeContents(label);
        const lines = new Set(Array.from(range.getClientRects()).map(rect => Math.round(rect.top)));
        const box = element.getBoundingClientRect(), text = label.getBoundingClientRect();
        return { lines: lines.size, fits: text.left >= box.left && text.right <= box.right, width: element.scrollWidth, client: element.clientWidth };
      });
      expect(layout.lines).toBe(1);
      expect(layout.fits).toBeTruthy();
      expect(layout.width).toBeLessThanOrEqual(layout.client + 1);
      await heading.click();
      await expect(heading).toHaveAttribute('aria-expanded', 'false');
      await heading.click();
    }
    const serviceGroup = page.getByRole('group', { name: appearance.language === 'zh-Hant' ? '提供服務' : '提供服务', exact: true });
    await serviceGroup.getByRole('button', { name: appearance.language === 'zh-Hant' ? '開光' : '开光', exact: true }).click();
    await expect(cards).toHaveCount(1);
    await expect(cards).toContainText('慧觉法师');
    // The selected service is deliberately the third enabled offering in the fixture.
    await expect(cards).toContainText(appearance.language === 'zh-Hant' ? '開光' : '开光');
    expect(new URL(page.url()).searchParams.get('serviceCode')).toBe('S006');
    expect(new URL(page.url()).searchParams.get('priceRange')).toBe('0-200');
    await page.reload();
    await expect(cards).toHaveCount(1);
    await expect(serviceGroup.getByRole('button', { name: appearance.language === 'zh-Hant' ? '開光' : '开光', exact: true })).toHaveAttribute('aria-pressed', 'true');
    await serviceGroup.getByRole('button', { name: appearance.language === 'zh-Hant' ? '供燈' : '供灯', exact: true }).click();
    await expect(cards).toHaveCount(124);
    await expect(cards.getByText('普通师傅1', { exact: true })).toBeVisible();
    await serviceGroup.getByRole('button', { name: '全部', exact: true }).click();
    await expect(cards).toHaveCount(125);
    expect(new URL(page.url()).searchParams.has('serviceCode')).toBe(false);
    await page.getByRole('button', { name: '搜索', exact: true }).click();
    await page.getByRole('searchbox').fill('  禪修 開光  ');
    await expect(cards).toHaveCount(1);
    // Names are user data and stay verbatim; cataloged service labels follow the UI language.
    await expect(cards).toContainText('慧觉法师');
    await expect(cards).toContainText('祈福');
    await expect(cards).toContainText('168');
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBeTruthy();
  });
}

test('a failed later directory page is an error and retry retrieves the complete list', async ({ page }) => {
  const fixture = await setup(page, true);
  await page.goto('/c/temples');
  await expect(page.getByText('寺院列表加载失败', { exact: true })).toBeVisible();
  await expect(page.getByText('分页暂时不可用', { exact: true })).toBeVisible();
  await expect(page.getByText('当前筛选无结果', { exact: true })).toHaveCount(0);
  await expect(page.locator('.directory-results a.card-press')).toHaveCount(0);
  // Keep every initial load failing, including React StrictMode's discarded load.
  // Recovery is a server-state change, not whichever request happens to arrive first.
  fixture.recover();
  await page.getByRole('button', { name: '重试', exact: true }).click();
  await expect(page.locator('.directory-results a.card-press')).toHaveCount(125);
  await expect(page.getByText('寺院列表加载失败', { exact: true })).toHaveCount(0);
  expect(fixture.calls.some(url => url.pathname.endsWith('/temples') && url.searchParams.get('page') === '7')).toBe(true);
});
