import { expect, test, type Page } from '@playwright/test';

const design = {
  id: 31, userId: '42', name: '远山手串', authorName: '山间创作者', useCount: 12,
  status: 'public', revision: 4, totalPrice: 595, fiveElements: ['wood'], meanings: ['peace'],
  designData: JSON.stringify({ version: 2, beads: [{ position: 0, materialId: 1, materialName: '木珠', unitPrice: 10, diameterMm: 10, color: '#77593d' }] }),
  publication: { id: 9, designRevision: 4, materialFee: 595 },
  publicationEligibility: { canPublish: true, reason: 'ready', message: '订单已付款，款式、用料和价格已确认。', orderId: 7 },
};
async function setup(page: Page, options: { many?: boolean; eligible?: boolean; longName?: boolean } = {}) {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.addInitScript(() => {
    localStorage.setItem('askxuan-language', 'zh-Hans');
    localStorage.setItem('askxuan-theme', 'light');
    localStorage.setItem('h5_token', 'fixture');
    localStorage.setItem('h5-auth', JSON.stringify({ state: { token: 'fixture', role: 'customer', userId: 42 }, version: 0 }));
  });
  let current = { ...design, ...(options.longName ? { name: '很长的作品名称也应保持卡片整齐清晰', authorName: '很长的真实作者昵称不会遮住使用次数' } : {}) };
  const reads: URL[] = [], writes: { path: string; body: any }[] = [];
  await page.route('**/api/v1/**', async route => {
    const req = route.request(), url = new URL(req.url()), path = url.pathname;
    if (req.method() !== 'GET') writes.push({ path, body: req.postDataJSON() });
    let data: unknown = { list: [], total: 0, count: 0 };
    if (path.endsWith('/chats/incoming-call')) data = { call: null };
    else if (path.endsWith('/diy/designs/31/status')) {
      const body = req.postDataJSON();
      current = { ...current, ...body.tags, revision: current.revision + 1 };
      data = current;
    } else if (path.endsWith('/diy/designs/31')) data = {
      ...current, publicationEligibility: options.eligible === false
        ? { canPublish: false, reason: 'payment_required', message: '订单尚未付款。', orderId: 7 }
        : current.publicationEligibility,
    };
    else if (path.endsWith('/diy/my-designs')) data = { list: [current], total: 1 };
    else if (path.endsWith('/diy/designs')) {
      reads.push(url);
      const rows = options.many ? [...Array.from({ length: 20 }, (_, i) => ({ ...design, id: i + 1, name: `金珠作品 ${i + 1}`, authorName: '另一位作者', fiveElements: ['metal'], meanings: ['career'] })), current] : [current];
      const keyword = url.searchParams.get('keyword') || '', element = url.searchParams.get('fiveElement'), meaning = url.searchParams.get('meaning');
      const filtered = rows.filter(row => (!keyword || `${row.name} ${row.authorName}`.includes(keyword)) && (!element || row.fiveElements.includes(element)) && (!meaning || row.meanings.includes(meaning)));
      const pageNo = Number(url.searchParams.get('page') || 1), size = Number(url.searchParams.get('size') || 20);
      data = { list: filtered.slice((pageNo - 1) * size, pageNo * size), total: filtered.length, page: pageNo, size };
    }
    await route.fulfill({ json: { code: 0, data } });
  });
  return { reads, writes };
}

for (const width of [320, 390, 1280]) test(`plaza keeps the primary action and author metadata readable at ${width}`, async ({ page }) => {
  await page.setViewportSize({ width, height: 954 }); await setup(page, { longName: true });
  await page.goto('/c/diy?tab=plaza');
  const action = page.getByRole('link', { name: '开始设计', exact: true });
  await expect(action).toBeVisible();
  const buttonBox = await action.boundingBox(); expect(buttonBox!.height).toBeGreaterThanOrEqual(56);
  const caption = page.getByText('打开设计器，自由搭配手串', { exact: true });
  await expect(caption).toBeVisible(); expect((await caption.boundingBox())!.y).toBeGreaterThanOrEqual(buttonBox!.y + buttonBox!.height);
  const card = page.locator('.diy-gallery-card');
  await expect(card).toContainText('很长的作品名称也应保持卡片整齐清晰');
  await expect(card).toContainText('很长的真实作者昵称不会遮住使用次数');
  await expect(card).toContainText('12 次使用'); await expect(card).toContainText('健康平安');
  await expect(card).not.toContainText('595'); await expect(card).not.toContainText('颗');
  await expect(page.getByText(/把喜欢，串在一起|件已加载|灵感未完/)).toHaveCount(0);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  const credit = await card.locator('.diy-gallery-credit').evaluate(element => {
    const [author, uses] = Array.from(element.children, child => child.getBoundingClientRect());
    return { noOverlap: author.right <= uses.left + 1, fits: uses.right <= element.getBoundingClientRect().right + 1 };
  });
  expect(credit).toEqual({ noOverlap: true, fits: true });
});

