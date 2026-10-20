import { test, expect, type Page } from '@playwright/test';

interface FixtureOptions { failProductsInitially?: boolean; waitForTemples?: Promise<void> }
async function setup(page: Page, options: FixtureOptions = {}) {
  const calls: URL[] = [];
  let productsUnavailable = !!options.failProductsInitially;
  await page.addInitScript(() => {
    localStorage.setItem('askxuan-language', 'zh-Hans');
    localStorage.setItem('askxuan-theme', 'light');
  });
  await page.route('**/api/v1/**', async route => {
    const url = new URL(route.request().url()), path = url.pathname.replace('/api/v1', '');
    calls.push(url);
    let data: unknown = { total: 0, list: [] };
    if (path === '/beliefs') data = { list: [{ code: 'han_buddhism', name: '汉传佛教' }] };
    if (path === '/beliefs/directory-tags') data = { list: [{ code: 'chan', group: 'tradition', name: '禅宗', value: '禅宗', beliefCode: 'han_buddhism', status: 'enabled' }] };
    if (path === '/regions') data = { list: [{ code: 'zj', name: '浙江省' }, { code: 'qh', name: '青海省' }] };
    if (path === '/service-types') data = { list: [{ code: 'S006', name: '开光' }, { code: 'S002', name: '供灯' }] };
    if (path === '/intentions/tags') data = { list: [{ code: 'health', name: '求健康', description: '身心安康' }] };
    if (path === '/marketing/banners') data = { total: 1, list: [{ id: 1, title: '静心生活专题', placement: 'customer_home', imageUrl: '/banner.png', linkType: 'ad_landing', linkValue: '/c/diy', sort: 1, status: 'enabled', startTime: '', endTime: '' }] };
    if (path === '/temples') {
      if (options.waitForTemples) await options.waitForTemples;
      const pageNumber = Number(url.searchParams.get('page') || 1);
      const records = Array.from({ length: 125 }, (_, index) => ({
        id: String(index + 1), name: index === 124 ? '灵隐寺' : index === 123 ? '云海寺' : `普通寺院${index + 1}`,
        region: index === 124 ? '杭州' : '西宁', regionCode: index === 124 ? 'zj' : 'qh', address: '',
        beliefCode: 'han_buddhism', type: '汉传佛教', sect: '', traditionCodes: ['chan'],
        serviceCodes: [index === 124 ? 'S006' : 'S002'], serviceTags: [], rating: 4.8,
      }));
      // The server may cap size=100; the last match deliberately lives beyond page one.
      data = { total: records.length, list: records.slice((pageNumber - 1) * 20, pageNumber * 20), page: pageNumber, size: 20 };
    }
    if (path === '/masters') data = { total: 1, list: [{ id: 'M1', dharmaName: '慧觉法师', layName: '张三', templeName: '灵隐寺', position: '法师', regionCode: 'zj', type: '汉传佛教', beliefCode: 'han_buddhism', sect: '', traditionCodes: ['chan'], specialties: ['禅修'], serviceTags: [{ serviceCode: 'S006', status: 'enabled' }] }] };
    if (path === '/products') {
      if (productsUnavailable) {
        return route.fulfill({ status: 503, json: { code: 500, message: '商品暂时不可用' } });
      }
      data = { total: 2, list: [{ id: 1, name: '灵隐文创珠', description: '浙江开光手串', tags: ['手串'] }, { id: 2, name: '云海手串', description: '青海天然菩提', tags: ['菩提'] }] };
    }
    if (path === '/diy/designs') data = { total: 0, list: null, page: 1, size: 100 };
    if (path === '/community/feed') data = { total: 1, list: [{ id: 'POST1', title: '公开修行记录', content: '每日静心，认真生活。', status: 'approved' }] };
    await route.fulfill({ json: { code: 0, data } });
  });
  return { calls, recoverProducts: () => { productsUnavailable = false; } };
}

async function submit(page: Page, text: string) {
  await page.getByRole('searchbox').fill(text);
  await page.locator('.global-search-form').getByRole('button', { name: '搜索', exact: true }).click();
}

const group = (page: Page, name: string) => page.getByRole('region', { name, exact: true });

