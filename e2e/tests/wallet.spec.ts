import {test,expect,type Page} from '@playwright/test';
async function setup(page:Page,role='customer'){
 await page.addInitScript(role=>{localStorage.setItem('h5_token','wallet-fixture');localStorage.setItem('h5-auth',JSON.stringify({state:{token:'wallet-fixture',role,userId:91001},version:0}));},role);
 const state={fail:false,calls:0};
 await page.route('**/api/v1/**',async route=>{
  const url=new URL(route.request().url());let data:any={list:[],total:0};
  if(url.pathname.endsWith('/payments/wallet')){
   state.calls++;if(state.fail)return route.fulfill({status:503,json:{code:50001,message:'暂时无法读取账单'}});
   const mock=url.searchParams.get('mode')==='mock';data={summary:{paidCents:mock?10001:0,refundedCents:mock?3003:0,refundingCents:mock?303:0},list:mock?[{id:1,paymentNo:'PAY1',orderType:'booking',orderNo:'B1',amountCents:10001,channel:'mock',status:'success',createdAt:'2026-09-26 10:00:00',refunds:[{id:1,refundNo:'RF1',amountCents:3003,status:'success',reason:'部分退款',createdAt:'2026-09-26 10:02:00'}]}]:[],total:mock?1:0,page:1,pageSize:20,mode:mock?'mock':'channel'};
  }else if(url.pathname.endsWith('/finance/wallet/master'))data={summary:{pendingCents:3400,confirmedCents:0,recordedPaidCents:0},settlements:[],withdrawals:[{id:1,number:'WD1',amountCents:300,status:'success',createdAt:'2026-09-26'}],total:0,withdrawalTotal:1,page:1,pageSize:20,withdrawEnabled:false,recordMode:'accounting_only'};
  else if(url.pathname.endsWith('/chats/incoming-call'))data={call:null};
  await route.fulfill({json:{code:0,data}});
 });return state;
}
for(const width of [320,390])test(`wallet money disclosure and refund details ${width}`,async({page})=>{
 await page.setViewportSize({width,height:844});await setup(page);await page.goto('/c/wallet');
 await expect(page.getByText('暂无这类账单')).toBeVisible();await page.getByRole('button',{name:'演示账单',exact:true}).click();
 await expect(page.locator('.wallet-total')).toHaveText('¥100.01');await expect(page.getByRole('button',{name:'演示账单',exact:true})).toHaveAttribute('aria-pressed','true');
 await page.locator('summary').click();await expect(page.getByText('退款完成 · ¥30.03')).toBeVisible();await expect(page.getByRole('link',{name:'查看关联订单'})).toHaveAttribute('href','/c/bookings/B1');
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
});
test('wallet failed load never displays zero balance and supports retry',async({page})=>{
 const state=await setup(page);state.fail=true;await page.goto('/c/wallet');await expect(page.getByRole('alert')).toContainText('暂时无法读取账单');await expect(page.locator('.wallet-total')).toHaveText('—');state.fail=false;await page.getByRole('button',{name:'重新加载'}).click();await expect(page.locator('.wallet-total')).toHaveText('¥0.00');
});
test('master wallet has no real withdrawal action and labels simulated history',async({page})=>{
 await setup(page,'master');await page.goto('/m/earnings');await expect(page.locator('.wallet-total')).toHaveText('¥34.00');await page.getByRole('button',{name:'历史提现'}).click();await expect(page.getByText('模拟完成',{exact:true})).toBeVisible();await expect(page.getByRole('button',{name:'申请提现'})).toHaveCount(0);await expect(page.getByRole('link',{name:'收入流水与趋势'})).toHaveAttribute('href','/m/earnings/history');
});
test('guest wallet redirects before sending protected request',async({page})=>{
 let requests=0;await page.route('**/api/v1/**',async route=>{if(route.request().url().includes('/payments/wallet'))requests++;await route.fulfill({json:{code:0,data:{}}})});await page.goto('/c/wallet');await expect(page).toHaveURL(/\/c\/login\?redirect=/);expect(requests).toBe(0);
});
