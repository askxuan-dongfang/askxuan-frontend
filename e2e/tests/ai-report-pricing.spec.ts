import { test, expect, type Page } from '@playwright/test'
import { seedPlatformAdmin, fulfillPlatformAdminAccess } from '../fixtures/platform-admin-access'

const initial = {code:'bazi',title:'八字命理',subtitle:'从个人资料出发理解自身优势',priceCents:990,revision:1,enabled:true,version:'1.0'}
async function setup(page:Page, options:{conflict?:boolean;role?:string}={}) {
  const identity=await seedPlatformAdmin(page,options.role||'platform_super','定价验收')
  let row={...initial},conflict=options.conflict
  const writes:any[]=[]
  await page.route('**/api/v1/**',async route=>{
    if(await fulfillPlatformAdminAccess(route,identity))return
    const request=route.request(),path=new URL(request.url()).pathname
    if(path.endsWith('/ai/admin/products/bazi')&&request.method()==='PUT'){
      const body=request.postDataJSON();writes.push(body)
      if(conflict){conflict=false;row={...row,priceCents:1490,revision:2};return route.fulfill({json:{code:40931,message:'报告价格已被其他管理员修改，请重新读取后再保存'}})}
      row={...row,priceCents:body.priceCents,revision:row.revision+1};return route.fulfill({json:{code:0,data:row}})
    }
    return route.fulfill({json:{code:0,data:path.endsWith('/ai/admin/products')?[row]:{list:[],total:0}}})
  })
  return writes
}
test('report pricing saves an exact cent price and keeps cancellation read-only',async({page})=>{
  const writes=await setup(page);await page.goto('/ai/report-pricing')
  await expect(page.getByRole('heading',{name:'报告定价',exact:true})).toBeVisible()
  await expect(page.getByRole('cell',{name:'¥9.90',exact:true})).toBeVisible()
  await page.getByRole('button',{name:'调整价格',exact:true}).click()
  const dialog=page.getByRole('dialog',{name:'调整报告价格',exact:true})
  await dialog.getByRole('spinbutton',{name:/每份价格/}).fill('12.34');await dialog.getByRole('button',{name:'取消',exact:true}).click();expect(writes).toHaveLength(0)
  await page.getByRole('button',{name:'调整价格',exact:true}).click();await dialog.getByRole('spinbutton',{name:/每份价格/}).fill('12.34')
  await dialog.getByRole('button',{name:'保存价格',exact:true}).click();await expect(dialog).toBeHidden()
  expect(writes).toEqual([{priceCents:1234,revision:1}]);await expect(page.getByRole('cell',{name:'¥12.34',exact:true})).toBeVisible()
  await page.reload();await expect(page.getByRole('cell',{name:'¥12.34',exact:true})).toBeVisible()
})
test('report pricing conflict preserves input until an explicit refresh',async({page})=>{
  await page.setViewportSize({width:390,height:844});const writes=await setup(page,{conflict:true});await page.goto('/ai/report-pricing')
  await page.getByRole('button',{name:'调整价格',exact:true}).click();const dialog=page.getByRole('dialog',{name:'调整报告价格',exact:true})
  const input=dialog.getByRole('spinbutton',{name:/每份价格/});await input.fill('19.90');await dialog.getByRole('button',{name:'保存价格',exact:true}).click()
  await expect(dialog.getByRole('alert')).toContainText('其他管理员');await expect(input).toHaveValue('19.90')
  await dialog.getByRole('button',{name:'重新读取当前价格',exact:true}).click();await expect(input).toHaveValue('14.90')
  await input.fill('19.90');await dialog.getByRole('button',{name:'保存价格',exact:true}).click();await expect(dialog).toBeHidden()
  expect(writes).toEqual([{priceCents:1990,revision:1},{priceCents:1990,revision:2}])
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBeTruthy()
})
test('shop admin cannot reach report pricing or its API',async({page})=>{
  const identity=await seedPlatformAdmin(page,'shop_admin','权限验收');const productCalls:string[]=[]
  await page.route('**/api/v1/**',async route=>{if(await fulfillPlatformAdminAccess(route,identity))return;if(route.request().url().includes('/ai/admin/products'))productCalls.push(route.request().url());await route.fulfill({json:{code:0,data:{list:[],total:0}}})})
  await page.goto('/ai/report-pricing');await expect(page).not.toHaveURL(/\/ai\//);expect(productCalls).toHaveLength(0)
})
