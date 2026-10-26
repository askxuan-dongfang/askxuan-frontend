import { test, expect, type Page } from '@playwright/test';

const materials = [
  { id: 1, name: '测试木珠', category: 'wood', shape: 'round', diameterMm: 10, colorHex: '#76583d' },
  { id: 2, name: '普通流苏', category: 'tassel', shape: 'tassel', diameterMm: 12, colorHex: '#a63531' },
  { id: 3, name: '中国结流苏', category: 'tassel', shape: 'tassel', diameterMm: 14, colorHex: '#a63531' },
].map(material => ({ ...material, spec: `${material.diameterMm}mm`, unitPrice: 10, unit: '颗', stock: 100, status: 'on_shelf', image: '' }));

async function setup(page: Page) {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.addInitScript(() => {
    localStorage.setItem('askxuan-language', 'zh-Hans');
    localStorage.setItem('askxuan-theme', 'light');
  });
  const writes: string[] = [], meshes: string[] = [], errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('request', request => {
    if (/\/geometry-[^/]+\.json$/.test(request.url())) meshes.push(new URL(request.url()).pathname);
  });
  // Every API response is local, including unanticipated requests from the shell.
  await page.route(/^https?:\/\/[^/]+\/api\//, async route => {
    const request = route.request(), path = new URL(request.url()).pathname;
    if (request.method() !== 'GET') writes.push(`${request.method()} ${path}`);
    const data = path.endsWith('/diy/materials') ? { list: materials, total: materials.length }
      : path.endsWith('/chats/incoming-call') ? { call: null }
      : path.endsWith('/chats/unread') ? { count: 0 } : { list: [], total: 0 };
    await route.fulfill({ json: { code: 0, data } });
  });
  return { writes, meshes, errors };
}

async function toolbarGeometry(page: Page) {
  return page.locator('.studio-viewport').evaluate(viewport => {
    const bounds = viewport.getBoundingClientRect();
    const rail = viewport.querySelector('.diy-3d-toolbar')!;
    const railBounds = rail.getBoundingClientRect(), railStyle = getComputedStyle(rail);
    const buttons = Array.from(viewport.querySelectorAll<HTMLButtonElement>('.diy-3d-toolbar button, .studio-expand-preview, .studio-history button')).map(button => {
      const box = button.getBoundingClientRect(), style = getComputedStyle(button);
      return { name: button.getAttribute('aria-label') || button.textContent?.trim(), left: box.left, top: box.top, right: box.right, bottom: box.bottom, width: box.width, height: box.height,
        fontFamily: style.fontFamily, fontSize: style.fontSize, paddingLeft: style.paddingLeft, paddingRight: style.paddingRight, minWidth: style.minWidth, boxSizing: style.boxSizing };
    });
    const overlaps = buttons.flatMap((a, i) => buttons.slice(i + 1).filter(b => Math.min(a.right, b.right) - Math.max(a.left, b.left) > .5 && Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top) > .5).map(b => [a.name, b.name]));
    return { buttons, overlaps, inside: buttons.every(button => button.left >= bounds.left - .5 && button.right <= bounds.right + .5 && button.top >= bounds.top - .5 && button.bottom <= bounds.bottom + .5), overflow: document.documentElement.scrollWidth > innerWidth,
      viewport: { width: bounds.width, height: bounds.height, left: bounds.left, right: bounds.right },
      window: { innerWidth, rootWidth: document.documentElement.getBoundingClientRect().width, bodyWidth: document.body.getBoundingClientRect().width, rootClientWidth: document.documentElement.clientWidth, scrollbarGutter: getComputedStyle(document.documentElement).scrollbarGutter, fonts: document.fonts.status },
      rail: { width: railBounds.width, left: railStyle.left, right: railStyle.right, gap: railStyle.gap },
      styleOrder: Array.from(document.querySelectorAll('style[data-vite-dev-id]')).map(style => style.getAttribute('data-vite-dev-id')).filter(path => path?.includes('/features/diy/')) };
  });
}

