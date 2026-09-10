import { test, expect } from '@playwright/test'
const product={id:1,name:'积分专属香囊',category:'生活礼品',description:'独立运营的积分商品',image:'',pointsPrice:2,stock:3,status:'on_sale',version:1}
const address={id:1,name:'测试用户',phone:'13800000000',province:'上海市',city:'上海市',district:'浦东新区',detail:'测试地址',isDefault:true}
for(const width of [375,768]){
 test(`H5 points redemption and cancellation ${width}`,async({page})=>{
  await page.setViewportSize({width,height:850})
  await page.addInitScript(()=>{localStorage.setItem('h5_token','test');localStorage.setItem('h5-auth',JSON.stringify({state:{role:'customer',token:'test',userId:1,displayName:'测试'},version:0}))})
  let balance=5;let orders:any[]=[];let requests:any[]=[]
  await page.route('**/api/v1/**',async route=>{
   const req=route.request(), path=new URL(req.url()).pathname;let data:any={}
   if(path==='/api/v1/points')data={balance}
   else if(path.endsWith('/points/ledger'))data=[{id:1,kind:'earn',delta:5,balanceAfter:5,referenceNo:'PAY123',createdAt:'2026-09-07 12:00:00'}]
   else if(path.endsWith('/points/products'))data=[product]
   else if(path.endsWith('/users/addresses'))data=[address]
   else if(path.endsWith('/points/orders')&&req.method()==='POST'){
    const body=req.postDataJSON();requests.push(body);balance-=2
    data={id:1,orderNo:'PT123',productName:product.name,quantity:1,pointsTotal:2,status:'pending',receiver:address.name,mobile:address.phone,address:address.detail,createdAt:'2026-09-07 12:01:00',carrier:'',trackingNo:''};orders=[data]
   }else if(path.endsWith('/points/orders/1/cancel')){balance+=2;orders[0].status='cancelled';data={success:true}}
   else if(path.endsWith('/points/orders'))data=orders
   await route.fulfill({json:{code:0,message:'ok',data}})
  })
  await page.goto('http://127.0.0.1:5386/c/points')
  await expect(page.getByText('消费获得')).toBeVisible()
  await page.getByRole('tab',{name:'积分商城',exact:true}).click()
  await page.getByRole('button',{name:/积分专属香囊/}).click()
  await expect(page.getByRole('dialog')).toBeVisible()
  await page.getByRole('button',{name:'确认兑换',exact:true}).click()
  await expect(page.getByText('2 积分 · 待发货')).toBeVisible()
  expect(requests).toHaveLength(1);expect(requests[0].expectedPrice).toBe(2);expect(requests[0].requestKey.length).toBeGreaterThan(16)
  page.once('dialog',d=>d.accept())
  await page.getByRole('button',{name:'取消兑换',exact:true}).click()
  await expect(page.getByText('2 积分 · 已取消')).toBeVisible()
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBeTruthy()
  await page.screenshot({path:`/private/tmp/askxuan-points-h5-${width}.png`,fullPage:true})
 })
}
test('shop admin independently creates a points product and ships redemption',async({page})=>{
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
 await page.goto('http://127.0.0.1:5387/commerce/points-mall')
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
