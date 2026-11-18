import {test,expect,type Page} from '@playwright/test';
const now=Math.floor(Date.now()/1000);
const emptyJourneyIndex={list:[],total:0,page:1,counts:{active:0,pending:0,confirmed:0,executing:0,receipt:0,complete:0,revision:0}};
const campaign={id:1,title:'秋日有礼 · 一份温暖的相逢',kind:'pool',prizeName:'东方香囊礼盒',image:'',description:'以草木香气，为日常留一份安静。\n礼盒含香囊一枚与便携礼袋。',rules:'每人每期消耗 10 积分参与一次。平台承担奖品与中国大陆地区配送费用。中奖后请填写完整地址。',prizeValue:12800,budget:18000,pointsCost:10,prizeQuantity:1,capacity:100,participantCount:99,awardedCount:0,startsAt:now-3600,endsAt:now+3600,status:'published',phase:'open',version:1,drawnAt:0,poolDigest:'',announcement:'',algorithm:'crypto-rand-uniform-v1'};
async function auth(page:Page,role='customer'){await page.addInitScript(role=>{localStorage.setItem('h5_token','test');localStorage.setItem('h5-auth',JSON.stringify({state:{role,token:'test',userId:1,displayName:'验收用户'},version:0}));},role)}
for(const width of [375,768,1280])test(`H5 pool record claim delivery ${width}`,async({page})=>{
 await page.setViewportSize({width,height:900});await auth(page);let c={...campaign};let mine:any=null;let order:any=null;let joins=0;let claimed:any;
 await page.route('**/api/v1/**',async route=>{const r=route.request(),p=new URL(r.url()).pathname;let data:any=[];
  if(p.endsWith('/campaigns/1/join')){expect(r.postDataJSON()).toMatchObject({expectedPoints:10});expect(r.postDataJSON().requestKey).toMatch(/^[a-z0-9-]{36}$/i);joins++;mine={id:1,campaignId:1,code:'WX00000001-000100',outcome:'pending',createdAt:now,title:c.title,pointsSpent:10};c.participantCount=100;c.phase='full';data=mine}
  else if(p.endsWith('/campaigns/1'))data={campaign:c,mine,pointsBalance:mine?90:100,winners:mine?.outcome==='won'?[mine]:[]};else if(p.endsWith('/points'))data={balance:100};else if(p.endsWith('/campaigns'))data=[c];else if(p.endsWith('/entries'))data=mine?[mine]:[];
  else if(p.endsWith('/orders/1/claim')){claimed=r.postDataJSON();order={...order,...claimed,status:'pending',claimedAt:now};data={success:true}}
  else if(p.endsWith('/orders/1/complete')){order.status='completed';order.completedAt=now;data={success:true}}
  else if(p.endsWith('/orders'))data=order?[order]:[];else if(p.endsWith('/users/addresses'))data=[{id:1,name:'验收用户',phone:'13800000000',province:'上海市',city:'上海市',district:'浦东新区',detail:'测试路 100 号',isDefault:true}];
  await route.fulfill({json:{code:0,message:'ok',data}})
 });
 await page.goto('http://127.0.0.1:5386/c/rewards?tab=pool');await expect(page.getByRole('heading',{name:'积分中心',exact:true})).toBeVisible();await expect(page.getByRole('tab',{name:'奖池'})).toBeVisible();await page.screenshot({path:test.info().outputPath(`askxuan-rewards-list-${width}.png`),fullPage:true,animations:'disabled'});await page.getByRole('link',{name:/东方香囊礼盒/}).click();await expect(page.getByRole('button',{name:'10 积分参与'})).toBeVisible();await page.getByRole('button',{name:'10 积分参与'}).click();expect(joins).toBe(0);await expect(page.getByRole('dialog',{name:'确认积分参与'})).toBeVisible();await page.getByRole('button',{name:'确认扣除 10 积分'}).click();await page.getByRole('button',{name:'关闭',exact:true}).click();await expect(page.getByRole('button',{name:'已参与',exact:true})).toBeDisabled();expect(joins).toBe(1);await expect(page.getByText(/按当前人数估算\s+1%/)).toBeVisible();await page.reload();await expect(page.getByRole('button',{name:'已参与',exact:true})).toBeDisabled();expect(joins).toBe(1);
 mine.outcome='won';c={...c,status:'drawn',phase:'drawn',awardedCount:1,drawnAt:now,poolDigest:'a'.repeat(64),announcement:'100 人参与，1 人中奖。'};order={id:1,campaignId:1,entryId:1,prizeName:c.prizeName,code:mine.code,status:'awaiting_address',receiver:'',mobile:'',address:'',carrier:'',trackingNo:'',createdAt:now,claimedAt:0,shippedAt:0,completedAt:0};await page.reload();await page.getByText('开奖留档').click();await expect(page.getByText('a'.repeat(64),{exact:true})).toBeVisible();await page.screenshot({path:test.info().outputPath(`askxuan-rewards-detail-${width}.png`),fullPage:true,animations:'disabled'});await page.getByRole('link',{name:'查看奖品与领奖'}).click();await page.getByRole('button',{name:'填写收货地址'}).click();const dialog=page.getByRole('dialog');await expect(dialog).toBeVisible();await page.getByLabel('选择已有地址').selectOption('1');await expect(page.getByLabel('收货人',{exact:true})).toHaveValue('验收用户');await page.screenshot({path:test.info().outputPath(`askxuan-rewards-claim-${width}.png`),fullPage:true,animations:'disabled'});await page.getByRole('button',{name:'确认地址，等待发货'}).click();await expect(dialog).not.toBeVisible();expect(claimed.address).toContain('测试路');await expect(page.getByText('待发货',{exact:true}).first()).toBeVisible();order.status='shipped';order.carrier='顺丰';order.trackingNo='SF-TEST-100';order.shippedAt=now;await page.getByRole('tab',{name:'抽奖记录'}).click();await page.getByRole('tab',{name:'我的奖品'}).click();page.once('dialog',d=>d.accept());await page.getByRole('button',{name:'确认收货'}).click();await expect(page.getByText('已完成',{exact:true})).toBeVisible();expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBeTruthy();
});
test('wheel persists immediate result and shows disclosed odds',async({page})=>{await page.setViewportSize({width:390,height:844});await auth(page);let mine:any=null;let joins=0;await page.route('**/api/v1/**',async route=>{const p=new URL(route.request().url()).pathname;let data:any={pointsBalance:mine?90:100,campaign:{...campaign,id:2,kind:'wheel',participantCount:mine?1:0,awardedCount:mine?1:0},mine,winners:mine?[mine]:[]};if(p.endsWith('/join')){joins++;mine={id:2,campaignId:2,code:'WX00000002-000001',outcome:'won',createdAt:now,title:'转盘测试',pointsSpent:10};data=mine}await route.fulfill({json:{code:0,message:'ok',data}})});await page.goto('http://127.0.0.1:5386/c/rewards/2');await expect(page.locator('.reward-facts')).toHaveCount(0);await page.getByRole('button',{name:'活动规则',exact:true}).click();await expect(page.getByText('奖品与概率')).toBeVisible();await page.getByRole('button',{name:'关闭',exact:true}).click();await page.getByRole('button',{name:'10 积分转一次'}).click();expect(joins).toBe(0);await page.getByRole('button',{name:'确认扣除 10 积分'}).click();await page.getByRole('button',{name:'关闭',exact:true}).click();await expect(page.getByRole('button',{name:/上次：.*查看/})).toBeVisible();await page.getByRole('button',{name:'抽奖记录',exact:true}).click();await expect(page.getByRole('dialog',{name:'抽奖记录'})).toContainText('WX00000002-000001');await page.getByRole('button',{name:'关闭',exact:true}).click();await page.screenshot({path:test.info().outputPath('askxuan-rewards-wheel.png'),fullPage:true,animations:'disabled'});await page.reload();await expect(page.getByRole('button',{name:/上次：.*查看/})).toBeEnabled();expect(joins).toBe(1)});
test('H5 header search only home and sign out only profile',async({page})=>{await auth(page);await page.route('**/api/v1/**',r=>r.fulfill({json:{code:0,message:'ok',data:new URL(r.request().url()).pathname.endsWith('/bookings/journeys')?emptyJourneyIndex:{list:[],total:0,balance:0}}}));for(const p of ['/c','/c/','/c/chats','/c/ai','/c/shop','/c/profile','/c/points','/c/rewards']){await page.goto(`http://127.0.0.1:5386${p}`);await expect(page.locator('header').getByRole('button',{name:/退出/})).toHaveCount(0);await expect(page.locator('header').getByRole('link',{name:'搜索',exact:true})).toHaveCount(p==='/c'||p==='/c/'?1:0)}await page.goto('http://127.0.0.1:5386/c/profile');await expect(page.getByRole('link',{name:/服务进度/})).toContainText('0 进行中');await expect(page.getByRole('button',{name:'退出登录',exact:true})).toBeVisible();page.once('dialog',d=>d.accept());await page.getByRole('button',{name:'退出登录',exact:true}).click();expect(await page.evaluate(()=>localStorage.getItem('h5_token'))).toBeNull()});
test('master profile retains exit after removing global header button',async({page})=>{await auth(page,'master');await page.route('**/api/v1/**',r=>r.fulfill({json:{code:0,message:'ok',data:new URL(r.request().url()).pathname.endsWith('/bookings/journeys')?emptyJourneyIndex:{list:[],total:0,dharmaName:'测试法师',authStatus:'approved'}}}));await page.goto('http://127.0.0.1:5386/m/profile');await expect(page.locator('header').getByRole('button',{name:/退出/})).toHaveCount(0);await expect(page.getByRole('button',{name:'退出登录',exact:true})).toBeVisible();page.once('dialog',d=>d.accept());await page.getByRole('button',{name:'退出登录',exact:true}).click();await expect(page).toHaveURL(/\/m\/login/)});
test('platform draft budget validation publish audit and ship',async({page})=>{
 const token='e30.'+Buffer.from(JSON.stringify({roles:['platform_super'],clientId:'platform-admin'})).toString('base64url')+'.test';await page.addInitScript(t=>localStorage.setItem('df_platform_admin_token',t),token);let saved:any,published=false,shipment:any;await page.route('**/api/v1/**',async route=>{const r=route.request(),p=new URL(r.url()).pathname;let data:any={};if(p.endsWith('/campaigns')&&r.method()==='POST'){saved=r.postDataJSON();data={...saved,id:3}}else if(p.endsWith('/campaigns'))data=[{...campaign,status:published?'published':'draft',phase:published?'open':'draft'}];else if(p.endsWith('/publish')){published=true;data={success:true}}else if(p.endsWith('/audit'))data=[{id:1,actor:'admin',action:'publish',detail:'规则冻结，10 积分参与',createdAt:now}];else if(p.endsWith('/campaigns/1'))data={campaign,winners:[]};else if(p.endsWith('/orders/1/ship')){shipment=r.postDataJSON();data={success:true}}else if(p.endsWith('/orders'))data=[{id:1,prizeName:campaign.prizeName,code:'WX00000001-000001',status:'pending',receiver:'验收用户',mobile:'13800000000',address:'上海测试地址',carrier:'',trackingNo:'',shippedAt:0}];await route.fulfill({json:{code:0,message:'ok',data}})});
 await page.goto('http://127.0.0.1:5387/marketing/rewards');await page.getByRole('button',{name:'添加抽奖商品'}).click();let d=page.getByRole('dialog');await expect(d).toBeVisible();await expect(d.getByText('活动标题',{exact:true})).toHaveCount(0);await expect(d.getByRole('button',{name:'添加奖品'})).toHaveCount(0);await d.locator('.rewards-prize-form').getByRole('textbox').first().fill('香囊礼盒');await d.locator('textarea').nth(0).fill('平台预算奖品详情');await expect(d.getByRole('button',{name:'保存草稿'})).toBeInViewport();await page.screenshot({path:test.info().outputPath('askxuan-rewards-admin-create.png'),fullPage:true,animations:'disabled'});await d.getByRole('button',{name:'保存草稿'}).click();await expect(d).not.toBeVisible();expect(saved.title).toBe('香囊礼盒');expect(saved.prizes).toHaveLength(1);expect(saved.budget).toBe(15000);expect(saved.pointsCost).toBe(10);expect(saved.prizeValue).toBe(10000);expect(saved.endsAt).toBeGreaterThan(saved.startsAt);
 await page.getByRole('button',{name:'发布',exact:true}).click();await page.getByRole('button',{name:'确认发布',exact:true}).click();await expect.poll(()=>published).toBe(true);await page.getByRole('button',{name:'详情 / 审计'}).click();d=page.getByRole('dialog');await expect(d.getByRole('heading',{name:'操作留档',exact:true})).toBeVisible();await d.getByRole('button',{name:/关闭此对话框|Close this dialog/}).click();await page.getByRole('tab',{name:'奖品履约'}).click();await page.getByRole('button',{name:'登记发货'}).click();d=page.getByRole('dialog');await d.getByRole('textbox').nth(0).fill('顺丰');await d.getByRole('textbox').nth(1).fill('SF100000');await d.getByRole('button',{name:'确认发货'}).click();await expect(d).not.toBeVisible();expect(shipment).toEqual({carrier:'顺丰',trackingNo:'SF100000'});await page.screenshot({path:test.info().outputPath('askxuan-rewards-admin-orders.png'),fullPage:true,animations:'disabled'});
});

