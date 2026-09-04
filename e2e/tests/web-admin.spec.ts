import { expect, test, type Page } from '@playwright/test'
import { mkdirSync } from 'node:fs'

const liveAuth = process.env.E2E_RUN_LIVE_AUTH === '1'
const externalBaseURL = process.env.E2E_LIVE_BASE_URL?.trim().replace(/\/+$/, '')

function appBaseURL(localPort: number, publicPath: string): string {
  return externalBaseURL ? `${externalBaseURL}${publicPath}` : `http://127.0.0.1:${localPort}`
}

type AdminApp = {
  key: 'temple' | 'shop' | 'platform'
  name: string
  baseURL: string
  account: string
  password: string
  role: string
  clientId: string
  tokenKey: string
  refreshKey: string
  userKey: string
  userInfo: Record<string, unknown>
  routes: string[]
}

const apps: AdminApp[] = [
  {
    key: 'temple',
    name: '寺院管理台',
    baseURL: appBaseURL(5273, '/temple'),
    account: process.env.E2E_TEMPLE_ACCOUNT?.trim() || '',
    password: process.env.E2E_TEMPLE_PASSWORD?.trim() || '',
    role: 'temple_admin',
    clientId: 'temple-admin',
    tokenKey: 'df_temple_admin_token',
    refreshKey: 'df_temple_admin_refresh_token',
    userKey: 'df_temple_admin_user',
    userInfo: { userId: 2, nickname: '灵隐寺管理员', templeId: 'T001', templeName: '灵隐寺' },
    routes: [
      '/dashboard',
      '/temple-info',
      '/temple-gallery',
      '/masters',
      '/masters/edit',
      '/services',
      '/services/edit',
      '/bookings',
      '/bookings/1',
      '/blessing-tasks',
      '/blessing-tasks/1',
      '/reviews',
      '/report',
      '/settings'
    ]
  },
  {
    key: 'shop',
    name: '商城管理台',
    baseURL: appBaseURL(5274, '/shop'),
    account: process.env.E2E_SHOP_ACCOUNT?.trim() || '',
    password: process.env.E2E_SHOP_PASSWORD?.trim() || '',
    role: 'shop_admin',
    clientId: 'shop-admin',
    tokenKey: 'df_shop_admin_token',
    refreshKey: 'df_shop_admin_refresh_token',
    userKey: 'df_shop_admin_user',
    userInfo: { userId: 3, nickname: '商城管理员', shopId: 1 },
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
    baseURL: appBaseURL(5275, '/admin'),
    account: process.env.E2E_PLATFORM_ACCOUNT?.trim() || '',
    password: process.env.E2E_PLATFORM_PASSWORD?.trim() || '',
    role: 'platform_super',
    clientId: 'platform-admin',
    tokenKey: 'df_platform_admin_token',
    refreshKey: 'df_platform_admin_refresh_token',
    userKey: 'df_platform_admin_user',
    userInfo: { userId: 1, nickname: '平台管理员' },
    routes: [
      '/dashboard',
      '/temple/list',
      '/temple/detail/T001',
      '/temple/review',
      '/master/list',
      '/master/review',
      '/master/create',
      '/master/detail/1',
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
      '/settings/taxonomy',
      '/settings/account',
      '/settings/dict',
      '/settings/log',
      '/settings/backup'
    ]
  }
]

async function login(page: Page, app: AdminApp) {
  if (!app.account || !app.password) {
    throw new Error(`真实登录验收缺少 ${app.key} 管理台账号或密码环境变量，未发送登录请求`)
  }
  await page.goto(`${app.baseURL}/login`, { waitUntil: 'networkidle' })
  await page.getByPlaceholder(/账号|管理员账号/).fill(app.account)
  await page.getByPlaceholder(/密码|登录密码/).fill(app.password)
  await page.getByRole('button', { name: /登\s*录/ }).click()
  await page.waitForURL((url) => !url.pathname.includes('/login'), { timeout: 20_000 })
  await expect(page.locator('body')).not.toHaveText(/白屏|Cannot GET/i)

}

