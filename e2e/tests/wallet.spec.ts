import {test,expect,type Page} from '@playwright/test';
import {emptyCreatorWallet} from '../fixtures/creator-wallet';

// AI reports share the cashier, and must never fall back to points or mock payment.
async function aiReportWallet(page:Page,options:{available?:number;demo?:boolean;disabled?:boolean;failure?:number}={}) {
 await page.addInitScript(()=>{localStorage.setItem('h5_token','report-wallet-fixture');localStorage.setItem('h5-auth',JSON.stringify({state:{token:'report-wallet-fixture',role:'customer',userId:91001},version:0}));});
 const state={paid:false,payments:[] as any[],pointsCalls:0};
 const report={id:801,reportNo:'AR-WALLET-801',skillCode:'bazi',title:'八字命理',version:'1',question:'',chapters:['完整分析'],priceCents:1990,status:'ready',summary:'余额解锁前可阅读摘要',createdAt:'2026-10-26'};
 await page.route('**/api/v1/**',async route=>{
  const path=new URL(route.request().url()).pathname;let data:any={list:[],total:0};
  if(path.includes('/points')||path.endsWith('/payments/ai-report'))state.pointsCalls++;
  if(path.endsWith('/ai/reports/801'))data={...report,unlocked:state.paid,content:state.paid?'## 完整分析\n已通过钱包支付的完整内容。':''};
  else if(path.endsWith('/payments/checkout/quote'))data={amountCents:1990,availableCents:options.available??5000,balanceEnabled:!options.disabled,mockEnabled:true,experience:false,mode:options.demo?'demo':'cash',balanceChannel:options.demo?'demo_balance':'balance'};
  else if(path.endsWith('/payments/checkout')){
   state.payments.push(route.request().postDataJSON());
   if(options.failure)return route.fulfill({json:{code:options.failure,message:options.failure===40901?'钱包余额不足':'金额已变化，请重新获取报价'}});
   state.paid=true;data={id:801,paymentNo:'PAY-WALLET-801',status:'success',channel:options.demo?'demo_balance':'balance'};
  }
  await route.fulfill({json:{code:0,data}});
 });
 await page.goto('/c/ai/reports/801');await expect(page.getByText('余额解锁前可阅读摘要')).toBeVisible();return state;
}
test('AI report custom price uses wallet only and unlocks once after confirmation',async({page})=>{
 const state=await aiReportWallet(page);await expect(page.locator('.ai-price')).toContainText('¥19.90');await expect(page.locator('.ai-report-workspace')).not.toContainText('积分');
 await page.getByRole('button',{name:'使用钱包余额解锁',exact:true}).click();const dialog=page.getByRole('dialog',{name:'确认解锁完整报告'});
 await expect(dialog.getByRole('radio',{name:/演示支付/})).toHaveCount(0);expect(state.payments).toHaveLength(0);
 await dialog.getByRole('button',{name:'关闭收银台'}).click();await expect(dialog).toHaveCount(0);expect(state.payments).toHaveLength(0);
 await page.getByRole('button',{name:'使用钱包余额解锁',exact:true}).click();await dialog.getByRole('button',{name:'确认支付 ¥19.90 并解锁'}).click();
 await expect(page.getByText('已通过钱包支付的完整内容。')).toBeVisible();expect(state.payments).toEqual([{orderType:'ai_report',orderNo:'AR-WALLET-801',expectedCents:1990,channel:'balance'}]);
 await page.reload();await expect(page.getByText('已通过钱包支付的完整内容。')).toBeVisible();expect(state.payments).toHaveLength(1);expect(state.pointsCalls).toBe(0);
});
test('AI report insufficient balance keeps the summary and links to the wallet',async({page})=>{
 const state=await aiReportWallet(page,{available:500});await page.getByRole('button',{name:'使用钱包余额解锁',exact:true}).click();
 await expect(page.getByText('余额不足，还差 ¥14.90，摘要已为您保留。')).toBeVisible();await expect(page.getByRole('button',{name:'确认支付 ¥19.90 并解锁'})).toBeDisabled();
 await expect(page.getByRole('link',{name:'去钱包充值'})).toHaveAttribute('href','/c/wallet');expect(state.payments).toHaveLength(0);expect(state.pointsCalls).toBe(0);
});
test('AI report uses the current demo wallet with an explicit simulated balance deduction',async({page})=>{
 const state=await aiReportWallet(page,{demo:true});await page.getByRole('button',{name:'使用钱包余额解锁',exact:true}).click();
 await expect(page.getByRole('radio',{name:/模拟余额支付/})).toBeChecked();await expect(page.getByRole('radio',{name:/演示支付/})).toHaveCount(0);
 await expect(page.getByText('本次扣减测试余额，不收取真实费用。订单退款将退回测试余额。')).toBeVisible();expect(state.payments).toHaveLength(0);
 await page.getByRole('button',{name:'确认模拟支付 ¥19.90 并解锁'}).click();await expect(page.getByText('已通过钱包支付的完整内容。')).toBeVisible();
 expect(state.payments).toEqual([{orderType:'ai_report',orderNo:'AR-WALLET-801',expectedCents:1990,channel:'demo_balance'}]);expect(state.pointsCalls).toBe(0);
});
test('AI report cannot fall back to mock when wallet payments are unavailable',async({page})=>{
 const state=await aiReportWallet(page,{disabled:true});await page.getByRole('button',{name:'使用钱包余额解锁',exact:true}).click();
 await expect(page.getByRole('button',{name:'确认支付 ¥19.90 并解锁'})).toBeDisabled();await expect(page.getByRole('radio',{name:/演示支付/})).toHaveCount(0);expect(state.payments).toHaveLength(0);
});
for(const code of [40901,40902])test(`AI report payment race ${code} preserves the locked report`,async({page})=>{
 const state=await aiReportWallet(page,{failure:code});await page.getByRole('button',{name:'使用钱包余额解锁',exact:true}).click();await page.getByRole('button',{name:'确认支付 ¥19.90 并解锁'}).click();
 await expect(page.getByRole('dialog').getByRole('alert')).toContainText(code===40901?'钱包余额不足':'金额已变化');await expect(page.getByRole('button',{name:'确认支付 ¥19.90 并解锁'})).toBeDisabled();
 if(code===40901)await expect(page.getByRole('link',{name:'去钱包充值'})).toBeVisible();else await expect(page.getByText('请关闭收银台后重新打开，核对最新报价。')).toBeVisible();
 expect(state.paid).toBe(false);expect(state.payments).toHaveLength(1);expect(state.pointsCalls).toBe(0);
});
async function setup(page:Page,role='customer'){
 await page.addInitScript(role=>{localStorage.setItem('h5_token','wallet-fixture');localStorage.setItem('h5-auth',JSON.stringify({state:{token:'wallet-fixture',role,userId:91001},version:0}));},role);
 const state={fail:false,cashFail:false,cashMalformed:false,quoteMalformed:false,calls:0,payCalls:0,paid:false,availableCents:10000,creatorData:emptyCreatorWallet() as unknown};
 await page.route('**/api/v1/**',async route=>{
  const url=new URL(route.request().url());let data:any={list:[],total:0};
  if(url.pathname.endsWith('/diy/creator-wallet'))data=state.creatorData;
  else if(url.pathname.endsWith('/payments/wallet/balance')){
   if(state.cashFail)return route.fulfill({status:503,json:{code:50001,message:'暂时无法读取余额'}});
   data=state.cashMalformed?{}:{availableCents:state.availableCents,heldCents:0,enabled:true,channels:[{id:'wechat',enabled:false},{id:'alipay',enabled:false}],entries:[],recharges:[],page:1,hasMore:false};
  }else if(url.pathname.endsWith('/payments/wallet')){
   state.calls++;if(state.fail)return route.fulfill({status:503,json:{code:50001,message:'暂时无法读取账单'}});
   const mock=url.searchParams.get('mode')==='mock';data={summary:{paidCents:mock?10001:0,refundedCents:mock?3003:0,refundingCents:mock?303:0},list:mock?[{id:1,paymentNo:'PAY1',orderType:'booking',orderNo:'B1',amountCents:10001,channel:'mock',status:'success',createdAt:'2026-09-26 10:00:00',refunds:[{id:1,refundNo:'RF1',amountCents:3003,status:'success',reason:'部分退款',createdAt:'2026-09-26 10:02:00'}]}]:[],total:mock?1:0,page:1,pageSize:20,mode:mock?'mock':'channel'};
  }else if(url.pathname.endsWith('/payments/checkout/quote')){
   expect(route.request().method()).toBe('POST');expect(route.request().postDataJSON()).toEqual({orderType:'booking',orderNo:'B1'});
   data={amountCents:1990,availableCents:state.availableCents,balanceEnabled:true,mockEnabled:false,experience:false,...(state.quoteMalformed?{pricing:{}}:{})};
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
test('cashier rejects a malformed pricing snapshot without opening or charging',async({page})=>{
 const state=await setup(page);state.quoteMalformed=true;await page.goto('/c/bookings/B1');
 await page.getByRole('button',{name:'继续支付',exact:true}).click();
 await expect(page.getByText('支付报价暂时无法读取，请重试',{exact:true})).toBeVisible();
 await expect(page.getByRole('dialog',{name:'确认支付'})).toHaveCount(0);expect(state.payCalls).toBe(0);
 state.quoteMalformed=false;await page.getByRole('button',{name:'继续支付',exact:true}).click();
 await expect(page.getByRole('button',{name:'支付 ¥19.90',exact:true})).toBeVisible();
 await page.getByRole('button',{name:'关闭收银台'}).click();expect(state.payCalls).toBe(0);
});
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
for(const malformed of ['missing account','missing money','invalid reward'] as const)test(`creator wallet isolates ${malformed} and recovers`,async({page})=>{
 const state=await setup(page);const valid=emptyCreatorWallet();
 state.creatorData=malformed==='missing account'?{}:malformed==='missing money'?{...valid,account:{heldCents:0,paidCents:0}}:{...valid,rewards:[null]};
 await page.goto('/c/wallet');const creator=page.getByRole('region',{name:'创作收益'});
 await expect(creator.getByRole('alert')).toContainText('创作收益数据格式异常');
 await expect(cashTotal(page)).toHaveText('100.00');await expect(billTotal(page)).toHaveText('¥0.00');
 await expect(creator.getByRole('button',{name:'申请提现',exact:true})).toHaveCount(0);
 state.creatorData=valid;await creator.getByRole('button',{name:'重新读取收益'}).click();
 await expect(creator.getByRole('alert')).toHaveCount(0);await expect(creator.getByText('可提现',{exact:true})).toBeVisible();
 await expect(creator.getByRole('button',{name:'申请提现',exact:true})).toBeDisabled();
});
test('creator refund debt remains visible and cannot be withdrawn',async({page})=>{
 const state=await setup(page);state.creatorData={...emptyCreatorWallet(),account:{availableCents:-100,heldCents:0,paidCents:0}};
 await page.goto('/c/wallet');const creator=page.getByRole('region',{name:'创作收益'});
 await expect(creator.getByText('¥-1.00',{exact:true})).toBeVisible();await expect(creator.getByRole('alert')).toContainText('退款奖励待抵扣');
 await expect(creator.getByRole('button',{name:'申请提现',exact:true})).toBeDisabled();await expect(cashTotal(page)).toHaveText('100.00');
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
test('cashier keeps its focus and scroll lock through a minified seconds exit',async({page})=>{
 const state=await setup(page);await page.goto('/c/bookings/B1');
 const trigger=page.getByRole('button',{name:'继续支付',exact:true});
 await trigger.click();const dialog=page.getByRole('dialog',{name:'确认支付'});
 await expect(dialog).toBeVisible();
 await dialog.evaluate(async el=>{await Promise.all(el.getAnimations().map(animation=>animation.finished));});
 await page.clock.install({time:new Date('2026-10-15T00:00:00Z')});
 await page.clock.pauseAt(new Date('2026-10-15T00:00:00Z'));
 // Exercise the fallback timer without an animationend event or wall-clock races.
 await page.addStyleTag({content:'.cashier-dialog[data-closing]{animation:none!important}'});
 await page.evaluate(()=>document.documentElement.style.setProperty('--motion-duration-exit','.4s'));
 await page.getByRole('button',{name:'关闭收银台'}).click();
 await expect(dialog).toHaveAttribute('data-closing','true');
 await expect(page.getByRole('button',{name:'支付 ¥19.90',exact:true})).toBeDisabled();
 // A mistaken parse of .4s as milliseconds would release the modal after 50ms.
 await page.clock.runFor(120);await expect(dialog).toHaveCount(1);
 expect(await page.evaluate(()=>document.body.style.overflow)).toBe('hidden');
 await page.clock.runFor(400);
 await expect(dialog).toHaveCount(0);await expect(trigger).toBeFocused();
 expect(await page.evaluate(()=>document.body.style.overflow)).not.toBe('hidden');
 expect(state.payCalls).toBe(0);
});
test('cashier reduced motion cancels immediately without charging',async({page})=>{
 await page.emulateMedia({reducedMotion:'reduce'});const state=await setup(page);
 await page.goto('/c/bookings/B1');const trigger=page.getByRole('button',{name:'继续支付',exact:true});
 await trigger.click();await expect(page.getByRole('dialog',{name:'确认支付'})).toBeVisible();
 await page.getByRole('button',{name:'关闭收银台'}).click();
 await expect(page.getByRole('dialog')).toHaveCount(0);await expect(trigger).toBeFocused();
 expect(state.payCalls).toBe(0);
});
test('master wallet has no real withdrawal action and labels simulated history',async({page})=>{
 await setup(page,'master');await page.goto('/m/earnings');await expect(page.locator('.wallet-total')).toHaveText('¥34.00');await page.getByRole('button',{name:'历史提现'}).click();await expect(page.getByText('模拟完成',{exact:true})).toBeVisible();await expect(page.getByRole('button',{name:'申请提现'})).toHaveCount(0);await expect(page.getByRole('link',{name:'收入流水与趋势'})).toHaveAttribute('href','/m/earnings/history');
});
test('guest wallet redirects before sending protected request',async({page})=>{
 let requests=0;await page.route('**/api/v1/**',async route=>{if(route.request().url().includes('/payments/wallet'))requests++;await route.fulfill({json:{code:0,data:{}}})});await page.goto('/c/wallet');await expect(page).toHaveURL(/\/c\/login\?redirect=/);expect(requests).toBe(0);
});