test('points is the activity entrance and wheel tab deep links work',async({page})=>{
 await auth(page); await page.setViewportSize({width:390,height:844});
 await page.route('**/api/v1/**',async r=>{const p=new URL(r.request().url()).pathname;const data=p.endsWith('/points')?{balance:100}:p.endsWith('/campaigns')?[]:p.includes('ledger')?[]:{list:[],total:0};await r.fulfill({json:{code:0,message:'ok',data}})});
 await page.goto('http://127.0.0.1:5386/c/points');for(const name of ['积分转盘','积分商城','奖池'])await expect(page.getByRole('tab',{name,exact:true})).toBeVisible();
 await expect(page.getByRole('tab',{name:'积分转盘',exact:true})).toHaveAttribute('aria-selected','true');
 await page.getByRole('tab',{name:'积分商城',exact:true}).click();await expect(page).toHaveURL(/points\?tab=mall/);
 for(const path of ['/c','/c/profile']) {await page.goto('http://127.0.0.1:5386'+path);await expect(page.locator('a[href^="/c/rewards"]')).toHaveCount(0)}
});
test('insufficient balance and cancelled confirmation never submit a join',async({page})=>{
 await auth(page);let balance=9,joins=0,phase='open';
 await page.route('**/api/v1/**',async r=>{if(r.request().method()==='POST')joins++;await r.fulfill({json:{code:0,message:'ok',data:{campaign:{...campaign,phase},mine:null,winners:[],pointsBalance:balance}}})});
 await page.goto('http://127.0.0.1:5386/c/rewards/1');await expect(page.getByRole('button',{name:'积分不足',exact:true})).toBeDisabled();expect(joins).toBe(0);
 balance=100;await page.reload();await page.getByRole('button',{name:'10 积分参与'}).click();await expect(page.getByRole('dialog',{name:'确认积分参与'})).toContainText('参与后剩余 90 积分');await page.getByRole('button',{name:'再想想'}).click();expect(joins).toBe(0);await expect(page.getByRole('dialog',{name:'确认积分参与'})).not.toBeVisible();phase='exhausted';await page.reload();await expect(page.getByRole('button',{name:'已结束',exact:true})).toBeDisabled();expect(joins).toBe(0);
});

