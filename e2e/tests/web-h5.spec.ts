import { expect, test, type Page } from '@playwright/test'
import { mkdirSync } from 'node:fs'

const liveAuth = process.env.E2E_RUN_LIVE_AUTH === '1'
const externalBaseURL = process.env.E2E_LIVE_BASE_URL?.trim().replace(/\/+$/, '')
const baseURL = externalBaseURL || 'http://127.0.0.1:5276'

function requiredLiveCredential(name: string): string {
  const value = process.env[name]?.trim()
  if (!value) throw new Error(`真实登录验收缺少环境变量 ${name}，未发送登录请求`)
  return value
}

const customerRoutes = [
  '/c',
  '/c/temples',
  '/c/temples/1',
  '/c/temples/1/booking',
  '/c/masters',
  '/c/masters/1',
  '/c/masters/1/booking',
  '/c/masters/1/consult',
  '/c/services',
  '/c/services/booking',
  '/c/chats',
  '/c/chats/C001',
  '/c/messages',
  '/c/ai',
  '/c/shop',
  '/c/shop/1',
  '/c/shop/orders',
  '/c/shop/orders/1',
  '/c/diy',
  '/c/diy/editor',
  '/c/diy/orders',
  '/c/diy/1',
  '/c/bookings',
  '/c/bookings/1',
  '/c/intentions/health',
  '/c/community',
  '/c/community/1',
  '/c/live/1',
  '/c/favorites',
  '/c/reviews',
  '/c/profile'
]

const masterRoutes = [
  '/m',
  '/m/bookings',
  '/m/bookings/1',
  '/m/calendar',
  '/m/chats',
  '/m/chats/C002',
  '/m/blessings',
  '/m/blessings/1',
  '/m/earnings',
  '/m/pricing',
  '/m/profile',
  '/m/service-tags',
  '/m/reviews',
  '/m/settings',
  '/m/content'
]

async function expectNoPageOverflow(page: Page) {
  const geometry = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
    bodyScrollWidth: document.body.scrollWidth
  }))
  expect(geometry.scrollWidth, `document overflow: ${JSON.stringify(geometry)}`).toBeLessThanOrEqual(geometry.clientWidth + 1)
  expect(geometry.bodyScrollWidth, `body overflow: ${JSON.stringify(geometry)}`).toBeLessThanOrEqual(geometry.clientWidth + 1)
}

async function expectBottomActionClearance(page: Page) {
  const bars = page.locator('[data-bottom-action-bar]:visible')
  const count = await bars.count()
  if (count === 0) return

  const originalScrollY = await page.evaluate(() => window.scrollY)
  await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight))
  await page.waitForTimeout(50)

  for (let index = 0; index < count; index += 1) {
    const geometry = await bars.nth(index).evaluate((bar) => {
      const spacer = bar.previousElementSibling as HTMLElement | null
      const content = spacer?.previousElementSibling as HTMLElement | null
      const actionRect = bar.getBoundingClientRect()
      const spacerRect = spacer?.getBoundingClientRect()
      const contentRect = content?.getBoundingClientRect()
      return {
        hasSpacer: spacer?.classList.contains('fixed-action-spacer') ?? false,
        actionTop: actionRect.top,
        actionHeight: actionRect.height,
        spacerHeight: spacerRect?.height ?? 0,
        contentBottom: contentRect?.bottom ?? actionRect.top
      }
    })
    expect(geometry.hasSpacer, `bottom action is missing its flow spacer: ${JSON.stringify(geometry)}`).toBe(true)
    expect(geometry.spacerHeight, `bottom action spacer is too short: ${JSON.stringify(geometry)}`).toBeGreaterThanOrEqual(geometry.actionHeight - 1)
    expect(geometry.contentBottom, `content is covered by bottom action: ${JSON.stringify(geometry)}`).toBeLessThanOrEqual(geometry.actionTop + 1)
  }

  await page.evaluate((scrollY) => window.scrollTo(0, scrollY), originalScrollY)
}

