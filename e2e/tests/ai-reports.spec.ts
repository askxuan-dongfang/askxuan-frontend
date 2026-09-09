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
 await page.locator('.ai-topic-grid a').first().click();await expect(page.getByRole('heading',{name:'八字命理',exact:true})).toBeVisible();await expect(page.getByRole('button',{name:'新建问事',exact:true})).toBeHidden();await page.screenshot({path:`/private/tmp/askxuan-ai-topic-top-${width}.png`,fullPage:true});await page.getByRole('link',{name:'返回问事',exact:true}).click();await expect(page.getByPlaceholder('输入你的问题，直接开始问事')).toHaveValue('保留我的聊天草稿');await page.locator('.ai-topic-grid a').first().click();await page.getByLabel('出生日期').fill('1995-06-15');await page.getByLabel('最想了解的问题').fill('如何理解我的职业方向？');await page.screenshot({path:`/private/tmp/askxuan-ai-topic-${width}.png`,fullPage:true});await page.getByRole('button',{name:'生成免费摘要'}).click();
 await expect(page.getByRole('heading',{name:'先看核心线索'})).toBeVisible();expect(created.skillCode).toBe('bazi');expect(created.requestKey.length).toBeGreaterThan(8);await expect(page.getByText('这是一份用于界面验收的报告示例。')).toHaveCount(0);
 await page.getByRole('button',{name:'解锁完整报告',exact:true}).click();await page.getByRole('button',{name:'暂不购买'}).click();expect(charges).toBe(0);
 await page.screenshot({path:`/private/tmp/askxuan-ai-preview-${width}.png`,fullPage:true});await page.getByRole('button',{name:'解锁完整报告',exact:true}).click();await page.getByRole('button',{name:'确认扣除积分并解锁'}).click();await expect(page.getByText('已解锁 · 可重复阅读')).toBeVisible();expect(charges).toBe(1);await page.screenshot({path:`/private/tmp/askxuan-ai-unlocked-${width}.png`,fullPage:true});
 expect(await page.locator('.ai-report-workspace').evaluate(el=>el.scrollWidth<=el.clientWidth)).toBeTruthy();await page.reload();await expect(page.getByText('已解锁 · 可重复阅读')).toBeVisible();expect(charges).toBe(1);
 await page.getByRole('link',{name:'返回问事',exact:true}).click();await expect(page.getByText('今天想问什么？')).toBeVisible();
});
