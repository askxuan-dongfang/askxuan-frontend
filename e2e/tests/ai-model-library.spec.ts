import { test, expect, type Page } from '@playwright/test'
import type { LibraryModel, ModelSupplier } from '../../apps/web-platform-admin/src/api/modelLibrary'
import { seedPlatformAdmin, fulfillPlatformAdminAccess } from '../fixtures/platform-admin-access'

async function setup(page: Page, customerModelIds?: string[], suppliers?: ModelSupplier[]) {
  const identity = await seedPlatformAdmin(page, 'platform_super', '模型库验收')
  const list: Partial<LibraryModel>[] = [
    {id:'ark-code-latest',name:'方舟套餐',model:'ark-code-latest',kind:'language',source:'legacy',provider:'volcengine',baseUrl:'https://ark.cn-beijing.volces.com/api/plan/v3',bindings:{chat:'ark-code-latest',document:'chat:ark-code-latest'}},
    {id:'embed',name:'向量模型',model:'bge-small',kind:'Embedding',source:'builtin',dimension:512,bindings:{embedding:'embed'}},
    {id:'rank',name:'重排模型',model:'bge-reranker',kind:'Rerank',source:'builtin',bindings:{rerank:'rank'}},
  ]
  if (customerModelIds !== undefined) list.push(
    {id:'vision',name:'图片模型',model:'vision',kind:'language',source:'registered',provider:'openai_compatible',baseUrl:'https://example.test',bindings:{chat:'vision',vision:'vision'}},
    {id:'go',name:'OpenCode Go 文本模型',model:'kimi',kind:'language',source:'registered',provider:'opencode_go',baseUrl:'https://opencode.ai/inference/go/openai/v1',bindings:{chat:'go',catalogTranslation:'go'}},
  )
  if (suppliers) list.push({
    id: 'deepseek-flash', name: 'DeepSeek Flash', model: 'deepseek-flash', kind: 'language', source: 'legacy',
    provider: 'deepseek', baseUrl: 'https://api.deepseek.com', bindings: { chat: 'deepseek-flash', vision: 'deepseek-flash' },
  })
  let uses = {chat:'',vision:'',embedding:'embed',rerank:'rank',document:''}, revision = 3
  const calls: {path:string;method:string;body:any}[] = []
  await page.route('**/api/v1/**', async route => {
    if (await fulfillPlatformAdminAccess(route, identity)) return
    const req=route.request(), path=new URL(req.url()).pathname, body=req.postData()?req.postDataJSON():null
    calls.push({path,method:req.method(),body})
    let data:any={list:[],total:0}
    if(path.endsWith('/model-library'))data={list,uses,customerModelIds,suppliers,revision,writable:true,defaultChat:'ark-code-latest',warnings:[]}
    else if(path.endsWith('/model-library/uses')){uses=body.uses;customerModelIds=body.customerModelIds;revision++}
    else if(path.endsWith('/model-library/language')){list.push({id:'registered',name:body.name,model:body.model,kind:'language',source:'registered',provider:body.provider,baseUrl:body.baseUrl,bindings:{chat:'registered',document:'chat:registered'}});revision++}
    else if (path.endsWith('/model-library/language/import') && suppliers) {
      const provider = body.provider as ModelSupplier
      const syncing = suppliers.includes(provider)
      const fresh: Partial<LibraryModel>[] = []
      if (!syncing) {
        suppliers.push(provider)
        const id = provider + '-pro'
        fresh.push({ id, name: 'DeepSeek Pro', model: 'deepseek-v4-pro', kind: 'language', source: 'registered', provider, bindings: { chat: id } })
        if (provider === 'opencode_go') fresh.push({
          id: 'go-vision', name: 'Go Vision', model: 'go-vision', kind: 'language', source: 'registered', provider, bindings: { chat: 'go-vision', vision: 'go-vision' },
        })
      } else {
        fresh.push({ id: 'go-new', name: 'Go New Model', model: 'go-new', kind: 'language', source: 'registered', provider, bindings: { chat: 'go-new' } })
      }
      list.push(...fresh)
      data = { added: fresh.length, existing: syncing ? 2 : provider === 'deepseek' ? 1 : 0 }
      revision++
    }
    await route.fulfill({json:{code:0,data}})
  })
  return calls
}
async function openSelect(page: Page, label: string) {
  const select = page.locator(`.el-select:has(input[aria-label="${label}"])`)
  await select.locator('.el-select__wrapper').click()
  const controls = await select.locator(`input[aria-label="${label}"]`).getAttribute('aria-controls')
  return page.locator(`[id="${controls}"]`)
}