function collectConsoleErrors(page: Page) {
  const errors: string[] = []
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(message.text())
  })
  page.on('pageerror', (error) => errors.push(error.message))
  return errors
}

function unsignedToken(payload: Record<string, unknown>) {
  const encode = (value: Record<string, unknown>) => Buffer.from(JSON.stringify(value)).toString('base64url')
  return `${encode({ alg: 'none', typ: 'JWT' })}.${encode(payload)}.ui-regression`
}

async function seedAdminSession(page: Page, app: AdminApp) {
  const token = unsignedToken({
    userId: app.userInfo.userId,
    roles: [app.role],
    clientId: app.clientId,
    exp: Math.floor(Date.now() / 1000) + 3600
  })
  await page.addInitScript(({ app, token }) => {
    localStorage.setItem(app.tokenKey, token)
    localStorage.setItem(app.refreshKey, 'ui-regression-refresh')
    localStorage.setItem(app.userKey, JSON.stringify(app.userInfo))
    if (app.key === 'temple') {
      localStorage.setItem('df_temple_admin_temple_id', String(app.userInfo.templeId || ''))
      localStorage.setItem('df_temple_admin_temple_name', String(app.userInfo.templeName || ''))
    }
  }, { app, token })
}

async function mockAdminApi(page: Page, resolveData?: (url: URL) => Record<string, unknown> | undefined) {
  await page.route('**/api/v1/**', async (route) => {
    const defaultData = {
      id: 1,
      list: [],
      items: [],
      total: 0,
      page: 1,
      size: 20,
      status: 'enabled',
      preferenceTags: [],
      permissions: [],
      roles: [],
      totalIncome: 0,
      commissionIncome: 0,
      templeIncome: 0,
      masterIncome: 0,
      shopIncome: 0,
      pendingWithdraw: 0,
      pendingCount: 0,
      approvedCount: 0,
      rejectedCount: 0
    }
    const data = resolveData?.(new URL(route.request().url())) ?? defaultData
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ code: 0, message: 'UI regression fixture', data })
    })
  })
}

function isBenignConsoleError(message: string) {
  return message.includes('favicon') ||
    message.includes('ResizeObserver loop completed') ||
    message.includes('ERR_CONNECTION_CLOSED')
}

async function expectNoPageOverflow(page: Page) {
  const geometry = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
    bodyScrollWidth: document.body.scrollWidth
  }))
  expect(geometry.scrollWidth, `document overflow: ${JSON.stringify(geometry)}`).toBeLessThanOrEqual(geometry.clientWidth + 1)
  expect(geometry.bodyScrollWidth, `body overflow: ${JSON.stringify(geometry)}`).toBeLessThanOrEqual(geometry.clientWidth + 1)
}

async function expectVisibleFormControlsInViewport(page: Page) {
  const clipped = await page.locator('form input, form textarea, form button, form [role="combobox"], form .el-input-number').evaluateAll((elements) => {
    const viewportWidth = window.innerWidth
    return elements.flatMap((element) => {
      const node = element as HTMLElement
      const style = window.getComputedStyle(node)
      const rect = node.getBoundingClientRect()
      if (style.display === 'none' || style.visibility === 'hidden' || Number(style.opacity) === 0 || rect.width === 0 || rect.height === 0) return []
      if (node.closest('.el-table, .aui-data-table__scroller, [data-allow-horizontal-scroll]')) return []
      if (rect.left >= -1 && rect.right <= viewportWidth + 1) return []
      return [{
        tag: node.tagName.toLowerCase(),
        className: node.className,
        label: node.getAttribute('aria-label') || node.getAttribute('placeholder') || node.textContent?.trim().slice(0, 40) || '',
        left: Math.round(rect.left),
        right: Math.round(rect.right),
        viewportWidth
      }]
    })
  })
  expect(clipped, `表单控件被视口裁切: ${JSON.stringify(clipped)}`).toEqual([])
}

