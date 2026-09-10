import { test, expect } from '@playwright/test';
const codes=['bazi','ziwei','marriage','fengshui','liuyao','qimen','tarot'];const names=['八字命理','紫微斗数','姻缘合盘','风水布局','六爻占卜','奇门遁甲','塔罗指引'];
const topics=codes.map((code,i)=>({code,title:names[i],subtitle:'从个人资料出发，理解性格与人生议题',priceCents:990,pointsPrice:10,chapters:['资料与分析边界','性格与优势','事业与发展','关系与相处','行动与复盘'],version:'1.0'}));
const skills=[{code:'general',name:'综合问事',inputSchema:{fields:[]}},...topics.map(t=>({code:t.code,name:t.title,inputSchema:{fields:[{key:'birthDate',label:'出生日期',type:'date',required:true}]}}))];
for(const width of [375,430,768])test(`topic preview purchase and preserved chat ${width}`,async({page})=>{
 await page.setViewportSize({width,height:900});await page.addInitScript(()=>{localStorage.setItem('h5_token','test');localStorage.setItem('h5-auth',JSON.stringify({state:{role:'customer',token:'test',userId:1,displayName:'测试'},version:0}));});
 let paid=false,charges=0,created:any;let report:any={id:1,reportNo:'AR-DEMO',skillCode:'bazi',title:'八字命理',question:'如何理解我的职业方向？',version:'1.0',chapters:topics[0].chapters,priceCents:990,pointsPrice:10,status:'ready',summary:'您关注的是职业方向与自身优势之间的匹配。本报告将从已有资料出发，分别梳理优势、关系和实际行动，并明确资料不足的部分。',createdAt:'2026-09-09 20:00'};
 await page.route('**/api/v1/**',async route=>{const req=route.request(),path=new URL(req.url()).pathname;let data:any={};
 if(path.endsWith('/ai/skills'))data={list:skills};else if(path.endsWith('/ai/topics'))data=topics;else if(path.endsWith('/ai/sessions'))data={list:[],total:0};else if(path==='/api/v1/points')data={balance:paid?10:20};
 else if(path.endsWith('/ai/reports')&&req.method()==='POST'){created=req.postDataJSON();data={...report,unlocked:false,content:''};}
 else if(path.endsWith('/ai/reports/1'))data={...report,unlocked:paid,content:paid?'## 资料与分析边界\n这是一份用于界面验收的报告示例。\n## 性格与优势\n把长期兴趣与已经掌握的技能分别记录，识别相互重叠的领域。\n## 行动与复盘\n制定一周行动计划，并通过实际反馈调整方向。':''};
 else if(path.endsWith('/ai/reports'))data=[report];else if(path.endsWith('/payments/ai-report')){charges++;paid=true;data={unlocked:true};}
 await route.fulfill({json:{code:0,message:'ok',data}});
 });
 await page.goto('http://127.0.0.1:5382/c/ai');await expect(page.getByText('一事一解，自有章法')).toBeVisible();await expect(page.locator('.ai-topic-grid a')).toHaveCount(7);
 await page.getByPlaceholder('输入你的问题，直接开始问事').fill('保留我的聊天草稿');await page.screenshot({path:`/private/tmp/askxuan-ai-home-${width}.png`,fullPage:true});
 await page.locator('.ai-topic-grid a').first().click();await expect(page.getByRole('heading',{name:'八字命理',exact:true})).toBeVisible();await expect(page.getByRole('button',{name:'新建问事',exact:true})).toBeHidden();await page.screenshot({path:`/private/tmp/askxuan-ai-topic-top-${width}.png`,fullPage:true});await page.getByRole('link',{name:'返回问事',exact:true}).click();await expect(page.getByPlaceholder('输入你的问题，直接开始问事')).toHaveValue('保留我的聊天草稿');await page.locator('.ai-topic-grid a').first().click();await page.getByLabel('出生日期').fill('1995-06-15');await page.getByRole('button',{name:'下一步，说说问题'}).click();await page.getByLabel('最想了解的问题').fill('如何理解我的职业方向？');await page.screenshot({path:`/private/tmp/askxuan-ai-topic-${width}.png`,fullPage:true});await page.getByRole('button',{name:'生成免费摘要'}).click();
 await expect(page.getByRole('heading',{name:'先看核心线索'})).toBeVisible();expect(created.skillCode).toBe('bazi');expect(created.requestKey.length).toBeGreaterThan(8);await expect(page.getByText('这是一份用于界面验收的报告示例。')).toHaveCount(0);
 await page.getByRole('button',{name:'解锁完整报告',exact:true}).click();await page.getByRole('button',{name:'暂不购买'}).click();expect(charges).toBe(0);
 await page.screenshot({path:`/private/tmp/askxuan-ai-preview-${width}.png`,fullPage:true});await page.getByRole('button',{name:'解锁完整报告',exact:true}).click();await page.getByRole('button',{name:'确认扣除积分并解锁'}).click();await expect(page.getByText('已解锁 · 可重复阅读')).toBeVisible();expect(charges).toBe(1);await page.screenshot({path:`/private/tmp/askxuan-ai-unlocked-${width}.png`,fullPage:true});
 expect(await page.locator('.ai-report-workspace').evaluate(el=>el.scrollWidth<=el.clientWidth)).toBeTruthy();await page.reload();await expect(page.getByText('已解锁 · 可重复阅读')).toBeVisible();expect(charges).toBe(1);
 await page.getByRole('link',{name:'返回问事',exact:true}).click();await expect(page.getByText('今天想问什么？')).toBeVisible();
});