for(const width of [320,390,566,768])test(`wheel is a compact game with secondary rules and records ${width}`,async({page})=>{
 await auth(page);await page.setViewportSize({width,height:900});let writes=0;
 const mine={id:2,campaignId:2,code:'WX-FOCUS-LOST',outcome:'lost',createdAt:now,title:'幸运转盘',pointsSpent:10};
 await page.route('**/api/v1/**',async r=>{if(r.request().method()!=='GET')writes++;await r.fulfill({json:{code:0,data:{campaign:{...campaign,id:2,kind:'wheel',participantCount:1},mine,winners:[],pointsBalance:90}}})});
 await page.goto('http://127.0.0.1:5386/c/rewards/2');
 await expect(page.locator('.reward-facts,.reward-ticket,.reward-detail-page > .reward-record,.reward-cta,.reward-notice')).toHaveCount(0);
 await expect(page.getByRole('button',{name:/上次：.*查看/})).toBeInViewport();
 await page.getByRole('button',{name:/上次：.*查看/}).click();await expect(page.getByRole('dialog',{name:'参与结果'})).toContainText('本期未中奖');await expect(page.getByRole('dialog',{name:'参与结果'})).not.toContainText('WX-FOCUS-LOST');await page.getByRole('button',{name:'关闭',exact:true}).click();
 await page.screenshot({path:test.info().outputPath(`askxuan-wheel-focus-${width}.png`),fullPage:true});
 await page.getByRole('button',{name:'活动规则',exact:true}).click();await expect(page.getByRole('dialog',{name:'活动规则'})).not.toContainText('奖品数量');await page.getByRole('button',{name:'关闭',exact:true}).click();
 await page.getByRole('button',{name:'抽奖记录',exact:true}).click();await expect(page.getByRole('dialog',{name:'抽奖记录'})).toContainText('WX-FOCUS-LOST');await page.getByRole('button',{name:'关闭',exact:true}).click();
 expect(writes).toBe(0);expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBeTruthy();
});