async function expectTapTargets(page: Page, role: 'customer' | 'master') {
  const violations = await page.locator('button:visible, a[href]:visible, [role="button"]:visible').evaluateAll((nodes, currentRole) => {
    return nodes.flatMap((node) => {
      const element = node as HTMLElement
      const style = window.getComputedStyle(element)
      const rect = element.getBoundingClientRect()
      if (
        style.pointerEvents === 'none' ||
        style.display === 'none' ||
        style.visibility === 'hidden' ||
        element.matches(':disabled') ||
        rect.width <= 1 ||
        rect.height <= 1
      ) return []
      const label = element.getAttribute('aria-label') || element.textContent?.trim().replace(/\s+/g, ' ').slice(0, 40) || ''
      const criticalAction = currentRole === 'master' && element.hasAttribute('data-critical-action')
      const minimumSize = criticalAction ? 48 : 44
      if (rect.width >= minimumSize && rect.height >= minimumSize) return []
      return [{
        tag: element.tagName.toLowerCase(),
        className: element.className,
        label,
        width: Math.round(rect.width * 10) / 10,
        height: Math.round(rect.height * 10) / 10,
        minimumSize
      }]
    })
  }, role)
  expect(violations, `点击热区不足: ${JSON.stringify(violations)}`).toEqual([])
}

async function expectTextUnclipped(page: Page, text: string) {
  const target = page.getByText(text, { exact: false }).first()
  await expect(target).toBeVisible()
  const geometry = await target.evaluate((element) => {
    const range = document.createRange()
    range.selectNodeContents(element)
    const textRect = range.getBoundingClientRect()
    const self = element as HTMLElement
    const style = window.getComputedStyle(self)
    const selfClipped = self.clientWidth > 0 && self.scrollWidth > self.clientWidth + 1 && ['hidden', 'clip'].includes(style.overflowX)
    let ancestorClipped = false
    let parent = self.parentElement
    while (parent && !parent.classList.contains('h5-app')) {
      const parentStyle = window.getComputedStyle(parent)
      if (['hidden', 'clip'].includes(parentStyle.overflowX)) {
        const parentRect = parent.getBoundingClientRect()
        if (textRect.left < parentRect.left - 1 || textRect.right > parentRect.right + 1) {
          ancestorClipped = true
          break
        }
      }
      parent = parent.parentElement
    }
    return {
      selfClipped,
      ancestorClipped,
      textOverflow: style.textOverflow,
      clientWidth: self.clientWidth,
      scrollWidth: self.scrollWidth,
      textLeft: Math.round(textRect.left * 10) / 10,
      textRight: Math.round(textRect.right * 10) / 10,
      viewportWidth: window.innerWidth,
    }
  })
  expect(geometry.selfClipped, `${text} 自身被裁切: ${JSON.stringify(geometry)}`).toBe(false)
  expect(geometry.ancestorClipped, `${text} 被祖先容器裁切: ${JSON.stringify(geometry)}`).toBe(false)
}

function collectConsoleErrors(page: Page) {
  const errors: string[] = []
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(message.text())
  })
  page.on('pageerror', (error) => errors.push(error.message))
  return errors
}

function isBenignConsoleError(message: string) {
  return message.includes('favicon') || message.includes('ResizeObserver loop completed')
}

function unsignedToken(payload: Record<string, unknown>) {
  const encode = (value: Record<string, unknown>) => Buffer.from(JSON.stringify(value)).toString('base64url')
  return `${encode({ alg: 'none', typ: 'JWT' })}.${encode(payload)}.ui-regression`
}

