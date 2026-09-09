import { test, expect, type Page } from '@playwright/test'
import { readFileSync } from 'node:fs'
const migration = JSON.parse(readFileSync('../scripts/admin-migration-manifest.json','utf8'))
const platformPaths: string[] = JSON.parse(readFileSync('../scripts/platform-route-baseline.json','utf8'))
const origin = 'http://127.0.0.1:5388'
function token(role: string) { return 'e30.'+Buffer.from(JSON.stringify({userId:9901,roles:[role],clientId:role==='shop_admin'?'shop-admin':'platform-admin',exp:Math.floor(Date.now()/1000)+3600})).toString('base64url')+'.fixture' }
async function session(page: Page, role='platform_super', legacy=false) {
 await page.addInitScript(({value,legacy})=>{
  if(sessionStorage.getItem('seeded'))return
  sessionStorage.setItem('seeded','1')
  const key=legacy?'shop':'platform'
  localStorage.setItem(`df_${key}_admin_token`,value)
  localStorage.setItem(`df_${key}_admin_user`,JSON.stringify({userId:9901,nickname:'迁移验收管理员'}))
 },{value:token(role),legacy})
}
const baseData={id:1,list:[],items:[],total:0,page:1,size:20,status:'enabled',preferenceTags:[],permissions:[],roles:[],images:[],skus:[],tags:[],salesTrend:[],topProducts:[],totalSales:0,totalOrders:0,avgOrderValue:0,refundRate:0,trend:[],records:[],logs:[],content:[],totalIncome:0,commissionIncome:0,templeIncome:0,masterIncome:0,shopIncome:0,pendingWithdraw:0,pendingCount:0,approvedCount:0,rejectedCount:0}
async function fixture(page: Page) {
 await page.route('**/api/v1/**',async route=>{
  const path=new URL(route.request().url()).pathname
  let data:any={...baseData}
  if(path.includes('/marketing/rewards/campaigns/'))data={campaign:{id:1,title:'迁移测试活动',kind:'pool',status:'draft'},winners:[]}
  else if(path.includes('/marketing/rewards/')||path.startsWith('/api/v1/admin/points/'))data=path.endsWith('/report')?{}:[]
  if(path.endsWith('/auth/roles')||path.endsWith('/auth/permissions'))data={list:[]}
  await route.fulfill({json:{code:0,message:'controlled migration fixture',data}})
 })
}
for(const width of [390,1440]) {
 for(const m of migration) test(`shop page ${m.path} at ${width}`,async({page})=>{
  await session(page,'shop_admin');await fixture(page);await page.setViewportSize({width,height:900})
  const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message))
  await page.goto(origin+'/admin'+m.path.replace('/:id?','').replace('/:id','/1'));await expect(page.locator('.ax-admin-header__title')).toHaveText(m.title)
  await expect(page.locator('.ax-admin-main')).not.toBeEmpty();await page.waitForTimeout(150)
  expect(errors).toEqual([]);expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBeTruthy()
 })
 for(const path of platformPaths) test(`platform page ${path} at ${width}`,async({page})=>{
  await session(page);await fixture(page);await page.setViewportSize({width,height:900})
  const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message))
  await page.goto(origin+'/admin'+path.replace('/:id','/1'));await expect(page.locator('.ax-admin-main')).not.toBeEmpty();await page.waitForTimeout(150)
  expect(errors).toEqual([]);expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBeTruthy()
 })
}
for(const m of migration) test(`legacy deep link ${m.legacy}`,async({page})=>{
 await session(page,'shop_admin',true);await fixture(page)
 const path=m.legacy.replace('/:id?','/9').replace('/:id','/9')
 await page.goto(origin+path+'?page=2#record')
 await expect(page).toHaveURL(origin+'/admin'+path.replace(/^\/shop/,'/commerce')+'?page=2#record')
 await expect(page.locator('.ax-admin-header__title')).toHaveText(m.title)
 expect(await page.evaluate(()=>localStorage.getItem('df_shop_admin_token'))).toBeNull()
 expect(await page.evaluate(()=>!!localStorage.getItem('df_platform_admin_token'))).toBeTruthy()
})
test('shop role cannot access platform functions and keeps valid session',async({page})=>{
 await session(page,'shop_admin');await fixture(page)
 for(const path of ['/settings/account','/finance/overview','/marketing/rewards','/temple/list']){
  await page.goto(origin+'/admin'+path);await expect(page).toHaveURL(/\/admin\/commerce\/dashboard$/)
  await expect(page.getByText('系统治理',{exact:true})).toHaveCount(0)
  await expect(page.getByText('增长运营',{exact:true})).toHaveCount(0)
 }
 expect(await page.evaluate(()=>!!localStorage.getItem('df_platform_admin_token'))).toBeTruthy()
})
test('platform service cannot bypass restricted child via broad parent',async({page})=>{
 await session(page,'platform_service');await fixture(page)
 await page.goto(origin+'/admin/marketing/rewards');await expect(page).toHaveURL(/\/admin\/dashboard$/)
 await expect(page.getByText('免费活动与奖品',{exact:true})).toHaveCount(0)
})
test('anonymous legacy login preserves intended page',async({page})=>{
 await page.goto(origin+'/shop/login?redirect=%2Forders%2F9')
 await expect(page).toHaveURL(origin+'/admin/login?redirect=%2Fcommerce%2Forders%2F9')
 await expect(page.getByPlaceholder('管理员账号')).toBeVisible()
})
test('existing unified identity wins over old shop session',async({page})=>{
 await session(page);await fixture(page)
 await page.addInitScript(value=>{if(!sessionStorage.getItem('oldSeeded')){localStorage.setItem('df_shop_admin_token',value);sessionStorage.setItem('oldSeeded','1')}},token('shop_admin'))
 await page.goto(origin+'/shop/products');await expect(page).toHaveURL(/\/admin\/commerce\/products$/)
 expect(await page.evaluate(()=>JSON.parse(atob(localStorage.getItem('df_platform_admin_token')!.split('.')[1])).roles)).toEqual(['platform_super'])
})
test('unified logout clears both sessions and old bookmark requires login',async({page})=>{
 await session(page,'shop_admin',true);await fixture(page);await page.goto(origin+'/shop/dashboard')
 await page.locator('.ax-admin-header__right .el-dropdown').click()
 await page.getByText('退出登录',{exact:true}).click();await page.locator('.el-message-box').getByRole('button',{name:'退出',exact:true}).click()
 await expect(page).toHaveURL(/\/admin\/login$/)
 await page.goto(origin+'/shop/products');await expect(page).toHaveURL(/\/admin\/login\?redirect=/)
 expect(await page.evaluate(()=>localStorage.getItem('df_platform_admin_token'))).toBeNull()
})

