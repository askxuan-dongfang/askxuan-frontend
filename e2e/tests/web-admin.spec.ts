import { expect, test, type Page } from '@playwright/test'
import { mkdirSync } from 'node:fs'

type AdminApp = {
  key: 'temple' | 'shop' | 'platform'
  name: string
  baseURL: string
  account: string
  password: string
  routes: string[]
}

const apps: AdminApp[] = [
  {
    key: 'temple',
    name: '寺院管理台',
    baseURL: 'http://127.0.0.1:5173',
    account: 'lingyin_admin',
    password: '123456',
    routes: [
      '/dashboard',
      '/temple-info',
      '/masters',
      '/masters/edit',
      '/services',
      '/services/edit',
      '/bookings',
      '/bookings/1',
      '/reviews',
      '/report',
      '/settings'
    ]
  },
  {
    key: 'shop',
    name: '商城管理台',
    baseURL: 'http://127.0.0.1:5174',
    account: 'admin',
    password: '123456',
    routes: [
      '/dashboard',
      '/products',
      '/products/edit',
      '/categories',
      '/materials',
      '/materials/edit',
      '/services',
      '/services/edit',
      '/orders',
      '/orders/1',
      '/diy-orders',
      '/diy-orders/1',
      '/logistics',
      '/returns',
      '/returns/1',
      '/reports'
    ]
  },
  {
    key: 'platform',
    name: '平台管理台',
    baseURL: 'http://127.0.0.1:5175',
    account: 'admin',
    password: '123456',
    routes: [
      '/dashboard',
      '/temple/list',
      '/temple/detail/T001',
      '/temple/review',
      '/master/list',
      '/master/review',
      '/user/list',
      '/user/detail/1',
      '/audit/comment',
      '/audit/design',
      '/audit/report',
      '/finance/overview',
      '/finance/temple',
      '/finance/master',
      '/finance/reconcile',
      '/marketing/banner',
      '/marketing/activity',
      '/marketing/coupon',
      '/settings/role',
      '/settings/dict',
      '/settings/log',
      '/settings/backup'
    ]
  }
]

async function login(page: Page, app: AdminApp) {
  const consoleErrors: string[] = []
  page.on('console', (msg) => {
    if (msg.type() === 'error') consoleErrors.push(msg.text())
  })
  page.on('pageerror', (error) => consoleErrors.push(error.message))

  await page.goto(`${app.baseURL}/login`, { waitUntil: 'networkidle' })
  await page.getByPlaceholder(/账号|管理员账号/).fill(app.account)
  await page.getByPlaceholder(/密码|登录密码/).fill(app.password)
  await page.getByRole('button', { name: /登\s*录/ }).click()
  await page.waitForURL((url) => !url.pathname.includes('/login'), { timeout: 20_000 })
  await expect(page.locator('body')).not.toHaveText(/白屏|Cannot GET/i)

  return consoleErrors
}

function isBenignConsoleError(message: string) {
  return message.includes('favicon') ||
    message.includes('ResizeObserver loop completed') ||
    message.includes('ERR_CONNECTION_CLOSED')
}

for (const app of apps) {
  test.describe(app.name, () => {
    test(`登录并截图核心路由`, async ({ page }, testInfo) => {
      const consoleErrors = await login(page, app)

      for (const route of app.routes) {
        await page.goto(`${app.baseURL}${route}`, { waitUntil: 'networkidle' })
        await expect(page.locator('body')).toBeVisible()
        await expect(page.locator('body')).not.toHaveText(/Cannot read|Unhandled|白屏/i)
        const safeRoute = route.replace(/^\//, '').replace(/[/:]/g, '_') || 'root'
        mkdirSync(`artifacts/web/${app.key}/${testInfo.project.name}`, { recursive: true })
        await page.screenshot({
          path: `artifacts/web/${app.key}/${testInfo.project.name}/${safeRoute}.png`,
          fullPage: true
        })
      }

      expect(consoleErrors.filter((msg) => !isBenignConsoleError(msg))).toEqual([])
    })
  })
}
