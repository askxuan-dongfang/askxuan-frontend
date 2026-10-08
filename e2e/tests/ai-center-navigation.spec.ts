import { test, expect, type Page } from '@playwright/test'
async function setup(page: Page, role = 'platform_super') {
  await page.addInitScript(role => {
    localStorage.setItem('df_platform_admin_token', 'e30.' + btoa(JSON.stringify({ userId: 1, roles: [role], clientId: 'platform-admin', exp: 4000000000 })) + '.fixture')
    localStorage.setItem('df_platform_admin_user', JSON.stringify({ userId: 1, nickname: '导航验收' }))
  }, role)
  const calls: string[] = []
  await page.route('**/api/v1/**', async route => {
    const path = new URL(route.request().url()).pathname; calls.push(path)
    let data: any = { list: [], total: 0 }
    if (path.endsWith('/ai/admin/agent')) data = { runtimeMode: 'harness', revision: 1, draftSaved: true, activeVersion: 1, draft: { name: '问事助手', instruction: '测试职责', model: '', maxOutputTokens: 8192, skills: [{ code: 'general', enabled: true, prompt: '', useTool: false }], evaluation: [] }, catalog: [{ code: 'general', name: '日常问事', description: '测试', version: '1', inputSchema: { fields: [] }, toolName: '', toolAvailable: false }], versions: [], audit: [], tested: true, liveEnabled: true, persistentRecovery: true, rollout: { versionId: 1, stableVersion: 1, percentage: 100, revision: 1 } }
    if (path.endsWith('/ai/admin/provider')) data = { provider: 'deepseek', baseUrl: 'https://api.deepseek.com', defaultModel: 'deepseek-flash', visionModel: '', enabledModels: [], thinkingEnabled: true, maxOutputTokens: 8192, revision: 1, hasApiKey: true, writable: true, source: 'platform', history: [] }
    await route.fulfill({ json: { code: 0, data } })
  })
  return calls
}
test('development routes retain the shared draft and guard exits', async ({ page }) => {
  await setup(page); await page.goto('/ai/operations')
  await expect(page).toHaveURL(/\/ai\/agent$/)
  await page.getByLabel('智能体名称', { exact: true }).fill('保留的草稿')
  await page.getByRole('menuitem', { name: '技能与工具', exact: true }).click()
  await expect(page).toHaveURL(/\/ai\/tools$/)
  await page.goBack()
  await expect(page.getByLabel('智能体名称', { exact: true })).toHaveValue('保留的草稿')
  await page.getByRole('menuitem', { name: '模型与连接', exact: true }).click()
  await expect(page.getByRole('dialog', { name: '离开智能体管理' })).toBeVisible()
  await page.getByRole('button', { name: '继续编辑', exact: true }).click()
  await expect(page).toHaveURL(/\/ai\/agent$/)
  await page.getByRole('menuitem', { name: '模型与连接', exact: true }).click()
  await page.getByRole('button', { name: '离开', exact: true }).click()
  await expect(page).toHaveURL(/\/ai\/connections\/models$/)
})
test('connection tabs preserve the draft and guard leaving connections', async ({ page }) => {
  await setup(page); await page.goto('/settings/ai?from=bookmark')
  await expect(page).toHaveURL(/\/ai\/connections\/models\?from=bookmark$/)
  await page.getByLabel('API Key', { exact: true }).fill('fixture-unsaved')
  await page.getByRole('link', { name: '联网搜索', exact: true }).click()
  await expect(page.getByRole('heading', { name: '联网搜索', exact: true })).toBeVisible()
  await expect(page.getByRole('heading', { name: '连接大模型', exact: true })).toBeHidden()
  await page.getByRole('link', { name: '大模型', exact: true }).click()
  await expect(page.getByLabel('API Key', { exact: true })).toHaveValue('fixture-unsaved')
  await page.getByRole('link', { name: '知识模型', exact: true }).click()
  await expect(page.getByRole('dialog', { name: '离开设置页面' })).toBeVisible()
  await page.getByRole('button', { name: '继续编辑', exact: true }).click()
  await expect(page.getByLabel('API Key', { exact: true })).toHaveValue('fixture-unsaved')
})
for (const [path, title] of [['agent','智能体编排'],['tools','技能与工具'],['debug','调试工作台'],['evaluations','质量评测'],['releases','版本与发布'],['runs','运行监控'],['knowledge','知识中心']] ) {
  test(`direct entry and reload: ${path}`, async ({ page }) => {
    const calls = await setup(page); await page.goto('/ai/' + path)
    await expect(page.getByRole('heading', { name: title, exact: true })).toBeVisible()
    await page.reload(); await expect(page.getByRole('heading', { name: title, exact: true })).toBeVisible()
    if (path === 'runs') expect(calls.some(p => p.endsWith('/agent/runs'))).toBeTruthy()
    if (path === 'evaluations') expect(calls.some(p => p.endsWith('/agent/evaluations'))).toBeTruthy()
  })
}
for (const role of ['shop_admin','platform_service']) test(`${role} cannot access any development workspace`, async ({ page }) => {
  const calls = await setup(page, role)
  for (const path of ['agent','tools','debug','evaluations','releases','runs','knowledge','connections/models','connections/search','connections/knowledge']) {
    await page.goto('/ai/' + path); await expect(page).not.toHaveURL(/\/ai\//)
  }
  expect(calls.filter(p => p.includes('/ai/admin/'))).toHaveLength(0)
})