for (const app of apps) {
  test.describe(app.name, () => {
    test(`登录页结构与核心路由响应式截图`, async ({ page }, testInfo) => {
      const consoleErrors = collectConsoleErrors(page)
      await page.goto(`${app.baseURL}/login`, { waitUntil: 'networkidle' })
      await expect(page.getByPlaceholder(/账号|管理员账号/)).toBeVisible()
      await expect(page.getByPlaceholder(/密码|登录密码/)).toBeVisible()
      await expect(page.getByRole('button', { name: /登\s*录/ })).toBeVisible()

      if (liveAuth) {
        await login(page, app)
      } else {
        await mockAdminApi(page)
        await seedAdminSession(page, app)
      }

      for (const route of app.routes) {
        await page.goto(`${app.baseURL}${route}`, { waitUntil: 'domcontentloaded' })
        await expect(page.locator('main')).toBeVisible()
        await expect(page.locator('body')).not.toHaveText(/Cannot read|Unhandled|白屏/i)
        await page.waitForTimeout(250)
        await expect(page.locator('.el-loading-mask:visible')).toHaveCount(0, { timeout: 5_000 })
          await expectNoPageOverflow(page)
          if ((test.info().project.use.viewport?.width || 0) <= 767) {
            await expectVisibleFormControlsInViewport(page)
          }

        const isDrawerViewport = await page.evaluate(() => window.innerWidth <= 991)
        if (isDrawerViewport) {
          const navigation = page.locator('aside[aria-label]')
          const closedBox = await navigation.boundingBox()
          expect(closedBox && closedBox.x + closedBox.width <= 1).toBeTruthy()
        }

        const safeRoute = route.replace(/^\//, '').replace(/[/:]/g, '_') || 'root'
        mkdirSync(`artifacts/web/${app.key}/${testInfo.project.name}`, { recursive: true })
        await page.screenshot({
          path: `artifacts/web/${app.key}/${testInfo.project.name}/${safeRoute}.png`,
          fullPage: true
        })
      }

      const isDrawerViewport = await page.evaluate(() => window.innerWidth <= 991)
      if (isDrawerViewport) {
        await page.goto(`${app.baseURL}/dashboard`, { waitUntil: 'domcontentloaded' })
        await page.getByRole('button', { name: '切换主导航' }).click()
        await expect.poll(async () => {
          const openBox = await page.locator('aside[aria-label]').boundingBox()
          return openBox?.x ?? -999
        }).toBeGreaterThanOrEqual(-1)
        await page.getByRole('button', { name: '关闭导航' }).click({ position: { x: 380, y: 20 } })
      }

      expect(consoleErrors.filter((msg) => !isBenignConsoleError(msg))).toEqual([])
    })
  })
}

const populatedMobileCases = [
  {
    app: apps[0],
    route: '/bookings',
    endpoint: '/api/v1/admin/bookings',
    expected: '祈福法会',
    item: {
      id: 'B20260904001', userId: 'U001', templeId: 'T001', templeName: '灵隐寺', masterId: 'M001',
      masterName: '智海法师', serviceId: 'S001', serviceName: '祈福法会', bookingDate: '2026-09-05',
      slotCode: 'AM', timeSlot: '09:00-10:00', serviceFee: 88, meritMoney: 100, totalFee: 188,
      paymentStatus: 'success', paymentNo: 'P001', meritMoneyTier: '随喜', status: 'pending', note: '', createTime: '2026-09-04 10:00:00'
    }
  },
  {
    app: apps[1],
    route: '/orders',
    endpoint: '/api/v1/admin/orders',
    expected: 'SO20260904001',
    item: {
      id: 1, orderNo: 'SO20260904001', userId: 'U001', totalAmount: 299, payAmount: 299,
      status: 'paid', addressId: 1, note: '', createTime: '2026-09-04 10:00:00'
    }
  },
  {
    app: apps[2],
    route: '/master/review',
    endpoint: '/api/v1/admin/platform/masters/audits',
    expected: 'M20260904001',
    item: {
      id: 1, masterCode: 'M20260904001', templeCode: 'T001', credentialUrls: [], status: 'pending',
      auditorId: 0, auditRemark: '', createTime: '2026-09-04 10:00:00'
    }
  }
]

test.describe('管理台移动任务卡', () => {
  for (const testCase of populatedMobileCases) {
    test(`${testCase.app.name}非空任务可查看和处理`, async ({ page }, testInfo) => {
      test.skip(testInfo.project.name !== 'admin-390', '非空任务卡交互只需在手机任务模式验证一次')
      await mockAdminApi(page, (url) => url.pathname === testCase.endpoint
        ? { list: [testCase.item], total: 1, page: 1, size: 20 }
        : undefined)
      await seedAdminSession(page, testCase.app)
      await page.goto(`${testCase.app.baseURL}${testCase.route}`, { waitUntil: 'domcontentloaded' })
      const card = page.locator('.mobile-task-card').filter({ hasText: testCase.expected }).first()
      await expect(card).toBeVisible()
      await expectNoPageOverflow(page)
    })
  }
})

async function mockEndpointFailure(page: Page, endpoint: string) {
  await page.route('**/api/v1/**', async (route) => {
    if (new URL(route.request().url()).pathname !== endpoint) {
      await route.fallback()
      return
    }
    await route.fulfill({
      status: 503,
      contentType: 'application/json',
      body: JSON.stringify({ code: 503, message: 'UI regression forced failure', data: null })
    })
  })
}

const shopReportFixture = {
  todayOrders: 12,
  todaySales: 1999,
  pendingShip: 3,
  totalOrders: 86,
  totalSales: 12888,
  trend: [
    { date: '2026-09-03', sales: 1688, orders: 9 },
    { date: '2026-09-04', sales: 1999, orders: 12 }
  ],
  topProducts: [{ productId: 1, productName: '菩提手串', sales: 3999, orderCount: 16 }],
  refundRate: 0.02
}

const templeReportFixture = {
  revenueStats: { totalRevenue: 9688, bookingCount: 42, avgBookingValue: 230.67, completedCount: 36 },
  bookingTrend: [
    { date: '2026-09-03', bookings: 5, revenue: 1188 },
    { date: '2026-09-04', bookings: 7, revenue: 1688 }
  ],
  serviceDistribution: [{ serviceName: '祈福法会', count: 18 }],
  masterRanking: [{ masterName: '智海法师', bookingCount: 12, revenue: 3288 }]
}

test.describe('管理台移动图表与异常语义', () => {
  test('390px 图表均提供可读数值摘要', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'admin-390', '图表移动摘要只需在手机任务模式验证一次')
    await mockAdminApi(page, (url) => {
      if (url.pathname === '/api/v1/admin/orders/report') return shopReportFixture
      if (url.pathname === '/api/v1/admin/finance/overview') {
        return { totalIncome: 28888, commissionIncome: 2888, templeIncome: 12000, masterIncome: 8000, shopIncome: 6000, pendingWithdraw: 2 }
      }
      if (url.pathname === '/api/v1/admin/audit/statistics') return { pendingCount: 6, approvedCount: 28, rejectedCount: 3 }
      if (url.pathname === '/api/v1/admin/platform/temples') return { list: [], total: 12, page: 1, size: 1 }
      if (url.pathname === '/api/v1/admin/platform/masters') return { list: [], total: 38, page: 1, size: 1 }
      if (url.pathname === '/api/v1/admin/users') return { list: [], total: 680, page: 1, size: 1 }
      if (url.pathname === '/api/v1/admin/bookings/report') return templeReportFixture
      return undefined
    })

    await seedAdminSession(page, apps[1])
    await page.goto(`${apps[1].baseURL}/dashboard`, { waitUntil: 'domcontentloaded' })
    const shopDashboardSummary = page.locator('.chart-mobile-summary')
    await expect(shopDashboardSummary).toBeVisible()
    await expect(shopDashboardSummary).toContainText('今日销售额')
    await expect(shopDashboardSummary).toContainText('¥1,999.00')

    await page.goto(`${apps[1].baseURL}/reports`, { waitUntil: 'domcontentloaded' })
    const shopReportSummary = page.locator('.mobile-report-summary')
    await expect(shopReportSummary).toBeVisible()
    await expect(shopReportSummary).toContainText('经营图表摘要')
    await expect(shopReportSummary).toContainText('菩提手串')

    await seedAdminSession(page, apps[2])
    await page.goto(`${apps[2].baseURL}/dashboard`, { waitUntil: 'domcontentloaded' })
    await expect(page.locator('.chart-card__mobile-summary')).toHaveCount(2)
    await expect(page.locator('.chart-card__mobile-summary').first()).toContainText('¥28888')
    await expect(page.locator('.chart-card__mobile-summary').last()).toContainText('6')

    await seedAdminSession(page, apps[0])
    await page.goto(`${apps[0].baseURL}/report`, { waitUntil: 'domcontentloaded' })
    const templeSummary = page.locator('.mobile-report-summary')
    await expect(templeSummary).toBeVisible()
    await expect(templeSummary).toContainText('经营摘要')
    await expect(templeSummary).toContainText('2 个')
    await expectNoPageOverflow(page)
  })

  const partialFailureCases = [
    {
      app: apps[1], endpoint: '/api/v1/admin/orders/report', module: '经营报表',
      value: (page: Page) => page.locator('.aui-stat-card').filter({ hasText: '今日销售额' }).locator('.aui-stat-card__value')
    },
    {
      app: apps[2], endpoint: '/api/v1/admin/finance/overview', module: '财务概览',
      value: (page: Page) => page.locator('.aui-stat-card').filter({ hasText: '平台总收入（元）' }).locator('.aui-stat-card__value')
    },
    {
      app: apps[0], endpoint: '/api/v1/admin/temples/blessing-tasks', module: '待分配加持',
      value: (page: Page) => page.locator('.ax-task-card').filter({ hasText: '待分配加持' }).locator('.ax-task-card__value')
    }
  ]

  for (const testCase of partialFailureCases) {
    test(`${testCase.app.name}局部失败点名模块且不伪装为 0`, async ({ page }, testInfo) => {
      test.skip(testInfo.project.name !== 'admin-390', '局部失败语义只需在手机任务模式验证一次')
      await mockAdminApi(page)
      await mockEndpointFailure(page, testCase.endpoint)
      await seedAdminSession(page, testCase.app)
      await page.goto(`${testCase.app.baseURL}/dashboard`, { waitUntil: 'domcontentloaded' })
      const feedback = page.locator('.ax-page-feedback')
      await expect(feedback).toBeVisible()
      await expect(feedback).toContainText(`失败模块：${testCase.module}`)
      await expect(testCase.value(page)).toContainText('—')
      await expect(testCase.value(page)).not.toContainText('0')
    })
  }

  test('报表 HTTP 成功但缺字段时进入失败态且不显示 undefined', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'admin-390', '缺字段成功响应只需在手机任务模式验证一次')
    await mockAdminApi(page)

    await seedAdminSession(page, apps[1])
    await page.goto(`${apps[1].baseURL}/dashboard`, { waitUntil: 'domcontentloaded' })
    await expect(page.locator('.ax-page-feedback')).toContainText('失败模块：经营报表')
    await expect(page.locator('.aui-stat-card').filter({ hasText: '今日订单' }).locator('.aui-stat-card__value')).toHaveText('—')
    await expect(page.locator('body')).not.toContainText('undefined')

    await seedAdminSession(page, apps[0])
    await page.goto(`${apps[0].baseURL}/dashboard`, { waitUntil: 'domcontentloaded' })
    await expect(page.locator('.ax-page-feedback')).toContainText('失败模块：经营报表')
    await expect(page.locator('.aui-stat-card').filter({ hasText: '累计预约' }).locator('.aui-stat-card__value')).toHaveText('—')
    await expect(page.locator('body')).not.toContainText('undefined')
  })
})