test('admin saves independent pool capacities and groups drawn results by prize',async({page})=>{
 const token='e30.'+Buffer.from(JSON.stringify({roles:['platform_super'],clientId:'platform-admin'})).toString('base64url')+'.test';
 await page.addInitScript(t=>localStorage.setItem('df_platform_admin_token',t),token);
 const prizes=[{id:11,name:'平安香囊',capacity:2,participantCount:2,drawnAt:now,phase:'drawn',announcement:'本奖品已开奖',poolDigest:'first-prize-digest',awardedCount:1},{id:12,name:'手串礼盒',capacity:5,participantCount:1,drawnAt:0,phase:'open',announcement:'',poolDigest:'',awardedCount:0}].map(p=>({...p,kind:'physical',image:'',value:1000,quantity:1,platform:'',instructions:'',expiresAt:0,redemptionUrl:''}));
 const pool={...campaign,id:5,prizes,prizeName:'2 种好礼',prizeQuantity:2,capacity:7,participantCount:3,awardedCount:1};let saved:any;
 await page.route('**/api/v1/**',async r=>{const req=r.request(),p=new URL(req.url()).pathname;let data:any=[];
  if(req.method()==='PUT'){saved=req.postDataJSON();data={...pool,...saved};}
  else if(p.endsWith('/campaigns'))data=[{...pool,status:'draft',phase:'draft'}];
  else if(p.endsWith('/campaigns/5'))data={campaign:pool,winners:[{id:1,prizeId:11,code:'POOL-FIRST-WINNER'}]};
  await r.fulfill({json:{code:0,data}});
 });
 await page.goto('http://127.0.0.1:5387/marketing/rewards');
 await page.getByRole('button',{name:'编辑全部商品',exact:true}).click();let dialog=page.getByRole('dialog',{name:'编辑抽奖商品'});
 await expect(dialog.locator('.rewards-prize-form')).toHaveCount(2);await expect(dialog.locator('input[placeholder="填写概率"]')).toHaveCount(0);await expect(dialog.locator('.rewards-slot-grid')).toHaveCount(0);
 await dialog.locator('.rewards-prize-form').nth(1).locator('.el-form-item').filter({hasText:'参与人数上限'}).getByRole('spinbutton').fill('8');
 await dialog.getByRole('button',{name:'保存草稿'}).click();await expect(dialog).not.toBeVisible();
 expect(saved.prizes.map((p:any)=>p.capacity)).toEqual([2,8]);expect(saved.capacity).toBe(10);expect(saved.pointsCost).toBe(10);expect(saved.wheelSlots).toEqual([]);expect(saved.prizes.every((p:any)=>p.probabilityBps===undefined)).toBe(true);
 const row1=page.getByRole('row').filter({hasText:pool.prizes[0].name}),row2=page.getByRole('row').filter({hasText:pool.prizes[1].name});
 await expect(row1).toContainText('已开奖');await expect(row2).toContainText('参与中');await expect(page.getByText('期号',{exact:true})).toHaveCount(0);
 await row1.getByRole('button',{name:'详情 / 审计'}).click();dialog=page.getByRole('dialog',{name:'活动详情与操作留档'});
 const cards=dialog.locator('.rewards-prize-form');await expect(cards.nth(0)).toContainText('2 / 2 人');await expect(cards.nth(0)).toContainText('POOL-FIRST-WINNER');await expect(cards.nth(0)).toContainText('first-prize-digest');await expect(cards).toHaveCount(1);await dialog.getByRole('button',{name:/关闭此对话框|Close this dialog/}).click();
 await row2.getByRole('button',{name:'详情 / 审计'}).click();await expect(cards).toHaveCount(1);await expect(cards.first()).toContainText('1 / 5 人');await expect(cards.first()).toContainText('参与中');await expect(cards.first()).not.toContainText('POOL-FIRST-WINNER');
});