test('imports both suppliers and syncs new models with the saved credential', async ({ page }) => {
  const calls = await setup(page, [], [])
  await page.goto('/ai/connections/models')
  const open = page.getByRole('button', { name: '导入供应商模型', exact: true })
  const dialog = page.getByRole('dialog', { name: '导入供应商模型', exact: true })

  await open.click()
  await dialog.getByLabel('供应商 API Key', { exact: true }).fill('fixture-go-key')
  await dialog.getByRole('button', { name: '导入全部可用模型', exact: true }).click()
  await expect(page.locator('.el-table__body')).toContainText('Go Vision')
  await expect(dialog).toBeHidden()

  await open.click()
  await expect(dialog.getByLabel('供应商 API Key', { exact: true })).toHaveCount(0)
  await dialog.getByRole('button', { name: '同步新增模型', exact: true }).click()
  await expect(page.locator('.el-table__body')).toContainText('Go New Model')
  await expect(dialog).toBeHidden()

  await open.click()
  const supplier = await openSelect(page, '供应商')
  await supplier.getByRole('option', { name: 'DeepSeek', exact: true }).click()
  const saved = await openSelect(page, '供应商已有连接')
  await saved.getByRole('option', { name: 'DeepSeek Flash', exact: true }).click()
  await expect(dialog.getByLabel('供应商 API Key', { exact: true })).toHaveCount(0)
  await dialog.getByRole('button', { name: '导入全部可用模型', exact: true }).click()
  await expect(dialog).toBeHidden()

  const requests = calls.filter(call => call.path.endsWith('/language/import')).map(call => call.body)
  expect(requests).toEqual([
    { provider: 'opencode_go', revision: 3, apiKey: 'fixture-go-key' },
    { provider: 'opencode_go', revision: 4 },
    { provider: 'deepseek', revision: 5, reuseConnection: 'deepseek-flash' },
  ])
  await page.getByRole('tab', { name: '默认用途', exact: true }).click()
  const chat = await openSelect(page, '聊天默认模型')
  await expect(chat.getByRole('option', { name: 'DeepSeek Pro · deepseek-v4-pro · OpenCode Go', exact: true })).toBeVisible()
  await expect(chat.getByRole('option', { name: 'DeepSeek Pro · deepseek-v4-pro · DeepSeek', exact: true })).toBeVisible()
})

test('catalog filters by capability and saves role-specific model identities',async({page})=>{
  const calls=await setup(page);await page.goto('/ai/connections/models')
  await expect(page.locator('.el-table__body')).toContainText('方舟套餐')
  await openSelect(page,'筛选模型用途');await page.getByRole('option',{name:'建索引 · Embedding',exact:true}).click()
  await expect(page.locator('.el-table__body')).toContainText('向量模型')
  await expect(page.locator('.el-table__body')).not.toContainText('方舟套餐')
  await page.getByRole('tab',{name:'默认用途',exact:true}).click()
  await openSelect(page,'建索引 · Embedding默认模型')
  await expect(page.getByRole('option',{name:'向量模型 · bge-small',exact:true})).toBeVisible()
  await expect(page.getByRole('option',{name:'方舟套餐 · ark-code-latest',exact:true})).toBeHidden()
  await page.keyboard.press('Escape')
  await openSelect(page,'文档理解默认模型');await page.getByRole('option',{name:'方舟套餐 · ark-code-latest',exact:true}).click()
  await page.getByRole('button',{name:'保存默认选择',exact:true}).click()
  await expect.poll(()=>calls.some(c=>c.path.endsWith('/model-library/uses'))).toBeTruthy()
  const saved=calls.find(c=>c.path.endsWith('/model-library/uses'))!.body
  expect(saved).toMatchObject({revision:3,uses:{document:'chat:ark-code-latest',embedding:'embed',rerank:'rank'}})
  expect(saved).not.toHaveProperty('customerModelIds')
})

