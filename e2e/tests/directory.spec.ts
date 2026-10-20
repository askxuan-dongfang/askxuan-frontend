import { test, expect, type Page } from '@playwright/test';

const beliefs = [
  { code: 'han_buddhism', name: '汉传佛教' }, { code: 'tibetan_buddhism', name: '藏传佛教' },
  { code: 'theravada_buddhism', name: '南传佛教' }, { code: 'daoism', name: '道教' }, { code: 'folk', name: '民间信仰' },
];
const tags = [{ code: 'chan', group: 'tradition', name: '禅宗', value: '禅宗', beliefCode: 'han_buddhism', status: 'enabled' }];
const regions = [{ code: 'zj', name: '浙江省' }, { code: 'bj', name: '北京市' }];
const services = [{ code: 'S006', name: '开光' }, { code: 'S002', name: '供灯' }];

async function setup(page: Page, failSecondPage = false) {
  const calls: URL[] = [];
  let shouldFail = failSecondPage;
  await page.addInitScript(() => {
    localStorage.setItem('askxuan-language', 'zh-Hans');
    localStorage.setItem('askxuan-theme', 'light');
  });
  await page.route('**/api/v1/**', async route => {
    const url = new URL(route.request().url()), path = url.pathname.replace('/api/v1', '');
    calls.push(url);
    let data: unknown = { list: [], total: 0 };
    if (path === '/beliefs') data = { list: beliefs };
    if (path === '/beliefs/directory-tags') data = { list: tags };
    if (path === '/regions') data = { list: regions };
    if (path === '/service-types') data = { list: services };
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
          : { ...common, dharmaName: target ? '慧觉法师' : `普通师傅${index + 1}`, layName: target ? '张三' : '', templeName: '', position: '独立师傅', specialties: [], avatar: '', serviceTags: [{ serviceCode: target ? 'S006' : 'S002', price: 168, status: 'enabled' }] };
      }).filter(row => !url.searchParams.get('regionCode') || row.regionCode === url.searchParams.get('regionCode'));
      // Deliberately cap the server page at 20 despite the client's size=100 request.
      data = { list: rows.slice((pageNumber - 1) * 20, pageNumber * 20), total: rows.length, page: pageNumber, size: 20 };
    }
    await route.fulfill({ json: { code: 0, data } });
  });
  return { calls, recover: () => { shouldFail = false; } };
}

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