async function mockH5Api(page: Page) {
  await page.route('**/api/v1/**', async (route) => {
    const request = route.request()
    const path = new URL(request.url()).pathname.replace(/^\/api\/v1/, '')
    const generic = {
      id: 1,
      list: [],
      items: [],
      total: 0,
      page: 1,
      size: 20,
      unreadCount: 0,
      pendingCount: 0,
      todayCount: 0,
      monthIncome: 0,
      availableBalance: 0,
      enabled: false,
      profile: {},
      stats: {}
    }
    let data: unknown = generic

    if (path === '/temples/1') {
      data = {
        id: '1', name: '云栖禅寺', region: '浙江杭州', type: '佛教', beliefCode: 'buddhism', sect: '禅宗',
        status: 'enabled', address: '杭州市西湖区云栖路', coverImage: '', rating: 4.9,
        description: '山林清幽，提供预约祈福与供灯服务。'
      }
    } else if (path === '/temples/1/services') {
      data = {
        list: [{
          id: 101, templeCode: '1', serviceCode: 'S001', serviceName: '祈福供灯', price: 168,
          status: 'enabled', timeSlots: ['09:00-10:00'],
          slots: [{ code: 'morning', label: '上午 09:00-10:00', startTime: '09:00', endTime: '10:00', capacity: 8, status: 'enabled', sort: 1 }]
        }]
      }
    } else if (path === '/masters/1') {
      data = {
        id: '1', dharmaName: '慧明法师', layName: '', templeId: '1', templeName: '云栖禅寺', position: '知客',
        beliefCode: 'buddhism', sect: '禅宗', type: '佛教', authStatus: '已认证', specialties: ['祈福', '禅修'],
        avatar: '', rating: 4.8, isOnline: true, manageBy: 'platform',
        serviceTags: [{ serviceCode: 'S001', price: 168, status: 'enabled' }]
      }
    } else if (path === '/bookings/availability') {
      data = {
        templeId: '1', serviceId: 'S001', serviceName: '祈福供灯', bookingDate: '2026-09-06', serviceFee: 168,
        slots: [{ slotCode: 'morning', label: '上午', timeRange: '09:00-10:00', capacity: 8, remaining: 5, available: true }]
      }
    } else if (path === '/bookings/1/review') {
      data = { id: 1, bookingId: '1', rating: 5, content: '体验很好，流程清晰。', images: [], masterReply: '随喜功德。', createTime: '2026-09-03 10:00:00' }
    } else if (path === '/bookings/1') {
      data = {
        id: '1', userId: '1', templeId: '1', templeName: '云栖禅寺', masterId: '1', masterName: '慧明法师',
        serviceId: 'S001', serviceName: '祈福供灯', bookingDate: '2026-09-06', timeSlot: '09:00-10:00',
        serviceFee: 168, meritMoney: 88, meritMoneyTier: '吉祥', totalFee: 256, status: 'completed',
        paymentNo: 'PAY202609040001', paymentChannel: 'mock', paymentStatus: 'success', createdAt: '2026-09-03 09:30:00', note: '祈愿家人平安'
      }
    } else if (path === '/products/1') {
      data = {
        id: 1, productNo: 'P202609040001', name: '天然菩提手串', categoryName: '佛珠手串',
        description: '精选天然菩提，手工打磨。', mainImage: '', status: 'on_shelf', price: 199, marketPrice: 239,
        stock: 20, tags: '寺院甄选,手工', skus: [{ id: 11, productId: 1, specName: '珠径', specValue: '10mm', price: 199, stock: 20 }], images: []
      }
    } else if (path === '/orders/1') {
      data = {
        id: 1, orderNo: 'SO202609040001', userId: '1', totalAmount: 199, payAmount: 199, status: 'shipped', addressId: 1,
        note: '', createTime: '2026-09-03 12:00:00',
        items: [{ id: 1, productId: 1, skuId: 11, productName: '天然菩提手串', skuSpec: '珠径：10mm', price: 199, quantity: 1, image: '' }],
        logistics: { id: 1, orderId: 1, expressCompany: '顺丰速运', trackingNo: 'SF1234567890', shipTime: '2026-09-04 08:00:00' }
      }
    } else if (path === '/diy/designs/1') {
      data = {
        id: 1, designNo: 'DIY202609040001', userId: '1', name: '秋山静心', totalPrice: 128, status: 'public', createTime: '2026-09-03 11:00:00',
        designData: JSON.stringify({ version: 2, wristSizeMm: 160, beads: [{ position: 0, materialId: 1, materialName: '菩提子', spec: '10mm', unitPrice: 8, subtype: 'main_bead', diameterMm: 10 }] })
      }
    } else if (path === '/diy/orders/availability') {
      data = { orderable: true, materialFee: 128, originalMaterialFee: 128, priceChanged: false, issues: [] }
    } else if (path === '/diy/materials') {
      data = {
        total: 2, page: 1, size: 100, list: [
          { id: 1, name: '菩提子', spec: '10mm', unitPrice: 8, unit: '颗', category: 'main_bead', fiveElements: 'wood', image: '', stock: 30, status: 'on_shelf', materialType: 'wood', shape: 'round', diameterMm: 10, colorHex: '#9B7447', textureKey: 'grain', finish: 'matte', translucency: 0.1 },
          { id: 2, name: '红玛瑙', spec: '8mm', unitPrice: 12, unit: '颗', category: 'spacer', fiveElements: 'fire', image: '', stock: 20, status: 'on_shelf', materialType: 'gemstone', shape: 'round', diameterMm: 8, colorHex: '#9E3E32', textureKey: 'pure', finish: 'polished', translucency: 0.35 }
        ]
      }
    } else if (path === '/chats' || path === '/bookings/chats') {
      data = {
        total: 2, page: 1, size: 50, list: [
          { conversationId: 'C001', sourceType: 'booking', sourceId: '1', bookingId: '1', peerId: '1', peerOpenIMId: 'm_1', peerName: '慧明法师', peerAvatar: '', templeName: '云栖禅寺', serviceName: '祈福供灯', bookingDate: '2026-09-06', expiresAt: '2026-09-08 18:00:00', lastMessage: '愿家人平安顺遂。', lastMessageAt: '2026-09-04 09:30:00', canChat: true, unreadCount: 1 },
          { conversationId: 'C002', sourceType: 'consultation', sourceId: '2', bookingId: '', peerId: '1', peerOpenIMId: 'u_1', peerName: '林居士', peerAvatar: '', templeName: '云栖禅寺', serviceName: '即时咨询', bookingDate: '', expiresAt: '2026-09-08 18:00:00', lastMessage: '请问如何静心？', lastMessageAt: '2026-09-04 09:35:00', canChat: true, unreadCount: 1 }
        ]
      }
    } else if (path === '/chats/C001/messages') {
      data = {
        total: 2, page: 1, size: 100, list: [
          { id: 1, conversationId: 'C001', sourceType: 'booking', bookingId: '1', clientMessageId: 'customer-1', senderType: 'customer', senderId: '1', receiverId: '1', content: '愿家人平安顺遂。', status: 'sent', createTime: '2026-09-04 09:30:00' },
          { id: 2, conversationId: 'C001', sourceType: 'booking', bookingId: '1', clientMessageId: 'master-1', senderType: 'master', senderId: '1', receiverId: '1', content: '已收到您的祈愿。', status: 'sent', createTime: '2026-09-04 09:31:00' }
        ]
      }
    } else if (path === '/chats/C002/messages') {
      data = {
        total: 2, page: 1, size: 100, list: [
          { id: 3, conversationId: 'C002', sourceType: 'consultation', bookingId: '', clientMessageId: 'customer-2', senderType: 'customer', senderId: '1', receiverId: '1', content: '请问如何静心？', status: 'sent', createTime: '2026-09-04 09:35:00' },
          { id: 4, conversationId: 'C002', sourceType: 'consultation', bookingId: '', clientMessageId: 'master-2', senderType: 'master', senderId: '1', receiverId: '1', content: '先从观呼吸开始。', status: 'sent', createTime: '2026-09-04 09:36:00' }
        ]
      }
    } else if (path === '/community/posts/1/comments') {
      data = { total: 1, page: 1, size: 50, list: [{ id: '1', postId: '1', userId: '1', content: '愿大家平安顺遂。', status: 'approved', createTime: '2026-09-03 16:00:00' }] }
    } else if (path === '/community/posts/1') {
      data = {
        id: '1', masterId: '1', type: 'article', title: '一念清净，处处莲花', content: '分享一段日常修行体会。',
        coverMediaId: 0, beliefCode: 'buddhism', status: 'approved', likeCount: 28, commentCount: 1, liked: false,
        assets: [], createTime: '2026-09-03 15:00:00'
      }
    } else if (path === '/live/rooms/1') {
      data = {
        id: 1, roomNo: 'LIVE001', ownerId: '1', masterId: '1', title: '晚课共修', coverMediaId: 0,
        provider: 'mock', status: 'living', openimGroupId: '', pushUrl: '', watchUrl: '', startedAt: '2026-09-04 19:00:00', endedAt: ''
      }
    } else if (path === '/admin/masters/bookings/1') {
      data = {
        id: '1', userId: '1', templeId: '1', templeName: '云栖禅寺', masterId: '1', masterName: '慧明法师',
        serviceId: 'S001', serviceName: '祈福供灯', bookingDate: '2026-09-06', timeSlot: '09:00-10:00',
        serviceFee: 168, meritMoney: 88, meritMoneyTier: '吉祥', totalFee: 256, paymentStatus: 'success',
        status: 'confirmed', note: '祈愿家人平安', createdAt: '2026-09-03 09:30:00'
      }
    } else if (path === '/admin/masters/blessing-tasks/1') {
      data = {
        id: 1, taskNo: 'BT202609040001', diyOrderNo: 'DIYORDER001', templeCode: '1', masterCode: '1', status: 'assigned',
        certificateUrls: [], assignTime: '2026-09-04 08:30:00', completeTime: '', createTime: '2026-09-04 08:00:00'
      }
    }
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ code: 0, message: 'UI regression fixture', data })
    })
  })
}