test.describe('管理台高风险操作确认', () => {
  test('订单发货展示影响与运单号，取消后不发送写请求', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'admin-390', '高风险确认只需在手机任务模式验证一次')
    let shipWrites = 0
    page.on('request', (request) => {
      if (request.method() === 'PUT' && new URL(request.url()).pathname === '/api/v1/admin/orders/1/ship') shipWrites += 1
    })
    await mockAdminApi(page, (url) => url.pathname === '/api/v1/admin/orders/1'
      ? {
          id: 1, orderNo: 'SO20260904001', userId: 'U001', totalAmount: 299, payAmount: 299,
          status: 'paid', addressId: 1, note: '', items: [], logistics: null, createTime: '2026-09-04 10:00:00'
        }
      : undefined)
    await seedAdminSession(page, apps[1])
    await page.goto(`${apps[1].baseURL}/orders/1`, { waitUntil: 'domcontentloaded' })
    await page.getByRole('button', { name: '发货', exact: true }).click()
    const shipDialog = page.getByRole('dialog', { name: '订单发货' })
    await expect(shipDialog).toContainText('发货后订单进入待收货状态')
    await shipDialog.getByText('请选择快递公司', { exact: true }).click()
    await page.getByText('顺丰速运', { exact: true }).last().click()
    await shipDialog.getByPlaceholder('请输入运单号').fill('SF1234567890')
    await shipDialog.getByRole('button', { name: '确认发货' }).click()
    await expect(page.getByText(/运单号 SF1234567890 将展示给用户.*不能在本页面撤回/)).toBeVisible()
    await page.getByRole('button', { name: '返回核对' }).click()
    await expect.poll(() => shipWrites).toBe(0)
  })

  test('提现审核说明金额与流转影响，取消后不发送写请求', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'admin-390', '高风险确认只需在手机任务模式验证一次')
    let auditWrites = 0
    page.on('request', (request) => {
      if (request.method() === 'PUT' && new URL(request.url()).pathname === '/api/v1/admin/finance/withdrawals/1/audit') auditWrites += 1
    })
    await mockAdminApi(page, (url) => url.pathname === '/api/v1/admin/finance/withdrawals'
      ? {
          list: [{
            id: 1, withdrawalNo: 'WD20260904001', applicantType: 'master', applicantId: 'M001', amount: 1688,
            bankCard: '6222020202020202', status: 'pending', auditTime: '', processTime: '', createTime: '2026-09-04 10:00:00'
          }],
          total: 1, page: 1, size: 20
        }
      : undefined)
    await seedAdminSession(page, apps[2])
    await page.goto(`${apps[2].baseURL}/finance/reconcile`, { waitUntil: 'domcontentloaded' })
    const card = page.locator('.mobile-task-card').filter({ hasText: 'WD20260904001' })
    await card.getByRole('button', { name: '通过' }).click()
    await expect(page.getByText(/金额 ¥1,688\.00，通过后将进入打款处理队列/)).toBeVisible()
    await page.getByRole('button', { name: '返回核对' }).click()
    await expect.poll(() => auditWrites).toBe(0)
  })

  test('共用审批弹窗解释生效范围，取消后不发送写请求', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'admin-390', '高风险确认只需在手机任务模式验证一次')
    let reviewWrites = 0
    page.on('request', (request) => {
      if (request.method() === 'PUT' && new URL(request.url()).pathname.includes('/api/v1/admin/platform/masters/audits/1/')) reviewWrites += 1
    })
    await mockAdminApi(page, (url) => url.pathname === '/api/v1/admin/platform/masters/audits'
      ? {
          list: [{ id: 1, masterCode: 'M20260904001', templeCode: 'T001', credentialUrls: [], status: 'pending', auditorId: 0, auditRemark: '', createTime: '2026-09-04 10:00:00' }],
          total: 1, page: 1, size: 20
        }
      : undefined)
    await seedAdminSession(page, apps[2])
    await page.goto(`${apps[2].baseURL}/master/review`, { waitUntil: 'domcontentloaded' })
    const card = page.locator('.mobile-task-card').filter({ hasText: 'M20260904001' })
    await card.getByRole('button', { name: '通过' }).click()
    const dialog = page.getByRole('dialog', { name: '审核通过' })
    await expect(dialog).toContainText('进入后续发布、展示或业务流转')
    await dialog.getByRole('button', { name: '取消' }).click()
    await expect.poll(() => reviewWrites).toBe(0)
  })
})
