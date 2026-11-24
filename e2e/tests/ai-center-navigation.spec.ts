import { test, expect, type Page } from '@playwright/test'
import { seedPlatformAdmin, fulfillPlatformAdminAccess } from '../fixtures/platform-admin-access'
async function setup(page: Page, role = 'platform_super', { tested = true, runtimeMode = 'harness', draftModel = 'test-chat' } = {}) {
  const identity = await seedPlatformAdmin(page, role, '导航验收')
  const calls: string[] = []
  await page.route('**/api/v1/**', async route => {
    if (await fulfillPlatformAdminAccess(route, identity)) return
    const path = new URL(route.request().url()).pathname; calls.push(path)
    let data: any = { list: [], total: 0 }
    if (path.endsWith('/ai/admin/agent')) data = { runtimeMode, revision: 1, draftSaved: true, activeVersion: 1, draft: { name: '问事助手', instruction: '测试职责', model: draftModel, maxOutputTokens: 8192, skills: [{ code: 'general', enabled: true, prompt: '', useTool: false }], evaluation: [] }, catalog: [{ code: 'general', name: '日常问事', description: '测试', version: '1', inputSchema: { fields: [] }, toolName: '', toolAvailable: false }], versions: [], audit: [], tested, liveEnabled: true, persistentRecovery: true, rollout: { versionId: 1, stableVersion: 1, percentage: 100, revision: 1 } }
    if (path.endsWith('/ai/admin/model-library')) data = { list: [{ id: 'test-chat', name: '问事测试模型', model: 'fixture-chat', provider: 'openai_compatible', kind: 'language', source: 'registered', bindings: { chat: 'test-chat' } }], uses: {chat:'',vision:'',embedding:'',rerank:'',document:''}, revision:1, writable:true, defaultChat:'deepseek-flash', warnings:[] }
    if (path.endsWith('/ai/admin/provider')) data = { provider: 'deepseek', baseUrl: 'https://api.deepseek.com', defaultModel: 'deepseek-flash', visionModel: '', enabledModels: [], thinkingEnabled: true, maxOutputTokens: 8192, revision: 1, hasApiKey: true, writable: true, source: 'platform', history: [] }
    if (path.endsWith('/ai/admin/products')) data = []
    await route.fulfill({ json: { code: 0, data } })
  })
  return calls
}
test('development routes retain the shared draft and guard exits', async ({ page }) => {
  await setup(page); await page.goto('/ai/operations')
  await expect(page).toHaveURL(/\/ai\/agent$/)
  await expect(page.getByRole('menuitem', { name: 'AI 开发中心', exact: true })).toHaveCount(1)
  await page.getByLabel('智能体名称', { exact: true }).fill('保留的草稿')
  const config = page.getByRole('navigation', { name: '配置', exact: true })
  await config.getByRole('link', { name: '技能与工具', exact: true }).click()
  await expect(page).toHaveURL(/\/ai\/tools$/)
  await config.getByRole('link', { name: '知识与上下文', exact: true }).click()
  await expect(page.getByRole('heading', { name: '知识与上下文', exact: true })).toBeVisible()
  await page.getByText('高级检索设置', { exact: true }).click()
  await expect(page.getByText('候选片段数量', { exact: true })).toBeVisible()
  await page.goBack()
  await page.goBack()
  await expect(page.getByLabel('智能体名称', { exact: true })).toHaveValue('保留的草稿')
  const models = page.getByRole('navigation', { name: '共享资源' }).getByRole('link', { name: '模型与连接' })
  const configurationStage = page.getByRole('navigation', { name: '开发流程' }).getByRole('link', { name: '配置', exact: true })
  await models.click()
  await expect(page).toHaveURL(/\/ai\/connections\/models$/)
  await configurationStage.click()
  await expect(page.getByLabel('智能体名称', { exact: true })).toHaveValue('保留的草稿')
  await models.click()
  await page.getByText('运营中心', { exact: true }).click()
  const reportPricing = page.getByRole('menuitem', { name: '报告定价', exact: true })
  await reportPricing.click()
  const dialog = page.getByRole('dialog', { name: '离开智能体管理' })
  await expect(dialog).toBeVisible()
  await page.getByRole('button', { name: '继续编辑', exact: true }).click()
  await expect(page).toHaveURL(/\/ai\/connections\/models$/)
  await reportPricing.click()
  await page.getByRole('button', { name: '离开', exact: true }).click()
  await expect(page).toHaveURL(/\/ai\/report-pricing$/)
  await expect(page.getByRole('navigation', { name: '开发流程' })).toHaveCount(0)
})
test('single-agent release shows the saved model and engine and links to a missing evaluation', async ({ page }) => {
  await setup(page, 'platform_super', { tested: false })
  await page.goto('/ai/releases')
  const agent = page.getByRole('region', { name: '问事智能体', exact: true })
  await expect(agent).toHaveCount(1)
  await expect(agent.getByRole('heading', { name: '发布问事智能体' })).toBeVisible()
  await expect(agent.getByRole('region', { name: '智能体状态' })).toContainText('Eino Harness')
  await expect(agent.getByText('问事测试模型 · fixture-chat', { exact: true })).toBeVisible()
  await expect(page.getByRole('button', { name: '发布当前草稿' })).toBeDisabled()
  const blocker = page.getByRole('status').filter({ hasText: '当前草稿尚未通过质量评测' })
  await blocker.getByRole('link', { name: '去评测' }).click()
  await expect(page.getByRole('heading', { name: '质量评测', exact: true })).toBeVisible()
  await expect(page.getByRole('button', { name: '添加用例' })).toBeVisible()
})
test('mobile can reach all development stages and shared resources', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await setup(page)
  await page.goto('/ai/report-pricing')
  await page.getByRole('button', { name: '打开主导航' }).click()
  await page.getByRole('menuitem', { name: 'AI 开发中心', exact: true }).click()
  await expect(page.getByRole('heading', { name: '职责与模型', exact: true })).toBeVisible()
  await expect(page.getByText('问事智能体', { exact: true })).toBeInViewport()
  const stages = page.getByRole('navigation', { name: '开发流程' })
  const stagesBounds = await stages.boundingBox()
  expect(stagesBounds).not.toBeNull()
  if (stagesBounds) {
    expect(stagesBounds.width).toBeGreaterThan(320)
    expect(stagesBounds.x + stagesBounds.width).toBeLessThanOrEqual(390)
  }
  for (const label of ['配置', '调试与评测', '发布', '运行']) {
    await expect(stages.getByRole('link', { name: label, exact: true })).toBeInViewport()
  }
  const resources = page.getByRole('navigation', { name: '共享资源' })
  await expect(resources.getByRole('link', { name: '知识中心' })).toBeInViewport()
  await expect(resources.getByRole('link', { name: '模型与连接' })).toBeInViewport()
  await stages.getByRole('link', { name: '发布', exact: true }).click()
  await expect(page.getByRole('button', { name: '发布当前草稿' })).toBeEnabled()
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBe(390)
  await page.getByRole('combobox', { name: '语言', exact: true }).selectOption('zh-Hant')
  await expect(page.getByRole('navigation', { name: '開發流程' })).toBeVisible()
})
test('model library redirects bookmarks and supports connection navigation', async ({ page }) => {
  await setup(page); await page.goto('/settings/ai?from=bookmark')
  await expect(page).toHaveURL(/\/ai\/connections\/models\?from=bookmark$/)
  await page.getByRole('button', {name:'添加模型',exact:true}).click()
  await page.getByLabel('模型显示名称', {exact:true}).fill('尚未保存')
  await page.getByRole('button', {name:'取消',exact:true}).click()
  await page.getByRole('link', {name:'联网搜索',exact:true}).click()
  await expect(page.getByRole('heading', {name:'联网搜索',exact:true})).toBeVisible()
  await page.getByRole('link', {name:'模型库',exact:true}).click()
  await expect(page.getByRole('heading', {name:'模型库',exact:true})).toBeVisible()
  await page.goto('/ai/connections/knowledge')
  await expect(page).toHaveURL(/\/ai\/connections\/models$/)
})
test('leaving the original connection for the library guards unsaved keys', async ({page}) => {
  await setup(page); await page.goto('/ai/connections/legacy')
  await page.getByLabel('API Key', {exact:true}).fill('fixture-unsaved')
  await page.getByRole('link', {name:'模型库',exact:true}).click()
  await expect(page.getByRole('dialog', {name:'离开设置页面'})).toBeVisible()
  await page.getByRole('button', {name:'继续编辑',exact:true}).click()
  await expect(page.getByLabel('API Key', {exact:true})).toHaveValue('fixture-unsaved')
})
for (const [path, title] of [['agent','职责与模型'],['tools','技能与工具'],['context','知识与上下文'],['debug','单次调试'],['evaluations','质量评测'],['releases','版本与发布'],['runs','运行监控'],['knowledge','知识中心']] ) {
  test(`direct entry and reload: ${path}`, async ({ page }) => {
    const fixture = path === 'debug' ? { runtimeMode: 'classic' } : path === 'releases' ? { draftModel: '' } : {}
    const calls = await setup(page, 'platform_super', fixture); await page.goto('/ai/' + path)
    await expect(page.getByRole('heading', { name: title, exact: true })).toBeVisible()
    await page.reload(); await expect(page.getByRole('heading', { name: title, exact: true })).toBeVisible()
    if (path === 'runs') expect(calls.some(p => p.endsWith('/agent/runs'))).toBeTruthy()
    if (path === 'debug') await expect(page.getByRole('region', { name: '智能体状态' })).toContainText('原问事流程')
    if (path === 'releases') await expect(page.getByText('平台聊天默认模型', { exact: true })).toBeVisible()
    if (path === 'agent') {
      await page.getByRole('link', { name: '进入单次调试', exact: true }).click()
      await expect(page).toHaveURL(/\/ai\/debug$/)
    }
    if (path === 'evaluations') {
      expect(calls.some(p => p.endsWith('/agent/evaluations'))).toBeTruthy()
      await page.getByRole('link', { name: '前往发布', exact: true }).click()
      await expect(page.getByRole('button', { name: '发布当前草稿' })).toBeEnabled()
    }
  })
}
for (const role of ['shop_admin','platform_service']) test(`${role} cannot access any development workspace`, async ({ page }) => {
  const calls = await setup(page, role)
  for (const path of ['agent','tools','context','debug','evaluations','releases','runs','report-pricing','knowledge','connections/models','connections/search','connections/knowledge']) {
    await page.goto('/ai/' + path); await expect(page).not.toHaveURL(/\/ai\//)
  }
  expect(calls.filter(p => p.includes('/ai/admin/'))).toHaveLength(0)
})
