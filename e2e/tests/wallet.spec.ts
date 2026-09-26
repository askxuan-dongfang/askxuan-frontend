import {test,expect,type Page} from '@playwright/test';
async function setup(page:Page,role='customer'){
 await page.addInitScript(role=>{localStorage.setItem('h5_token','wallet-fixture');localStorage.setItem('h5-auth',JSON.stringify({state:{token:'wallet-fixture',role,userId:91001},version:0}));},role);
 const state={fail:false,cashFail:false,cashMalformed:false,calls:0,payCalls:0,paid:false,availableCents:10000};
 await page.route('**/api/v1/**',async route=>{
  const url=new URL(route.request().url());let data:any={list:[],total:0};
  if(url.pathname.endsWith('/payments/wallet/balance')){
   if(state.cashFail)return route.fulfill({status:503,json:{code:50001,message:'暂时无法读取余额'}});
   data=state.cashMalformed?{}:{availableCents:state.availableCents,heldCents:0,enabled:true,channels:[{id:'wechat',enabled:false},{id:'alipay',enabled:false}],entries:[],recharges:[],page:1,hasMore:false};
  }else if(url.pathname.endsWith('/payments/wallet')){
   state.calls++;if(state.fail)return route.fulfill({status:503,json:{code:50001,message:'暂时无法读取账单'}});
   const mock=url.searchParams.get('mode')==='mock';data={summary:{paidCents:mock?10001:0,refundedCents:mock?3003:0,refundingCents:mock?303:0},list:mock?[{id:1,paymentNo:'PAY1',orderType:'booking',orderNo:'B1',amountCents:10001,channel:'mock',status:'success',createdAt:'2026-09-26 10:00:00',refunds:[{id:1,refundNo:'RF1',amountCents:3003,status:'success',reason:'部分退款',createdAt:'2026-09-26 10:02:00'}]}]:[],total:mock?1:0,page:1,pageSize:20,mode:mock?'mock':'channel'};
  }else if(url.pathname.endsWith('/payments/checkout')){
   if(route.request().method()==='POST'){
    expect(route.request().postDataJSON()).toEqual({orderType:'booking',orderNo:'B1',expectedCents:1990,channel:'balance'});
    state.payCalls++;state.paid=true;data={id:1,paymentNo:'PAY1',status:'success',channel:'balance'};
   }else data={amountCents:1990,availableCents:state.availableCents,balanceEnabled:true,mockEnabled:false,experience:false};
  }else if(url.pathname.endsWith('/bookings/B1')||url.pathname.endsWith('/bookings/B1/pay')){
   data={id:'B1',userId:'91001',templeId:'T1',templeName:'测试寺院',masterId:'',masterName:'',serviceId:'S1',serviceName:'预约服务',bookingDate:'2026-10-01',timeSlot:'09:00',serviceFee:19.9,meritMoney:0,totalFee:19.9,status:state.paid?'pending':'pending_payment',paymentStatus:state.paid?'success':'pending',paymentChannel:state.paid?'balance':'',createdAt:'2026-09-26 12:00:00'};
  }else if(url.pathname.endsWith('/bookings/B1/fulfillment'))data={status:state.paid?'pending':'pending_payment',logs:[],receipts:[]};
  else if(url.pathname.endsWith('/bookings/B1/review'))return route.fulfill({status:404,json:{code:40409,message:'暂无评价'}});
  else if(url.pathname.endsWith('/finance/wallet/master'))data={summary:{pendingCents:3400,confirmedCents:0,recordedPaidCents:0},settlements:[],withdrawals:[{id:1,number:'WD1',amountCents:300,status:'success',createdAt:'2026-09-26'}],total:0,withdrawalTotal:1,page:1,pageSize:20,withdrawEnabled:false,recordMode:'accounting_only'};
  else if(url.pathname.endsWith('/chats/incoming-call'))data={call:null};
  await route.fulfill({json:{code:0,data}});
 });return state;
}
const cashTotal=(page:Page)=>page.locator('[aria-label="钱包余额"] .wallet-total');
const billTotal=(page:Page)=>page.locator('[aria-label="账单汇总"] .wallet-total');
for(const width of [320,390])test(`wallet money disclosure and refund details ${width}`,async({page})=>{
 await page.setViewportSize({width,height:844});await setup(page);await page.goto('/c/wallet');
 await expect(cashTotal(page)).toHaveText('100.00');await expect(page.getByText('暂无这类账单')).toBeVisible();
 await page.getByRole('button',{name:'充值',exact:true}).click();await expect(page.getByRole('button',{name:'前往支付',exact:true})).toBeDisabled();
 await page.getByRole('button',{name:'演示账单',exact:true}).click();
 await expect(billTotal(page)).toHaveText('¥100.01');await expect(cashTotal(page)).toHaveText('100.00');await expect(page.getByRole('button',{name:'演示账单',exact:true})).toHaveAttribute('aria-pressed','true');
 await page.locator('.wallet-entry summary').click();await expect(page.getByText('退款完成 · ¥30.03')).toBeVisible();await expect(page.getByRole('link',{name:'查看关联订单'})).toHaveAttribute('href','/c/bookings/B1');
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
});
test('wallet failed bill load keeps balance separate and supports retry',async({page})=>{
 const state=await setup(page);state.fail=true;await page.goto('/c/wallet');await expect(page.getByRole('alert')).toContainText('暂时无法读取账单');await expect(billTotal(page)).toHaveText('—');await expect(cashTotal(page)).toHaveText('100.00');state.fail=false;await page.getByRole('button',{name:'重新加载',exact:true}).click();await expect(billTotal(page)).toHaveText('¥0.00');
});
for(const malformed of [false,true])test(`wallet unavailable balance stays unknown and recovers ${malformed}`,async({page})=>{
 const state=await setup(page);state.cashFail=!malformed;state.cashMalformed=malformed;await page.goto('/c/wallet');await expect(page.getByRole('alert')).toContainText(malformed?'钱包数据格式异常':'暂时无法读取余额');await expect(cashTotal(page)).toHaveText('—');state.cashFail=false;state.cashMalformed=false;await page.getByRole('button',{name:'刷新余额'}).click();await expect(cashTotal(page)).toHaveText('100.00');
});
test('cashier never charges on opening or cancelling, requires explicit priced confirmation',async({page})=>{
 const state=await setup(page);await page.goto('/c/bookings/B1');await page.getByRole('button',{name:'继续支付',exact:true}).click();await expect(page.getByRole('dialog',{name:'确认支付'})).toBeVisible();expect(state.payCalls).toBe(0);await page.getByRole('button',{name:'关闭收银台'}).click();await expect(page.getByRole('dialog')).toHaveCount(0);expect(state.payCalls).toBe(0);
 await page.getByRole('button',{name:'继续支付',exact:true}).click();await page.getByRole('button',{name:'支付 ¥19.90',exact:true}).click();await expect(page.getByRole('dialog')).toHaveCount(0);await expect(page.locator('[aria-label="状态：已支付"]')).toBeVisible();await expect(page.getByText('钱包余额',{exact:true})).toBeVisible();expect(state.payCalls).toBe(1);
});
test('cashier disables insufficient balance without falling back to a charge',async({page})=>{
 const state=await setup(page);state.availableCents=100;await page.goto('/c/bookings/B1');await page.getByRole('button',{name:'继续支付',exact:true}).click();await expect(page.getByText('可用 ¥1.00 · 余额不足')).toBeVisible();await expect(page.getByRole('button',{name:'支付 ¥19.90',exact:true})).toBeDisabled();expect(state.payCalls).toBe(0);await page.getByRole('button',{name:'关闭收银台'}).click();
});
test('master wallet has no real withdrawal action and labels simulated history',async({page})=>{
 await setup(page,'master');await page.goto('/m/earnings');await expect(page.locator('.wallet-total')).toHaveText('¥34.00');await page.getByRole('button',{name:'历史提现'}).click();await expect(page.getByText('模拟完成',{exact:true})).toBeVisible();await expect(page.getByRole('button',{name:'申请提现'})).toHaveCount(0);await expect(page.getByRole('link',{name:'收入流水与趋势'})).toHaveAttribute('href','/m/earnings/history');
});
test('guest wallet redirects before sending protected request',async({page})=>{
 let requests=0;await page.route('**/api/v1/**',async route=>{if(route.request().url().includes('/payments/wallet'))requests++;await route.fulfill({json:{code:0,data:{}}})});await page.goto('/c/wallet');await expect(page).toHaveURL(/\/c\/login\?redirect=/);expect(requests).toBe(0);
});
