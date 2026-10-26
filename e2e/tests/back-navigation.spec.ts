import { test, expect, type Page } from '@playwright/test';
import {emptyCreatorWallet} from '../fixtures/creator-wallet';
const bead = { position:0, materialId:1, materialName:'测试木珠', spec:'10mm', unitPrice:10, subtype:'wood', diameterMm:10 };
const design = { id:1, userId:'42', name:'返回测试手串', status:'public', revision:1, totalPrice:10, designData:JSON.stringify({version:2,wristSizeMm:160,beads:[bead],items:[{...bead,quantity:1}]}) };
type Eligibility = { canPublish: boolean; reason: string; message: string; orderId?: number };
type FixtureOptions = { eligibility?: Eligibility | null; status?: string; draftName?: string; publicationError?: string; reads?: URL[]; language?: string; theme?: string };
const ready: Eligibility = { canPublish:true, reason:'ready', message:'订单已付款，款式、用料和价格已确认。', orderId:9 };
async function setup(page: Page, options: FixtureOptions = {}) {
 await page.emulateMedia({reducedMotion:'reduce'});
 await page.addInitScript(options => {localStorage.setItem('askxuan-language',options.language || 'zh-Hans');localStorage.setItem('askxuan-theme',options.theme || 'light');localStorage.setItem('h5_token','fixture');localStorage.setItem('h5-auth',JSON.stringify({state:{token:'fixture',role:'customer',userId:42},version:0}));}, {language:options.language,theme:options.theme});
 const writes:string[]=[];
 let current:any={...design,status:options.status || design.status,name:options.draftName || design.name,draftChanged:!!options.draftName,publication:{id:11,designRevision:1,materialFee:10,publishedAt:'2026-10-20T10:00:00Z'}}; let copied:any=null;
 let published:any={...current,name:design.name,draftChanged:false};
 const owned=()=>({...current,publicationEligibility:options.eligibility === undefined ? ready : options.eligibility ?? undefined});
 await page.route('**/api/v1/**', async route => {
  const req=route.request(),url=new URL(req.url()),path=url.pathname;
  if(req.method()==='GET')options.reads?.push(url);
  if(req.method()!=='GET')writes.push(path);
  let data:any={list:[],total:0};
  if(path.endsWith('/bookings/journeys'))data={list:[],total:0,counts:{active:0,receipt:0,complete:0,confirmed:0,executing:0,revision:0}};
  else if(path.endsWith('/users/profile'))data={userId:42,nickname:'返回测试用户',mobile:'',avatar:''};
  else if(path.endsWith('/points'))data={balance:0};
  else if(path.endsWith('/diy/creator-wallet'))data=emptyCreatorWallet();
  else if(path.endsWith('/payments/wallet'))data={summary:{paidCents:0,refundedCents:0,refundingCents:0},list:[],total:0,page:1,pageSize:20,mode:'channel'};
  else if(path.endsWith('/payments/wallet/balance'))data={availableCents:0,heldCents:0,enabled:true,channels:[],entries:[],recharges:[],page:1,hasMore:false};
  else if(path.endsWith('/diy/designs/1/copy')){copied={...published,id:2,sourceDesignId:1,sourcePublicationId:published.publication.id,status:'private',name:published.name+' · 副本',revision:1,publication:undefined,draftChanged:false,publicationEligibility:{canPublish:false,reason:'order_required',message:'副本需完成自己的定制订单后再发布。'}};data=copied;}
  else if(path.endsWith('/diy/designs/1/status')){
   const body=req.postDataJSON(),eligibility=owned().publicationEligibility;
   if(body.revision!==current.revision)return route.fulfill({json:{code:40914,message:'设计已更新，请刷新后重试'}});
   if(body.status==='public' && (options.publicationError || !eligibility?.canPublish || eligibility?.reason!=='ready'))return route.fulfill({json:{code:40915,message:options.publicationError || eligibility?.message || '资格暂未同步'}});
   current={...current,status:body.status,revision:current.revision+1};
   if(body.status==='public'){current.draftChanged=false;current.publication={...current.publication,id:(current.publication?.id || 11)+1,designRevision:current.revision};published={...current};}
   data=owned();
  }
  else if(path.endsWith('/diy/designs/1'))data=url.searchParams.get('view')==='published'?published:owned();
  else if(path.endsWith('/diy/designs/2'))data=copied;
  else if(path.endsWith('/diy/designs')&&req.method()==='POST'){const body=req.postDataJSON();expect(body).not.toHaveProperty('status');if(body.id===2){copied={...copied,...body,status:'private',revision:copied.revision+1};data={id:2,revision:copied.revision};}else{current={...current,...body,draftChanged:current.status==='public',revision:current.revision+1};data={id:1,revision:current.revision};}}
  else if(path.endsWith('/diy/my-designs'))data={list:copied?[owned(),copied]:[owned()],total:copied?2:1};
  else if(path.endsWith('/diy/designs'))data={list:current.status==='public'?[published]:[],total:current.status==='public'?1:0};
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
for (const viewport of [{width:320,height:568},{width:390,height:844},{width:844,height:390},{width:1280,height:800}]) test(`DIY fit settings stay fully on screen ${viewport.width}`, async ({page}) => {
 await page.setViewportSize(viewport); await setup(page); await page.goto('/c/diy/editor');
 await page.locator('button[aria-controls="diy-fit-settings"]').click();
 const dialog=page.getByRole('dialog',{name:'佩戴与搭配'}); await expect(dialog).toBeVisible();
 const box=await dialog.boundingBox(); expect(box).not.toBeNull();
 expect(box!.x).toBeGreaterThanOrEqual(0); expect(box!.y).toBeGreaterThanOrEqual(0);
 expect(box!.x+box!.width).toBeLessThanOrEqual(viewport.width+1); expect(box!.y+box!.height).toBeLessThanOrEqual(viewport.height+1);
 await page.getByRole('button',{name:'关闭佩戴设置'}).click(); await expect(dialog).not.toBeVisible();
 await expect(page.getByRole('button',{name:'撤销',exact:true})).toHaveText('撤销');
 await expect(page.getByRole('button',{name:'重做',exact:true})).toHaveText('重做');
});
async function mine(page:Page){await page.goto('/c/diy?tab=mine');await expect(page.getByText('已发布',{exact:true})).toBeVisible();await page.getByRole('link',{name:'编辑设计：返回测试手串',exact:true}).click();await expect(page).toHaveURL(/\/c\/diy\/editor\?design=1$/);}
async function viewer(page:Page){await page.goto('/c/diy?tab=plaza');await page.getByRole('link',{name:'查看作品：返回测试手串',exact:true}).click();await expect(page).toHaveURL(/\/c\/diy\/1$/);}
for (const entry of ['direct', 'plaza'] as const) test(`DIY preview fills viewport and keeps tools together after ${entry} entry`, async ({page}) => {
 await page.setViewportSize({width:489,height:954});const writes=await setup(page);
 if(entry==='plaza'){
  await page.goto('/c/diy?tab=plaza');
  await page.getByRole('link',{name:'开始设计',exact:false}).click();
 }else await page.goto('/c/diy/editor');
 await expect(page).toHaveURL(/\/c\/diy\/editor$/);
 const viewport=page.locator('.studio-viewport');
 const expand=page.getByRole('button',{name:'扩大预览',exact:true});
 await expect(viewport.locator('.diy-3d-toolbar')).toBeVisible();
 await page.evaluate(()=>document.fonts.ready);
 const geometry=()=>viewport.evaluate(element=>{
  const box=element.getBoundingClientRect();
  const preview=element.querySelector('.diy-3d-inline')!.getBoundingClientRect();
  const canvas=element.querySelector('.diy-3d-canvas-area')!.getBoundingClientRect();
  const tools=[element.querySelector('.diy-3d-toolbar button')!,element.querySelector('.studio-expand-preview')!,element.querySelector('.studio-history button')!].map(button=>button.getBoundingClientRect());
  return {height:box.height,fillError:Math.max(Math.abs(preview.top-box.top),Math.abs(preview.bottom-box.bottom),Math.abs(preview.left-box.left),Math.abs(preview.right-box.right)),canvasGap:preview.bottom-canvas.bottom,toolBottomGaps:tools.map(tool=>Math.abs(tool.bottom-box.bottom)),widthFits:document.documentElement.scrollWidth<=innerWidth};
 });
 const assertGeometry=async()=>{
  await expect.poll(async()=>{
   const result=await geometry();
   return result.fillError<1&&Math.abs(result.canvasGap-44)<1&&result.toolBottomGaps.every(gap=>gap<1)&&result.widthFits;
  }).toBe(true);
  return geometry();
 };
 const initial=await assertGeometry();
 await page.getByRole('button',{name:'添加测试木珠',exact:true}).click();
 await expect(page.locator('.studio-stage-top small')).toHaveText('1 / 60 颗');
 await viewport.focus();await viewport.press('ArrowRight');
 await expect(page.locator('.studio-accessible-selection')).toHaveText('第 1 颗 测试木珠');
 await expand.click();
 const collapse=page.getByRole('button',{name:'收起预览',exact:true});
 await expect(collapse).toHaveAttribute('aria-pressed','true');
 await expect(page.locator('.studio-library')).toBeHidden();
 expect((await assertGeometry()).height).toBeGreaterThan(initial.height);
 await collapse.click();
 await expect(expand).toHaveAttribute('aria-pressed','false');
 await expect(page.locator('.studio-library')).toBeVisible();
 expect((await assertGeometry()).height).toBeCloseTo(initial.height,0);
 await viewport.focus();await viewport.press('Delete');
 await expect(page.locator('.studio-stage-top small')).toHaveText('0 / 60 颗');
 await viewport.locator('.studio-history').getByRole('button',{name:'撤销',exact:true}).click();
 await expect(page.locator('.studio-stage-top small')).toHaveText('1 / 60 颗');
 expect(writes).toEqual([]);
});
for(const width of [390,1280])test(`my design opens editor directly and Back restores my list ${width}`,async({page})=>{
 await page.setViewportSize({width,height:844});await setup(page);await mine(page);
 await expect(page.getByRole('button',{name:'保存设计',exact:true})).toBeVisible();
 await back(page).click();await expect(page).toHaveURL(/\/c\/diy\?tab=mine$/);await expect(page.getByRole('tab',{name:'我的设计'})).toHaveAttribute('aria-selected','true');expect(await index(page)).toBe(0);
 await back(page).click();await expect(page).toHaveURL(/\/c$/);expect(await index(page)).toBe(0);
});
test('direct editor safely replaces with gallery and home',async({page})=>{
 await setup(page);await page.goto('/c/diy/editor');await expect(page.getByRole('button',{name:'保存设计',exact:true})).toBeVisible();
 await back(page).click();await expect(page).toHaveURL(/\/c\/diy$/);expect(await index(page)).toBe(0);
 await back(page).click();await expect(page).toHaveURL(/\/c$/);expect(await index(page)).toBe(0);
});
test('saving a published design preserves its public snapshot and returns once to my list',async({page})=>{
 await setup(page);await mine(page);
 await page.getByRole('button',{name:'保存设计',exact:true}).click();
 await expect(page.getByText('修改将保存为私有草稿，已发布定稿保持不变；满足发布条件后可在我的设计中发布新定稿。',{exact:true})).toBeVisible();
 await page.getByRole('textbox',{name:'设计名称',exact:true}).fill('修改后的私有草稿');
 await page.getByRole('button',{name:'保存作品',exact:true}).click();
 await expect(page).toHaveURL(/\/c\/diy\?tab=mine$/);expect(await index(page)).toBe(0);await expect(page.getByText('草稿已修改',{exact:true})).toBeVisible();
 await expect(page.getByRole('link',{name:'编辑设计：修改后的私有草稿',exact:true})).toBeVisible();
 await back(page).click();await expect(page).toHaveURL(/\/c$/);expect(await index(page)).toBe(0);
 await viewer(page);await expect(page.getByRole('heading',{name:design.name,exact:true})).toBeVisible();
 await expect(page.getByText('修改后的私有草稿',{exact:true})).toHaveCount(0);
});
test('even the authors public detail is a read-only viewer',async({page})=>{
 const reads:URL[]=[];const writes=await setup(page,{reads,draftName:'未发布的新标题'});await viewer(page);
 await expect(page.getByText('作者：我',{exact:true})).toBeVisible();await expect(page.getByRole('heading',{name:'用料',exact:true})).toBeVisible();
 await expect(page.getByRole('button',{name:'复制并编辑',exact:true})).toBeVisible();
 await expect(page.getByRole('link',{name:'继续编辑',exact:true})).toHaveCount(0);await expect(page.getByRole('button',{name:/下架|发布到|按此设计定制/})).toHaveCount(0);
 await expect(page.getByRole('heading',{name:design.name,exact:true})).toBeVisible();
 expect(reads.some(url=>url.pathname.endsWith('/diy/designs/1')&&url.searchParams.get('view')==='published')).toBe(true);
 expect(writes).toEqual([]);await back(page).click();await expect(page).toHaveURL(/tab=plaza$/);
});
test('copy opens a new private design without modifying the viewed work',async({page})=>{
 const writes=await setup(page,{draftName:'作者未发布的草稿'});await viewer(page);await page.getByRole('button',{name:'复制并编辑',exact:true}).click();
 await expect(page).toHaveURL(/editor\?design=2$/);await expect(page.getByRole('button',{name:'保存设计',exact:true})).toBeVisible();
 expect(writes.filter(path=>path.includes('/diy/designs'))).toEqual(['/api/v1/diy/designs/1/copy']);
 await back(page).click();await expect(page).toHaveURL(/\/c\/diy\/1$/);await expect(page.getByRole('heading',{name:'返回测试手串',exact:true})).toBeVisible();
 await page.goto('/c/diy?tab=mine');
 const copy=page.locator('.diy-gallery-card').filter({has:page.getByRole('heading',{name:'返回测试手串 · 副本',exact:true})});
 await copy.getByRole('button',{name:'发布',exact:true}).click();
 await expect(page.getByText('副本需完成自己的定制订单后再发布。',{exact:true})).toBeVisible();
 await expect(page.getByRole('button',{name:'确认发布',exact:true})).toHaveCount(0);
 expect(writes).toEqual(['/api/v1/diy/designs/1/copy']);
});
test('publishing controls belong to my list and preserve revision state',async({page})=>{
 const writes=await setup(page);await page.goto('/c/diy?tab=mine');await page.getByRole('button',{name:'下架',exact:true}).click();
 await page.getByRole('button',{name:'取消',exact:true}).click();expect(writes).toEqual([]);
 await page.getByRole('button',{name:'下架',exact:true}).click();await page.getByRole('button',{name:'确认下架',exact:true}).click();
 await expect(page.getByText('未发布',{exact:true})).toBeVisible();await page.getByRole('button',{name:'发布',exact:true}).click();await page.getByRole('button',{name:'确认发布',exact:true}).click();
 await expect(page.getByText('已发布',{exact:true})).toBeVisible();expect(writes).toEqual(['/api/v1/diy/designs/1/status','/api/v1/diy/designs/1/status']);
});
for(const eligibility of [
 {canPublish:false,reason:'order_required',message:'请先完成本款定制订单。'},
 {canPublish:false,reason:'payment_required',message:'订单尚未付款。',orderId:9},
 {canPublish:false,reason:'confirmation_required',message:'款式、用料和价格尚未确认。',orderId:9},
 {canPublish:true,reason:'future_reason',message:'需要进一步确认发布资格。'},
 null,
] as const)test(`publishing stays blocked for ${eligibility?.reason || 'missing server eligibility'}`,async({page})=>{
 const writes=await setup(page,{status:'private',eligibility});await page.goto('/c/diy?tab=mine');
 await page.getByRole('button',{name:'发布',exact:true}).click();
 await expect(page.getByText(eligibility?.message || '发布资格暂未同步，请刷新后重试。',{exact:true})).toBeVisible();
 await expect(page.getByRole('button',{name:'确认发布',exact:true})).toHaveCount(0);
 await expect(page.getByRole('button',{name:'刷新资格',exact:true})).toBeVisible();
 expect(writes).toEqual([]);
});
test('refresh uses server eligibility and a later server rejection never shows a published success',async({page})=>{
 const options:FixtureOptions={status:'private',eligibility:{canPublish:false,reason:'confirmation_required',message:'等待确认款式、用料和价格。',orderId:9}};
 const writes=await setup(page,options);await page.goto('/c/diy?tab=mine');await page.getByRole('button',{name:'发布',exact:true}).click();
 await expect(page.getByText(options.eligibility!.message,{exact:true})).toBeVisible();
 options.eligibility=ready;options.publicationError='订单状态已变化，请重新核验。';
 await page.getByRole('button',{name:'刷新资格',exact:true}).click();
 await page.getByRole('button',{name:'确认发布',exact:true}).click();
 await expect(page.getByRole('alert')).toHaveText('订单状态已变化，请重新核验。');
 await expect(page.getByText('未发布',{exact:true})).toBeVisible();await expect(page.getByText('已发布',{exact:true})).toHaveCount(0);
 options.publicationError=undefined;
 await page.getByRole('button',{name:'刷新资格',exact:true}).click();await page.getByRole('button',{name:'确认发布',exact:true}).click();
 await expect(page.getByText('已发布',{exact:true})).toBeVisible();
 expect(writes).toEqual(['/api/v1/diy/designs/1/status','/api/v1/diy/designs/1/status']);
});
test('publishing a new finalized draft updates the public snapshot without changing existing copies',async({page})=>{
 await setup(page,{draftName:'新定稿标题'});await viewer(page);await page.getByRole('button',{name:'复制并编辑',exact:true}).click();
 await expect(page).toHaveURL(/editor\?design=2$/);await page.goto('/c/diy?tab=mine');
 await page.getByRole('button',{name:'发布新定稿',exact:true}).click();
 await expect(page.getByText('更新后，广场将展示本次定稿作品，已有副本与订单不受影响。',{exact:true})).toBeVisible();
 await page.getByRole('button',{name:'确认更新',exact:true}).click();
 await expect(page.getByText('已发布',{exact:true})).toBeVisible();
 await expect(page.getByRole('button',{name:'发布新定稿',exact:true})).toHaveCount(0);
 await expect(page.getByRole('heading',{name:'返回测试手串 · 副本',exact:true})).toBeVisible();
 await page.goto('/c/diy/1');await expect(page.getByRole('heading',{name:'新定稿标题',exact:true})).toBeVisible();
});
for(const language of ['zh-Hans','zh-Hant'])for(const width of [320,390,509])test(`compact gallery keeps readable bead artwork ${language} ${width}`,async({page})=>{
 await page.setViewportSize({width,height:954});await setup(page,{language,theme:language==='zh-Hant'?'dark':'light'});await page.goto('/c/diy?tab=plaza');
 for(const tab of ['plaza','mine']){
  if(tab==='mine')await page.getByRole('tab',{name:language==='zh-Hant'?'我的設計':'我的设计',exact:true}).click();
  const hero=page.locator('.diy-plaza-compact'),ring=hero.locator('.diy-hero-ornament');
  await expect(ring).toBeVisible();await expect(ring).toHaveText('一珠一心意');await expect(ring.locator('i')).toHaveCount(15);
  const geometry=await hero.evaluate(element=>{
   const box=element.getBoundingClientRect(),copy=element.querySelector('.diy-hero-copy')!.getBoundingClientRect(),ring=element.querySelector('.diy-hero-ornament')!;
   return {height:box.height,width:parseFloat(getComputedStyle(ring).width),fits:copy.left>=box.left&&copy.right<=box.right&&copy.top>=box.top&&copy.bottom<=box.bottom};
  });
  expect(geometry.height).toBeLessThanOrEqual(144);expect(geometry.width).toBe(112);expect(geometry.fits).toBeTruthy();
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBeTruthy();
 }
});
test('editor checkout browser Back keeps saved design and keyboard bead editing',async({page})=>{
 await setup(page);await mine(page);
 await page.getByRole('button',{name:/^去定制/}).click();await page.getByRole('button',{name:'保存并继续',exact:true}).click();await expect(page.getByRole('heading',{name:'确认订单',exact:true})).toBeVisible();
 await page.goBack();await expect(page.getByRole('button',{name:'保存设计',exact:true})).toBeEnabled();
 const count=page.locator('.studio-stage-top small'),preview=page.getByRole('group',{name:/^手串预览/});
 await expect(count).toHaveText('1 / 60 颗');await preview.focus();await preview.press('ArrowRight');
 await expect(page.locator('.studio-accessible-selection')).toHaveText('第 1 颗 测试木珠');
 await expect(page.locator('.studio-bead-menu')).toHaveCount(0);await preview.press('Delete');await expect(count).toHaveText('0 / 60 颗');
 await page.locator('.studio-history').getByRole('button',{name:'撤销',exact:true}).click();await expect(count).toHaveText('1 / 60 颗');
 await back(page).click();await expect(page).toHaveURL(/tab=mine$/);
});
test('repeated back clicks do not skip the originating my-design list',async({page})=>{
 await setup(page);await mine(page);
 // History updates before the lazy editor mounts; the old plaza header has the same selector.
 await expect(page.getByRole('button',{name:'保存设计',exact:true})).toBeEnabled();
 await back(page).evaluate((button:HTMLButtonElement)=>{button.click();button.click();button.click();});
 await expect(page).toHaveURL(/\/c\/diy\?tab=mine$/);expect(await index(page)).toBe(0);
});
test('profile survives an unavailable growth snapshot and BackLink preserves history',async({page})=>{
 await setup(page);await page.goto('/c/profile');await page.locator('a[href="/c/wallet"]').first().click();await expect(page).toHaveURL(/\/c\/wallet$/);
 await page.getByRole('link',{name:'返回我的',exact:true}).click();await expect(page).toHaveURL(/\/c\/profile$/);expect(await index(page)).toBe(0);
 await page.goto('/c/wallet');await page.getByRole('link',{name:'返回我的',exact:true}).click();await expect(page).toHaveURL(/\/c\/profile$/);expect(await index(page)).toBe(0);
});
test('legacy growth rules open within benefits and retain rule history retry and pagination',async({page})=>{
 await page.setViewportSize({width:320,height:844});await setup(page);
 const levels=Array.from({length:5},(_,i)=>({code:i+1,name:`测试等级${i+1}`,threshold:i*100,goodsRateBps:10000,serviceRateBps:10000,couponMinimumCents:0,couponValueCents:0,benefit:'测试权益'}));
 const config={levels,tasks:[{kind:'note',award:1,limit:1,period:'day'}],monthlyGrowthLimit:50,monthlyDiscountLimitCents:1000,goodsDiscountCapCents:100,serviceDiscountCapCents:100,observationDays:7,couponDays:30};
 const rule={version:'fixture-v2',summary:'当前规则测试',effectiveAt:1792425600,createdAt:1792425600,status:'current',config};
 let failPageTwo=true;const rulePages:number[]=[];
 await page.route('**/api/v1/payments/growth/**',async route=>{
  const url=new URL(route.request().url());let data:unknown=[];
  if(url.pathname.endsWith('/overview'))data={total:0,level:levels[0],levels,nextThreshold:100,remaining:100,pending:0,monthlyEarned:0,monthlyLimit:50,badgeVisible:false,ruleVersion:rule.version,revision:1,updatedAt:1,serverTime:1,rule,discountsEnabled:false,coupons:[],tasks:[]};
  else if(url.pathname.endsWith('/notice/claim'))data={notice:null};
  else if(url.pathname.endsWith('/rules')){
   const p=Number(url.searchParams.get('page') || 1);rulePages.push(p);
   if(p===2&&failPageTwo)return route.fulfill({status:503,json:{code:500,message:'历史版本暂时不可用'}});
   data={items:[p===1?rule:{...rule,version:'fixture-v1',status:'historical'}],hasMore:p===1,currentVersion:rule.version};
  }
  await route.fulfill({json:{code:0,data}});
 });
 await page.goto('/c/growth?tab=rules');
 await expect.poll(()=>new URL(page.url()).searchParams.get('tab')).toBe('benefits');
 expect(new URL(page.url()).searchParams.get('section')).toBe('rules');
 const tabs=page.locator('.growth-tabs');
 await expect(tabs.getByRole('button')).toHaveText(['成长档案','成长任务','成长明细','等级权益']);
 await expect(tabs.getByRole('button',{name:'等级权益',exact:true})).toHaveAttribute('aria-current','page');
 const disclosure=page.locator('.growth-benefit-rules'),summary=page.locator('.growth-benefit-rules > summary');
 await expect(disclosure).toHaveAttribute('open','');await expect(summary).toBeFocused();
 const rules=disclosure.locator('.growth-rules');
 await expect(rules.getByRole('heading',{name:'获取规则',exact:true})).toBeVisible();
 await expect(rules.getByRole('heading',{name:'升级规则',exact:true})).toBeVisible();
 await expect(rules.getByRole('heading',{name:'折扣规则',exact:true})).toBeVisible();
 await rules.getByRole('button',{name:'下一页',exact:true}).click();
 await expect(rules.getByRole('alert')).toContainText('历史版本暂时不可用');
 failPageTwo=false;await rules.getByRole('button',{name:'重试',exact:true}).click();
 await expect(rules.locator('summary')).toContainText('fixture-v1');
 expect(rulePages.filter(p=>p===2).length).toBeGreaterThanOrEqual(2);
 await summary.click();await expect(disclosure).not.toHaveAttribute('open','');
 await tabs.getByRole('button',{name:'成长档案',exact:true}).click();
 await page.getByRole('button',{name:'查看当前规则',exact:true}).click();
 await expect(disclosure).toHaveAttribute('open','');
 await expect(rules.locator('summary')).toContainText('fixture-v2');
 await expect(tabs.getByRole('button')).toHaveCount(4);
});