const product={id:1,name:'积分专属香囊',category:'生活礼品',description:'独立运营',image:'',pointsPrice:2,stock:3,status:'on_sale',version:1}
test('write: shop admin independently creates a points product and ships redemption',async({page})=>{
 const token='e30.'+Buffer.from(JSON.stringify({roles:['shop_admin'],clientId:'shop-admin'})).toString('base64url')+'.test'
 await page.addInitScript(t=>localStorage.setItem('df_platform_admin_token',t),token)
 let saved:any,shipped:any
 await page.route('**/api/v1/**',async route=>{
  const req=route.request(),path=new URL(req.url()).pathname;let data:any={}
  if(path.endsWith('/points/report'))data={productCount:1,orderCount:1,pointsSpent:2,pendingCount:1}
  else if(path.endsWith('/points/products')&&req.method()==='POST'){saved=req.postDataJSON();data={...saved,id:2,version:1}}
  else if(path.endsWith('/points/products'))data=[product]
  else if(path.endsWith('/points/orders'))data=[{id:1,orderNo:'PT-test',productName:product.name,quantity:1,pointsTotal:2,status:'pending',receiver:'测试',mobile:'13800000000',address:'测试地址',createdAt:'2026-09-07',carrier:'',trackingNo:''}]
  else if(path.endsWith('/points/orders/1/ship')){shipped=req.postDataJSON();data={success:true}}
  await route.fulfill({json:{code:0,message:'ok',data}})
 })
 await page.goto('http://127.0.0.1:5388/admin/commerce/points-mall')
 await expect(page.getByRole('heading',{name:'积分商城'})).toBeVisible()
 await page.getByRole('button',{name:'新增积分商品'}).click()
 const dialog=page.getByRole('dialog')
 await dialog.getByRole('textbox').nth(0).fill('独立积分礼品')
 await dialog.getByRole('button',{name:'保存',exact:true}).click()
 await expect(dialog).not.toBeVisible()
 expect(saved.name).toBe('独立积分礼品');expect(saved.status).toBe('draft')
 await page.getByRole('tab',{name:'兑换订单'}).click()
 await page.getByRole('button',{name:'发货',exact:true}).click()
 await dialog.getByRole('textbox').nth(0).fill('顺丰')
 await dialog.getByRole('textbox').nth(1).fill('SF123456')
 await dialog.getByRole('button',{name:'确认发货'}).click()
 await expect(dialog).not.toBeVisible()
 await expect(page.locator('.el-loading-mask')).toHaveCount(0)
 expect(shipped).toEqual({carrier:'顺丰',trackingNo:'SF123456'})
 await page.screenshot({path:'/private/tmp/askxuan-points-admin.png',fullPage:true})
})
test('write: product create keeps payload and returns to unified list',async({page})=>{
 await session(page,'shop_admin');await fixture(page);let saved:any
 await page.route('**/api/v1/admin/products**',async route=>{
  const req=route.request(),path=new URL(req.url()).pathname
  let data:any={list:[],total:0}
  if(path.endsWith('/categories'))data={list:[{id:1,name:'测试分类',parentId:0,level:1,sort:1}],total:1}
  if(req.method()==='POST'){saved=req.postDataJSON();data={id:1}}
  await route.fulfill({json:{code:0,data}})
 })
 await page.goto(origin+'/admin/commerce/products/edit')
 await page.getByPlaceholder('请输入商品名称').fill('迁移商品')
 await page.locator('.el-select__wrapper').click();await page.getByRole('option',{name:'测试分类'}).click()
 await page.getByPlaceholder('粘贴主图 URL').fill('https://example.com/gift.png');await page.getByRole('button',{name:'填入',exact:true}).click()
 await page.getByRole('spinbutton',{name:/售价/}).fill('88')
 await page.getByRole('spinbutton',{name:/库存/}).fill('10')
 await page.getByRole('button',{name:'保存',exact:true}).click();await expect(page).toHaveURL(/\/admin\/commerce\/products$/)
 expect(saved).toMatchObject({name:'迁移商品',categoryId:1,price:88,stock:10,mainImage:'https://example.com/gift.png'})
})
for(const diy of [false,true])test(`write: ${diy?'DIY':'cash'} order shipping`,async({page})=>{
 await session(page,'shop_admin');await fixture(page);let shipped:any,status=diy?'awaiting_shipment':'paid'
 const api=diy?'/admin/diy/orders/1':'/admin/orders/1'
 await page.route('**/api/v1'+api+'**',async route=>{
  if(route.request().method()==='PUT'){shipped=route.request().postDataJSON();status='shipped'}
  await route.fulfill({json:{code:0,data:{...baseData,id:1,orderNo:'MIGRATION-ORDER',status,paymentStatus:'success',items:[],materialFee:88,blessFee:0,totalFee:88,totalAmount:88,payAmount:88}}})
 })
 await page.goto(origin+'/admin/commerce/'+(diy?'diy-orders':'orders')+'/1')
 await page.getByRole('button',{name:'发货',exact:true}).click()
 const dialog=page.locator('.el-dialog:visible')
 await dialog.locator('.el-select__wrapper').click();await page.getByRole('option',{name:'顺丰速运'}).click()
 await dialog.getByPlaceholder('请输入运单号').fill('SF-MIGRATION')
 await dialog.getByRole('button',{name:/确认发货|发货/}).click()
 await page.locator('.el-message-box').getByRole('button',{name:'确认发货',exact:true}).click()
 await expect(dialog).not.toBeVisible();expect(shipped).toMatchObject({expressCompany:'顺丰速运',trackingNo:'SF-MIGRATION'})
 await expect(page.getByRole('button',{name:'发货',exact:true})).toHaveCount(0)
})
test('write: return review and received goods and refund remain available',async({page})=>{
 await session(page,'shop_admin');await fixture(page);let status='pending_review';const writes:any[]=[]
 await page.route('**/api/v1/admin/orders/returns/1**',async route=>{
  const req=route.request(),path=new URL(req.url()).pathname
  if(req.method()==='PUT'){writes.push({path,body:req.postData()?req.postDataJSON():{}});status=path.endsWith('/review')?'approved':path.endsWith('/receive')?'return_received':'refunding'}
  await route.fulfill({json:{code:0,data:{...baseData,id:1,returnNo:'RETURN-MIGRATION',status,refundAmount:88,orderId:1}}})
 })
 await page.goto(origin+'/admin/commerce/returns/1');await page.getByRole('button',{name:'通过审核',exact:true}).click()
 await page.locator('.el-message-box textarea').fill('测试收件说明');await page.locator('.el-message-box').getByRole('button',{name:'确认通过'}).click()
 await expect(page.locator('.el-message-box')).not.toBeVisible();expect(writes[0].body).toMatchObject({action:'approve',reason:'测试收件说明'})
 status='return_shipping';await page.reload();await page.getByRole('button',{name:'确认收到退货'}).click();await page.locator('.el-message-box').getByRole('button',{name:'确定',exact:true}).click()
 await expect(page.locator('.el-message-box')).not.toBeVisible();expect(writes[1].path).toContain('/receive')
 await page.getByRole('button',{name:/^退款$|发起退款|执行退款/}).click()
 await page.locator('.el-dialog:visible').getByRole('button',{name:'确认退款',exact:true}).click()
 await page.locator('.el-message-box').getByRole('button',{name:'确认退款',exact:true}).click()
 await expect(page.locator('.el-dialog:visible')).toHaveCount(0);expect(writes[2].body).toEqual({amount:88})
})
test('write: logistics company and freight template persist through unified client',async({page})=>{
 await session(page,'shop_admin');await fixture(page);const writes:any[]=[]
 await page.route('**/api/v1/admin/logistics/**',async route=>{
  if(route.request().method()==='POST')writes.push({path:new URL(route.request().url()).pathname,body:route.request().postDataJSON()})
  await route.fulfill({json:{code:0,data:{id:1,list:[],total:0}}})
 })
 await page.goto(origin+'/admin/commerce/logistics');await page.getByRole('button',{name:'新建',exact:true}).click()
 let dialog=page.locator('.el-dialog:visible')
 await dialog.getByRole('textbox',{name:/编码/}).fill('TEST');await dialog.getByRole('textbox',{name:/名称/}).fill('测试物流')
 await dialog.getByRole('button',{name:'保存',exact:true}).click();await expect(dialog).not.toBeVisible()
 await page.getByRole('tab',{name:'运费模板'}).click();await page.getByRole('button',{name:'新建',exact:true}).click()
 dialog=page.locator('.el-dialog:visible');await dialog.getByRole('textbox',{name:'模板名称'}).fill('测试运费')
 await dialog.getByRole('button',{name:'保存',exact:true}).click();await expect(dialog).not.toBeVisible()
 expect(writes[0].body).toMatchObject({code:'TEST',name:'测试物流'});expect(writes[1].body).toMatchObject({name:'测试运费',type:'by_piece'})
 await page.screenshot({path:'/private/tmp/unified-admin-logistics.png',fullPage:true})
})
for(const kind of ['categories','materials','services'])test(`write: ${kind} creation preserves form`,async({page})=>{
 await session(page,'shop_admin');await fixture(page);let saved:any
 await page.route('**/api/v1/**',async route=>{
  if(route.request().method()==='POST'){saved=route.request().postDataJSON();await route.fulfill({json:{code:0,data:{id:1}}})}
  else await route.fallback()
 })
 await page.goto(origin+'/admin/commerce/'+kind+(kind==='categories'?'':'/edit'))
 if(kind==='categories'){
  await page.getByRole('button',{name:'新建分类',exact:true}).click()
  await page.locator('.el-dialog:visible').getByRole('textbox').first().fill('迁移分类')
  await page.locator('.el-dialog:visible').getByRole('button',{name:'保存',exact:true}).click()
  await expect(page.locator('.el-dialog:visible')).toHaveCount(0)
  expect(saved).toMatchObject({name:'迁移分类',parentId:0})
 }else {
  if(kind==='materials') await page.getByRole('textbox',{name:/材料名称/}).fill('迁移材料')
  else {
   await page.getByRole('textbox',{name:/服务名称/}).fill('迁移服务')
   await page.getByRole('textbox',{name:/寺院编码/}).fill('T-TEST')
   await page.getByRole('textbox',{name:/法师编码/}).fill('M-TEST')
  }
  await page.getByRole('button',{name:'保存',exact:true}).click();await expect(page).toHaveURL(origin+'/admin/commerce/'+kind)
  expect(saved).toMatchObject(kind==='materials'?{name:'迁移材料',unit:'颗',category:'main_bead'}:{serviceName:'迁移服务',templeCode:'T-TEST',masterCode:'M-TEST'})
 }
})