test('customer options and role defaults are saved together and can be cleared', async ({ page }) => {
  const calls = await setup(page, [])
  await page.goto('/ai/connections/models')
  await page.getByRole('tab', { name: '默认用途', exact: true }).click()
  const chat = await openSelect(page, '聊天默认模型')
  await chat.getByRole('option', { name: 'OpenCode Go 文本模型 · kimi', exact: true }).click()
  const translation = await openSelect(page, '目录翻译默认模型')
  await translation.getByRole('option', { name: 'OpenCode Go 文本模型 · kimi', exact: true }).click()
  const vision = await openSelect(page, '图片理解默认模型')
  await expect(vision.getByRole('option', { name: 'OpenCode Go 文本模型 · kimi', exact: true })).toHaveCount(0)
  await vision.getByRole('option', { name: '图片模型 · vision', exact: true }).click()
  const listbox = await openSelect(page, '信众可选模型')
  const imageOption = listbox.getByRole('option', { name: '图片模型 · vision', exact: true })
  await expect(listbox.getByRole('option')).toHaveCount(3)
  await imageOption.click()
  await page.keyboard.press('Escape')
  const save = page.getByRole('button', { name: '保存用途配置', exact: true })
  await save.click()
  await expect(save).toBeDisabled()
  const requests = () => calls.filter(call => call.path.endsWith('/model-library/uses')).map(call => call.body)
  expect(requests()).toMatchObject([{ revision: 3, uses: { chat: 'go', vision: 'vision', catalogTranslation: 'go' }, customerModelIds: ['vision'] }])
  await openSelect(page, '信众可选模型')
  await imageOption.click()
  await page.keyboard.press('Escape')
  await save.click()
  await expect(save).toBeDisabled()
  expect(requests()[1]).toMatchObject({ revision: 4, uses: { vision: 'vision' }, customerModelIds: [] })
})

test('adding another model reuses the saved connection without a browser key',async({page})=>{
  const calls=await setup(page);await page.goto('/ai/connections/models')
  await page.getByRole('button',{name:'添加模型',exact:true}).click()
  await page.getByLabel('模型显示名称',{exact:true}).fill('另一个方舟模型')
  await page.getByLabel('服务商模型 ID',{exact:true}).fill('kimi-latest')
  await openSelect(page,'复用连接');await page.getByRole('option',{name:'方舟套餐 · volcengine',exact:true}).click()
  await expect(page.getByLabel('模型 API Key',{exact:true})).toHaveCount(0)
  await expect(page.getByLabel('模型接口地址',{exact:true})).toHaveValue('https://ark.cn-beijing.volces.com/api/plan/v3')
  await page.getByRole('dialog',{name:'添加模型'}).getByRole('button',{name:'添加模型',exact:true}).click()
  await expect(page.locator('.el-table__body')).toContainText('另一个方舟模型')
  const saved=calls.find(c=>c.path.endsWith('/model-library/language'))!.body
  expect(saved).toMatchObject({model:'kimi-latest',reuseConnection:'ark-code-latest',apiKey:'',revision:3})
  expect(calls.some(c=>c.method==='PUT'&&c.path.endsWith('/provider'))).toBeFalsy()
})

test('new knowledge base selects index and document models from the same library',async({page})=>{
  const calls=await setup(page);await page.goto('/ai/knowledge')
  await page.getByRole('button',{name:'新建知识库',exact:true}).click()
  await openSelect(page,'建索引模型');await expect(page.getByRole('option',{name:'向量模型 · bge-small',exact:true})).toBeVisible();await page.keyboard.press('Escape')
  await openSelect(page,'文档理解模型');await page.getByRole('option',{name:'方舟套餐 · ark-code-latest',exact:true}).click()
  const dialog=page.getByRole('dialog',{name:'新建知识库'})
  await dialog.getByLabel('名称',{exact:true}).fill('统一模型验收')
  await dialog.getByRole('button',{name:'保存',exact:true}).click()
  await expect.poll(()=>calls.some(c=>c.method==='POST'&&c.path.endsWith('/knowledge-bases'))).toBeTruthy()
  const body=calls.find(c=>c.method==='POST'&&c.path.endsWith('/knowledge-bases'))!.body
  expect(body).toMatchObject({embeddingModel:'embed',summaryModel:'chat:ark-code-latest'})
})
