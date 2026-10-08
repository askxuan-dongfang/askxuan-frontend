import { test, expect, type Page } from '@playwright/test';
const bead = { position:0, materialId:1, materialName:'测试木珠', spec:'10mm', unitPrice:10, subtype:'wood', diameterMm:10 };
const design = { id:1, userId:'42', name:'返回测试手串', status:'private', revision:1, totalPrice:10, designData:JSON.stringify({version:2,wristSizeMm:160,beads:[bead],items:[{...bead,quantity:1}]}) };
async function setup(page: Page) {
 await page.emulateMedia({reducedMotion:'reduce'});
 await page.addInitScript(() => {localStorage.setItem('h5_token','fixture');localStorage.setItem('h5-auth',JSON.stringify({state:{token:'fixture',role:'customer',userId:42},version:0}));});
 const writes:string[]=[];
 await page.route('**/api/v1/**', async route => {
  const req=route.request(),path=new URL(req.url()).pathname;
  if(req.method()!=='GET')writes.push(path);
  let data:any={list:[],total:0};
  if(path.endsWith('/bookings/journeys'))data={list:[],total:0,counts:{active:0,receipt:0,complete:0,confirmed:0,executing:0,revision:0}};
  else if(path.endsWith('/users/profile'))data={userId:42,nickname:'返回测试用户',mobile:'',avatar:''};
  else if(path.endsWith('/points'))data={balance:0};
  else if(path.endsWith('/payments/wallet'))data={summary:{paidCents:0,refundedCents:0,refundingCents:0},list:[],total:0,page:1,pageSize:20,mode:'channel'};
  else if(path.endsWith('/payments/wallet/balance'))data={availableCents:0,heldCents:0,enabled:true,channels:[],entries:[],recharges:[],page:1,hasMore:false};
  else if(path.endsWith('/diy/designs/1'))data=design;
  else if(path.endsWith('/diy/designs')&&req.method()==='POST')data={id:1,revision:2};
  else if(path.endsWith('/diy/designs')||path.endsWith('/diy/my-designs'))data={list:[design],total:1};
  else if(path.endsWith('/diy/materials'))data={list:[{id:1,name:'测试木珠',spec:'10mm',unitPrice:10,category:'wood',stock:100,status:'on_shelf',image:'',diameterMm:10}],total:1};
  else if(path.endsWith('/diy/orders/availability'))data={orderable:true,materialFee:10,originalMaterialFee:10,priceChanged:false,issues:[]};
  else if(path.endsWith('/chats/incoming-call'))data={call:null};
  else if(path.endsWith('/chats/unread'))data={count:0};
  await route.fulfill({json:{code:0,data}});
 });
 return writes;
}
const back=(page:Page)=>page.locator('.flow-nav .back-button');
const index=(page:Page)=>page.evaluate(()=>history.state.idx);
async function gallery(page:Page){await page.goto('/c/diy?tab=mine');await page.getByRole('link',{name:/返回测试手串/}).click();await expect(page).toHaveURL(/\/c\/diy\/1$/);await expect(page.getByRole('link',{name:'继续编辑',exact:true})).toBeVisible();}
for(const width of [390,1280])test(`DIY actual source, tab restoration and no return loop ${width}`,async({page})=>{
 await page.setViewportSize({width,height:844});await setup(page);await gallery(page);
 await page.getByRole('link',{name:'继续编辑',exact:true}).click();await expect(page.getByRole('button',{name:'保存设计',exact:true})).toBeVisible();
 await back(page).click();await expect(page).toHaveURL(/\/c\/diy\/1$/);
 await back(page).click();await expect(page).toHaveURL(/\/c\/diy\?tab=mine$/);await expect(page.getByRole('tab',{name:'我的设计'})).toHaveAttribute('aria-selected','true');expect(await index(page)).toBe(0);
 await back(page).click();await expect(page).toHaveURL(/\/c$/);expect(await index(page)).toBe(0);
});
test('direct editor safely replaces with gallery and home',async({page})=>{
 await setup(page);await page.goto('/c/diy/editor');await expect(page.getByRole('button',{name:'保存设计',exact:true})).toBeVisible();
 await back(page).click();await expect(page).toHaveURL(/\/c\/diy$/);expect(await index(page)).toBe(0);
 await back(page).click();await expect(page).toHaveURL(/\/c$/);expect(await index(page)).toBe(0);
});
test('saving existing design returns once to its origin, not a duplicate detail',async({page})=>{
 await setup(page);await gallery(page);await page.getByRole('link',{name:'继续编辑',exact:true}).click();
 await page.getByRole('button',{name:'保存设计',exact:true}).click();await page.getByRole('button',{name:'保存作品',exact:true}).click();
 await expect(page).toHaveURL(/\/c\/diy\/1$/);expect(await index(page)).toBe(1);
 await back(page).click();await expect(page).toHaveURL(/tab=mine$/);expect(await index(page)).toBe(0);
});
test('detail checkout uses one reversible history step and never submits an order on Back',async({page})=>{
 const writes=await setup(page);await gallery(page);await page.getByRole('button',{name:'按此设计定制',exact:true}).click();await expect(page.getByRole('heading',{name:'确认定制',exact:true})).toBeVisible();expect(await index(page)).toBe(2);
 await page.goBack();await expect(page.getByRole('heading',{name:'作品详情',exact:true})).toBeVisible();expect(await index(page)).toBe(1);
 await page.goForward();await expect(page.getByRole('heading',{name:'确认定制',exact:true})).toBeVisible();
 await back(page).click();await expect(page.getByRole('heading',{name:'作品详情',exact:true})).toBeVisible();
 await page.getByRole('button',{name:'按此设计定制',exact:true}).click();await expect(page.getByRole('heading',{name:'确认定制',exact:true})).toBeVisible();
 await page.reload();await expect(page.getByRole('heading',{name:'作品详情',exact:true})).toBeVisible();
 expect(writes.filter(p=>p.endsWith('/order')||p.endsWith('/orders')||p.includes('/payments'))).toEqual([]);
});
test('editor checkout browser Back keeps the saved design and editable beads',async({page})=>{
 await setup(page);await gallery(page);await page.getByRole('link',{name:'继续编辑',exact:true}).click();
 await page.getByRole('button',{name:/^去定制/}).click();await page.getByRole('button',{name:'保存并继续',exact:true}).click();await expect(page.getByRole('heading',{name:'确认订单',exact:true})).toBeVisible();
 await page.goBack();await expect(page.getByRole('button',{name:'保存设计',exact:true})).toBeEnabled();await expect(page.locator('.diy-action-total')).toContainText('1 颗');
 await back(page).click();await expect(page).toHaveURL(/\/c\/diy\/1$/);
});
test('repeated back clicks in a single pending navigation do not skip the gallery',async({page})=>{
 await setup(page);await gallery(page);
 await back(page).evaluate((button:HTMLButtonElement)=>{button.click();button.click();button.click();});
 await expect(page).toHaveURL(/\/c\/diy\?tab=mine$/);expect(await index(page)).toBe(0);
});
test('global BackLink uses a history pop and direct fallback does not add entries',async({page})=>{
 await setup(page);await page.goto('/c/profile');await page.locator('a[href="/c/wallet"]').first().click();await expect(page).toHaveURL(/\/c\/wallet$/);
 await page.locator('.wallet-top .back-button').click();await expect(page).toHaveURL(/\/c\/profile$/);expect(await index(page)).toBe(0);
 await page.goto('/c/wallet');await page.locator('.wallet-top .back-button').click();await expect(page).toHaveURL(/\/c\/profile$/);expect(await index(page)).toBe(0);
});
