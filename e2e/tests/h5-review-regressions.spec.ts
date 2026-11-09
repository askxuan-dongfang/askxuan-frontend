import { expect, test, type Page } from '@playwright/test';

function token(role: 'customer' | 'master') {
  const encode = (value: unknown) => Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${encode({ alg: 'none' })}.${encode({ userId: 7, masterId: role === 'master' ? 1 : undefined, roles: [role], clientId: role, exp: Math.floor(Date.now() / 1000) + 3600 })}.fixture`;
}
async function setup(page: Page, role?: 'customer' | 'master') {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.addInitScript(({ role, accessToken }) => {
    localStorage.setItem('askxuan-language', 'zh-Hans'); localStorage.setItem('askxuan-theme', 'light');
    if (role && !localStorage.getItem('h5-auth')) {
      localStorage.setItem('h5_token', accessToken);
      localStorage.setItem('h5-auth', JSON.stringify({ state: { token: accessToken, role, userId: 7, masterId: role === 'master' ? 1 : undefined, displayName: '本地测试' }, version: 0 }));
    }
  }, { role, accessToken: role ? token(role) : '' });
  await page.route('**/api/v1/**', async route => {
    const path = new URL(route.request().url()).pathname.replace('/api/v1', '');
    const data = path === '/chats/incoming-call' ? { call: null } : path === '/bookings/eligibility' ? { eligible: false } : { list: [], total: 0, count: 0 };
    await route.fulfill({ json: { code: 0, data } });
  });
}
const material = { id: 1, name: '回归测试木珠', spec: '10mm', unitPrice: 10, unit: '颗', category: 'main_bead', materialType: 'wood', shape: 'round', diameterMm: 10, colorHex: '#76583d', image: '', stock: 100, status: 'on_shelf' };
const bead = { slotId: 'guest-1', materialId: 1, name: material.name, spec: '10mm', diameterMm: 10, shape: 'round', subtype: 'main_bead', color: '#76583d', unitPrice: 10, image: '', materialType: 'wood', textureKey: '', finish: 'polished', translucency: 0, fiveElement: 'wood' };

test('service tags wait for a successful read and still allow an intentional empty save', async ({ page }) => {
  await setup(page, 'master');
  let release!: () => void; const gate = new Promise<void>(resolve => { release = resolve; });
  let failed = true; const writes: unknown[] = [];
  await page.route('**/api/v1/admin/masters/service-tags', async route => {
    if (route.request().method() === 'PUT') { writes.push(route.request().postDataJSON()); await route.fulfill({ json: { code: 0, data: { list: [] } } }); return; }
    await gate;
    if (failed) await route.fulfill({ status: 503, json: { code: 50001, message: '目录读取失败' } });
    else await route.fulfill({ json: { code: 0, data: { list: [{ serviceCode: 'S001', price: 9.9 }] } } });
  });
  await page.goto('/m/service-tags'); const save = page.getByRole('button', { name: '保存服务标签', exact: true });
  await expect(save).toBeDisabled(); release();
  await expect(page.getByRole('alert')).toContainText('目录读取失败'); await expect(save).toBeDisabled(); expect(writes).toEqual([]);
  failed = false; await page.getByRole('button', { name: '重新加载', exact: true }).click();
  await expect(page.getByRole('spinbutton', { name: '祈福价格', exact: true })).toHaveValue('9.9');
  await page.getByRole('button', { name: '祈福', exact: true }).click(); await save.click();
  await expect(page.getByText('服务标签已保存', { exact: true })).toBeVisible(); expect(writes).toEqual([{ tags: [] }]);
});

test('failed blessing pagination retries page two and tasks work from the keyboard', async ({ page }) => {
  await setup(page, 'master'); let failSecond = true; const pages: number[] = [];
  const task = (id: number) => ({ id, taskNo: `TASK-${id}`, diyOrderNo: `DIY-${id}`, status: 'assigned', certificateUrls: [], assignTime: '2026-11-09' });
  await page.route('**/api/v1/admin/masters/blessing-tasks?*', async route => {
    const url = new URL(route.request().url()), pageNo = Number(url.searchParams.get('page'));
    if (url.searchParams.get('size') === '1') { await route.fulfill({ json: { code: 0, data: { total: 21, list: [] } } }); return; }
    pages.push(pageNo);
    if (pageNo === 2 && failSecond) { failSecond = false; await route.fulfill({ status: 503, json: { code: 50001, message: '第二页读取失败' } }); return; }
    await route.fulfill({ json: { code: 0, data: { total: 21, list: pageNo === 1 ? Array.from({ length: 20 }, (_, i) => task(i + 1)) : [task(21)] } } });
  });
  await page.goto('/m/blessings'); await expect(page.getByRole('link').filter({ hasText: 'TASK-' })).toHaveCount(20);
  await page.locator('.page > div[style="height: 1px;"]').scrollIntoViewIfNeeded();
  await expect(page.getByRole('alert')).toContainText('第二页读取失败');
  await page.getByRole('button', { name: '重新加载', exact: true }).click();
  const last = page.getByRole('link').filter({ hasText: 'TASK-21' }); await expect(last).toBeVisible(); expect(pages.filter(n => n > 1)).toEqual([2, 2]);
  await last.focus(); await expect(last).toBeFocused(); await last.press('Enter'); await expect(page).toHaveURL(/\/m\/blessings\/21$/);
});

test('pricing edits a description and links to the actual service fee editor', async ({ page }) => {
  await setup(page, 'master'); const writes: unknown[] = [];
  await page.route('**/api/v1/admin/masters/profile', async route => {
    if (route.request().method() === 'PUT') writes.push(route.request().postDataJSON());
    await route.fulfill({ json: { code: 0, data: { pricing: '', dharmaName: '本地师傅' } } });
  });
  await page.goto('/m/pricing');
  const tier = page.getByRole('button', { name: '¥399 参考档位', exact: true }); await tier.focus(); await tier.press('Enter');
  await expect(tier).toHaveAttribute('aria-pressed', 'true'); await page.getByRole('button', { name: '保存说明', exact: true }).click();
  await expect(page.getByText('定价说明已保存', { exact: true })).toBeVisible();
  expect(writes).toHaveLength(1); expect(Object.keys(writes[0] as object)).toEqual(['pricing']);
  await page.getByRole('link', { name: '设置服务价格', exact: true }).click(); await expect(page).toHaveURL(/\/m\/service-tags$/);
});

test('guest login resumes the design across refresh without overwriting the account draft', async ({ page }) => {
  await setup(page);
  const accountDraft = JSON.stringify({ version: 1, beads: [bead, { ...bead, slotId: 'account-2' }], name: '账号原有草稿', wristSize: 180, allowance: 8 });
  await page.addInitScript(({ bead, accountDraft }) => {
    if (!localStorage.getItem('draft-fixture-seeded')) {
      localStorage.setItem('diy-studio-draft-v1:guest:new', JSON.stringify({ version: 1, beads: [bead], name: '登录前的设计', wristSize: 160, allowance: 8 }));
      localStorage.setItem('diy-studio-draft-v1:7:new', accountDraft); localStorage.setItem('draft-fixture-seeded', '1');
    }
  }, { bead, accountDraft });
  await page.route('**/api/v1/diy/materials', route => route.fulfill({ json: { code: 0, data: { list: [material] } } }));
  await page.route('**/api/v1/auth/options', route => route.fulfill({ json: { code: 0, data: { emailEnabled: true, agreementVersion: 'fixture' } } }));
  await page.route('**/api/v1/auth/captcha', route => route.fulfill({ json: { code: 0, data: { id: 'local-captcha', image: 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg"/>', expiresIn: 60 } } }));
  await page.route('**/api/v1/auth/login', route => route.fulfill({ json: { code: 0, data: { accessToken: token('customer'), refreshToken: 'fixture', userInfo: { userId: 7, nickname: '本地测试' } } } }));
  await page.goto('/c/diy/editor'); await expect(page.locator('.studio-stage-top small')).toHaveText('1 / 60 颗');
  await page.getByRole('button', { name: '保存设计', exact: true }).click(); await expect(page).toHaveURL(/\/c\/login\?redirect=/);
  expect(new URL(page.url()).searchParams.get('redirect')).toBe('/c/diy/editor?resume=guest');
  await page.getByLabel('邮箱／用户名', { exact: true }).fill('fixture'); await page.getByLabel('密码', { exact: true }).fill('fixture');
  await page.getByRole('textbox', { name: '图片验证码', exact: true }).fill('12345'); await page.getByRole('button', { name: '登录', exact: true }).click();
  await expect(page).toHaveURL(/\/c\/diy\/editor\?resume=guest$/); await expect(page.locator('.studio-stage-top small')).toHaveText('1 / 60 颗');
  await page.reload(); await expect(page.locator('.studio-stage-top small')).toHaveText('1 / 60 颗');
  await page.getByRole('button', { name: '保存设计', exact: true }).click(); await expect(page.getByRole('textbox', { name: '设计名称', exact: true })).toHaveValue('登录前的设计');
  expect(await page.evaluate(() => localStorage.getItem('diy-studio-draft-v1:7:new'))).toBe(accountDraft);
  await page.getByRole('button', { name: '继续编辑', exact: true }).click(); await page.goto('/c/diy/editor');
  await expect(page.locator('.studio-stage-top small')).toHaveText('2 / 60 颗');
});

test('unknown service prices are nonnumeric until the real catalogue arrives', async ({ page }) => {
  await setup(page); let release!: () => void; const gate = new Promise<void>(resolve => { release = resolve; });
  await page.route('**/api/v1/service-types', async route => { await gate; await route.fulfill({ json: { code: 0, data: { list: [{ code: 'S008', name: '求姻缘', priceRange: '¥100-500' }] } } }); });
  await page.goto('/c/services'); const card = page.getByRole('link').filter({ hasText: '求姻缘' });
  await expect(card).toContainText('查看报价'); await expect(card).not.toContainText('¥0'); release(); await expect(card).toContainText('¥100-500');
});

test('a public design guest draft is checked against its source revision before copying', async ({ page }) => {
  await setup(page, 'customer');
  const accountDraft = JSON.stringify({ version: 1, beads: [bead], name: '账号草稿保留', revision: 4 });
  await page.addInitScript(({ bead, accountDraft }) => {
    localStorage.setItem('diy-studio-draft-v1:guest:30', JSON.stringify({ version: 1, beads: [bead, { ...bead, slotId: 'edited-2' }], name: '游客修改后的作品', revision: 4 }));
    localStorage.setItem('diy-studio-draft-v1:7:30', accountDraft);
  }, { bead, accountDraft });
  const source = { id: 30, userId: '99', name: '公开源作品', revision: 4, status: 'public', designData: JSON.stringify({ version: 2, beads: [{ ...bead, position: 0, materialName: material.name }] }) };
  await page.route('**/api/v1/diy/materials', route => route.fulfill({ json: { code: 0, data: { list: [material] } } }));
  await page.route('**/api/v1/diy/designs/30', route => route.fulfill({ json: { code: 0, data: source } }));
  await page.route('**/api/v1/diy/designs/30/copy', route => route.fulfill({ json: { code: 0, data: { ...source, id: 31, userId: '7', revision: 1, status: 'private' } } }));
  await page.goto('/c/diy/editor?design=30&resume=guest');
  await expect(page.locator('.studio-stage-top small')).toHaveText('2 / 60 颗');
  await page.getByRole('button', { name: '保存设计', exact: true }).click();
  await expect(page.getByRole('textbox', { name: '设计名称', exact: true })).toHaveValue('游客修改后的作品');
  expect(await page.evaluate(() => localStorage.getItem('diy-studio-draft-v1:7:30'))).toBe(accountDraft);
});

test('initial home loading is not shown as empty business data', async ({ page }) => {
  await setup(page); let release!: () => void; const gate = new Promise<void>(resolve => { release = resolve; });
  await page.route(/\/api\/v1\/(intentions\/tags|temples|masters)(\?|$)/, async route => { await gate; await route.fulfill({ json: { code: 0, data: { list: [] } } }); });
  await page.goto('/c'); await expect(page.getByRole('status', { name: '加载心愿…' })).toBeVisible();
  await expect(page.getByText('暂无心愿入口', { exact: true })).toHaveCount(0); release(); await expect(page.getByText('暂无心愿入口', { exact: true })).toBeVisible();
});

test('decimal fees are preserved in wishes, master cards and consultation summaries', async ({ page }) => {
  await setup(page, 'customer');
  await page.route('**/api/v1/intentions?*', route => route.fulfill({ json: { code: 0, data: { list: [{ resourceType: 'master', sourceId: 'M7', title: '小数服务', subtitle: '', price: 9.9 }], tags: [], total: 1, page: 1, size: 30 } } }));
  await page.goto('/c/intentions/peace'); await expect(page.locator('.price')).toContainText('9.9');
  await page.route('**/api/v1/masters?*', route => route.fulfill({ json: { code: 0, data: { list: [{ id: 'M7', dharmaName: '小数咨询师', rating: 5, consultEnabled: true, consultFee: 9.9, manageBy: 'platform', serviceTags: [] }], total: 1 } } }));
  await page.goto('/c/masters'); await expect(page.getByText('咨询 ¥9.9', { exact: true })).toBeVisible();
  await page.route('**/api/v1/consultations/quote?*', route => route.fulfill({ json: { code: 0, data: { enabled: true, masterId: 'M7', masterName: '小数咨询师', consultFee: 9.9, validHours: 24, responseMinutes: 30 } } }));
  await page.goto('/c/masters/M7/consult'); await expect(page.locator('.stat strong').first()).toHaveText('¥9.9');
});

test('a wallet consultation does not claim simulated payment after checkout', async ({ page }) => {
  await setup(page, 'customer');
  const order = { id: 'C7', masterId: 'M7', masterName: '本地咨询师', consultFee: 9.9, paymentStatus: 'pending', status: 'pending_payment', expiresAt: '2026-11-10', simulated: false };
  await page.route('**/api/v1/consultations/quote?*', route => route.fulfill({ json: { code: 0, data: { enabled: true, masterId: 'M7', masterName: '本地咨询师', consultFee: 9.9, validHours: 24, responseMinutes: 30 } } }));
  await page.route('**/api/v1/consultations', route => route.fulfill({ json: { code: 0, data: order } }));
  await page.route('**/api/v1/consultations/C7', route => route.fulfill({ json: { code: 0, data: { ...order, paymentStatus: 'success', status: 'active', conversationId: 'CHAT7' } } }));
  await page.route('**/api/v1/payments/checkout/quote', route => route.fulfill({ json: { code: 0, data: { mode: 'cash', balanceChannel: 'balance', amountCents: 990, availableCents: 10000, balanceEnabled: true, mockEnabled: false, experience: false } } }));
  await page.route('**/api/v1/payments/checkout', route => route.fulfill({ json: { code: 0, data: { id: 1, paymentNo: 'P7', status: 'success', channel: 'balance' } } }));
  await page.goto('/c/masters/M7/consult'); await page.getByRole('button', { name: '确认并开始咨询', exact: true }).click();
  await expect(page.getByRole('heading', { name: '确认支付', exact: true })).toBeVisible(); await page.getByRole('button', { name: '支付 ¥9.90', exact: true }).click();
  await expect(page.getByRole('heading', { name: '咨询已开通', exact: true })).toBeVisible(); await expect(page.getByText('钱包余额', { exact: true })).toBeVisible();
  await expect(page.getByText('模拟支付（测试）', { exact: true })).toHaveCount(0);
});
