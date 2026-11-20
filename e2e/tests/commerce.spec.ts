import {test,expect} from '@playwright/test'
const address={id:1,name:'测试用户',phone:'13800000000',province:'上海市',city:'上海市',district:'浦东新区',detail:'测试地址',isDefault:true}
const product={id:1,name:'山间木珠手串',description:'天然木色，陪伴日常',mainImage:'',status:'on_shelf',price:200,stock:8,skus:[{id:1,specName:'尺寸',specValue:'8mm',stock:8,price:200}]}
const order={id:11,orderNo:'O-COMMERCE',userId:'1',addressId:1,totalAmount:200,payAmount:200,status:'pending_payment',note:'',createTime:'2026-09-08',items:[{id:1,productId:1,productName:product.name,price:200,quantity:1}]}
async function customer(page:any){await page.addInitScript(()=>{localStorage.setItem('h5_token','test');localStorage.setItem('h5-auth',JSON.stringify({state:{role:'customer',token:'test',userId:1,displayName:'验收'},version:0}))})}
test('peace wish carries a verified slot through booking and explicit payment', async ({ page }) => {
  await customer(page);
  await page.setViewportSize({ width: 390, height: 844 });
  await page.clock.setFixedTime(new Date(2026, 10, 20, 10));
  const start = '2026-11-20';
  const paidResult = { id: 'B1', status: 'pending', paymentStatus: 'success', paymentNo: 'PAY-B1', serviceFee: 0, meritMoney: 68, totalFee: 68, simulated: true };
  const pendingResult = { ...paidResult, status: 'pending_payment', paymentStatus: 'pending', paymentNo: '', simulated: false };
  const requests: unknown[] = [];
  let payments = 0;
  let preferredAvailable = true;
  await page.route('**/api/v1/**', async route => {
    const req = route.request();
    const url = new URL(req.url());
    const path = url.pathname.replace('/api/v1', '');
    let data: unknown = { list: [], total: 0 };
    if (path === '/intentions') data = { page: 1, size: 30, total: 2, tags: [{ code: 'peace', name: '求平安' }], list: [
      { resourceType: 'service', sourceId: '1', title: '清和院 · 平安祈福', subtitle: '现场说明', templeCode: 'T001', serviceCode: 'S001', price: 68 },
      { resourceType: 'service', sourceId: '2', title: '清和院 · 待确认项目', subtitle: '', templeCode: 'T001', serviceCode: 'S002', price: 36 },
    ] };
    else if (path === '/temples/T001') data = { id: 'T001', name: '清和院', rating: 0, status: '正常' };
    else if (path === '/temples/T001/services') data = {
      list: [{ id: 1, templeCode: 'T001', serviceCode: 'S001', serviceName: '平安祈福', status: 'on_shelf', price: 68, timeSlots: ['11:00-12:00'] }],
      meritMoneyTiers: [{ tier: '随喜', amount: 0, description: '' }],
    };
    else if (path === '/bookings/availability') data = {
      templeId: 'T001', serviceId: url.searchParams.get('serviceId'), bookingDate: url.searchParams.get('date'), serviceName: '平安祈福', serviceFee: 68,
      slots: url.searchParams.get('serviceId') === 'S001' ? [
        { slotCode: 'past', label: '上午', timeRange: '08:00-09:00', capacity: 4, remaining: 4, available: true },
        { slotCode: 'a', label: '上午', timeRange: '11:00-12:00', capacity: 4, remaining: preferredAvailable ? 4 : 0, available: preferredAvailable },
        { slotCode: 'b', label: '下午', timeRange: '14:00-15:00', capacity: 4, remaining: 4, available: true },
      ] : [],
    };
    else if (path === '/bookings' && req.method() === 'POST') { requests.push(req.postDataJSON()); data = pendingResult; }
    else if (path === '/bookings/B1/pay') data = paidResult;
    else if (path === '/bookings/B1') data = { ...paidResult, serviceName: '平安祈福', templeName: '清和院', bookingDate: start, timeSlot: '11:00-12:00' };
    else if (path === '/bookings/B1/fulfillment') data = { status: 'pending', receipts: [], logs: [] };
    else if (path === '/payments/checkout/quote') data = { mode: 'cash', amountCents: 6800, availableCents: 0, balanceEnabled: false, mockEnabled: true, experience: false };
    else if (path === '/payments/checkout') { payments++; data = { id: 1, paymentNo: 'PAY-B1', status: 'success', channel: 'mock' }; }
    await route.fulfill({ json: { code: 0, data } });
  });
  await page.goto('http://127.0.0.1:5376/c/intentions/peace');
  const offer = page.getByRole('link', { name: /平安祈福/ });
  await expect(offer).toContainText('11:00-12:00');
  await expect(page.getByText('08:00-09:00')).toHaveCount(0);
  await expect(page.getByText('清和院 · 待确认项目')).toBeHidden();
  await page.getByRole('button', { name: '查看全部服务' }).click();
  await expect(page.getByText('清和院 · 待确认项目')).toBeVisible();
  await page.getByRole('button', { name: '收起服务' }).click();
  await offer.click();
  await expect(page).toHaveURL(/date=2026-11-20&slotCode=a/);
  await page.getByRole('button', { name: '继续预约' }).click();
  await expect(page.getByRole('button', { name: /08:00-09:00/ })).toBeDisabled();
  const review = page.getByRole('dialog', { name: '核对预约' });
  await page.getByRole('button', { name: '核对预约信息' }).click();
  await expect(review).toContainText('2026-11-20 11:00-12:00');
  expect(requests).toHaveLength(0);
  await review.getByRole('button', { name: '关闭预约核对' }).click();
  await page.getByRole('button', { name: '核对预约信息' }).click();
  await expect(review).toContainText('2026-11-20 11:00-12:00');
  await review.getByRole('button', { name: '提交预约' }).click();
  await expect(page.getByRole('heading', { name: '预约待支付' })).toBeVisible();
  expect(requests).toEqual([expect.objectContaining({ bookingDate: start, slotCode: 'a', manualPayment: true })]);
  expect(payments).toBe(0);
  await page.getByRole('button', { name: '继续支付', exact: true }).click();
  await page.getByRole('button', { name: '确认演示支付', exact: true }).click();
  await expect(page.getByRole('heading', { name: '预约已支付' })).toBeVisible();
  expect(payments).toBe(1);
  await page.getByRole('button', { name: '查看预约详情' }).click();
  await expect(page.getByText('预约场次等待承办方确认。')).toBeVisible();
  preferredAvailable = false;
  await page.goto('http://127.0.0.1:5376/c/temples/T001/booking?serviceCode=S001&date=2026-11-20&slotCode=a');
  await expect(page.getByText('所选场次已不可预约，请重新选择。')).toBeVisible();
  await expect(page.getByRole('button', { name: '请选择可预约时段' })).toBeDisabled();
  await page.getByRole('button', { name: /14:00-15:00/ }).click();
  await page.getByRole('button', { name: '核对预约信息' }).click();
  await expect(review).toContainText('2026-11-20 14:00-15:00');
  expect(requests).toHaveLength(1);
});
for(const width of [375,768])test(`H5 cart checkout retry preserves request ${width}`,async({page})=>{
 await customer(page);await page.setViewportSize({width,height:900});let requests:any[]=[],paid=false
 await page.route('**/api/v1/**',async route=>{let data:any={};const req=route.request(),path=new URL(req.url()).pathname;
 if(path.endsWith('/products/1'))data=product
 else if(path.endsWith('/users/addresses'))data={list:[address]}
 else if(path==='/api/v1/orders'&&req.method()==='POST'){requests.push(req.postDataJSON());if(requests.length===1){await route.fulfill({status:503,json:{code:500,message:'网络中断，请重试'}});return}data={id:11,orderNo:order.orderNo}}
 else if(path.endsWith('/orders/11/returns'))data=[]
 else if(path.endsWith('/orders/11'))data={...order,status:paid?'paid':'pending_payment'}
 else if(path==='/api/v1/payments/checkout/quote')data={mode:'cash',amountCents:20000,availableCents:0,balanceEnabled:false,mockEnabled:true,experience:false}
 else if(path==='/api/v1/payments/checkout'){paid=true;data={id:2,paymentNo:'PAY-fixture',status:'success',channel:'mock'}}
 else if(path.endsWith('/payments/2'))data={id:2,status:'success'}
 await route.fulfill({json:{code:0,message:'ok',data}})})
 await page.goto('http://127.0.0.1:5376/c/shop/1');await page.getByRole('button',{name:'加入购物车',exact:true}).click();await page.getByRole('button',{name:'确认加入购物车',exact:true}).click()
 await page.goto('http://127.0.0.1:5376/c/shop/cart');await expect(page.getByText('山间木珠手串')).toBeVisible();await page.getByRole('button',{name:/去结算/}).click()
 await page.getByRole('button',{name:'提交订单'}).click();await expect(page.locator('.error-note')).toContainText('网络中断，请重试')
 await page.getByRole('button',{name:'提交订单'}).click();await page.getByRole('button',{name:'继续支付',exact:true}).click();await page.getByRole('button',{name:'确认演示支付',exact:true}).click();await expect(page).toHaveURL(/shop\/orders\/11/);await expect(page.getByRole('heading',{name:'订单详情',exact:true})).toBeVisible();await expect(page.getByText('O-COMMERCE',{exact:true})).toBeVisible()
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
