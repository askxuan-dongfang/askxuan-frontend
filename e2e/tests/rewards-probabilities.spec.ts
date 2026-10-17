import {test,expect} from '@playwright/test';

const now=Math.floor(Date.now()/1000);
const prizes=[{id:11,name:'平安香囊',kind:'physical',probabilityBps:1234},{id:12,name:'礼品卡 50 元',kind:'code',probabilityBps:250},{id:13,name:'商城兑换券',kind:'link',probabilityBps:500}].map(p=>({...p,image:'',value:5000,quantity:1000,awardedCount:900,stockCount:0,platform:p.kind==='physical'?'':'测试平台',instructions:p.kind==='physical'?'':'仅本地测试',expiresAt:p.kind==='physical'?0:now+864000,redemptionUrl:''}));
const campaign={id:4,title:'积分好礼',kind:'wheel',prizes,prizeName:'三种好礼',image:'',description:'本期好礼',rules:'每人每期一次',prizeValue:5000,budget:20000000,pointsCost:10,prizeQuantity:3000,capacity:10000,participantCount:8000,awardedCount:2700,startsAt:now-3600,endsAt:now+86400,status:'published',phase:'open',version:1,drawnAt:0,poolDigest:'',announcement:'',algorithm:'crypto-rand-fixed-bps-v1'};

for(const width of [320,1280])test(`prize details and fixed odds without inventory ${width}`,async({page},info)=>{
 await page.setViewportSize({width,height:900});
 await page.addInitScript(()=>{localStorage.setItem('h5_token','local-only');localStorage.setItem('h5-auth',JSON.stringify({state:{token:'local-only',role:'customer',userId:99026},version:0}));});
 let writes=0;
 await page.route('**/api/v1/**',async r=>{if(r.request().method()!=='GET')writes++;await r.fulfill({json:{code:0,data:{campaign,mine:null,winners:[],pointsBalance:100}}});});
 await page.goto('http://127.0.0.1:5386/c/rewards/4');
 await expect(page.locator('.wheel-prize-preview')).toHaveCount(0);
 await expect(page.locator('.wheel-experience')).not.toContainText(/库存|有货|没货|剩余.*份/);
 await page.locator('[data-prize-id="12"]').first().click();
 const detail=page.getByRole('dialog',{name:'奖品详情'});
 await expect(detail).toContainText('礼品卡 50 元');await expect(detail).toContainText('2.5%');
 await expect(detail).not.toContainText(/库存|剩余.*份/);await detail.getByRole('button',{name:'关闭'}).click();
 await page.locator('[data-prize-id="11"]').first().focus();await page.keyboard.press('Enter');
 await expect(detail).toContainText('12.34%');await detail.getByRole('button',{name:'关闭'}).click();
 await page.getByRole('button',{name:'活动规则',exact:true}).click();
 const rules=page.getByRole('dialog',{name:'活动规则'});await expect(rules).toContainText('80.16%');await expect(rules).not.toContainText(/库存|奖品数量|剩余.*份/);
 await rules.getByRole('button',{name:'关闭'}).click();
 const bounds=await page.locator('.reward-wheel-art').boundingBox();expect(bounds).toBeTruthy();expect(Math.abs(bounds!.width-bounds!.height)).toBeLessThan(1);
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBeTruthy();expect(writes).toBe(0);
 await page.screenshot({path:info.outputPath(`wheel-${width}.png`),fullPage:true});
});

test('admin rejects excess probability and saves precise published odds',async({page})=>{
 const token='e30.'+Buffer.from(JSON.stringify({roles:['platform_super'],clientId:'platform-admin'})).toString('base64url')+'.test';
 await page.addInitScript(t=>localStorage.setItem('df_platform_admin_token',t),token);
 let saved:any;
 await page.route('**/api/v1/**',async r=>{const req=r.request(),p=new URL(req.url()).pathname;let data:any=[];
 if(req.method()==='PUT'){saved=req.postDataJSON();data={...saved,id:4};}
 else if(p.endsWith('/campaigns'))data=[{...campaign,status:'draft',phase:'draft',participantCount:0,awardedCount:0}];
 else if(p.endsWith('/campaigns/4'))data={campaign:{...campaign,...saved,status:'draft',phase:'draft'},winners:[]};
 await r.fulfill({json:{code:0,data}});});
 await page.goto('http://127.0.0.1:5387/marketing/rewards');await page.getByRole('button',{name:'编辑',exact:true}).click();
 const dialog=page.getByRole('dialog',{name:'编辑活动草稿'});const probability=dialog.locator('input[placeholder="填写概率"]').first();
 await probability.fill('99');await dialog.getByRole('button',{name:'保存草稿'}).click();await expect(page.getByText('请填写每项中奖概率（0.01%–100%），总和不能超过 100%')).toBeVisible();expect(saved).toBeUndefined();
 await expect(dialog.locator('.rewards-slot-grid .el-select')).toHaveCount(10);
 await probability.fill('12.34');await dialog.getByRole('button',{name:'保存草稿'}).click();await expect(dialog).not.toBeVisible();expect(saved.prizes.map((p:any)=>p.probabilityBps)).toEqual([1234,250,500]);expect(saved.wheelSlots).toHaveLength(10);expect(new Set(saved.wheelSlots)).toEqual(new Set([0,1,2,-1]));
});