test('DIY hanging materials preserve editing and toolbar access across phone widths', async ({ page }, testInfo) => {
  // One real WebGL session exercises the full journey and responsive resizing.
  test.setTimeout(120_000);
  await page.setViewportSize({ width: 320, height: 568 });
  const fixture = await setup(page);
  await page.goto('/c/diy/editor');
  const preview = page.locator('.studio-viewport > .diy-3d-inline');
  const viewport = page.locator('.studio-viewport');
  const count = page.locator('.studio-stage-top small');
  const undo = viewport.locator('.studio-history').getByRole('button', { name: '撤销', exact: true });
  await expect(preview).toHaveAttribute('data-ready', 'true', { timeout: 30_000 });
  await expect(preview).toHaveAttribute('data-presentation', 'flat');
  await expect(page.locator('.diy-3d-fallback')).toHaveCount(0);

  await page.getByRole('button', { name: '添加测试木珠', exact: true }).click();
  await expect(preview).toHaveAttribute('data-presentation', 'flat');
  await page.getByRole('button', { name: '添加普通流苏', exact: true }).click();
  await expect(preview).toHaveAttribute('data-presentation', 'hanging');
  await expect(count).toHaveText('2 / 60 颗');

  // Removing the last hanging piece returns to flat; undo restores its default.
  await viewport.focus();
  await viewport.press('Delete');
  await expect(count).toHaveText('1 / 60 颗');
  await expect(preview).toHaveAttribute('data-presentation', 'flat');
  await undo.click();
  await expect(count).toHaveText('2 / 60 颗');
  await expect(preview).toHaveAttribute('data-presentation', 'hanging');

  await page.getByRole('button', { name: '添加中国结流苏', exact: true }).click();
  await expect(count).toHaveText('3 / 60 颗');
  await expect(page.locator('.studio-accessible-selection')).toContainText('中国结流苏');
  await expect.poll(() => fixture.meshes.some(path => path.endsWith('/geometry-tassel.json')) && fixture.meshes.some(path => path.endsWith('/geometry-tassel_knot.json'))).toBe(true);
  await viewport.focus();
  await viewport.press('Delete');
  await expect(count).toHaveText('2 / 60 颗');
  await expect(preview).toHaveAttribute('data-presentation', 'hanging');
  await undo.click();
  await expect(count).toHaveText('3 / 60 颗');

  await page.getByRole('button', { name: '切换为平放展示', exact: true }).click();
  await expect(preview).toHaveAttribute('data-presentation', 'flat');
  await page.getByRole('button', { name: '切换为悬挂展示', exact: true }).click();
  await expect(preview).toHaveAttribute('data-presentation', 'hanging');
  // Preview is lazy-loaded. Its real stylesheet must not undo the editor's
  // narrow toolbar when it arrives after the editor stylesheet.
  await page.evaluate(() => {
    const previewStyle = Array.from(document.querySelectorAll<HTMLStyleElement>('style[data-vite-dev-id]')).find(style => style.dataset.viteDevId?.endsWith('/src/features/diy/preview.css'));
    if (!previewStyle) throw new Error('Expected Vite preview stylesheet for lazy-load order regression');
    document.head.append(previewStyle);
  });
  for (const scrollbars of ['platform', 'classic-15px'] as const) {
    // Linux reserves a classic gutter for scrollbar-gutter:stable. Overlay-only
    // hosts reserve the same missing width explicitly; native gutters are not doubled.
    const missingGutter = scrollbars === 'classic-15px' ? await page.evaluate(() => Math.max(0, 15 - (innerWidth - document.body.getBoundingClientRect().width))) : 0;
    const classicStyle = missingGutter ? await page.addStyleTag({ content: `html{width:calc(100% - ${missingGutter}px)}` }) : null;
    for (const width of [320, 390, 489]) {
      await page.setViewportSize({ width, height: width === 320 ? 568 : 954 });
      await page.evaluate(() => document.fonts.ready);
      const geometry = await toolbarGeometry(page);
      const diagnostic = JSON.stringify({ scrollbars, width, ...geometry }, null, 2);
      await testInfo.attach(`toolbar-geometry-${scrollbars}-${width}`, { body: diagnostic, contentType: 'application/json' });
      if (scrollbars === 'classic-15px') expect(geometry.window.innerWidth - geometry.window.bodyWidth, diagnostic).toBeGreaterThanOrEqual(14.5);
      expect(geometry.buttons).toHaveLength(6);
      expect(geometry.overlaps, diagnostic).toEqual([]);
      expect(geometry.inside).toBe(true);
      expect(geometry.overflow).toBe(false);
      for (const button of geometry.buttons) expect(button.height).toBeGreaterThanOrEqual(44);

      // Icon-only history actions retain their accessible name and keyboard focus.
      await page.getByRole('button', { name: '扩大预览', exact: true }).focus();
      await page.keyboard.press('Tab');
      await expect(undo).toBeFocused();
      expect(await undo.evaluate(button => parseFloat(getComputedStyle(button).outlineWidth))).toBeGreaterThanOrEqual(2);
      await expect(viewport.locator('.studio-history').getByRole('button', { name: '重做', exact: true })).toBeVisible();
    }
    await classicStyle?.evaluate(style => style.remove());
  }
  expect(fixture.errors).toEqual([]);
  expect(fixture.writes).toEqual([]);
});