async function signIn(page:any) { await page.addInitScript(()=>{localStorage.setItem('h5_token','fixture');localStorage.setItem('h5-auth',JSON.stringify({state:{role:'customer',token:'fixture',userId:1,displayName:'验收'},version:0}));}); }
test('all seven guided topics, native validation, suggestions and reduced motion',async({page})=>{
 await signIn(page);await page.setViewportSize({width:320,height:850});await page.emulateMedia({reducedMotion:'reduce'});
 await page.route('**/api/v1/**',route=>{const path=new URL(route.request().url()).pathname;const data=path.endsWith('/ai/skills')?{list:skills}:path.endsWith('/ai/topics')?topics:path.endsWith('/points')?{balance:20}:{list:[],total:0};return route.fulfill({json:{code:0,data}});});
 for(const [i,code] of codes.entries()){
  await page.goto(`http://127.0.0.1:5382/c/ai/topics/${code}`);
  await expect(page.getByRole('heading',{name:names[i],exact:true})).toBeVisible();
  await page.getByRole('button',{name:'下一步，说说问题'}).click();await expect(page.getByLabel('出生日期')).toBeVisible();
  await page.getByLabel('出生日期').fill('1995-06-15');await page.getByRole('button',{name:'下一步，说说问题'}).click();
  await page.locator('.ai-question-prompts button').first().click();await expect(page.getByLabel('最想了解的问题')).not.toHaveValue('');
  await page.getByRole('button',{name:'修改资料'}).click();await expect(page.getByLabel('出生日期')).toHaveValue('1995-06-15');
  expect(await page.locator('.ai-report-workspace .art-motif').evaluate(el=>getComputedStyle(el).animationName)).toBe('none');
  expect(await page.locator('.ai-report-workspace').evaluate(el=>el.scrollWidth<=el.clientWidth)).toBeTruthy();
  await page.screenshot({path:`/private/tmp/ai-redesign-topic-${code}-320.png`,fullPage:true});
 }
});
test('generating, failed retry, insufficient balance and readable report navigation',async({page})=>{
 await signIn(page);let status='generating',paid=false,charges=0;
 await page.route('**/api/v1/**',route=>{const path=new URL(route.request().url()).pathname;let data:any={list:[],total:0};
  if(path.endsWith('/ai/reports/4/retry')){status='ready';data={id:4,skillCode:'tarot',title:'塔罗指引',status,summary:'真实返回摘要',pointsPrice:10,chapters:['内心关注'],unlocked:paid,content:''};}
  else if(path.endsWith('/ai/reports/4'))data={id:4,reportNo:'FIXTURE',skillCode:'tarot',title:'塔罗指引',status,summary:'真实返回摘要',pointsPrice:10,chapters:['内心关注'],unlocked:paid,content:paid?'## 内心关注\n**加粗内容**与正文\n<script>不执行</script>\n## 行动\n记录真实反馈':''};
  else if(path.endsWith('/points'))data={balance:5};else if(path.endsWith('/ai/topics'))data=topics;else if(path.endsWith('/ai/skills'))data={list:skills};else if(path.endsWith('/payments/ai-report')){charges++;data={};}
  return route.fulfill({json:{code:0,data}});
 });
 await page.goto('http://127.0.0.1:5382/c/ai/reports/4');await expect(page.getByText('报告生成中 · 尚未扣除积分')).toBeVisible();await page.screenshot({path:'/private/tmp/ai-redesign-generating.png'});
 status='failed';await page.reload();await page.getByRole('button',{name:'免费重试'}).click();await expect(page.getByText('还差 5 积分，摘要已为您保留。')).toBeVisible();expect(charges).toBe(0);
 paid=true;await page.reload();await page.getByText('章节导航',{exact:true}).click();await page.getByRole('link',{name:'行动',exact:true}).click();await expect(page.getByRole('heading',{name:'行动',exact:true})).toBeVisible();await page.getByRole('button',{name:'Aa · 放大字号'}).click();await expect(page.locator('.ai-report-prose')).toHaveClass(/large-type/);await expect(page.locator('.ai-report-prose script')).toHaveCount(0);
});
test('history delete cancel, failure, current and noncurrent; stale list cannot restore deletion',async({page})=>{
 await signIn(page);const rows=[{id:101,title:'验收当前会话',skillCode:'general',status:'active',updatedAt:'2026-09-10'},{id:102,title:'验收其他会话',skillCode:'general',status:'active',updatedAt:'2026-09-10'}];let deletes:number[]=[],fail=true;
 await page.route('**/api/v1/**',async route=>{const req=route.request(),path=new URL(req.url()).pathname;let data:any={};
  if(req.method()==='DELETE'){const id=Number(path.split('/').pop());deletes.push(id);if(fail){await route.fulfill({json:{code:500,message:'删除失败，请重试'}});return;}data={id};}
  else if(path.endsWith('/ai/sessions'))data={list:rows,total:2};
  else if(path.endsWith('/ai/skills'))data={list:skills};else if(path.endsWith('/ai/topics'))data=topics;
  else if(path.endsWith('/messages'))data={list:[{id:1,sessionId:101,role:'assistant',content:'需要保留的当前消息',status:'completed'}]};
  await route.fulfill({json:{code:0,data}});
 });
 await page.goto('http://127.0.0.1:5382/c/ai');await expect(page.getByText('需要保留的当前消息')).toBeVisible();await page.getByRole('button',{name:'历史问事',exact:true}).click();await page.screenshot({path:'/private/tmp/ai-redesign-history.png'});
 await page.getByRole('button',{name:'删除会话：验收其他会话'}).click();await page.getByRole('button',{name:'保留会话'}).click();expect(deletes.length).toBe(0);
 await page.getByRole('button',{name:'删除会话：验收其他会话'}).click();await page.getByRole('button',{name:'确认删除',exact:true}).click();await expect(page.getByRole('alert')).toHaveText('删除失败，请重试');fail=false;
 await page.getByRole('button',{name:'确认删除',exact:true}).click();await expect(page.getByRole('button',{name:'删除会话：验收其他会话'})).toHaveCount(0);
 await page.getByRole('button',{name:'关闭历史问事'}).click();await expect(page.getByText('需要保留的当前消息')).toBeVisible();
 await page.getByRole('button',{name:'历史问事',exact:true}).click();await page.getByRole('button',{name:'删除会话：验收当前会话'}).click();await page.getByRole('button',{name:'确认删除',exact:true}).click();await expect(page.getByText('暂无历史问事')).toBeVisible();await page.getByRole('button',{name:'关闭历史问事'}).click();await expect(page.getByText('需要保留的当前消息')).toHaveCount(0);await expect(page.getByPlaceholder('输入你的问题，直接开始问事')).toHaveValue('');
 expect(deletes).toEqual([102,102,101]);
});