test('last public directory page is indexed and simplified/traditional whitespace terms are ANDed', async ({ page }) => {
  const { calls } = await setup(page);
  await page.goto('/c/search');
  await submit(page, '  靈隱   浙江　開光  ');
  const temples = group(page, '寺院');
  await expect(temples.getByRole('link')).toHaveCount(1);
  await expect(temples.getByRole('link')).toContainText('灵隐寺');
  await expect(temples.getByRole('link')).toHaveAttribute('href', '/c/temples/125');
  expect(calls.some(url => url.pathname.endsWith('/temples') && url.searchParams.get('page') === '7')).toBe(true);
  await submit(page, '靈隱 青海');
  await expect(temples.getByRole('link')).toHaveCount(0);
  await expect(temples.getByText('没有匹配结果', { exact: true })).toBeVisible();
});

test('late full catalog response respects the latest search words', async ({ page }) => {
  let release!: () => void;
  const pending = new Promise<void>(resolve => { release = resolve; });
  const { calls } = await setup(page, { waitForTemples: pending });
  await page.goto('/c/search?q=靈隱');
  await expect.poll(() => calls.some(url => url.pathname.endsWith('/temples'))).toBe(true);
  try {
    await submit(page, '雲海 青海');
    await expect(group(page, '商品').getByRole('link')).toContainText('云海手串');
  } finally { release(); }
  await expect(group(page, '寺院').getByRole('link')).toHaveCount(1);
  await expect(group(page, '寺院').getByRole('link')).toContainText('云海寺');
  await expect(group(page, '寺院')).not.toContainText('灵隐寺');
  expect(new URL(page.url()).searchParams.get('q')).toBe('雲海 青海');
});

test('one failed category can retry while other categories remain searchable', async ({ page }) => {
  const fixture = await setup(page, { failProductsInitially: true });
  await page.goto('/c/search?q=開光');
  await expect(group(page, '商品').getByRole('alert')).toContainText('这类内容暂时无法搜索');
  await expect(group(page, '寺院').getByRole('link')).toContainText('灵隐寺');
  await expect(group(page, '师傅').getByRole('link')).toContainText('慧觉法师');
  // Recovery must not depend on how many initial/aborted requests StrictMode sends.
  fixture.recoverProducts();
  await group(page, '商品').getByRole('button', { name: '重试', exact: true }).click();
  await expect(group(page, '商品').getByRole('link')).toContainText('灵隐文创珠');
  await expect(group(page, '商品').getByRole('alert')).toHaveCount(0);
  await expect(group(page, '寺院').getByRole('link')).toContainText('灵隐寺');
});

test('the real empty public design protocol is an empty result rather than an error', async ({ page }) => {
  await setup(page);
  await page.goto('/c/search?q=手串');
  await expect(group(page, '手串作品').getByText('没有匹配结果', { exact: true })).toBeVisible();
  await expect(group(page, '手串作品').getByRole('alert')).toHaveCount(0);
});

test('global content loading reads only public endpoints and never narrows the master directory', async ({ page }) => {
  const { calls } = await setup(page);
  await page.goto('/c/search?q=禪宗');
  await expect(group(page, '寺院').getByRole('button', { name: /显示更多/ })).toBeVisible();
  await expect(group(page, '师傅').getByRole('link')).toContainText('慧觉法师');
  const paths = calls.map(url => url.pathname);
  for (const endpoint of ['/temples', '/masters', '/products', '/diy/designs', '/community/feed', '/marketing/banners']) {
    expect(paths.some(path => path === `/api/v1${endpoint}`)).toBe(true);
  }
  expect(paths.filter(path => /\/(?:admin|my-designs|orders|bookings|addresses|favorites|wallet|points)(?:\/|$)/.test(path))).toEqual([]);
  expect(calls.filter(url => url.pathname.endsWith('/masters')).every(url => !url.searchParams.has('manageBy') && !url.searchParams.has('templeId'))).toBe(true);
});

test('feature matches link to their real public destination', async ({ page }) => {
  await setup(page);
  for (const [query, title, path] of [['寺庙', '找寺院', '/c/temples'], ['商城', '商城', '/c/shop'], ['DIY', 'DIY手串', '/c/diy']]) {
    await page.goto(`/c/search?q=${encodeURIComponent(query)}`);
    const link = group(page, '功能').getByRole('link', { name: title, exact: true });
    await expect(link).toHaveAttribute('href', path);
    await link.click();
    await expect(page).toHaveURL(new RegExp(`${path.replaceAll('/', '\\/')}$`));
  }
});
