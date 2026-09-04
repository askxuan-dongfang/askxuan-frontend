import { expect, test, type Page } from '@playwright/test'
import { mkdirSync } from 'node:fs'

const loginCases: ReadonlyArray<{ route: string; root: string; input: string; logo?: string }> = [
  { route: '/c/login', root: '.h5-app', input: '请输入手机号码' },
  { route: '/m/login', root: '.h5-app', input: '请输入法师账号' },
  { route: '/admin/login', root: '.login', input: '管理员账号', logo: '.login__seal' },
  { route: '/shop/login', root: '.login-page', input: '请输入账号', logo: '.login-symbol' },
  { route: '/temple/login', root: '.login-page', input: '请输入账号', logo: '.login-mark' }
]

const publicH5Routes = [
  '/c',
  '/c/temples',
  '/c/masters',
  '/c/services',
  '/c/shop',
  '/c/diy',
  '/c/community'
] as const

function safeRoute(route: string) {
  return route.replace(/^\//, '').replace(/[/:]/g, '_') || 'root'
}

function collectBrowserFailures(page: Page) {
  const consoleErrors: string[] = []
  const httpErrors: string[] = []
  page.on('console', (message) => {
    if (message.type() === 'error') consoleErrors.push(message.text())
  })
  page.on('pageerror', (error) => consoleErrors.push(error.message))
  page.on('response', (response) => {
    if (response.status() >= 400) httpErrors.push(`${response.status()} ${response.url()}`)
  })
  return { consoleErrors, httpErrors }
}

function benignConsoleError(message: string) {
  return message.includes('favicon') || message.includes('ResizeObserver loop completed')
}

async function expectNoPageOverflow(page: Page) {
  let geometry: { clientWidth: number; documentWidth: number; bodyWidth: number } | undefined
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      geometry = await page.evaluate(() => ({
        clientWidth: document.documentElement.clientWidth,
        documentWidth: document.documentElement.scrollWidth,
        bodyWidth: document.body.scrollWidth
      }))
      break
    } catch (error) {
      const navigationRace = error instanceof Error && error.message.includes('Execution context was destroyed')
      if (!navigationRace || attempt === 2) throw error
      await page.waitForLoadState('domcontentloaded')
      await page.waitForTimeout(100)
    }
  }
  if (!geometry) throw new Error('页面几何信息不可用')
  expect(geometry.documentWidth, `document overflow: ${JSON.stringify(geometry)}`).toBeLessThanOrEqual(geometry.clientWidth + 1)
  expect(geometry.bodyWidth, `body overflow: ${JSON.stringify(geometry)}`).toBeLessThanOrEqual(geometry.clientWidth + 1)
}

async function expectVisibleControlsInViewport(page: Page) {
  const clipped = await page.locator('input:visible, button:visible').evaluateAll((nodes) => nodes.flatMap((node) => {
    const rect = node.getBoundingClientRect()
    if (rect.width <= 1 || rect.height <= 1) return []
    if (rect.left >= -1 && rect.right <= document.documentElement.clientWidth + 1) return []
    return [{
      label: node.getAttribute('aria-label') || node.getAttribute('placeholder') || node.textContent?.trim().slice(0, 30) || '',
      left: rect.left,
      right: rect.right,
      viewport: document.documentElement.clientWidth
    }]
  }))
  expect(clipped, `visible controls clipped by viewport: ${JSON.stringify(clipped)}`).toEqual([])
}

test.describe('ECS 公开页面无凭证验收', () => {
  test('五端登录页可渲染且不会提交凭证', async ({ page }, testInfo) => {
    const failures = collectBrowserFailures(page)
    const artifactDir = `artifacts/web-public/${testInfo.project.name}`
    mkdirSync(artifactDir, { recursive: true })

    for (const item of loginCases) {
      const response = await page.goto(item.route, { waitUntil: 'domcontentloaded' })
      expect(response?.status(), `${item.route} document status`).toBe(200)
      await expect(page.locator(item.root).first()).toBeVisible()
      await expect(page.getByPlaceholder(item.input).first()).toBeVisible()
      if (item.logo) {
        const logo = page.locator(item.logo).first()
        await expect(logo).toBeVisible()
        await expect.poll(() => logo.evaluate((node) => node instanceof HTMLImageElement ? node.naturalWidth : 0)).toBeGreaterThan(0)
      }
      if (item.route === '/admin/login') {
        await expect(page.locator('.login__title')).toHaveCSS('color', 'rgb(240, 230, 218)')
      }
      if (item.route === '/shop/login') {
        await expect(page.getByText(/shop_admin|123456/)).toHaveCount(0)
      }
      await expectNoPageOverflow(page)
      await expectVisibleControlsInViewport(page)
      await page.screenshot({ path: `${artifactDir}/${safeRoute(item.route)}.png`, fullPage: true })
    }

    expect(failures.consoleErrors.filter((message) => !benignConsoleError(message))).toEqual([])
    expect(failures.httpErrors).toEqual([])
  })

  test('信众端公开路由使用 ECS 真实只读接口渲染', async ({ page }, testInfo) => {
    const failures = collectBrowserFailures(page)
    const artifactDir = `artifacts/web-public/${testInfo.project.name}`
    mkdirSync(artifactDir, { recursive: true })

    for (const route of publicH5Routes) {
      const response = await page.goto(route, { waitUntil: 'domcontentloaded' })
      expect(response?.status(), `${route} document status`).toBe(200)
      await expect(page.locator('.h5-app')).toBeVisible()
      await expect(page.getByText('页面暂时无法显示')).toHaveCount(0)
      await page.waitForTimeout(500)
      await expectNoPageOverflow(page)
      await page.screenshot({ path: `${artifactDir}/${safeRoute(route)}.png`, fullPage: true })
    }

    expect(failures.consoleErrors.filter((message) => !benignConsoleError(message))).toEqual([])
    expect(failures.httpErrors).toEqual([])
  })
})