test('admin detects pool capacity ignored by an old service',async({page})=>{
 const token='e30.'+Buffer.from(JSON.stringify({roles:['platform_super'],clientId:'platform-admin'})).toString('base64url')+'.test';await page.addInitScript(t=>localStorage.setItem('df_platform_admin_token',t),token);
 let writes=0;const draft={...campaign,status:'draft',phase:'draft',participantCount:0};
 await page.route('**/api/v1/**',async r=>{const req=r.request(),p=new URL(req.url()).pathname;let data:any=[];if(req.method()==='PUT'){writes++;data=draft;}else if(p.endsWith('/campaigns'))data=[draft];await r.fulfill({json:{code:0,data}})});
 await page.goto('http://127.0.0.1:5387/marketing/rewards');await page.getByRole('button',{name:'编辑',exact:true}).click();const dialog=page.getByRole('dialog',{name:'编辑抽奖商品'});await dialog.getByRole('button',{name:'保存草稿'}).click();
 await expect(page.getByText('奖品参与人数未保存，请联系管理员完成活动服务升级后重试')).toBeVisible();await expect(dialog).toBeVisible();expect(writes).toBe(1);await expect(page.getByText('草稿已保存',{exact:true})).toHaveCount(0);
});


test('admin pool digital prize requires a full day to redeem after cutoff',async({page})=>{
 const token='e30.'+Buffer.from(JSON.stringify({roles:['platform_super'],clientId:'platform-admin'})).toString('base64url')+'.test';await page.addInitScript(t=>localStorage.setItem('df_platform_admin_token',t),token);
 const end=now+86400;const draft={...campaign,status:'draft',phase:'draft',endsAt:end,prizes:[{id:11,name:'礼品卡',kind:'code',image:'',value:1000,quantity:1,capacity:5,awardedCount:0,platform:'测试平台',instructions:'按说明兑换',expiresAt:end+86399,redemptionUrl:''}]};let writes=0;
 await page.route('**/api/v1/**',async r=>{const req=r.request(),p=new URL(req.url()).pathname;let data:any=[];if(req.method()==='PUT'){writes++;data={...draft,...req.postDataJSON()};}else if(p.endsWith('/campaigns'))data=[draft];else if(p.endsWith('/campaigns/1'))data={campaign:draft,winners:[]};await r.fulfill({json:{code:0,data}})});
 await page.goto('http://127.0.0.1:5387/marketing/rewards');await page.getByRole('button',{name:'编辑',exact:true}).click();const dialog=page.getByRole('dialog',{name:'编辑抽奖商品'});await dialog.getByRole('button',{name:'保存草稿'}).click();
 await expect(page.getByText('请补全各奖品，奖池兑换有效期须距活动截止至少 24 小时')).toBeVisible();expect(writes).toBe(0);
 const expiry=new Date((end+86400)*1000),pad=(n:number)=>String(n).padStart(2,'0');
 const value=`${expiry.getFullYear()}-${pad(expiry.getMonth()+1)}-${pad(expiry.getDate())} ${pad(expiry.getHours())}:${pad(expiry.getMinutes())}:${pad(expiry.getSeconds())}`;
 await dialog.locator('input[placeholder="截止后至少 24 小时"]').fill(value);await dialog.locator('input[placeholder="截止后至少 24 小时"]').press('Tab');await dialog.getByRole('button',{name:'保存草稿'}).click();await expect(dialog).not.toBeVisible();expect(writes).toBe(1);
});