async function seedH5Session(page: Page, role: 'customer' | 'master') {
  const payload = role === 'master'
    ? { userId: 2, masterId: 1, roles: ['master'], clientId: 'master', exp: Math.floor(Date.now() / 1000) + 3600 }
    : { userId: 1, roles: ['customer'], clientId: 'customer', exp: Math.floor(Date.now() / 1000) + 3600 }
  const token = unsignedToken(payload)
  await page.addInitScript(({ role, token }) => {
    const state = {
      token,
      refreshToken: 'ui-regression-refresh',
      role,
      displayName: role === 'master' ? '演示法师' : '演示信众',
      userId: role === 'master' ? 2 : 1,
      masterId: role === 'master' ? 1 : undefined
    }
    localStorage.setItem('h5_token', token)
    localStorage.setItem('h5_refresh_token', state.refreshToken)
    localStorage.setItem('h5-auth', JSON.stringify({ state, version: 0 }))
  }, { role, token })
}

async function loginCustomer(page: Page) {
  await page.goto(`${baseURL}/c/login`, { waitUntil: 'networkidle' })
  if (!liveAuth) {
    await expect(page.getByPlaceholder('请输入手机号码')).toBeVisible()
    await expect(page.getByPlaceholder('请输入验证码')).toBeVisible()
    await mockH5Api(page)
    await seedH5Session(page, 'customer')
    return
  }
  if (!page.url().endsWith('/c/login')) return
  await page.getByPlaceholder('请输入手机号码').fill(requiredLiveCredential('E2E_CUSTOMER_PHONE'))
  await page.getByPlaceholder('请输入验证码').fill(requiredLiveCredential('E2E_CUSTOMER_CODE'))
  await page.getByRole('button', { name: '登 录' }).click()
  await page.waitForURL(`${baseURL}/c`, { timeout: 20_000 })
}

