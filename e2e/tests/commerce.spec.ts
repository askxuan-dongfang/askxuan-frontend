import {test,expect} from '@playwright/test'
const address={id:1,name:'测试用户',phone:'13800000000',province:'上海市',city:'上海市',district:'浦东新区',detail:'测试地址',isDefault:true}
const product={id:1,name:'山间木珠手串',description:'天然木色，陪伴日常',mainImage:'',status:'on_shelf',price:200,stock:8,skus:[{id:1,specName:'尺寸',specValue:'8mm',stock:8,price:200}]}
const order={id:11,orderNo:'O-COMMERCE',userId:'1',addressId:1,totalAmount:200,payAmount:200,status:'pending_payment',note:'',createTime:'2026-09-08',items:[{id:1,productId:1,productName:product.name,price:200,quantity:1}]}
async function customer(page:any){await page.addInitScript(()=>{localStorage.setItem('h5_token','test');localStorage.setItem('h5-auth',JSON.stringify({state:{role:'customer',token:'test',userId:1,displayName:'验收'},version:0}))})}
for(const width of [375,768])test(`H5 cart checkout retry preserves request ${width}`,async({page})=>{
 await customer(page);await page.setViewportSize({width,height:900});let requests:any[]=[],paid=false
 await page.route('**/api/v1/**',async route=>{let data:any={};const req=route.request(),path=new URL(req.url()).pathname;
 if(path.endsWith('/products/1'))data=product
 else if(path.endsWith('/users/addresses'))data={list:[address]}
 else if(path==='/api/v1/orders'&&req.method()==='POST'){requests.push(req.postDataJSON());if(requests.length===1){await route.fulfill({status:503,json:{code:500,message:'网络中断，请重试'}});return}data={id:11,orderNo:order.orderNo}}
 else if(path.endsWith('/orders/11/returns'))data=[]
 else if(path.endsWith('/orders/11'))data={...order,status:paid?'paid':'pending_payment'}
 else if(path==='/api/v1/payments'){paid=true;data={id:2,paymentNo:'PAY-real'}}
 else if(path.endsWith('/payments/2'))data={id:2,status:'success'}
 await route.fulfill({json:{code:0,message:'ok',data}})})
 await page.goto('http://127.0.0.1:5376/c/shop/1');await page.getByRole('button',{name:'加入购物车',exact:true}).click()
 await page.goto('http://127.0.0.1:5376/c/shop/cart');await expect(page.getByText('山间木珠手串')).toBeVisible()
 await page.getByRole('button',{name:'确认订单并模拟支付'}).click();await expect(page.getByText('网络中断，请重试')).toBeVisible()
 await page.getByRole('button',{name:'确认订单并模拟支付'}).click();await expect(page).toHaveURL(/shop\/orders\/11/);await expect(page.getByRole('heading',{name:'订单详情',exact:true})).toBeVisible();await expect(page.getByText('O-COMMERCE',{exact:true})).toBeVisible()
 expect(requests).toHaveLength(2);expect(requests[0].requestId).toBe(requests[1].requestId);expect(requests[1].addressId).toBe(1)
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBeTruthy()
 await page.screenshot({path:`/private/tmp/commerce-order-${width}.png`,fullPage:true})
})
test('H5 aftersales tracks approval and return shipment',async({page})=>{
 await customer(page);let state='shipped',returns:any[]=[]
 await page.route('**/api/v1/**',async route=>{const req=route.request(),path=new URL(req.url()).pathname;let data:any={}
 if(path.endsWith('/orders/11/return')){state='in_return';returns=[{id:5,returnNo:'RO-test',status:'pending_review',reason:req.postDataJSON().reason,refundAmount:200,carrier:'',trackingNo:'',reviewNote:''}];data={id:5,returnNo:'RO-test'}}
 else if(path.endsWith('/returns/5/ship')){Object.assign(returns[0],req.postDataJSON(),{status:'return_shipping'});data={success:true}}
 else if(path.endsWith('/orders/11/returns'))data=returns
 else if(path.endsWith('/orders/11'))data={...order,status:state}
 await route.fulfill({json:{code:0,message:'ok',data}})})
 await page.goto('http://127.0.0.1:5376/c/shop/orders/11');await page.getByRole('textbox',{name:'售后原因'}).fill('尺寸不合适');await page.getByRole('button',{name:'提交售后申请'}).click();await expect(page.getByText('等待商家审核')).toBeVisible()
 returns[0].status='approved';await page.getByRole('button',{name:'刷新订单进度'}).click();await page.getByRole('textbox',{name:'退货物流公司'}).fill('顺丰');await page.getByRole('textbox',{name:'退货运单号'}).fill('SF-COMMERCE');await page.getByRole('button',{name:'提交寄回物流'}).click();await expect(page.getByText('商品寄回中')).toBeVisible();expect(returns[0].trackingNo).toBe('SF-COMMERCE')
})
test('DIY shipped order can be confirmed',async({page})=>{
 await customer(page);let status='shipped'
 await page.route('**/api/v1/**',async route=>{if(route.request().method()==='PUT')status='completed';await route.fulfill({json:{code:0,message:'ok',data:{list:[{id:1,orderNo:'DIY-test',designId:1,status,paymentStatus:'success',materialFee:200,blessFee:0,totalFee:200,items:[]}]}}})})
 await page.goto('http://127.0.0.1:5376/c/diy/orders');page.once('dialog',d=>d.accept());await page.getByRole('button',{name:'确认收到作品'}).click();await expect(page.getByRole('button',{name:'确认收到作品'})).toHaveCount(0)
})
test('platform commerce separates cash and points',async({page})=>{
 const token='e30.'+Buffer.from(JSON.stringify({roles:['platform_super']})).toString('base64url')+'.test';await page.addInitScript(t=>localStorage.setItem('df_platform_admin_token',t),token)
 await page.route('**/api/v1/**',async route=>{const path=new URL(route.request().url()).pathname;let data:any={total:1,list:[{...order,status:'paid'}]};if(path.endsWith('/orders/11'))data={...order,status:'paid'};else if(path.endsWith('/orders/report'))data={totalSales:200,pendingShip:1};else if(path.endsWith('/points/report'))data={pendingCount:3,pointsSpent:7};await route.fulfill({json:{code:0,message:'ok',data}})})
 await page.goto('http://127.0.0.1:5370/commerce');await expect(page.getByRole('heading',{name:'商城运营中心'})).toBeVisible();await expect(page.getByText('兑换消耗 7 积分，不计入现金销售')).toBeVisible();await page.getByRole('button',{name:'查看详情'}).first().click();await expect(page.getByRole('button',{name:'安排发货'})).toBeVisible();await page.screenshot({path:'/private/tmp/commerce-platform.png',fullPage:true})
})