test('deleting current chat suppresses late message response and animations actually move',async({page})=>{
 await signIn(page);let releaseMessage:()=>void=()=>{};const delayed=new Promise<void>(resolve=>{releaseMessage=resolve;});
 await page.route('**/api/v1/**',async route=>{const req=route.request(),path=new URL(req.url()).pathname;let data:any={};
  if(path.endsWith('/ai/sessions')&&req.method()==='GET')data={list:[{id:301,title:'待返回会话',skillCode:'general',status:'active'}]};
  else if(path.endsWith('/ai/sessions/301')&&req.method()==='DELETE')data={id:301};
  else if(path.endsWith('/messages')){await delayed;data={list:[{id:9,sessionId:301,role:'assistant',content:'迟到的已删除消息',status:'completed'}]};}
  else if(path.endsWith('/ai/topics'))data=topics;else if(path.endsWith('/ai/skills'))data={list:skills};
  try{await route.fulfill({json:{code:0,data}});}catch{}
 });
 await page.goto('http://127.0.0.1:5382/c/ai');await page.getByRole('button',{name:'历史问事',exact:true}).click();await page.getByRole('button',{name:'删除会话：待返回会话'}).click();await page.getByRole('button',{name:'确认删除',exact:true}).click();await expect(page.getByText('暂无历史问事')).toBeVisible();releaseMessage();await page.getByRole('button',{name:'关闭历史问事'}).click();await expect(page.getByText('迟到的已删除消息')).toHaveCount(0);
 const motif=page.locator('.ai-topic-grid .art-motif').first();await expect(motif).toBeVisible();const before=await motif.evaluate(el=>getComputedStyle(el).transform);await expect.poll(()=>motif.evaluate(el=>getComputedStyle(el).transform)).not.toBe(before);
});