async function loginMaster(page: Page) {
  await page.goto(`${baseURL}/m/login`, { waitUntil: 'networkidle' })
  if (!liveAuth) {
    await expect(page.getByPlaceholder('请输入法师账号')).toBeVisible()
    await expect(page.getByPlaceholder('请输入密码')).toBeVisible()
    await mockH5Api(page)
    await seedH5Session(page, 'master')
    return
  }
  await page.getByPlaceholder('请输入法师账号').fill(requiredLiveCredential('E2E_MASTER_ACCOUNT'))
  await page.getByPlaceholder('请输入密码').fill(requiredLiveCredential('E2E_MASTER_PASSWORD'))
  await page.getByRole('button', { name: '登 录' }).click()
  await page.waitForURL(`${baseURL}/m`, { timeout: 20_000 })
}

test.describe('双端 H5 响应式回归', () => {
  test('信众端核心路由无页面级横向溢出', async ({ page }, testInfo) => {
    const consoleErrors = collectConsoleErrors(page)
    await loginCustomer(page)
    for (const route of customerRoutes) {
      await page.goto(`${baseURL}${route}`, { waitUntil: 'domcontentloaded' })
      await expect(page.locator('.h5-app')).toBeVisible()
      await page.waitForTimeout(250)
      await expectNoPageOverflow(page)
      await expectBottomActionClearance(page)
      if (testInfo.project.name === 'h5-390') await expectTapTargets(page, 'customer')
      const safeRoute = route.replace(/^\//, '').replace(/[/:]/g, '_') || 'root'
      mkdirSync(`artifacts/web/h5-customer/${testInfo.project.name}`, { recursive: true })
      await page.screenshot({
        path: `artifacts/web/h5-customer/${testInfo.project.name}/${safeRoute}.png`,
        fullPage: true
      })
    }
    expect(consoleErrors.filter((message) => !isBenignConsoleError(message))).toEqual([])
  })

  test('法师端核心路由无页面级横向溢出', async ({ page }, testInfo) => {
    const consoleErrors = collectConsoleErrors(page)
    await loginMaster(page)
    for (const route of masterRoutes) {
      await page.goto(`${baseURL}${route}`, { waitUntil: 'domcontentloaded' })
      await expect(page.locator('.h5-app')).toBeVisible()
      await page.waitForTimeout(250)
      await expectNoPageOverflow(page)
      await expectBottomActionClearance(page)
      if (testInfo.project.name === 'h5-390') await expectTapTargets(page, 'master')
      const safeRoute = route.replace(/^\//, '').replace(/[/:]/g, '_') || 'root'
      mkdirSync(`artifacts/web/h5-master/${testInfo.project.name}`, { recursive: true })
      await page.screenshot({
        path: `artifacts/web/h5-master/${testInfo.project.name}/${safeRoute}.png`,
        fullPage: true
      })
    }
    expect(consoleErrors.filter((message) => !isBenignConsoleError(message))).toEqual([])
  })

  test('信众端关键详情使用完整契约数据渲染', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'h5-390', '关键内容断言仅在主验收视口执行')
    await loginCustomer(page)
    const cases = [
      ['/c/temples/1', '云栖禅寺'],
      ['/c/masters/1', '慧明法师'],
      ['/c/shop/1', '天然菩提手串'],
      ['/c/shop/orders/1', 'SO202609040001'],
      ['/c/bookings/1', '祈愿家人平安'],
      ['/c/diy/1', '秋山静心'],
      ['/c/community/1', '一念清净，处处莲花'],
      ['/c/live/1', '晚课共修']
    ] as const
    for (const [route, text] of cases) {
      await page.goto(`${baseURL}${route}`, { waitUntil: 'domcontentloaded' })
      await expect(page.getByText(text, { exact: false }).first()).toBeVisible()
      await expectNoPageOverflow(page)
    }
  })

  test('法师端预约与加持详情使用完整契约数据渲染', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'h5-390', '关键内容断言仅在主验收视口执行')
    await loginMaster(page)
    await page.goto(`${baseURL}/m/bookings/1`, { waitUntil: 'domcontentloaded' })
    await expect(page.getByText('祈愿家人平安')).toBeVisible()
    await expectNoPageOverflow(page)
    await page.goto(`${baseURL}/m/blessings/1`, { waitUntil: 'domcontentloaded' })
    await expect(page.getByText('BT202609040001')).toBeVisible()
    await expectNoPageOverflow(page)
  })

  test('P0 预约、DIY 与双端聊天使用可操作契约数据渲染', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'h5-390', '关键流程断言仅在主验收视口执行')

    await loginCustomer(page)
    await page.goto(`${baseURL}/c/temples/1/booking`, { waitUntil: 'domcontentloaded' })
    await expect(page.getByText('祈福供灯', { exact: true }).first()).toBeVisible()
    await expect(page.getByText('缺少预约参数')).toHaveCount(0)
    await expectBottomActionClearance(page)

    await page.goto(`${baseURL}/c/diy/editor`, { waitUntil: 'domcontentloaded' })
    await expect(page.getByText('菩提子', { exact: true }).first()).toBeVisible()
    await expectBottomActionClearance(page)

    await page.goto(`${baseURL}/c/chats/C001`, { waitUntil: 'domcontentloaded' })
    await expect(page.getByText('愿家人平安顺遂。', { exact: true })).toBeVisible()
    await expect(page.getByText('已收到您的祈愿。', { exact: true })).toBeVisible()

    await loginMaster(page)
    await page.goto(`${baseURL}/m/chats/C002`, { waitUntil: 'domcontentloaded' })
    await expect(page.getByText('请问如何静心？', { exact: true })).toBeVisible()
    await expect(page.getByText('先从观呼吸开始。', { exact: true })).toBeVisible()
    await expectNoPageOverflow(page)
  })

  test('320px 金额状态时间和业务编号保留完整语义', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'h5-320', '窄屏语义完整性只在 320px 验收视口执行')

    await loginCustomer(page)
    await page.goto(`${baseURL}/c/shop/orders/1`, { waitUntil: 'domcontentloaded' })
    for (const value of ['SO202609040001', '已发货', '¥199.00', '2026-09-03 12:00', 'SF1234567890']) {
      await expectTextUnclipped(page, value)
    }

    await page.goto(`${baseURL}/c/bookings/1`, { waitUntil: 'domcontentloaded' })
    for (const value of ['PAY202609040001', '已完成', '¥256', '2026-09-03 09:30:00']) {
      await expectTextUnclipped(page, value)
    }

    await loginMaster(page)
    await page.goto(`${baseURL}/m/bookings/1`, { waitUntil: 'domcontentloaded' })
    for (const value of ['单号：1', '2026-09-03 09:30:00', '09:00-10:00', '¥256.00']) {
      await expectTextUnclipped(page, value)
    }

    await page.goto(`${baseURL}/m/blessings/1`, { waitUntil: 'domcontentloaded' })
    for (const value of ['BT202609040001', 'DIYORDER001', '待接单', '2026-09-04 08:30']) {
      await expectTextUnclipped(page, value)
    }
  })

  test('空数据筛选无结果接口失败和能力关闭可区分并可恢复', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'h5-390', '数据状态语义只在主验收视口执行')
    await loginCustomer(page)

    let templeMode: 'empty' | 'populated' | 'error' = 'empty'
    await page.route('**/api/v1/**', async (route) => {
      const path = new URL(route.request().url()).pathname
      if (path === '/api/v1/service-types') {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ code: 0, message: 'UI regression fixture', data: { list: [{ code: 'S999', name: '测试服务' }] } })
        })
        return
      }
      if (path !== '/api/v1/temples') {
        await route.fallback()
        return
      }
      if (templeMode === 'error') {
        await route.fulfill({
          status: 503,
          contentType: 'application/json',
          body: JSON.stringify({ code: 50301, message: '寺院服务暂不可用' })
        })
        return
      }
      const list = templeMode === 'populated' ? [{
        id: 'state-1', name: '状态测试寺院', region: '浙江杭州', type: '佛教', beliefCode: 'buddhism', sect: '禅宗',
        status: 'enabled', address: '测试地址', coverImage: '', rating: 4.8, description: '状态测试数据', serviceCodes: []
      }] : []
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ code: 0, message: 'UI regression fixture', data: { list, total: list.length } })
      })
    })

    await page.goto(`${baseURL}/c/temples`, { waitUntil: 'domcontentloaded' })
    await expect(page.getByText('暂无已入驻寺院')).toBeVisible()
    await expect(page.getByRole('button', { name: '返回首页' })).toBeVisible()

    templeMode = 'populated'
    await page.reload({ waitUntil: 'domcontentloaded' })
    await expect(page.getByText('状态测试寺院').first()).toBeVisible()
    await page.getByRole('button', { name: '测试服务' }).click()
    await expect(page.getByText('当前筛选无结果')).toBeVisible()
    await expect(page.getByRole('button', { name: '清除筛选' })).toBeVisible()

    templeMode = 'error'
    await page.reload({ waitUntil: 'domcontentloaded' })
    await expect(page.getByText('寺院列表加载失败')).toBeVisible()
    await expect(page.locator('.empty p')).toBeVisible()
    await expect(page.getByRole('button', { name: '重试' })).toBeVisible()

    await page.goto(`${baseURL}/c/live/1`, { waitUntil: 'domcontentloaded' })
    await expect(page.getByText('直播能力当前不可用')).toBeVisible()
    await expect(page.getByRole('button', { name: '返回大师广场' })).toBeVisible()

    await loginMaster(page)
    await page.goto(`${baseURL}/m/content`, { waitUntil: 'domcontentloaded' })
    await expect(page.getByText('直播能力未开放', { exact: false })).toBeVisible()
    await expect(page.getByRole('button', { name: '返回工作台' })).toBeVisible()
  })

  test('OpenIM 仅在有效凭证后按 Go WASM 再 SDK 的顺序加载', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'h5-390', 'OpenIM 懒加载顺序只在主验收视口执行')
    await loginCustomer(page)

    let imToken = ''
    const runtimeRequests: string[] = []
    page.on('request', (request) => {
      const pathname = new URL(request.url()).pathname
      if (
        pathname.includes('/node_modules/@openim/wasm-client-sdk/assets/wasm_exec.js') ||
        pathname.includes('/node_modules/.vite/deps/@openim_wasm-client-sdk') ||
        pathname.endsWith('/openIM.wasm') ||
        pathname.endsWith('/sql-wasm.wasm')
      ) runtimeRequests.push(pathname)
    })
    await page.route('**/api/v1/auth/im-token', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ code: 0, message: 'UI regression fixture', data: { imToken } })
      })
    })

    await page.goto(`${baseURL}/c/chats/C001`, { waitUntil: 'domcontentloaded' })
    await expect(page.getByText('即时通讯服务未返回有效凭证', { exact: false })).toBeVisible()
    await page.waitForTimeout(200)
    expect(runtimeRequests, '无有效凭证时不得请求 OpenIM 运行时或 SDK').toEqual([])

    imToken = 'ui-regression-openim-token'
    runtimeRequests.length = 0
    await page.reload({ waitUntil: 'domcontentloaded' })
    await expect.poll(() => runtimeRequests.length, { timeout: 10_000 }).toBeGreaterThanOrEqual(2)
    const goRuntimeIndex = runtimeRequests.findIndex((path) => path.includes('wasm_exec.js'))
    const sdkIndex = runtimeRequests.findIndex((path) => path.includes('@openim_wasm-client-sdk'))
    expect(goRuntimeIndex, `未加载 Go/WASM 运行时: ${JSON.stringify(runtimeRequests)}`).toBeGreaterThanOrEqual(0)
    expect(sdkIndex, `未加载 OpenIM SDK: ${JSON.stringify(runtimeRequests)}`).toBeGreaterThan(goRuntimeIndex)
    await expect(page.getByText('Go is not defined', { exact: false })).toHaveCount(0)
  })
})