test('admin refuses to publish or confirm probability ignored by an old service',async({page})=>{
 const token='e30.'+Buffer.from(JSON.stringify({roles:['platform_super'],clientId:'platform-admin'})).toString('base64url')+'.test';
 await page.addInitScript(t=>localStorage.setItem('df_platform_admin_token',t),token);
 const legacy={...campaign,prizes:undefined,status:'draft',phase:'draft',participantCount:0,awardedCount:0};let writes=0,publishes=0;
 await page.route('**/api/v1/**',async r=>{const req=r.request(),p=new URL(req.url()).pathname;let data:any=[];
  if(p.endsWith('/publish'))publishes++;
  if(req.method()==='PUT'){writes++;data=legacy;}
  else if(p.endsWith('/campaigns'))data=[legacy];
  await r.fulfill({json:{code:0,data}});
 });
 await page.goto('http://127.0.0.1:5387/marketing/rewards');await page.getByRole('button',{name:'发布',exact:true}).click();
 await expect(page.getByText('请先编辑并成功保存每项中奖概率，再发布活动')).toBeVisible();expect(publishes).toBe(0);
 await page.getByRole('button',{name:'编辑',exact:true}).click();const dialog=page.getByRole('dialog',{name:'编辑活动草稿'});
 await dialog.locator('input[placeholder="填写概率"]').fill('12.34');await dialog.getByRole('button',{name:'保存草稿'}).click();
 await expect(page.getByText('概率或转盘排布未保存，请联系管理员完成活动服务升级后重试')).toBeVisible();await expect(dialog).toBeVisible();expect(writes).toBe(1);
 await expect(page.getByText('草稿已保存',{exact:true})).toHaveCount(0);
});

for(const width of [320,390,768,1280])test(`points hub three modes and repeat spins ${width}`,async({page})=>{
 await page.setViewportSize({width,height:900});await page.emulateMedia({reducedMotion:'reduce'});
 await page.addInitScript(()=>{localStorage.setItem('h5_token','local-only');localStorage.setItem('h5-auth',JSON.stringify({state:{token:'local-only',role:'customer',userId:99026},version:0}));});
 let balance=25;const entries:any[]=[];const keys:string[]=[];
 await page.route('**/api/v1/**',async r=>{const req=r.request(),u=new URL(req.url()),p=u.pathname;let data:any=[];
  if(p.endsWith('/join')){const b=req.postDataJSON();expect(b.expectedPoints).toBe(10);expect(b.requestKey).toBeTruthy();keys.push(b.requestKey);balance-=10;const e={id:entries.length+1,campaignId:4,prizeId:11,prizeName:'平安香囊',outcome:'won',code:`TEST-${entries.length+1}`,createdAt:now,pointsSpent:10,title:campaign.title};entries.push(e);data=e;}
  else if(p.endsWith('/points'))data={balance};
  else if(p.endsWith('/campaigns'))data=u.searchParams.get('kind')==='wheel'?[campaign]:[];
  else if(p.endsWith('/campaigns/4'))data={campaign,mine:entries.at(-1)||null,winners:entries,pointsBalance:balance};
  else if(p.endsWith('/entries'))data=entries;
  await r.fulfill({json:{code:0,data}});
 });
 await page.goto('http://127.0.0.1:5386/c/points');
 for(const name of ['积分转盘','积分商城','奖池'])await expect(page.getByRole('tab',{name,exact:true})).toBeVisible();
 await expect(page.locator('[data-slot-index]')).toHaveCount(10);
 await page.getByRole('button',{name:'10 积分转一次',exact:true}).click();await page.getByRole('button',{name:'确认扣除 10 积分'}).click();
 const result=page.getByRole('dialog',{name:'参与结果'});await expect(result).toContainText('恭喜中奖');
 await result.getByRole('button',{name:'再转一次 · 10 积分'}).click();await page.getByRole('button',{name:'确认扣除 10 积分'}).click();
 await expect(result).toContainText('恭喜中奖');await result.getByRole('button',{name:'关闭',exact:true}).click();
 expect(keys).toHaveLength(2);expect(keys[0]).not.toBe(keys[1]);await expect(page.locator('.points-account-value')).toHaveText('5');await expect(page.getByRole('button',{name:'积分不足',exact:true})).toBeDisabled();
 await page.getByRole('link',{name:'抽奖记录',exact:true}).click();await expect(page.locator('.reward-entry-row')).toHaveCount(2);
 await page.getByRole('button',{name:'返回',exact:true}).click();await expect(page.getByRole('tab',{name:'积分转盘',exact:true})).toBeVisible();
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBeTruthy();
});
