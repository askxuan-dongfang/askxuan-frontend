import { test, expect, type Page } from '@playwright/test'
import type { LibraryModel } from '../../apps/web-platform-admin/src/api/modelLibrary'
import { seedPlatformAdmin, fulfillPlatformAdminAccess } from '../fixtures/platform-admin-access'

async function setup(page: Page, customerModelIds?: string[]) {
  const identity = await seedPlatformAdmin(page, 'platform_super', '模型库验收')
  const list: Partial<LibraryModel>[] = [
    {id:'ark-code-latest',name:'方舟套餐',model:'ark-code-latest',kind:'language',source:'legacy',provider:'volcengine',baseUrl:'https://ark.cn-beijing.volces.com/api/plan/v3',bindings:{chat:'ark-code-latest',document:'chat:ark-code-latest'}},
    {id:'embed',name:'向量模型',model:'bge-small',kind:'Embedding',source:'builtin',dimension:512,bindings:{embedding:'embed'}},
    {id:'rank',name:'重排模型',model:'bge-reranker',kind:'Rerank',source:'builtin',bindings:{rerank:'rank'}},
  ]
  if (customerModelIds !== undefined) list.push(
    {id:'vision',name:'图片模型',model:'vision',kind:'language',source:'registered',provider:'openai_compatible',baseUrl:'https://example.test',bindings:{chat:'vision',vision:'vision'}},
    {id:'go',name:'翻译模型',model:'kimi',kind:'language',source:'registered',provider:'opencode_go',baseUrl:'https://opencode.ai/inference/go/openai/v1',bindings:{catalogTranslation:'go'}},
  )
  let uses = {chat:'',vision:'',embedding:'embed',rerank:'rank',document:''}, revision = 3
  const calls: {path:string;method:string;body:any}[] = []
  await page.route('**/api/v1/**', async route => {
    if (await fulfillPlatformAdminAccess(route, identity)) return
    const req=route.request(), path=new URL(req.url()).pathname, body=req.postData()?req.postDataJSON():null
    calls.push({path,method:req.method(),body})
    let data:any={list:[],total:0}
    if(path.endsWith('/model-library'))data={list,uses,customerModelIds,revision,writable:true,defaultChat:'ark-code-latest',warnings:[]}
    else if(path.endsWith('/model-library/uses')){uses=body.uses;customerModelIds=body.customerModelIds;revision++}
    else if(path.endsWith('/model-library/language')){list.push({id:'registered',name:body.name,model:body.model,kind:'language',source:'registered',provider:body.provider,baseUrl:body.baseUrl,bindings:{chat:'registered',document:'chat:registered'}});revision++}
    await route.fulfill({json:{code:0,data}})
  })
  return calls
}
async function openSelect(page:Page,label:string){await page.locator(`.el-select:has(input[aria-label="${label}"]) .el-select__wrapper`).click()}

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
  await openSelect(page, '图片理解默认模型')
  await page.getByRole('option', { name: '图片模型 · vision', exact: true }).click()
  await openSelect(page, '信众可选模型')
  const pool = page.locator('input[aria-label="信众可选模型"]')
  const listbox = page.locator(`[id="${await pool.getAttribute('aria-controls')}"]`)
  const imageOption = listbox.getByRole('option', { name: '图片模型 · vision', exact: true })
  await expect(listbox.getByRole('option')).toHaveCount(2)
  await imageOption.click()
  await page.keyboard.press('Escape')
  const save = page.getByRole('button', { name: '保存用途配置', exact: true })
  await save.click()
  await expect(save).toBeDisabled()
  const requests = () => calls.filter(call => call.path.endsWith('/model-library/uses')).map(call => call.body)
  expect(requests()).toMatchObject([{ revision: 3, uses: { vision: 'vision' }, customerModelIds: ['vision'] }])
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