test('plaza filters and author search reach works beyond the loaded page', async ({ page }) => {
  const { reads } = await setup(page, { many: true }); await page.goto('/c/diy?tab=plaza');
  await expect(page.locator('.diy-gallery-card')).toHaveCount(20);
  await page.getByRole('button', { name: /浏览更多作品/ }).click();
  await expect(page.locator('.diy-gallery-card')).toHaveCount(21);
  await page.getByRole('group', { name: '五行', exact: true }).getByRole('button', { name: '木', exact: true }).click();
  await expect(page.locator('.diy-gallery-card')).toHaveCount(1);
  await page.getByRole('group', { name: '寓意', exact: true }).getByRole('button', { name: '健康平安', exact: true }).click();
  await expect.poll(() => reads.at(-1)?.searchParams.get('meaning')).toBe('peace');
  expect(reads.at(-1)?.searchParams.get('fiveElement')).toBe('wood');
  expect(reads.at(-1)?.searchParams.get('page')).toBe('1');
  await page.getByRole('searchbox', { name: '搜索作品名称、作者' }).fill('山间创作者');
  await expect.poll(() => reads.at(-1)?.searchParams.get('keyword')).toBe('山间创作者');
  await expect(page.locator('.diy-gallery-card')).toContainText('远山手串');
  await page.getByRole('group', { name: '寓意', exact: true }).getByRole('button', { name: '事业顺遂', exact: true }).click();
  await expect(page.getByText('暂无匹配作品', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: '清除筛选', exact: true }).click();
  await expect(page.locator('.diy-gallery-card')).toHaveCount(20);
  expect(reads.at(-1)?.searchParams.get('page')).toBe('1');
  expect(reads.at(-1)?.searchParams.get('keyword')).toBeNull();
  expect(reads.at(-1)?.searchParams.get('fiveElement')).toBeNull();
  expect(reads.at(-1)?.searchParams.get('meaning')).toBeNull();
});

test('an unchanged published work can update and clear tags without saving a new design or placing an order', async ({ page }) => {
  const { writes } = await setup(page); await page.goto('/c/diy?tab=mine');
  await page.getByRole('button', { name: '编辑标签', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: '编辑发布标签' }); await expect(dialog).toBeVisible();
  await expect(dialog.getByRole('button', { name: '木', exact: true })).toHaveAttribute('aria-pressed', 'true');
  await dialog.getByRole('button', { name: '金', exact: true }).click();
  await dialog.getByRole('button', { name: '助力学业', exact: true }).click();
  await dialog.getByRole('button', { name: '确认更新', exact: true }).click(); await expect(dialog).toBeHidden();
  expect(writes).toEqual([{ path: '/api/v1/diy/designs/31/status', body: { revision: 4, status: 'public', tags: { fiveElements: ['wood', 'metal'], meanings: ['peace', 'study'] } } }]);
  await page.getByRole('button', { name: '编辑标签', exact: true }).click();
  for (const name of ['木', '金', '健康平安', '助力学业']) await dialog.getByRole('button', { name, exact: true }).click();
  await dialog.getByRole('button', { name: '确认更新', exact: true }).click(); await expect(dialog).toBeHidden();
  expect(writes).toHaveLength(2);
  expect(writes[1]).toEqual({ path: '/api/v1/diy/designs/31/status', body: { revision: 5, status: 'public', tags: { fiveElements: [], meanings: [] } } });
  await expect(page.locator('.diy-gallery-card .diy-design-tags')).toHaveCount(0);
});

test('editing publication tags still requires the existing payment eligibility', async ({ page }) => {
  const { writes } = await setup(page, { eligible: false }); await page.goto('/c/diy?tab=mine');
  await page.getByRole('button', { name: '编辑标签', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: '编辑发布标签' });
  await expect(dialog).toContainText('订单尚未付款。');
  await expect(dialog.getByRole('button', { name: '确认更新', exact: true })).toHaveCount(0);
  expect(writes).toEqual([]);
});

test('bracelet orders open directly on the order controls', async ({ page }) => {
  await setup(page); await page.goto('/c/diy/orders');
  await expect(page.getByRole('heading', { name: '订单中心', exact: true })).toBeVisible();
  await expect(page.getByText('心意成串，静候相逢', { exact: true })).toHaveCount(0);
  await expect(page.getByRole('button', { name: '全部', exact: true })).toBeVisible();
});