test('H5 pool participation stays independent when one prize draws early',async({page})=>{
 await auth(page);await page.setViewportSize({width:390,height:844});
 const prizes=[{id:11,name:'平安香囊',capacity:1},{id:12,name:'手串礼盒',capacity:3}].map(p=>({...p,participantCount:0,drawnAt:0,phase:'open',announcement:'',poolDigest:'',awardedCount:0,kind:'physical',image:'',value:1000,quantity:1,platform:'',instructions:'',expiresAt:0,redemptionUrl:''}));
 const pool={...campaign,id:6,prizes,prizeName:'2 种好礼',prizeQuantity:2,capacity:4,participantCount:0};let balance=30;const entries:any[]=[];const joins:number[]=[];
 await page.route('**/api/v1/**',async r=>{const req=r.request(),p=new URL(req.url()).pathname;let data:any=[];
  if(p.endsWith('/join')){const b=req.postDataJSON();joins.push(b.prizeId);expect(b.expectedPoints).toBe(10);const prize=prizes.find(p=>p.id===b.prizeId)!;prize.participantCount++;const drawn=prize.participantCount===prize.capacity;prize.phase=drawn?'drawn':'open';prize.drawnAt=drawn?now:0;prize.announcement=drawn?'本奖品已开奖':'';balance-=10;const entry={id:entries.length+1,campaignId:6,prizeId:prize.id,prizeName:prize.name,code:`POOL-${prize.id}`,outcome:drawn?'won':'pending',createdAt:now,title:pool.title,pointsSpent:10};entries.push(entry);data=entry;}
  else if(p.endsWith('/campaigns/6'))data={campaign:pool,mine:entries.at(-1)||null,mineEntries:entries,pointsBalance:balance,winners:entries.filter(e=>e.outcome==='won')};
  else if(p.endsWith('/campaigns')){
   const pageNumber=Number(new URL(req.url()).searchParams.get('page'));
   data=pageNumber===1?Array.from({length:20},(_,i)=>({...campaign,id:100+i,prizes:[],prizeName:'纪念商品'+i,drawnAt:now,phase:'drawn'})):[pool];
  } else if(p.endsWith('/points'))data={balance};
  else if(p.endsWith('/entries'))data=entries;
  await r.fulfill({json:{code:0,data}});
 });
 await page.goto('http://127.0.0.1:5386/c/rewards/6');
 await expect(page).toHaveURL(/points\?tab=pool$/);
 const catalog=page.locator('.pool-catalog'),firstCard=catalog.getByRole('link',{name:/平安香囊/}),secondCard=catalog.getByRole('link',{name:/手串礼盒/});
 await expect(catalog.getByRole('link')).toHaveCount(22);
 await expect(catalog.getByRole('link').first()).toHaveAttribute('href','/c/rewards/6?prize=11');
 await expect(catalog).not.toContainText(/第\s*\d+\s*期/);
 await firstCard.click();const first=page.locator('.reward-pool-prize[aria-label="平安香囊"]'),second=page.locator('.reward-pool-prize[aria-label="手串礼盒"]');
 await expect(second).toHaveCount(0);await first.getByRole('button',{name:'10 积分参与',exact:true}).click();await page.getByRole('button',{name:'确认扣除 10 积分'}).click();await page.getByRole('button',{name:'关闭',exact:true}).click();
 await expect(first).toContainText('本奖品已开奖');await expect(first).toContainText('POOL-11');await expect(first.getByRole('button',{name:'已参与',exact:true})).toBeDisabled();
 await page.goto('http://127.0.0.1:5386/c/points?tab=pool');await expect(firstCard).toContainText('已开奖');await expect(firstCard).toContainText('查看结果');await expect(secondCard).toContainText('去参与');
 await secondCard.click();await expect(page).toHaveURL(/rewards\/6\?prize=12$/);await expect(second).not.toContainText('POOL-11');
 await second.getByRole('button',{name:'10 积分参与',exact:true}).click();await page.getByRole('button',{name:'确认扣除 10 积分'}).click();await page.getByRole('button',{name:'关闭',exact:true}).click();await page.reload();
 await expect(first).toHaveCount(0);await expect(second.getByRole('button',{name:'已参与',exact:true})).toBeDisabled();expect(joins).toEqual([11,12]);expect(balance).toBe(10);expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
});
